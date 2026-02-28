-- Push Tokens table
-- Stores APNs device tokens for push notification delivery
CREATE TABLE IF NOT EXISTS push_tokens (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     TEXT NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token       TEXT NOT NULL,
    platform    TEXT NOT NULL DEFAULT 'ios',   -- 'ios', 'android', 'web'
    app_version TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    
    UNIQUE(user_id, token)
);

CREATE INDEX idx_push_tokens_user ON push_tokens(user_id);

-- Notification Preferences table
CREATE TABLE IF NOT EXISTS notification_preferences (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             TEXT NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    is_enabled          BOOLEAN NOT NULL DEFAULT true,
    
    -- Category toggles
    friend_activity     BOOLEAN NOT NULL DEFAULT true,
    personal_records    BOOLEAN NOT NULL DEFAULT true,
    workout_reminders   BOOLEAN NOT NULL DEFAULT true,
    challenges          BOOLEAN NOT NULL DEFAULT true,
    social              BOOLEAN NOT NULL DEFAULT true,
    
    -- Reminder schedule
    reminder_hour       INTEGER NOT NULL DEFAULT 8   CHECK (reminder_hour BETWEEN 0 AND 23),
    reminder_minute     INTEGER NOT NULL DEFAULT 0   CHECK (reminder_minute BETWEEN 0 AND 59),
    reminder_days       INTEGER[] NOT NULL DEFAULT '{1,2,3,4,5}',  -- 0=Sun, 6=Sat
    
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Notification Events log (for analytics and debugging)
CREATE TABLE IF NOT EXISTS notification_events (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         TEXT NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type            TEXT NOT NULL,  -- NotificationType rawValue
    payload         JSONB,
    sent_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    delivered       BOOLEAN,
    opened          BOOLEAN DEFAULT false,
    opened_at       TIMESTAMPTZ
);

CREATE INDEX idx_notification_events_user ON notification_events(user_id, sent_at DESC);

-- RLS
ALTER TABLE push_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_events ENABLE ROW LEVEL SECURITY;

-- Push tokens
CREATE POLICY "Users can manage own push tokens"
    ON push_tokens FOR ALL
    USING (auth.uid()::text = user_id)
    WITH CHECK (auth.uid()::text = user_id);

-- Notification preferences
CREATE POLICY "Users can manage own preferences"
    ON notification_preferences FOR ALL
    USING (auth.uid()::text = user_id)
    WITH CHECK (auth.uid()::text = user_id);

-- Notification events (read-only for users)
CREATE POLICY "Users can view own notification events"
    ON notification_events FOR SELECT
    USING (auth.uid()::text = user_id);

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER push_tokens_updated_at
    BEFORE UPDATE ON push_tokens
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER notification_preferences_updated_at
    BEFORE UPDATE ON notification_preferences
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Helper function: get active push tokens for a user
-- Used by backend notification service
CREATE OR REPLACE FUNCTION get_user_push_tokens(target_user_id TEXT)
RETURNS TABLE(token TEXT, platform TEXT) AS $$
    SELECT token, platform
    FROM push_tokens
    WHERE user_id = target_user_id
    ORDER BY updated_at DESC;
$$ LANGUAGE sql SECURITY DEFINER;

-- Helper function: check if user has a notification type enabled
CREATE OR REPLACE FUNCTION user_has_notif_enabled(target_user_id TEXT, category TEXT)
RETURNS BOOLEAN AS $$
    SELECT 
        is_enabled AND (
            CASE category
                WHEN 'friend_activity' THEN friend_activity
                WHEN 'personal_records' THEN personal_records
                WHEN 'workout_reminders' THEN workout_reminders
                WHEN 'challenges' THEN challenges
                WHEN 'social' THEN social
                ELSE true
            END
        )
    FROM notification_preferences
    WHERE user_id = target_user_id;
$$ LANGUAGE sql SECURITY DEFINER;
