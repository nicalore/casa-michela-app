import 'dart:js_interop';

@JS('__hideCasaMichelaSplash')
external void _hideCasaMichelaSplash();

// Contract with index.html: calling this hook triggers the CSS blur fade of
// #splash-overlay, and must happen once the first Flutter frame is painted.
void hideInitialSplash()
{
  try
  {
    _hideCasaMichelaSplash();
  }
  catch (_)
  {
    // The hook is absent when a cached index.html predates the overlay:
    // failing to hide it must never prevent the app from starting.
  }
}