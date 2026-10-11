import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

final RegExp _softwareRenderer = RegExp(r'swiftshader|llvmpipe|softpipe|software|basic render', caseSensitive: false);

bool hasWeakGraphicsImpl()
{
  try
  {
    final web.Navigator navigator = web.window.navigator;

    if (navigator.hardwareConcurrency <= 2)
    {
      return true;
    }

    // Chromium only.
    final JSAny? memory = (navigator as JSObject).getProperty<JSAny?>('deviceMemory'.toJS);

    if (memory.isA<JSNumber>() && (memory as JSNumber).toDartDouble <= 2)
    {
      return true;
    }

    return _rendersInSoftware();
  }
  catch (_)
  {
    return false;
  }
}

bool _rendersInSoftware()
{
  // Refused when the browser would draw on the CPU or on a blocklisted GPU.
  final JSObject? context = web.HTMLCanvasElement().getContext(
    'webgl',
    web.WebGLContextAttributes(failIfMajorPerformanceCaveat: true),
  );

  if (context == null)
  {
    return true;
  }

  final web.WebGLRenderingContext gl = context as web.WebGLRenderingContext;

  try
  {
    if (gl.getExtension('WEBGL_debug_renderer_info') == null)
    {
      return false;
    }

    final JSAny? renderer = gl.getParameter(web.WEBGL_debug_renderer_info.UNMASKED_RENDERER_WEBGL);

    return renderer.isA<JSString>() && _softwareRenderer.hasMatch((renderer as JSString).toDart);
  }
  finally
  {
    // Browsers cap live contexts: this one must not take the engine's place.
    (gl.getExtension('WEBGL_lose_context') as web.WEBGL_lose_context?)?.loseContext();
  }
}
