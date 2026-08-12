// Supabase Edge Function: send-push
// Dispatches APNs push notifications to iOS devices.
//
// Invoke via: supabase.functions.invoke('send-push', { body: { ... } })
// Or trigger from a Supabase DB webhook / cron.
//
// Required env vars:
//   APNS_KEY_ID       — Apple APNs key ID
//   APNS_TEAM_ID      — Apple Developer team ID
//   APNS_PRIVATE_KEY  — .p8 key contents (base64 encoded)
//   APNS_BUNDLE_ID    — App bundle ID (com.Xomware.Xomfit)
//   SUPABASE_URL      — auto-provided
//   SUPABASE_SERVICE_ROLE_KEY — auto-provided

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SignJWT, importPKCS8 } from "https://deno.land/x/jose@v4.14.4/index.ts";

const APNS_HOST = "https://api.push.apple.com"; // Production
const APNS_DEV_HOST = "https://api.sandbox.push.apple.com"; // Development

interface PushRequest {
  user_id: string;
  type: string;
  title: string;
  body: string;
  sender_id?: string;
  target_id?: string;
  use_sandbox?: boolean;
}

serve(async (req: Request) => {
  try {
    const payload: PushRequest = await req.json();
    const { user_id, type, title, body, sender_id, target_id, use_sandbox } = payload;

    if (!user_id || !type || !title) {
      return new Response(JSON.stringify({ error: "Missing required fields" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Init Supabase admin client
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceKey);

    // Check if user has this notification type enabled
    const { data: prefs } = await supabase
      .from("notification_preferences")
      .select("*")
      .eq("user_id", user_id)
      .single();

    if (prefs && !prefs.is_enabled) {
      return jsonResponse({ skipped: true, reason: "notifications_disabled" });
    }

    // Map notification type to preference column
    const typeToColumn: Record<string, string> = {
      friend_request: "social",
      friend_accepted: "social",
      like: "social",
      comment: "social",
      new_pr: "personal_records",
      streak_milestone: "personal_records",
      friend_workout: "friend_activity",
    };

    const prefColumn = typeToColumn[type];
    if (prefs && prefColumn && !prefs[prefColumn]) {
      return jsonResponse({ skipped: true, reason: `${prefColumn}_disabled` });
    }

    // Get user's push tokens
    const { data: tokens, error: tokenError } = await supabase
      .from("push_tokens")
      .select("token, platform")
      .eq("user_id", user_id);

    if (tokenError || !tokens?.length) {
      return jsonResponse({ skipped: true, reason: "no_push_tokens" });
    }

    // Generate APNs JWT
    const apnsJWT = await generateAPNsJWT();
    const bundleId = Deno.env.get("APNS_BUNDLE_ID") || "com.Xomware.Xomfit";

    // Which APNs environment a token belongs to is decided by the aps-environment
    // entitlement of the build that produced it, so a single project routinely has
    // both kinds alive at once: sandbox tokens from local Xcode builds and
    // production tokens from TestFlight. Choosing one host up front — which is
    // what the caller-supplied `use_sandbox` flag did, hardcoded to true by the
    // DB trigger — silently dropped every notification to the other half, which is
    // why TestFlight builds never received a push. Instead, try the environment
    // the caller suggests first and fall back to the other on BadDeviceToken,
    // which is the only error that actually means "right token, wrong host".
    const preferredHost = use_sandbox ? APNS_DEV_HOST : APNS_HOST;
    const fallbackHost = use_sandbox ? APNS_HOST : APNS_DEV_HOST;

    const apnsPayload = {
      aps: {
        alert: { title, body },
        sound: "default",
        badge: 1,
        "mutable-content": 1,
      },
      type,
      sender_id: sender_id || "",
      target_id: target_id || "",
    };

    const postTo = (host: string, token: string) =>
      fetch(`${host}/3/device/${token}`, {
        method: "POST",
        headers: {
          Authorization: `bearer ${apnsJWT}`,
          "apns-topic": bundleId,
          "apns-push-type": "alert",
          "apns-priority": "10",
          "Content-Type": "application/json",
        },
        body: JSON.stringify(apnsPayload),
      });

    // Send to each iOS token
    const results = [];
    for (const { token, platform } of tokens) {
      if (platform !== "ios") continue;

      let host = preferredHost;
      let response = await postTo(host, token);
      let reason = response.ok ? null : await readAPNsReason(response);

      if (reason === "BadDeviceToken") {
        host = fallbackHost;
        response = await postTo(host, token);
        reason = response.ok ? null : await readAPNsReason(response);
      }

      results.push({
        token: token.substring(0, 8) + "...",
        status: response.status,
        environment: host === APNS_DEV_HOST ? "sandbox" : "production",
        ok: response.ok,
        // Surfaced so a misconfigured APNs key or bundle id is visible in the
        // function logs instead of looking like a silent no-op.
        reason,
      });

      // 410 Gone means the app was uninstalled — the token is dead in both
      // environments, so it is safe to drop. A BadDeviceToken that survived the
      // fallback is not necessarily dead, so it is left alone.
      if (response.status === 410) {
        await supabase
          .from("push_tokens")
          .delete()
          .eq("token", token);
      }
    }

    // Log the notification event
    await supabase.from("notification_events").insert({
      user_id,
      type,
      payload: { title, body, sender_id, target_id },
      delivered: results.some((r) => r.ok),
    });

    return jsonResponse({ sent: results.length, results });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});

async function generateAPNsJWT(): Promise<string> {
  const keyId = Deno.env.get("APNS_KEY_ID")!;
  const teamId = Deno.env.get("APNS_TEAM_ID")!;
  const privateKeyBase64 = Deno.env.get("APNS_PRIVATE_KEY")!;

  const privateKeyPem = atob(privateKeyBase64);
  const privateKey = await importPKCS8(privateKeyPem, "ES256");

  return await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyId })
    .setIssuer(teamId)
    .setIssuedAt()
    .sign(privateKey);
}

/// APNs returns its failure cause as `{"reason": "BadDeviceToken"}`. The body is
/// read defensively because a non-JSON error (a gateway failure, say) must not
/// take down the send loop.
async function readAPNsReason(response: Response): Promise<string | null> {
  try {
    const body = await response.json();
    return body?.reason ?? null;
  } catch {
    return null;
  }
}

function jsonResponse(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
