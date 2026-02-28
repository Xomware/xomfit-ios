-- ============================================================
-- Form Check Videos — attach short clips to logged workout sets
-- ============================================================

-- Enum for video visibility
CREATE TYPE video_visibility AS ENUM ('private', 'friends', 'public');

-- Main table
CREATE TABLE IF NOT EXISTS form_check_videos (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    set_id            TEXT NOT NULL,           -- local set ID from the app
    exercise_id       TEXT NOT NULL,
    exercise_name     TEXT NOT NULL,
    video_remote_url  TEXT,                    -- Supabase Storage URL after upload
    duration_seconds  DOUBLE PRECISION NOT NULL DEFAULT 0,
    weight            DOUBLE PRECISION NOT NULL DEFAULT 0,
    reps              INTEGER NOT NULL DEFAULT 0,
    visibility        video_visibility NOT NULL DEFAULT 'private',
    is_public         BOOLEAN NOT NULL DEFAULT FALSE,
    likes             INTEGER NOT NULL DEFAULT 0,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Comments on form check videos
CREATE TABLE IF NOT EXISTS form_check_comments (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    video_id   UUID NOT NULL REFERENCES form_check_videos(id) ON DELETE CASCADE,
    user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    text       TEXT NOT NULL CHECK (char_length(text) BETWEEN 1 AND 500),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Likes table (to prevent double-liking)
CREATE TABLE IF NOT EXISTS form_check_likes (
    video_id   UUID NOT NULL REFERENCES form_check_videos(id) ON DELETE CASCADE,
    user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (video_id, user_id)
);

-- Indexes
CREATE INDEX idx_form_check_videos_user_id     ON form_check_videos(user_id);
CREATE INDEX idx_form_check_videos_set_id      ON form_check_videos(set_id);
CREATE INDEX idx_form_check_videos_visibility  ON form_check_videos(visibility);
CREATE INDEX idx_form_check_comments_video_id  ON form_check_comments(video_id);

-- updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_form_check_videos_updated_at
    BEFORE UPDATE ON form_check_videos
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- Row Level Security
-- ============================================================

ALTER TABLE form_check_videos  ENABLE ROW LEVEL SECURITY;
ALTER TABLE form_check_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE form_check_likes   ENABLE ROW LEVEL SECURITY;

-- form_check_videos policies

-- Owner can see all their own videos
CREATE POLICY "users_own_videos" ON form_check_videos
    FOR ALL USING (auth.uid() = user_id);

-- Friends can see 'friends' visibility videos (requires a friends/follows table)
CREATE POLICY "friends_can_view" ON form_check_videos
    FOR SELECT USING (
        visibility = 'friends'
        AND EXISTS (
            SELECT 1 FROM friendships
            WHERE status = 'accepted'
              AND (
                (requester_id = auth.uid() AND addressee_id = form_check_videos.user_id)
                OR
                (addressee_id = auth.uid() AND requester_id = form_check_videos.user_id)
              )
        )
    );

-- Anyone can see 'public' videos
CREATE POLICY "public_videos_viewable" ON form_check_videos
    FOR SELECT USING (visibility = 'public');

-- form_check_comments policies
CREATE POLICY "comments_visible_with_video" ON form_check_comments
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM form_check_videos v
            WHERE v.id = form_check_comments.video_id
        )
    );

CREATE POLICY "users_can_comment" ON form_check_comments
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_delete_own_comments" ON form_check_comments
    FOR DELETE USING (auth.uid() = user_id);

-- form_check_likes policies
CREATE POLICY "likes_visible" ON form_check_likes
    FOR SELECT USING (TRUE);

CREATE POLICY "users_can_like" ON form_check_likes
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_can_unlike" ON form_check_likes
    FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- Supabase Storage bucket (run this manually in the dashboard
-- or via the storage API, not possible in SQL migrations):
--
--   Bucket name: form-check-videos
--   Public: false (videos are private by default)
--   File size limit: 50 MB
--   Allowed MIME types: video/mp4, video/quicktime
-- ============================================================
