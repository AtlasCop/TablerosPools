// Edge Function: google-oauth-exchange
//
// Recibe el "code" de autorización que Google devuelve tras el login/consentimiento
// (flujo de código de autorización, NO el implícito) y lo cambia por un access_token
// (corto, ~1 hora) y un refresh_token (de larga duración) llamando al endpoint de
// tokens de Google — algo que solo se puede hacer desde un servidor, porque requiere
// el Client Secret, que nunca debe llegar al navegador.
//
// El refresh_token se guarda en la tabla google_oauth_tokens, asociado a quien hizo
// la solicitud (identificado por su sesión de Supabase) — así queda disponible para
// que google-oauth-refresh lo use más adelante sin volver a pedirle nada a esa persona.
//
// Solo se le devuelve al navegador el access_token — el refresh_token nunca sale de
// aquí.

import { createClient } from "npm:@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "method_not_allowed" }), { status: 405, headers: CORS_HEADERS });
  }

  try {
    const authHeader = req.headers.get("Authorization") || "";
    const jwt = authHeader.replace(/^Bearer\s+/i, "");
    if (!jwt) {
      return new Response(JSON.stringify({ error: "missing_auth" }), { status: 401, headers: CORS_HEADERS });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

    // Verifica quién es la persona dueña de esta sesión de Supabase, usando
    // su propio JWT (no confiamos en nada que mande el cliente sobre su identidad).
    const authClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
    });
    const { data: userData, error: userError } = await authClient.auth.getUser();
    if (userError || !userData?.user) {
      return new Response(JSON.stringify({ error: "invalid_session" }), { status: 401, headers: CORS_HEADERS });
    }
    const userId = userData.user.id;

    const body = await req.json().catch(() => ({}));
    const code = body?.code;
    const redirectUri = body?.redirectUri;
    if (!code || !redirectUri) {
      return new Response(JSON.stringify({ error: "missing_code_or_redirect_uri" }), { status: 400, headers: CORS_HEADERS });
    }

    const clientId = Deno.env.get("GOOGLE_CLIENT_ID")!;
    const clientSecret = Deno.env.get("GOOGLE_CLIENT_SECRET")!;

    const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        code,
        client_id: clientId,
        client_secret: clientSecret,
        redirect_uri: redirectUri,
        grant_type: "authorization_code",
      }),
    });
    const tokenData = await tokenRes.json();

    if (!tokenRes.ok || !tokenData.access_token) {
      return new Response(JSON.stringify({ error: "google_exchange_failed", detail: tokenData }), { status: 400, headers: CORS_HEADERS });
    }

    if (tokenData.refresh_token) {
      const serviceClient = createClient(supabaseUrl, serviceRoleKey);
      const { error: upsertError } = await serviceClient
        .from("google_oauth_tokens")
        .upsert({ userId, refreshToken: tokenData.refresh_token, updatedAt: new Date().toISOString() });
      if (upsertError) {
        return new Response(JSON.stringify({ error: "storage_failed", detail: upsertError.message }), { status: 500, headers: CORS_HEADERS });
      }
    }
    // Si Google no mandó refresh_token (ya se había conectado antes y no se
    // forzó "prompt=consent" esta vez), seguimos igual: puede que ya hubiera
    // uno guardado de una conexión anterior.

    return new Response(
      JSON.stringify({ access_token: tokenData.access_token, expires_in: tokenData.expires_in, got_refresh_token: !!tokenData.refresh_token }),
      { headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(JSON.stringify({ error: "unexpected_error", detail: String(err) }), { status: 500, headers: CORS_HEADERS });
  }
});
