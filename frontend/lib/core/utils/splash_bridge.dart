import 'dart:js_interop';

@JS('__hideCasaMichelaSplash')
external void _hideCasaMichelaSplash();

// Contract with index.html: triggers the CSS fade of #splash-overlay once the
// first frame is painted.
void hideInitialSplash()
{
  try
  {
    _hideCasaMichelaSplash();
  }
  catch (_)
  {
    // The hook is absent when a cached index.html predates the overlay: never
    // block startup on it.
  }
}