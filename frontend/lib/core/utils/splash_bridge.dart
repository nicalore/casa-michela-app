import 'dart:js_interop';

@JS('__hideCasaMichelaSplash')
external void _hideCasaMichelaSplash();

/// Segnala a index.html che il primo frame Flutter è stato dipinto,
/// così l'overlay bianco iniziale può sfumare con l'animazione blur
/// definita in CSS (#splash-overlay / .splash-overlay-hidden).
void hideInitialSplash() {
  try {
    _hideCasaMichelaSplash();
  } catch (_) {
    // Se la funzione JS non esiste (es. build non-web) non deve
    // bloccare l'avvio dell'app.
  }
}