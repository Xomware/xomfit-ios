-- Social Feed Schema Migration
-- Supports: workout posts, PR announcements, milestones, streaks

-- Feed items table
CREATE TABLE IF NOT EXISTS feed_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    activity_type TEXT NOT NULL CHECK (activity_type IN ('workout', 'personal_record', 'milestone', 'streak')),
    caption TEXT,
    visibility TEXT NOT NULL DEFAULT 'friends' CHECK (visibility IN ('friends', 'followers', 'everyone')),
    payload JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Feed likes
CREATE TABLE IF NOT EXISTS feed_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    feed_item_id UUID NOT NULL REFERENCES feed_items(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(feed_item_id, user_id)
);

-- Feed comments
CREATE TABLE IF NOT EXISTS feed_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    feed_item_id UUID NOT NULL REFERENCES feed_items(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    text TEXT NOT NULL CHECK (char_length(text) > 0 AND char_length(text) <= 1000),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Feed reports (for moderation)
CREATE TABLE IF NOT EXISTS feed_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    feed_item_id UUID NOT NULL REFERENCES feed_items(id) ON DELETE CASCADE,
    reporter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(feed_item_id, reporter_id)
);

-- Hidden items (user-level hide)
CREATE TABLE IF NOT EXISTS feed_hidden_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    feed_item_id UUID NOT NULL REFERENCES feed_items(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(feed_item_id, user_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_feed_items_user_id ON feed_items(user_id);
CREATE INDEX IF NOT EXISTS idx_feed_items_created_at ON feed_items(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feed_items_activity_type ON feed_items(activity_type);
CREATE INDEX IF NOT EXISTS idx_feed_likes_feed_item_id ON feed_likes(feed_item_id);
CREATE INDEX IF NOT EXISTS idx_feed_likes_user_id ON feed_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_feed_comments_feed_item_id ON feed_comments(feed_item_id);
CREATE INDEX IF NOT EXISTS idx_feed_hidden_items_user_id ON feed_hidden_items(user_id);

-- RLS Policies
ALTER TABLE feed_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE feed_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE feed_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE feed_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE feed_hidden_items ENABLE ROW LEVEL SECURITY;

-- Feed items: users can read friend/public posts, write own
CREATE POLICY "Users can read visible feed items" ON feed_items
    FOR SELECT USING (
        visibility = 'everyone'
        OR user_id = auth.uid()
        OR (visibility = 'friends' AND user_id IN (
            SELECT friend_id FROM friendships WHERE user_id = auth.uid() AND status = 'mutual'
            UNION
            SELECT user_id FROM friendships WHERE friend_id = auth.uid() AND status = 'mutual'
        ))
        OR (visibility = 'followers' AND user_id IN (
            SELECT friend_id FROM friendships WHERE user_id = auth.uid()
        ))
    );

CREATE POLICY "Users can insert own feed items" ON feed_items
    FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can delete own feed items" ON feed_items
    FOR DELETE USING (user_id = auth.uid());

-- Likes: anyone who can see the post can like it
CREATE POLICY "Users can manage own likes" ON feed_likes
    FOR ALL USING (user_id = auth.uid());

-- Comments: anyone who can see the post can comment
CREATE POLICY "Users can read comments" ON feed_comments
    FOR SELECT USING (true);

CREATE POLICY "Users can insert comments" ON feed_comments
    FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can delete own comments" ON feed_comments
    FOR DELETE USING (user_id = auth.uid());

-- Reports: users can only manage their own
CREATE POLICY "Users can manage own reports" ON feed_reports
    FOR ALL USING (reporter_id = auth.uid());

-- Hidden items: users can only manage their own
CREATE POLICY "Users can manage own hidden items" ON feed_hidden_items
    FOR ALL USING (user_id = auth.uid());

-- View for feed with aggregated likes/comments count
CREATE OR REPLACE VIEW feed_items_with_stats AS
SELECT
    fi.*,
    COALESCE(lc.like_count, 0) AS like_count,
    COALESCE(cc.comment_count, 0) AS comment_count
FROM feed_items fi
LEFT JOIN (
    SELECT feed_item_id, COUNT(*) AS like_count
    FROM feed_likes GROUP BY feed_item_id
) lc ON fi.id = lc.feed_item_id
LEFT JOIN (
    SELECT feed_item_id, COUNT(*) AS comment_count
    FROM feed_comments GROUP BY feed_item_id
) cc ON fi.id = cc.feed_item_id;
