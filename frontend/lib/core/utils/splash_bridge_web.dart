import 'dart:js_interop';

@JS('__hideCasaMichelaSplash')
external void _hideCasaMichelaSplash();

void hideInitialSplashImpl()
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
