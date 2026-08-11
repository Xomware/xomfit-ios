-- Cardio sessions
--
-- Kept in its own table rather than folded into `workouts`. A workout is a list
-- of exercises with sets; cardio has no sets, and the two share almost no
-- columns — merging them would mean every strength row carrying nil distance,
-- pace and elevation, and every cardio row carrying an empty exercise list.

CREATE TABLE IF NOT EXISTS cardio_sessions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    modality            TEXT NOT NULL,
    start_time          TIMESTAMPTZ NOT NULL,
    end_time            TIMESTAMPTZ NOT NULL,
    -- Moving time, which is what pace is computed from. Falls back to elapsed
    -- time when the source does not distinguish the two.
    duration_seconds    DOUBLE PRECISION NOT NULL,
    distance_miles      DOUBLE PRECISION,
    active_calories     DOUBLE PRECISION,
    average_heart_rate  DOUBLE PRECISION,
    max_heart_rate      DOUBLE PRECISION,
    elevation_gain_feet DOUBLE PRECISION,
    notes               TEXT,
    -- Set when imported from Apple Health rather than logged by hand. Garmin,
    -- Whoop and Polar all write to Health, so this covers every wearable
    -- without a per-vendor integration.
    healthkit_uuid      TEXT,
    source_name         TEXT,
    created_at          TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE cardio_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can CRUD own cardio sessions" ON cardio_sessions
    FOR ALL USING (user_id = auth.uid());

-- Importing is re-run every time the user opens the cardio tab, so the same
-- Health workout must not land twice. Partial, because hand-logged sessions
-- have no UUID and any number of them may coexist.
CREATE UNIQUE INDEX IF NOT EXISTS idx_cardio_sessions_healthkit
    ON cardio_sessions (user_id, healthkit_uuid)
    WHERE healthkit_uuid IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_cardio_sessions_user_time
    ON cardio_sessions (user_id, start_time DESC);

-- Guard against a client typo silently creating a modality nothing can render.
-- Listed explicitly rather than left open: the set is closed by design, since
-- pace only means something when you know whether it was a run or a row.
ALTER TABLE cardio_sessions
    ADD CONSTRAINT cardio_sessions_modality_check
    CHECK (modality IN (
        'outdoorRun', 'indoorRun', 'outdoorWalk', 'indoorWalk', 'hike',
        'row', 'outdoorBike', 'indoorBike', 'stairMaster', 'elliptical'
    ));

-- A session that ends before it starts is data corruption, and a zero-length
-- one makes pace infinite.
ALTER TABLE cardio_sessions
    ADD CONSTRAINT cardio_sessions_duration_check
    CHECK (end_time > start_time AND duration_seconds > 0);
