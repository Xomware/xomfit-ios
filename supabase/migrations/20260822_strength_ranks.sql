-- Published strength ranks, so a lifter's ladder is visible on their profile.
--
-- Only the *tier* is stored, never the inputs. Ranking needs bodyweight, sex
-- and age; sex and age live in on-device storage and have never left the phone,
-- and bodyweight comes from body measurements, which are private. Publishing
-- the computed result keeps all three where they are — each lifter ranks
-- themselves on their own device and shares only the label.
--
-- Deliberately no weights here either. `personal_records` is private
-- (`user_id = auth.uid()`), and while the feed already broadcasts individual
-- PRs, this table is not the place to duplicate that. A tier says "Diamond
-- bench"; it does not say what they lifted.

CREATE TABLE IF NOT EXISTS user_strength_ranks (
    user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    exercise_id   TEXT NOT NULL,
    exercise_name TEXT NOT NULL,
    -- StrengthTier rawValue: 1 bronze .. 6 god. `unranked` (0) is never stored;
    -- the absence of a row is what "unranked" means.
    tier          SMALLINT NOT NULL CHECK (tier BETWEEN 1 AND 6),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, exercise_id)
);

ALTER TABLE user_strength_ranks ENABLE ROW LEVEL SECURITY;

-- Readable by any signed-in user: profiles are already viewable, and a tier is
-- less revealing than the PR posts the feed publishes.
CREATE POLICY "Strength ranks are readable" ON user_strength_ranks
    FOR SELECT USING (auth.uid() IS NOT NULL);

-- Writable only by the lifter they belong to. Ranks are computed on-device, so
-- nothing else has the inputs to write them anyway.
CREATE POLICY "Users write own strength ranks" ON user_strength_ranks
    FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users update own strength ranks" ON user_strength_ranks
    FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "Users delete own strength ranks" ON user_strength_ranks
    FOR DELETE USING (user_id = auth.uid());

CREATE INDEX IF NOT EXISTS idx_user_strength_ranks_user
    ON user_strength_ranks (user_id, tier DESC);
