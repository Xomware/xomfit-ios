-- ============================================
-- XOMFIT: ALL TABLES — Run this ONCE in Supabase SQL Editor
-- ============================================

-- ============================================
-- 1. PROFILES
-- ============================================
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE,
    display_name TEXT,
    avatar_url TEXT,
    bio TEXT DEFAULT '',
    is_private BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read any public profile" ON profiles
    FOR SELECT USING (NOT is_private OR id = auth.uid());

CREATE POLICY "Users can update own profile" ON profiles
    FOR UPDATE USING (id = auth.uid());

CREATE POLICY "Users can insert own profile" ON profiles
    FOR INSERT WITH CHECK (id = auth.uid());

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO profiles (id, username, display_name)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
        COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1))
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================
-- 2. FRIENDSHIPS
-- ============================================
CREATE TABLE IF NOT EXISTS friendships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    addressee_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined', 'blocked')),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(requester_id, addressee_id)
);

ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can see own friendships" ON friendships
    FOR SELECT USING (requester_id = auth.uid() OR addressee_id = auth.uid());

CREATE POLICY "Users can send friend requests" ON friendships
    FOR INSERT WITH CHECK (requester_id = auth.uid());

CREATE POLICY "Users can update friendships addressed to them" ON friendships
    FOR UPDATE USING (addressee_id = auth.uid() OR requester_id = auth.uid());

CREATE POLICY "Users can delete own friendships" ON friendships
    FOR DELETE USING (requester_id = auth.uid() OR addressee_id = auth.uid());

-- ============================================
-- 3. WORKOUTS
-- ============================================
CREATE TABLE IF NOT EXISTS workouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE workouts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can CRUD own workouts" ON workouts
    FOR ALL USING (user_id = auth.uid());

-- ============================================
-- 4. WORKOUT EXERCISES
-- ============================================
CREATE TABLE IF NOT EXISTS workout_exercises (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workout_id UUID NOT NULL REFERENCES workouts(id) ON DELETE CASCADE,
    exercise_id TEXT NOT NULL,
    exercise_name TEXT NOT NULL,
    sort_order INT NOT NULL DEFAULT 0
);

ALTER TABLE workout_exercises ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can CRUD own workout exercises" ON workout_exercises
    FOR ALL USING (workout_id IN (SELECT id FROM workouts WHERE user_id = auth.uid()));

-- ============================================
-- 5. WORKOUT SETS
-- ============================================
CREATE TABLE IF NOT EXISTS workout_sets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workout_exercise_id UUID NOT NULL REFERENCES workout_exercises(id) ON DELETE CASCADE,
    set_number INT NOT NULL DEFAULT 1,
    weight DOUBLE PRECISION NOT NULL DEFAULT 0,
    reps INT NOT NULL DEFAULT 0,
    rpe DOUBLE PRECISION,
    is_completed BOOLEAN DEFAULT false,
    is_pr BOOLEAN DEFAULT false,
    completed_at TIMESTAMPTZ
);

ALTER TABLE workout_sets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can CRUD own workout sets" ON workout_sets
    FOR ALL USING (workout_exercise_id IN (
        SELECT we.id FROM workout_exercises we
        JOIN workouts w ON w.id = we.workout_id
        WHERE w.user_id = auth.uid()
    ));

-- ============================================
-- 6. PERSONAL RECORDS
-- ============================================
CREATE TABLE IF NOT EXISTS personal_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    exercise_id TEXT NOT NULL,
    exercise_name TEXT NOT NULL,
    weight DOUBLE PRECISION NOT NULL,
    reps INT NOT NULL,
    previous_weight DOUBLE PRECISION,
    previous_reps INT,
    improvement_pct DOUBLE PRECISION,
    workout_id UUID REFERENCES workouts(id) ON DELETE SET NULL,
    achieved_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE personal_records ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own PRs" ON personal_records
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can insert own PRs" ON personal_records
    FOR INSERT WITH CHECK (user_id = auth.uid());

-- ============================================
-- 7. FEED ITEMS
-- ============================================
CREATE TABLE IF NOT EXISTS feed_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    activity_type TEXT NOT NULL CHECK (activity_type IN ('workout', 'personal_record', 'milestone', 'streak')),
    caption TEXT,
    visibility TEXT NOT NULL DEFAULT 'everyone' CHECK (visibility IN ('friends', 'followers', 'everyone')),
    payload JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE feed_items ENABLE ROW LEVEL SECURITY;

-- Simplified RLS: users see their own + everyone-visible + accepted friends' posts
CREATE POLICY "Users can read visible feed items" ON feed_items
    FOR SELECT USING (
        user_id = auth.uid()
        OR visibility = 'everyone'
        OR (visibility = 'friends' AND user_id IN (
            SELECT CASE
                WHEN requester_id = auth.uid() THEN addressee_id
                ELSE requester_id
            END
            FROM friendships
            WHERE status = 'accepted'
              AND (requester_id = auth.uid() OR addressee_id = auth.uid())
        ))
    );

CREATE POLICY "Users can insert own feed items" ON feed_items
    FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can delete own feed items" ON feed_items
    FOR DELETE USING (user_id = auth.uid());

-- ============================================
-- 8. FEED LIKES
-- ============================================
CREATE TABLE IF NOT EXISTS feed_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    feed_item_id UUID NOT NULL REFERENCES feed_items(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(feed_item_id, user_id)
);

ALTER TABLE feed_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own likes" ON feed_likes
    FOR ALL USING (user_id = auth.uid());

CREATE POLICY "Users can read all likes" ON feed_likes
    FOR SELECT USING (true);

-- ============================================
-- 9. FEED COMMENTS
-- ============================================
CREATE TABLE IF NOT EXISTS feed_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    feed_item_id UUID NOT NULL REFERENCES feed_items(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    text TEXT NOT NULL CHECK (char_length(text) > 0 AND char_length(text) <= 1000),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE feed_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read comments" ON feed_comments
    FOR SELECT USING (true);

CREATE POLICY "Users can insert comments" ON feed_comments
    FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can delete own comments" ON feed_comments
    FOR DELETE USING (user_id = auth.uid());

-- ============================================
-- 10. INDEXES
-- ============================================
CREATE INDEX IF NOT EXISTS idx_workouts_user_id ON workouts(user_id);
CREATE INDEX IF NOT EXISTS idx_workouts_start_time ON workouts(start_time DESC);
CREATE INDEX IF NOT EXISTS idx_workout_exercises_workout_id ON workout_exercises(workout_id);
CREATE INDEX IF NOT EXISTS idx_workout_sets_exercise_id ON workout_sets(workout_exercise_id);
CREATE INDEX IF NOT EXISTS idx_personal_records_user_id ON personal_records(user_id);
CREATE INDEX IF NOT EXISTS idx_personal_records_exercise ON personal_records(user_id, exercise_id);
CREATE INDEX IF NOT EXISTS idx_friendships_requester ON friendships(requester_id);
CREATE INDEX IF NOT EXISTS idx_friendships_addressee ON friendships(addressee_id);
CREATE INDEX IF NOT EXISTS idx_feed_items_user ON feed_items(user_id);
CREATE INDEX IF NOT EXISTS idx_feed_items_created ON feed_items(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feed_likes_feed_item ON feed_likes(feed_item_id);
CREATE INDEX IF NOT EXISTS idx_feed_comments_feed_item ON feed_comments(feed_item_id);
