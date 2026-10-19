import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/models/me_response.dart';
import '../../services/api_service.dart';
import 'device_push_native.dart' if (dart.library.js_interop) 'device_push_web.dart' as device;
import 'notification_board.dart';
import 'notification_item.dart';
import 'notification_kinds.dart';
import 'push_types.dart';

enum NotificationSwitch
{
  // No push here, or the server has no key: nothing to offer.
  unsupported,
  off,
  // Refused for good: only the browser's or the system's settings can undo it.
  blocked,
  on,
}

abstract final class DeviceNotifications
{
  // Turned off by hand here: kept off even while the system allows them.
  static const String _offKey = 'notifications_off';

  // The first-access question was put on this device.
  static const String _offeredKey = 'notifications_offered';

  static final ValueNotifier<NotificationSwitch> _state = ValueNotifier(NotificationSwitch.unsupported);

  static ValueListenable<NotificationSwitch> get state => _state;

  static NotificationSwitch? _debugState;

  // Widget tests run on no device: this stands in for what it would answer.
  @visibleForTesting
  static set debugState(NotificationSwitch? value)
  {
    _debugState = value;
    _state.value = value ?? NotificationSwitch.unsupported;
  }

  static bool _following = false;
  static String? _signedIn;
  static String? _serverKey;
  static String? _address;

  // A tap that opened the app before anyone was signed in.
  static PushNews? _pendingOpened;

  // Once in main: every sign-in reads the device again and keeps its subscription current.
  static void follow()
  {
    if (_following)
    {
      return;
    }

    _following = true;
    ApiService().identity.addListener(_onIdentity);
    ApiService().beforeSignOut = _forget;
    NotificationBoard.instance.addListener(_tidy);
    device.pushNews().listen(_hear);
    AppLifecycleListener(onResume: _onResume);
    _onIdentity();
  }

  static void _hear(PushNews news)
  {
    if (news.type == PushNewsType.opened && _signedIn == null)
    {
      _pendingOpened = news;
    }
    else if (news.type != PushNewsType.renewed)
    {
      NotificationBoard.instance.hear(news);
    }
    else if (_signedIn != null && _state.value == NotificationSwitch.on)
    {
      unawaited(refresh(subscribe: true));
    }
  }

  // Back from the system's settings, where they may have been allowed or blocked.
  static void _onResume()
  {
    if (_signedIn != null)
    {
      unawaited(refresh(subscribe: _state.value != NotificationSwitch.on));
    }
  }

  static void _onIdentity()
  {
    final MeResponse? me = ApiService().identity.value;
    final String? taxCode = me?.taxCode;

    if (taxCode == _signedIn)
    {
      return;
    }

    // Signed out or someone else in, here or by a session ended elsewhere.
    if (_signedIn != null)
    {
      unawaited(_quiet(device.clearPushNotifications()));
    }

    _signedIn = taxCode;
    NotificationBoard.instance.clear();
    NotificationKinds.instance.clear();

    if (taxCode == null)
    {
      return;
    }

    unawaited(refresh(subscribe: true));

    final PushNews? opened = _pendingOpened;
    _pendingOpened = null;

    if (opened != null)
    {
      unawaited(NotificationBoard.instance.hear(opened));
    }
  }

  // Read here or elsewhere, or withdrawn: off the system's tray too.
  static void _tidy()
  {
    final List<NotificationItem>? items = NotificationBoard.instance.items;
    final DateTime? listedAt = NotificationBoard.instance.listedAt;

    if (_state.value != NotificationSwitch.on || items == null || listedAt == null)
    {
      return;
    }

    unawaited(_quiet(device.tidyPushNotifications(
      unread: {for (final item in items) if (!item.read) item.id},
      listed: {for (final item in items) item.id},
      listedAt: listedAt,
    )));
  }

  static Future<T?> _quiet<T>(Future<T?> work) async
  {
    try
    {
      return await work;
    }
    catch (error)
    {
      if (kDebugMode)
      {
        debugPrint('Notifications: $error');
      }

      return null;
    }
  }

  static Future<bool> _turnedOff() async
  {
    final SharedPreferences? prefs = await _quiet(SharedPreferences.getInstance());

    return prefs?.getBool(_offKey) ?? false;
  }

  static Future<void> _remember(String key, bool value) async
  {
    final SharedPreferences? prefs = await _quiet(SharedPreferences.getInstance());

    await _quiet(prefs?.setBool(key, value) ?? Future<bool>.value(false));
  }

  // [subscribe] makes the browser's subscription when missing and hands it to the server.
  static Future<NotificationSwitch> refresh({bool subscribe = false}) async
  {
    final NotificationSwitch next = await _read(subscribe: subscribe);

    _state.value = next;

    return next;
  }

  static Future<NotificationSwitch> _read({required bool subscribe}) async
  {
    final NotificationSwitch? stand = _debugState;

    if (stand != null)
    {
      return stand;
    }

    if (!device.pushPlatformSupported)
    {
      return NotificationSwitch.unsupported;
    }

    if (device.pushNeedsServerKey)
    {
      _serverKey ??= await _quiet(ApiService().getWebPushKey());

      if (_serverKey == null)
      {
        return NotificationSwitch.unsupported;
      }
    }

    final PushPermission permission = await _quiet(device.readPushPermission()) ?? PushPermission.unsupported;

    switch (permission)
    {
      case PushPermission.unsupported:
        return NotificationSwitch.unsupported;
      case PushPermission.denied:
        return NotificationSwitch.blocked;
      case PushPermission.prompt:
        return NotificationSwitch.off;
      case PushPermission.granted:
        break;
    }

    if (await _turnedOff())
    {
      return NotificationSwitch.off;
    }

    if (!device.pushNeedsSubscription)
    {
      return NotificationSwitch.on;
    }

    final PushAddress? address = await _quiet(
      subscribe ? device.subscribePush(_serverKey) : device.currentPushAddress(),
    );

    if (address == null)
    {
      return NotificationSwitch.off;
    }

    if (subscribe && ApiService().identity.value != null)
    {
      await _quiet(ApiService().registerPushAddress(address));
    }

    _address = address.address;

    return NotificationSwitch.on;
  }

  // Asks the system first, straight from the tap: browsers ask only inside one.
  static Future<NotificationSwitch> turnOn() async
  {
    // The test stand-in answers as the device would after this.
    if (_debugState != null)
    {
      _debugState = NotificationSwitch.on;
    }

    final PushPermission permission = await _quiet(device.askPushPermission()) ?? PushPermission.unsupported;

    if (permission == PushPermission.denied && _debugState == null)
    {
      _state.value = NotificationSwitch.blocked;

      return NotificationSwitch.blocked;
    }

    if (permission != PushPermission.granted && _debugState == null)
    {
      return refresh();
    }

    await _remember(_offKey, false);

    final NotificationSwitch result = await refresh(subscribe: true);

    if (result == NotificationSwitch.on)
    {
      await _wakeKinds();
    }

    return result;
  }

  // Back on with every kind off, nothing would arrive: they all come back.
  static Future<void> _wakeKinds() async
  {
    final NotificationKinds kinds = NotificationKinds.instance;

    await kinds.load();

    final List<NotificationKindChoice>? choices = kinds.choices;

    if (choices == null || choices.isEmpty || choices.any((choice) => choice.enabled))
    {
      return;
    }

    await _quiet(kinds.save([for (final choice in choices) choice.turned(true)]));
  }

  static Future<void> turnOff() async
  {
    if (_debugState != null)
    {
      _debugState = NotificationSwitch.off;
    }

    await _remember(_offKey, true);
    await _unsubscribe();
    await refresh();
  }

  // With every kind off there is nothing to show: this device turns them off too.
  static Future<void> chooseKinds(List<NotificationKindChoice> wanted) async
  {
    await NotificationKinds.instance.save(wanted);

    if (wanted.isNotEmpty && wanted.every((choice) => !choice.enabled))
    {
      await turnOff();
    }
  }

  static Future<void> _unsubscribe() async
  {
    final String? address = await _quiet(device.unsubscribePush()) ?? _address;

    _address = null;

    if (address != null)
    {
      await _quiet(ApiService().forgetPushAddress(address));
    }
  }

  // A shared computer must not bring the last person's notifications to the next one.
  static Future<void> _forget()
  {
    return _unsubscribe();
  }

  // The system page that turns them back on, where the device has one.
  static Future<bool> openSettings() async => await _quiet(device.openPushSettings()) ?? false;

  // The first-access question: once per device, and only while the system can still ask.
  static Future<bool> shouldOffer() async
  {
    if (await refresh() != NotificationSwitch.off)
    {
      return false;
    }

    final PushPermission permission = await _quiet(device.readPushPermission()) ?? PushPermission.unsupported;
    final SharedPreferences? prefs = await _quiet(SharedPreferences.getInstance());

    return permission == PushPermission.prompt && prefs != null && !(prefs.getBool(_offeredKey) ?? false);
  }

  static Future<void> markOffered() => _remember(_offeredKey, true);
}
