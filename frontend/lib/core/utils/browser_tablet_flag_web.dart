import 'dart:js_interop';

@JS('__casaMichelaIsTablet')
external JSBoolean? get _casaMichelaIsTablet;

bool browserReportsTabletImpl()
{
  try
  {
    return _casaMichelaIsTablet?.toDart ?? false;
  }
  catch (_)
  {
    // Absent when a cached index.html predates the flag.
    return false;
  }
}
