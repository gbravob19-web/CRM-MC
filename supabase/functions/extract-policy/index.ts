// Supabase Edge Function: reads a policy PDF with Claude and returns the
// client/policy fields as JSON, so the CRM's "Cargar PDF de póliza" button
// can pre-fill the form for review before saving.
//
// Deploy: Supabase Dashboard -> Edge Functions -> Deploy a new function
// (name it exactly "extract-policy") -> paste this file's contents.
// Or, with the Supabase CLI: `supabase functions deploy extract-policy`.
//
// Requires a secret set in Project Settings -> Edge Functions -> Secrets:
//   ANTHROPIC_API_KEY = <your key from console.anthropic.com>

import { createClient } from "npm:@supabase/supabase-js@2";

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY") || "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") || "";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const EXTRACTION_SCHEMA = `{
  "typeKey": "auto|inmueble|negocio|consorcio|vidaSalud|art|ap|caucion|tecnico",
  "dni": "string",
  "apellido": "string",
  "nombre": "string",
  "aseguradora": "string",
  "nPoliza": "string",
  "sumaAsegurada": "string (solo dígitos, sin puntos ni signos)",
  "prima": "string (solo dígitos, sin puntos ni signos)",
  "vigenciaDesde": "YYYY-MM-DD",
  "vigenciaHasta": "YYYY-MM-DD"
}`;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });

  try {
    if (!ANTHROPIC_API_KEY) {
      return new Response(JSON.stringify({ error: "Falta configurar el secreto ANTHROPIC_API_KEY en el proyecto." }), {
        status: 500,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    const authHeader = req.headers.get("Authorization") || "";
    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userErr } = await supabase.auth.getUser();
    if (userErr || !userData.user) {
      return new Response(JSON.stringify({ error: "No autenticado" }), {
        status: 401,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    const { pdfBase64 } = await req.json();
    if (!pdfBase64) {
      return new Response(JSON.stringify({ error: "Falta el PDF" }), {
        status: 400,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    const anthropicRes = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-sonnet-5",
        max_tokens: 1024,
        messages: [{
          role: "user",
          content: [
            { type: "document", source: { type: "base64", media_type: "application/pdf", data: pdfBase64 } },
            {
              type: "text",
              text: "Extraé los datos de esta póliza de seguro y devolvé SOLO un JSON (sin texto adicional, sin bloques de markdown) con exactamente esta forma:\n" +
                EXTRACTION_SCHEMA +
                '\nSi un dato no está en el documento, dejalo como cadena vacía "". "typeKey" debe ser el que mejor describa el tipo de bien asegurado, eligiendo únicamente entre esas opciones.',
            },
          ],
        }],
      }),
    });

    if (!anthropicRes.ok) {
      const errText = await anthropicRes.text();
      return new Response(JSON.stringify({ error: "Error de IA: " + errText }), {
        status: 502,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    const anthropicJson = await anthropicRes.json();
    const text = (anthropicJson.content || []).map((b: { text?: string }) => b.text || "").join("");
    const match = text.match(/\{[\s\S]*\}/);
    if (!match) {
      return new Response(JSON.stringify({ error: "La IA no devolvió un JSON válido" }), {
        status: 502,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    const extracted = JSON.parse(match[0]);
    return new Response(JSON.stringify(extracted), {
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }
});
