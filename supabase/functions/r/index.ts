/**
 * Short link of a published routine: <project>.supabase.co/functions/v1/r/7K2QXM
 *
 * On Android it redirects to the app (intent://r/7K2QXM, scheme fitstreak). If
 * the app isn't installed, or from a computer, the code is shown to paste by
 * hand. Supabase doesn't allow serving HTML from its domain, which is why this
 * is a redirect and not a page with a button.
 *
 * When deploying it, turn off "Verify JWT": anyone opens it.
 */

/** Android package the intent opens. */
const PACKAGE = "com.arturoc.fitstreak";

/** Public URL of this function, for the browser fallback. */
const BASE = `${Deno.env.get("SUPABASE_URL")}/functions/v1/r`;

Deno.serve((req) => {
  const url = new URL(req.url);
  const id = (url.pathname.split("/").filter(Boolean).pop() ?? "").toUpperCase();
  const valid = /^[2-9A-HJ-NP-Z]{6}$/.test(id);
  const android = /Android/i.test(req.headers.get("user-agent") ?? "");

  if (valid && android && !url.searchParams.has("web")) {
    const fallback = encodeURIComponent(`${BASE}/${id}?web=1`);
    const intent =
      `intent://r/${id}#Intent;scheme=fitstreak;package=${PACKAGE};S.browser_fallback_url=${fallback};end`;
    return new Response(null, { status: 302, headers: { Location: intent } });
  }

  const text = valid
    ? `Rutina de FitStreak · código FS-${id}\n\n` +
      `Para seguirla, abre este enlace en un móvil Android con FitStreak instalada.\n` +
      `También puedes copiar el código FS-${id} y pegarlo en FitStreak → Opciones → Importar mi rutina.`
    : "Este enlace de FitStreak no es válido.";
  return new Response(text, {
    status: valid ? 200 : 404,
    headers: { "content-type": "text/plain; charset=utf-8" },
  });
});
