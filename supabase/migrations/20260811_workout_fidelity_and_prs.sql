-- Workout persistence fidelity + PR engine rebuild
--
-- Two independent data-loss bugs are fixed here:
--
-- 1. `workout_exercises` and `workout_sets` had no columns for fields the client
--    model has always carried, so every save silently discarded them. Most
--    damaging is `weight_mode`: a set logged as 25 lb *per side* round-tripped
--    as 25 lb total, halving the recorded volume.
--
-- 2. `personal_records` was created with `achieved_at` / `previous_weight`, but
--    the client has always written `date` / `previous_best`. Every PR insert
--    failed with an undefined-column error that PRService swallowed, so no PR
--    has ever been persisted. Rather than add the client's names, the client is
--    being moved onto these canonical names; this migration only guarantees the
--    canonical columns exist and relaxes any hand-patched legacy columns so
--    inserts that omit them still succeed.

-- ---------------------------------------------------------------------------
-- 1. workout_exercises — restore the dropped variant/config fields
-- ---------------------------------------------------------------------------

ALTER TABLE workout_exercises
    ADD COLUMN IF NOT EXISTS selected_grip        TEXT,
    ADD COLUMN IF NOT EXISTS selected_attachment  TEXT,
    ADD COLUMN IF NOT EXISTS selected_position    TEXT,
    ADD COLUMN IF NOT EXISTS selected_laterality  TEXT NOT NULL DEFAULT 'bilateral',
    ADD COLUMN IF NOT EXISTS superset_group_id    UUID,
    ADD COLUMN IF NOT EXISTS rest_seconds         INT,
    ADD COLUMN IF NOT EXISTS notes                TEXT;

-- Supersets are resolved by grouping on this within a workout.
CREATE INDEX IF NOT EXISTS idx_workout_exercises_superset
    ON workout_exercises (workout_id, superset_group_id)
    WHERE superset_group_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 2. workout_sets — restore weight mode, drop sets, form-check video
-- ---------------------------------------------------------------------------

ALTER TABLE workout_sets
    ADD COLUMN IF NOT EXISTS weight_mode  TEXT NOT NULL DEFAULT 'total',
    ADD COLUMN IF NOT EXISTS is_drop_set  BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS video_url    TEXT;

-- Guard against typos from the client; the app only ever sends these two.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'workout_sets_weight_mode_check'
    ) THEN
        ALTER TABLE workout_sets
            ADD CONSTRAINT workout_sets_weight_mode_check
            CHECK (weight_mode IN ('total', 'perSide'));
    END IF;
END $$;

-- Existing rows predate the column and were all logged as total. The DEFAULT
-- already covers them; this is only here to make the intent explicit for anyone
-- reading the history and wondering whether a backfill was skipped by mistake.
-- (No UPDATE needed — NOT NULL DEFAULT backfills in place.)

-- ---------------------------------------------------------------------------
-- 3. personal_records — canonical columns, e1RM ranking, variant segmentation
-- ---------------------------------------------------------------------------

-- Guarantee the canonical columns exist regardless of which of the two
-- historical migration files this project was actually bootstrapped from.
ALTER TABLE personal_records
    ADD COLUMN IF NOT EXISTS achieved_at     TIMESTAMPTZ DEFAULT now(),
    ADD COLUMN IF NOT EXISTS previous_weight DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS previous_reps   INT;

-- PRs are now ranked on estimated 1RM so that a heavier-but-fewer-reps set and a
-- lighter-but-more-reps set are actually comparable. `kind` distinguishes the
-- all-rep-ranges e1RM record from the per-rep-range weight record, which is
-- still worth keeping ("best ever 5-rep set").
ALTER TABLE personal_records
    ADD COLUMN IF NOT EXISTS estimated_1rm       DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS previous_1rm        DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS kind                TEXT NOT NULL DEFAULT 'e1rm',
    ADD COLUMN IF NOT EXISTS weight_mode         TEXT NOT NULL DEFAULT 'total',
    ADD COLUMN IF NOT EXISTS selected_grip       TEXT,
    ADD COLUMN IF NOT EXISTS selected_attachment TEXT,
    ADD COLUMN IF NOT EXISTS selected_laterality TEXT NOT NULL DEFAULT 'bilateral',
    -- Stable identity for "this exercise performed this way". Rope pushdowns and
    -- straight-bar pushdowns are different lifts and should not share a record.
    ADD COLUMN IF NOT EXISTS variant_key         TEXT,
    ADD COLUMN IF NOT EXISTS workout_id          UUID REFERENCES workouts(id) ON DELETE SET NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'personal_records_kind_check'
    ) THEN
        ALTER TABLE personal_records
            ADD CONSTRAINT personal_records_kind_check
            CHECK (kind IN ('e1rm', 'rep_range'));
    END IF;
END $$;

-- If this database was hand-patched at some point to carry the client's old
-- `date` / `previous_best` names, they may be NOT NULL. The rewritten client no
-- longer sends them, so relax them rather than fail every insert.
DO $$
DECLARE
    legacy_col TEXT;
BEGIN
    FOREACH legacy_col IN ARRAY ARRAY['date', 'previous_best'] LOOP
        IF EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name = 'personal_records' AND column_name = legacy_col
        ) THEN
            EXECUTE format('ALTER TABLE personal_records ALTER COLUMN %I DROP NOT NULL', legacy_col);
        END IF;
    END LOOP;

    -- `date` additionally needs a default, since it is the one legacy column
    -- likely to be part of a legacy NOT NULL primary-ish constraint.
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'personal_records' AND column_name = 'date'
    ) THEN
        EXECUTE 'ALTER TABLE personal_records ALTER COLUMN date SET DEFAULT now()';
    END IF;
END $$;

-- Backfill: every pre-existing row is a per-rep-range weight record, since e1RM
-- ranking did not exist when it was written. Compute its e1RM with the same
-- Epley formula the client uses so old records rank alongside new ones.
UPDATE personal_records
SET kind          = 'rep_range',
    estimated_1rm = CASE
                        WHEN reps <= 1 THEN weight
                        ELSE weight * (1.0 + reps::double precision / 30.0)
                    END,
    variant_key   = exercise_id
WHERE estimated_1rm IS NULL;

-- The unique indexes below cannot be created while duplicate historical rows
-- exist. The old client appended a new row per PR event rather than updating a
-- current-record row, so a user could hold several rows for the same
-- exercise + rep count. Collapse each group down to its best effort, keeping the
-- heaviest (then most recent) and deleting the rest.
--
-- In practice this table is expected to be empty or near-empty, since the
-- undefined-column bug meant inserts never succeeded — but a project whose DB
-- was hand-patched at some point may well have rows, and a migration that only
-- works on an empty table is not a migration.
DELETE FROM personal_records pr
USING (
    SELECT id,
           row_number() OVER (
               -- Mirrors the two partial indexes below exactly: reps is part of
               -- the key for rep_range records but not for e1rm ones.
               PARTITION BY user_id, variant_key, kind,
                            (CASE WHEN kind = 'e1rm' THEN NULL ELSE reps END)
               ORDER BY weight DESC, achieved_at DESC NULLS LAST, id
           ) AS rn
    FROM personal_records
) dupes
WHERE pr.id = dupes.id AND dupes.rn > 1;

-- Two different uniqueness rules, so two partial indexes rather than one shared
-- one. An e1RM record is the single best effort at *any* rep count, so reps must
-- NOT be part of its key — including it would let one variant accumulate a
-- separate "e1RM record" per rep count, which is the exact bug being fixed.
-- A rep-range record is by definition one per rep count.
--
-- These let the client upsert instead of read-then-insert, which also removes
-- the race where two devices finishing a workout at once both write a new PR.
CREATE UNIQUE INDEX IF NOT EXISTS idx_personal_records_e1rm_current
    ON personal_records (user_id, variant_key)
    WHERE kind = 'e1rm';

CREATE UNIQUE INDEX IF NOT EXISTS idx_personal_records_rep_range_current
    ON personal_records (user_id, variant_key, reps)
    WHERE kind = 'rep_range';

CREATE INDEX IF NOT EXISTS idx_personal_records_lookup
    ON personal_records (user_id, exercise_id, achieved_at DESC);
