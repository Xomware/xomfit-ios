-- Notification dispatch triggers
-- These functions call the send-push Edge Function when events occur.
-- Requires: supabase_url() and service_role_key() to be available,
-- or use pg_net extension for async HTTP calls.

-- Enable pg_net for async HTTP from Postgres
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- Helper: dispatch a push notification via Edge Function
CREATE OR REPLACE FUNCTION notify_user(
    target_user_id TEXT,
    notif_type TEXT,
    notif_title TEXT,
    notif_body TEXT,
    sender_user_id TEXT DEFAULT NULL,
    target_entity_id TEXT DEFAULT NULL
)
RETURNS void AS $$
DECLARE
    edge_url TEXT;
    service_key TEXT;
BEGIN
    -- These should be set as Supabase project secrets / vault
    edge_url := current_setting('app.settings.supabase_url', true) || '/functions/v1/send-push';
    service_key := current_setting('app.settings.service_role_key', true);

    -- Skip if settings not configured
    IF edge_url IS NULL OR service_key IS NULL THEN
        RETURN;
    END IF;

    PERFORM extensions.http_post(
        edge_url,
        jsonb_build_object(
            'user_id', target_user_id,
            'type', notif_type,
            'title', notif_title,
            'body', notif_body,
            'sender_id', sender_user_id,
            'target_id', target_entity_id,
            'use_sandbox', true  -- flip to false for production
        )::text,
        'application/json',
        ARRAY[
            extensions.http_header('Authorization', 'Bearer ' || service_key)
        ]
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger: notify on new like
CREATE OR REPLACE FUNCTION on_feed_like_notify()
RETURNS TRIGGER AS $$
DECLARE
    feed_owner_id TEXT;
    liker_name TEXT;
BEGIN
    -- Get the feed item owner
    SELECT user_id INTO feed_owner_id FROM feed_items WHERE id = NEW.feed_item_id;

    -- Don't notify yourself
    IF feed_owner_id = NEW.user_id THEN RETURN NEW; END IF;

    -- Get liker display name
    SELECT COALESCE(display_name, username, 'Someone')
    INTO liker_name
    FROM profiles WHERE id = NEW.user_id;

    PERFORM notify_user(
        feed_owner_id,
        'like',
        'New Like',
        liker_name || ' liked your post',
        NEW.user_id,
        NEW.feed_item_id
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER feed_like_notification
    AFTER INSERT ON feed_likes
    FOR EACH ROW EXECUTE FUNCTION on_feed_like_notify();

-- Trigger: notify on new comment
CREATE OR REPLACE FUNCTION on_feed_comment_notify()
RETURNS TRIGGER AS $$
DECLARE
    feed_owner_id TEXT;
    commenter_name TEXT;
    comment_preview TEXT;
BEGIN
    SELECT user_id INTO feed_owner_id FROM feed_items WHERE id = NEW.feed_item_id;

    IF feed_owner_id = NEW.user_id THEN RETURN NEW; END IF;

    SELECT COALESCE(display_name, username, 'Someone')
    INTO commenter_name
    FROM profiles WHERE id = NEW.user_id;

    comment_preview := LEFT(NEW.text, 50);
    IF LENGTH(NEW.text) > 50 THEN
        comment_preview := comment_preview || '...';
    END IF;

    PERFORM notify_user(
        feed_owner_id,
        'comment',
        'New Comment',
        commenter_name || ': ' || comment_preview,
        NEW.user_id,
        NEW.feed_item_id
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER feed_comment_notification
    AFTER INSERT ON feed_comments
    FOR EACH ROW EXECUTE FUNCTION on_feed_comment_notify();

-- Trigger: notify on friend request
CREATE OR REPLACE FUNCTION on_friendship_notify()
RETURNS TRIGGER AS $$
DECLARE
    requester_name TEXT;
BEGIN
    -- Only notify on new pending requests
    IF NEW.status != 'pending' THEN RETURN NEW; END IF;

    SELECT COALESCE(display_name, username, 'Someone')
    INTO requester_name
    FROM profiles WHERE id = NEW.requester_id;

    PERFORM notify_user(
        NEW.addressee_id,
        'friend_request',
        'New Friend Request',
        requester_name || ' wants to be your friend',
        NEW.requester_id,
        NEW.id
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER friendship_request_notification
    AFTER INSERT ON friendships
    FOR EACH ROW EXECUTE FUNCTION on_friendship_notify();

-- Trigger: notify on friend request accepted
CREATE OR REPLACE FUNCTION on_friendship_accepted_notify()
RETURNS TRIGGER AS $$
DECLARE
    accepter_name TEXT;
BEGIN
    IF OLD.status = 'pending' AND NEW.status = 'accepted' THEN
        SELECT COALESCE(display_name, username, 'Someone')
        INTO accepter_name
        FROM profiles WHERE id = NEW.addressee_id;

        PERFORM notify_user(
            NEW.requester_id,
            'friend_accepted',
            'Friend Request Accepted',
            accepter_name || ' accepted your friend request',
            NEW.addressee_id,
            NEW.id
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER friendship_accepted_notification
    AFTER UPDATE ON friendships
    FOR EACH ROW EXECUTE FUNCTION on_friendship_accepted_notify();
