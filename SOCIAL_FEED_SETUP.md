# Social Feed Feature — Database Setup

This document outlines the Supabase database schema required for the Social Feed feature (issue #9).

## Overview

The Social Feed allows users to:
- See friends' completed workouts
- View new PRs and milestones
- Like, react, and comment on posts
- Share workouts to the feed
- Filter posts by friends/following/discover

## Required Tables

### 1. `feed_posts` (View-based)
Aggregates completed workouts marked as shared. This can be a view:

```sql
CREATE VIEW feed_posts AS
SELECT 
  w.id,
  w.user_id,
  w.name,
  w.start_time,
  w.end_time,
  w.notes,
  w.is_public,
  COUNT(DISTINCT fl.user_id) as like_count,
  COUNT(DISTINCT fc.id) as comment_count
FROM workouts w
LEFT JOIN feed_likes fl ON w.id = fl.post_id
LEFT JOIN feed_comments fc ON w.id = fc.post_id
WHERE w.is_shared_to_feed = true
  AND w.is_completed = true
GROUP BY w.id
ORDER BY w.start_time DESC;
```

### 2. `feed_likes`
Tracks likes on feed posts:

```sql
CREATE TABLE feed_likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES workouts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(post_id, user_id)
);

CREATE INDEX idx_feed_likes_post_id ON feed_likes(post_id);
CREATE INDEX idx_feed_likes_user_id ON feed_likes(user_id);
```

### 3. `feed_comments`
Stores comments on feed posts:

```sql
CREATE TABLE feed_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES workouts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  text TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_feed_comments_post_id ON feed_comments(post_id);
CREATE INDEX idx_feed_comments_user_id ON feed_comments(user_id);
CREATE INDEX idx_feed_comments_created_at ON feed_comments(created_at DESC);
```

### 4. `feed_reactions`
Tracks emoji reactions on feed posts:

```sql
CREATE TABLE feed_reactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES workouts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  emoji TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(post_id, user_id, emoji)
);

CREATE INDEX idx_feed_reactions_post_id ON feed_reactions(post_id);
CREATE INDEX idx_feed_reactions_emoji ON feed_reactions(emoji);
```

### 5. `friendships` (if not exists)
Manages friend relationships:

```sql
CREATE TABLE IF NOT EXISTS friendships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  friend_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'pending', -- pending, accepted, blocked
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, friend_id)
);

CREATE INDEX idx_friendships_user_id ON friendships(user_id);
CREATE INDEX idx_friendships_status ON friendships(status);
```

### 6. `follows` (if not exists)
Manages follow relationships:

```sql
CREATE TABLE IF NOT EXISTS follows (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  following_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, following_id)
);

CREATE INDEX idx_follows_user_id ON follows(user_id);
CREATE INDEX idx_follows_following_id ON follows(following_id);
```

## Updates to Existing Tables

### `workouts` Table
Add these columns if they don't exist:

```sql
ALTER TABLE workouts 
ADD COLUMN IF NOT EXISTS is_shared_to_feed BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT FALSE;

CREATE INDEX idx_workouts_shared_completed ON workouts(is_shared_to_feed, is_completed);
```

## Row-Level Security (RLS)

Enable RLS on all feed tables:

```sql
-- feed_likes RLS
ALTER TABLE feed_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "feed_likes_select" ON feed_likes
  FOR SELECT USING (TRUE);

CREATE POLICY "feed_likes_insert" ON feed_likes
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "feed_likes_delete" ON feed_likes
  FOR DELETE USING (auth.uid() = user_id);

-- feed_comments RLS
ALTER TABLE feed_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "feed_comments_select" ON feed_comments
  FOR SELECT USING (TRUE);

CREATE POLICY "feed_comments_insert" ON feed_comments
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "feed_comments_update" ON feed_comments
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "feed_comments_delete" ON feed_comments
  FOR DELETE USING (auth.uid() = user_id);

-- feed_reactions RLS
ALTER TABLE feed_reactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "feed_reactions_select" ON feed_reactions
  FOR SELECT USING (TRUE);

CREATE POLICY "feed_reactions_insert" ON feed_reactions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "feed_reactions_delete" ON feed_reactions
  FOR DELETE USING (auth.uid() = user_id);
```

## Implementation Checklist

- [ ] Create `feed_likes` table
- [ ] Create `feed_comments` table
- [ ] Create `feed_reactions` table
- [ ] Create/update `friendships` table
- [ ] Create/update `follows` table
- [ ] Add columns to `workouts` table
- [ ] Enable RLS on all feed tables
- [ ] Create indexes for performance
- [ ] Test queries in Supabase SQL editor
- [ ] Update FeedViewModel to use real Supabase queries

## API Endpoints (Future REST API)

Once the backend API is set up, these endpoints should be available:

- `GET /api/feed/friends` — Friends' workouts
- `GET /api/feed/following` — Following users' workouts
- `GET /api/feed/discover` — Public workouts
- `POST /api/feed/{workoutId}/like` — Like a post
- `DELETE /api/feed/{workoutId}/like` — Unlike a post
- `POST /api/feed/{workoutId}/comment` — Add comment
- `POST /api/feed/{workoutId}/react` — Add reaction
- `PUT /api/workouts/{workoutId}/share` — Share workout to feed

## Notes

- All timestamps use ISO 8601 format
- Emoji reactions are stored as UTF-8 text
- Comments are currently plain text (no markdown)
- Consider adding notification triggers for new comments/reactions
- Consider archiving old posts after 30 days
