import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'notification_item.dart';
import 'push_types.dart';

const MethodChannel _channel = MethodChannel('it.casamichela.app/notifications');

String get pushPlatform => Platform.isIOS ? 'ios' : 'android';

bool get pushPlatformSupported => Platform.isAndroid || Platform.isIOS;

// Android is reached through its Firebase token; iOS has no push service yet.
bool get pushNeedsSubscription => Platform.isAndroid;

const bool pushNeedsServerKey = false;

PushPermission _permissionOf(String? value)
{
  return switch (value)
  {
    'granted' => PushPermission.granted,
    'denied' => PushPermission.denied,
    'prompt' => PushPermission.prompt,
    _ => PushPermission.unsupported,
  };
}

Future<T?> _invoke<T>(String method) async
{
  if (!pushPlatformSupported)
  {
    return null;
  }

  try
  {
    return await _channel.invokeMethod<T>(method);
  }
  on MissingPluginException
  {
    return null;
  }
}

Future<PushPermission> readPushPermission() async
{
  try
  {
    return _permissionOf(await _invoke<String>('status'));
  }
  on PlatformException
  {
    return PushPermission.unsupported;
  }
}

Future<PushPermission> askPushPermission() async
{
  try
  {
    return _permissionOf(await _invoke<String>('request'));
  }
  on PlatformException
  {
    return PushPermission.unsupported;
  }
}

// The token Firebase gives this install; asking for it registers the app the first time.
Future<PushAddress?> currentPushAddress() async
{
  if (!pushNeedsSubscription)
  {
    return null;
  }

  final String? token = await _invoke<String>('token');

  return token == null ? null : PushAddress(platform: pushPlatform, address: token);
}

Future<PushAddress?> subscribePush(String? serverKey) => currentPushAddress();

// The token dies with it; the caller tells the server which one it was.
Future<String?> unsubscribePush() async
{
  if (pushNeedsSubscription)
  {
    await _invoke<bool>('deleteToken');
  }

  return null;
}

StreamController<PushNews>? _news;

PushNews? _newsOf(MethodCall call)
{
  final Object? id = call.arguments;

  return switch (call.method)
  {
    'arrived' when id is int => PushNews(PushNewsType.arrived, id),
    'opened' when id is int => PushNews(PushNewsType.opened, id),
    'dismissed' when id is int => PushNews(PushNewsType.dismissed, id),
    'renewed' => const PushNews(PushNewsType.renewed, 0),
    _ => null,
  };
}

// The app hears from its own Firebase service; the notification that opened it comes first.
Stream<PushNews> pushNews()
{
  if (!pushPlatformSupported)
  {
    return const Stream.empty();
  }

  final StreamController<PushNews> news = _news ??= StreamController<PushNews>.broadcast(
    onListen: () async
    {
      final int? opened = await _invoke<int>('takeOpened').catchError((Object _) => null);

      if (opened != null)
      {
        _news?.add(PushNews(PushNewsType.opened, opened));
      }
    },
  );

  _channel.setMethodCallHandler((call) async
  {
    final PushNews? told = _newsOf(call);

    if (told != null)
    {
      news.add(told);
    }
  });

  return news.stream;
}

Future<bool> openPushSettings() async
{
  try
  {
    return await _invoke<bool>('openSettings') ?? false;
  }
  on PlatformException
  {
    return false;
  }
}

// Takes off the tray what the list says is read or gone; one posted after it may be new.
Future<void> tidyPushNotifications({
  required Set<int> unread,
  required Set<int> listed,
  required DateTime listedAt,
}) async
{
  if (!pushNeedsSubscription)
  {
    return;
  }

  try
  {
    await _channel.invokeMethod<void>('tidy', {
      'unread': unread.toList(),
      'listed': listed.toList(),
      'listedAt': listedAt.millisecondsSinceEpoch,
    });
  }
  on PlatformException
  {
    return;
  }
  on MissingPluginException
  {
    return;
  }
}

// Signed out: the next person on this phone sees nothing of the last one's.
Future<void> clearPushNotifications() async
{
  if (!pushNeedsSubscription)
  {
    return;
  }

  try
  {
    await _channel.invokeMethod<void>('clear');
  }
  on PlatformException
  {
    return;
  }
  on MissingPluginException
  {
    return;
  }
}
