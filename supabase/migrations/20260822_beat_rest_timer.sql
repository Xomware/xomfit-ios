-- Track whether a set was completed before its rest timer expired.
--
-- This exists so the "back under the bar" badge is a pure function of workout
-- history, like every other badge in the catalog. The alternative — a counter
-- in UserDefaults — would be unauditable, unrecoverable after a reinstall, and
-- would break the property that a badge can always be recomputed from what the
-- lifter actually logged.
--
-- Meaning: at the moment this set was marked complete, the rest timer started
-- by the PREVIOUS set was still running. Sets that skip rest entirely (drop-set
-- chains) are false, which is correct — there was no clock to beat.

ALTER TABLE workout_sets
    ADD COLUMN IF NOT EXISTS beat_rest_timer BOOLEAN NOT NULL DEFAULT false;

-- Existing rows predate the column. They are all false, which is honest: the
-- app was not recording this, so we do not know and must not guess. The badge
-- counts forward from here.
