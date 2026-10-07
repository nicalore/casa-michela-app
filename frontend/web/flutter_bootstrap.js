{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    hostElement: document.querySelector('#flutter_host'),
    // Served by us, not gstatic.com: no visitor IP reaches Google.
    canvasKitBaseUrl: 'canvaskit/',
    // Mirrors the engine's gstatic paths, which change with Flutter upgrades.
    // A missing file must not answer 404, or the engine retries it forever; the SPA fallback does.
    // Absolute: skwasm would look for Roboto under assets/.
    fontFallbackBaseUrl: new URL('fallback_fonts/', document.baseURI).href,
  },
});