import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'notification_item.dart';
import 'push_types.dart';

// No page lives at the worker's address: it answers no request and controls no tab.
const String _scope = '/push/';

const String _workerScript = 'push_sw.js';

// Mirrors CHANNEL in web/push_sw.js.
const String _channelName = 'casa-michela-notifications';

// Mirrors OPENED in web/push_sw.js: the notification that opened a new tab.
const String _openedParameter = 'notification';

const String pushPlatform = 'web';

// Browsers are reached through their subscription, made with the server's key.
const bool pushNeedsSubscription = true;
const bool pushNeedsServerKey = true;

bool get pushPlatformSupported =>
    web.window.isSecureContext &&
    web.window.navigator.has('serviceWorker') &&
    globalContext.has('PushManager') &&
    globalContext.has('Notification');

PushPermission _permissionOf(String value)
{
  return switch (value)
  {
    'granted' => PushPermission.granted,
    'denied' => PushPermission.denied,
    _ => PushPermission.prompt,
  };
}

Future<PushPermission> readPushPermission() async
{
  if (!pushPlatformSupported)
  {
    return PushPermission.unsupported;
  }

  return _permissionOf(web.Notification.permission);
}

// Safari and Firefox ask only inside a click: nothing may be awaited before this.
Future<PushPermission> askPushPermission() async
{
  if (!pushPlatformSupported)
  {
    return PushPermission.unsupported;
  }

  final JSString answer = await web.Notification.requestPermission().toDart;

  return _permissionOf(answer.toDart);
}

// Once per app start: with no page in its scope, the browser never checks for a newer worker.
bool _updateAsked = false;

// Asked of the browser every time: a registration kept from before may have been dropped since.
Future<web.ServiceWorkerRegistration> _registration() async
{
  final registration = await web.window.navigator.serviceWorker
      .register(_workerScript.toJS, web.RegistrationOptions(scope: _scope))
      .toDart;

  if (!_updateAsked && registration.active != null)
  {
    _updateAsked = true;
    unawaited(registration.update().toDart.then<void>((_) {}, onError: (Object _) {}));
  }

  // Subscribing needs a worker already active, not one still installing.
  final web.ServiceWorker? pending = registration.installing ?? registration.waiting;

  if (registration.active != null || pending == null)
  {
    return registration;
  }

  final Completer<void> active = Completer<void>();

  void settle()
  {
    if (pending.state == 'activated' && !active.isCompleted)
    {
      active.complete();
    }
  }

  pending.onstatechange = ((web.Event event) => settle()).toJS;
  settle();
  await active.future;

  return registration;
}

String _base64Url(Uint8List bytes) => base64Url.encode(bytes).replaceAll('=', '');

Uint8List _bytesOf(String base64UrlText)
{
  return base64Url.decode(base64Url.normalize(base64UrlText));
}

PushAddress? _addressOf(web.PushSubscription subscription)
{
  final JSArrayBuffer? p256dh = subscription.getKey('p256dh');
  final JSArrayBuffer? auth = subscription.getKey('auth');

  if (p256dh == null || auth == null)
  {
    return null;
  }

  return PushAddress(
    platform: pushPlatform,
    address: subscription.endpoint,
    p256dh: _base64Url(p256dh.toDart.asUint8List()),
    auth: _base64Url(auth.toDart.asUint8List()),
  );
}

bool _sameKey(web.PushSubscription subscription, Uint8List key)
{
  final JSArrayBuffer? held = subscription.options.applicationServerKey;

  if (held == null)
  {
    return false;
  }

  final Uint8List bytes = held.toDart.asUint8List();

  if (bytes.length != key.length)
  {
    return false;
  }

  for (var i = 0; i < key.length; i++)
  {
    if (bytes[i] != key[i])
    {
      return false;
    }
  }

  return true;
}

Future<PushAddress?> currentPushAddress() async
{
  if (!pushPlatformSupported)
  {
    return null;
  }

  final registration = await _registration();
  final web.PushSubscription? subscription = await registration.pushManager.getSubscription().toDart;

  return subscription == null ? null : _addressOf(subscription);
}

// A subscription made with another server key is dropped: it would refuse every push.
Future<PushAddress?> subscribePush(String? serverKey) async
{
  if (!pushPlatformSupported || serverKey == null)
  {
    return null;
  }

  final Uint8List key = _bytesOf(serverKey);
  final registration = await _registration();
  final web.PushSubscription? held = await registration.pushManager.getSubscription().toDart;

  if (held != null)
  {
    if (_sameKey(held, key))
    {
      return _addressOf(held);
    }

    await held.unsubscribe().toDart;
  }

  final web.PushSubscription subscription = await registration.pushManager
      .subscribe(web.PushSubscriptionOptionsInit(userVisibleOnly: true, applicationServerKey: key.toJS))
      .toDart;

  return _addressOf(subscription);
}

// The address it had, for the server to forget.
Future<String?> unsubscribePush() async
{
  if (!pushPlatformSupported)
  {
    return null;
  }

  final registration = await _registration();
  final web.PushSubscription? subscription = await registration.pushManager.getSubscription().toDart;

  if (subscription == null)
  {
    return null;
  }

  final String address = subscription.endpoint;

  await subscription.unsubscribe().toDart;

  return address;
}

PushNews? _newsOf(Object? data)
{
  if (data is! Map)
  {
    return null;
  }

  final Object? id = data['id'];
  final PushNewsType? type = switch (data['type'])
  {
    'arrived' => PushNewsType.arrived,
    'opened' => PushNewsType.opened,
    'dismissed' => PushNewsType.dismissed,
    _ => null,
  };

  if (type == null || id is! num)
  {
    return null;
  }

  return PushNews(type, id.toInt(), quiet: data['quiet'] == true);
}

Stream<PushNews> pushNews()
{
  if (!pushPlatformSupported || !globalContext.has('BroadcastChannel'))
  {
    return const Stream.empty();
  }

  web.BroadcastChannel? channel;
  late final StreamController<PushNews> news;

  news = StreamController<PushNews>.broadcast(
    onListen: ()
    {
      final int? opened = int.tryParse(Uri.base.queryParameters[_openedParameter] ?? '');

      if (opened != null)
      {
        news.add(PushNews(PushNewsType.opened, opened));
      }

      channel = web.BroadcastChannel(_channelName)
        ..onmessage = ((web.MessageEvent event)
        {
          final PushNews? told = _newsOf(event.data.dartify());

          if (told != null)
          {
            news.add(told);
          }
        }).toJS;
    },
    onCancel: ()
    {
      channel?.close();
      channel = null;
    },
  );

  return news.stream;
}

// The browser's own settings cannot be opened from a page.
Future<bool> openPushSettings() async => false;

int? _idOf(web.Notification notification)
{
  final Object? data = notification.data.dartify();
  final Object? id = data is Map ? data['id'] : null;

  return id is num ? id.toInt() : null;
}

// Safari and Firefox keep no creation time: those are left alone unless known.
DateTime? _shownAt(web.Notification notification)
{
  final JSAny? stamp = (notification as JSObject).getProperty('timestamp'.toJS);

  return stamp.isA<JSNumber>()
      ? DateTime.fromMillisecondsSinceEpoch((stamp as JSNumber).toDartDouble.toInt())
      : null;
}

// Closes what the list says is read or gone; one shown after the list was fetched may be new.
Future<void> tidyPushNotifications({
  required Set<int> unread,
  required Set<int> listed,
  required DateTime listedAt,
}) async
{
  if (!pushPlatformSupported || web.Notification.permission != 'granted')
  {
    return;
  }

  final web.ServiceWorkerRegistration? registration =
      await web.window.navigator.serviceWorker.getRegistration(_scope).toDart;

  if (registration == null)
  {
    return;
  }

  final JSArray<web.Notification> shown = await registration.getNotifications().toDart;

  for (final web.Notification notification in shown.toDart)
  {
    final int? id = _idOf(notification);
    final DateTime? shownAt = _shownAt(notification);

    if (id == null || unread.contains(id))
    {
      continue;
    }

    if (listed.contains(id) || (shownAt != null && shownAt.isBefore(listedAt)))
    {
      notification.close();
    }
  }
}

// Signed out: the next person at this computer sees nothing of the last one's.
Future<void> clearPushNotifications() async
{
  if (!pushPlatformSupported)
  {
    return;
  }

  final web.ServiceWorkerRegistration? registration =
      await web.window.navigator.serviceWorker.getRegistration(_scope).toDart;

  if (registration == null)
  {
    return;
  }

  final JSArray<web.Notification> shown = await registration.getNotifications().toDart;

  for (final web.Notification notification in shown.toDart)
  {
    notification.close();
  }
}
