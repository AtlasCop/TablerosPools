// Edge Function: google-oauth-refresh
//
// Cambia el refresh_token guardado de quien hace la solicitud por un
// access_token nuevo (~1 hora de vida) — esto SIEMPRE funciona, sin
// depender de que el navegador permita una verificación silenciosa con
// Google (eso era lo que fallaba antes y hacía que la conexión se cayera
// cada tanto pidiendo iniciar sesión de nuevo).
//
// Si Google responde que el refresh_token ya no sirve (por ejemplo, la
// persona revocó el acceso desde su cuenta de Google), se borra el
// registro guardado y se le avisa al navegador para que muestre
// "Desconectado" de verdad, en vez de insistir con un token muerto.

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

    const authClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
    });
    const { data: userData, error: userError } = await authClient.auth.getUser();
    if (userError || !userData?.user) {
      return new Response(JSON.stringify({ error: "invalid_session" }), { status: 401, headers: CORS_HEADERS });
    }
    const userId = userData.user.id;

    const serviceClient = createClient(supabaseUrl, serviceRoleKey);
    const { data: row, error: fetchError } = await serviceClient
      .from("google_oauth_tokens")
      .select("refreshToken")
      .eq("userId", userId)
      .maybeSingle();
    if (fetchError) {
      return new Response(JSON.stringify({ error: "lookup_failed", detail: fetchError.message }), { status: 500, headers: CORS_HEADERS });
    }
    if (!row?.refreshToken) {
      return new Response(JSON.stringify({ error: "not_connected" }), { status: 404, headers: CORS_HEADERS });
    }

    const clientId = Deno.env.get("GOOGLE_CLIENT_ID")!;
    const clientSecret = Deno.env.get("GOOGLE_CLIENT_SECRET")!;

    const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        refresh_token: row.refreshToken,
        client_id: clientId,
        client_secret: clientSecret,
        grant_type: "refresh_token",
      }),
    });
    const tokenData = await tokenRes.json();

    if (!tokenRes.ok || !tokenData.access_token) {
      // invalid_grant = el refresh token ya no sirve (revocado, o vencido
      // por seguir en modo "Prueba" en Google Cloud) — se limpia para no
      // seguir intentando con algo muerto.
      if (tokenData.error === "invalid_grant") {
        await serviceClient.from("google_oauth_tokens").delete().eq("userId", userId);
      }
      return new Response(JSON.stringify({ error: "google_refresh_failed", detail: tokenData }), { status: 400, headers: CORS_HEADERS });
    }

    // Es raro, pero Google a veces manda un refresh_token nuevo al refrescar
    // — si pasa, hay que guardar ese en vez del viejo.
    if (tokenData.refresh_token && tokenData.refresh_token !== row.refreshToken) {
      await serviceClient
        .from("google_oauth_tokens")
        .update({ refreshToken: tokenData.refresh_token, updatedAt: new Date().toISOString() })
        .eq("userId", userId);
    }

    return new Response(
      JSON.stringify({ access_token: tokenData.access_token, expires_in: tokenData.expires_in }),
      { headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(JSON.stringify({ error: "unexpected_error", detail: String(err) }), { status: 500, headers: CORS_HEADERS });
  }
});
