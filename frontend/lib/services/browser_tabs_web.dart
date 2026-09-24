import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

// Web Locks need a secure page, both need a recent browser: without them
// each tab goes on alone, as before.
final bool _hasLocks = web.window.navigator.has('locks');
final bool _hasChannel = globalContext.has('BroadcastChannel');

web.BroadcastChannel? _channel;

web.BroadcastChannel? _openChannel()
{
  if (!_hasChannel)
  {
    return null;
  }

  return _channel ??= web.BroadcastChannel('casa-michela-tabs');
}

Future<T> inTurnWithOtherTabsImpl<T>(String lock, Future<T> Function() body) async
{
  if (!_hasLocks)
  {
    return body();
  }

  late T result;
  Object? failure;
  StackTrace? failureTrace;

  // The failure is carried across by hand: a rejection passing through
  // JavaScript would come back as a JavaScript error, not the Dart one.
  JSPromise granted(web.Lock? _)
  {
    return () async
    {
      try
      {
        result = await body();
      }
      catch (error, stackTrace)
      {
        failure = error;
        failureTrace = stackTrace;
      }
    }().toJS;
  }

  await web.window.navigator.locks.request(lock, granted.toJS).toDart;

  if (failure != null)
  {
    Error.throwWithStackTrace(failure!, failureTrace!);
  }

  return result;
}

void tellOtherTabsImpl(Map<String, String> message)
{
  _openChannel()?.postMessage(jsonEncode(message).toJS);
}

void listenToOtherTabsImpl(void Function(Map<String, String> message) onMessage)
{
  _openChannel()?.onmessage = (web.MessageEvent event)
  {
    final Object? data = event.data.dartify();

    if (data is! String)
    {
      return;
    }

    try
    {
      onMessage(Map<String, String>.from(jsonDecode(data) as Map));
    }
    on FormatException
    {
      // Not one of ours.
    }
    on TypeError
    {
      // Not one of ours.
    }
  }.toJS;
}
