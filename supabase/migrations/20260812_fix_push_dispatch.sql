-- Fix push notification dispatch
--
-- Three independent faults kept every remote notification from ever arriving.
-- Local notifications (rest timer, warmup) are scheduled on-device and were
-- unaffected, which is why notifications appeared to work only while the app
-- was open.
--
--   1. `use_sandbox` was hardcoded true here, so every push was addressed to the
--      APNs sandbox gateway. TestFlight builds carry production tokens, which
--      sandbox rejects with BadDeviceToken. The flag is now omitted entirely and
--      send-push tries both environments — see that function for why picking one
--      up front cannot be correct when a project has both build types alive.
--   2. `notify_user` returned silently when the project settings were missing,
--      making an unconfigured project indistinguishable from a working one. It
--      now raises a warning that lands in the Postgres logs.
--   3. The aps-environment entitlement was `development` (fixed in the app).
--
-- Also adds the missing new_pr trigger: `send-push` has always mapped a
-- `new_pr` type to the personal_records preference column, but nothing ever
-- emitted one.

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
    base_url    TEXT;
    edge_url    TEXT;
    service_key TEXT;
BEGIN
    base_url    := current_setting('app.settings.supabase_url', true);
    service_key := current_setting('app.settings.service_role_key', true);

    -- current_setting(..., true) yields NULL for an unset setting, and NULL
    -- concatenation would previously make edge_url NULL too — so the original
    -- guard did fire, it just did so without leaving any trace.
    IF base_url IS NULL OR base_url = '' OR service_key IS NULL OR service_key = '' THEN
        RAISE WARNING
            'notify_user: dropped % notification for user % — app.settings.supabase_url / app.settings.service_role_key are not configured on this project',
            notif_type, target_user_id;
        RETURN;
    END IF;

    edge_url := base_url || '/functions/v1/send-push';

    PERFORM extensions.http_post(
        edge_url,
        jsonb_build_object(
            'user_id', target_user_id,
            'type',    notif_type,
            'title',   notif_title,
            'body',    notif_body,
            'sender_id', sender_user_id,
            'target_id', target_entity_id
            -- `use_sandbox` deliberately omitted: send-push defaults to the
            -- production gateway and falls back to sandbox on BadDeviceToken,
            -- so both TestFlight and local development builds are reachable
            -- without this function needing to know which one is asking.
        )::text,
        'application/json',
        ARRAY[
            extensions.http_header('Authorization', 'Bearer ' || service_key)
        ]
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------------------------------------------------------------------------
-- New: notify the lifter when they set a personal record
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION on_personal_record_notify()
RETURNS TRIGGER AS $$
DECLARE
    lift_name TEXT;
    body_text TEXT;
BEGIN
    -- Only the all-rep-ranges record is worth interrupting someone for. A
    -- rep-range record fires far more often and would be noise. This also keeps
    -- the 20260811 backfill quiet, since every row it touches is a rep_range.
    IF COALESCE(NEW.kind, 'rep_range') <> 'e1rm' THEN
        RETURN NEW;
    END IF;

    -- Records are upserted in place, so this trigger sees an UPDATE for any
    -- write to an existing row — including ones that do not represent a new
    -- record. Only an actual improvement should notify.
    IF TG_OP = 'UPDATE'
       AND NOT (COALESCE(NEW.estimated_1rm, 0) > COALESCE(OLD.estimated_1rm, 0)) THEN
        RETURN NEW;
    END IF;

    lift_name := NEW.exercise_name;

    IF NEW.previous_weight IS NULL THEN
        body_text := 'First record on ' || lift_name || ' — ' ||
                     round(NEW.weight)::TEXT || ' x ' || NEW.reps::TEXT;
    ELSE
        body_text := lift_name || ' — ' || round(NEW.weight)::TEXT || ' x ' ||
                     NEW.reps::TEXT || ' (up from ' ||
                     round(NEW.previous_weight)::TEXT || ')';
    END IF;

    PERFORM notify_user(
        NEW.user_id::TEXT,
        'new_pr',
        'New Personal Record',
        body_text,
        NULL,
        NEW.id::TEXT
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS personal_record_notification ON personal_records;

-- Fires on UPDATE as well as INSERT because records are now upserted in place:
-- one current row per variant, rather than a new row per PR event. Beating an
-- existing record is an UPDATE, and that is the most common way a PR happens.
CREATE TRIGGER personal_record_notification
    AFTER INSERT OR UPDATE ON personal_records
    FOR EACH ROW EXECUTE FUNCTION on_personal_record_notify();
