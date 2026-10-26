import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/models/me_response.dart';
import 'account_keys.dart';
import 'api_service.dart';

enum TourPlatform
{
  mobile('mobile', 'mobile_tour'),
  desktop('desktop', 'desktop_tour');

  // In the API path.
  final String path;

  // Of the device's copy: "<prefix>/<account key>/<slug>" holds the version seen.
  final String prefix;

  const TourPlatform(this.path, this.prefix);
}

// Tutorial tours seen per account, kept on the server so each shows once whatever the device.
// The device keeps a copy: a mark the server missed is sent again at the next start.
class SeenTours
{
  static final SeenTours mobile = SeenTours._(TourPlatform.mobile);
  static final SeenTours desktop = SeenTours._(TourPlatform.desktop);

  // Every tour counts as seen: a test looking at a page gets no tour over it.
  @visibleForTesting
  static bool debugAllSeen = false;

  final TourPlatform platform;

  // Off until follow(): the device's copy alone answers.
  bool _following = false;

  String? _owner;
  Map<String, int>? _server;
  Future<Map<String, int>?>? _loading;

  SeenTours._(this.platform);

  // From main: the server's marks are read as soon as someone signs in, new ones are sent.
  void follow()
  {
    if (_following)
    {
      return;
    }

    _following = true;
    ApiService().identity.addListener(_onIdentity);
    _onIdentity();
  }

  void _onIdentity()
  {
    final MeResponse? me = ApiService().identity.value;

    if (me == null)
    {
      _forget();

      return;
    }

    unawaited(_fromServer(me.taxCode));
  }

  void _forget()
  {
    _owner = null;
    _server = null;
    _loading = null;
  }

  String _prefixOf(String taxCode) => '${platform.prefix}/${accountKeyOf(taxCode)}/';

  String _key(String taxCode, String slug) => '${_prefixOf(taxCode)}$slug';

  // Slugs marked here and not yet heard by the server.
  String _pendingKey(String taxCode) => '${platform.prefix}_pending/${accountKeyOf(taxCode)}';

  // Set once the local marks unknown to the server have all been sent.
  String _sentKey(String taxCode) => '${platform.prefix}_sent/${accountKeyOf(taxCode)}';


  Map<String, int> _local(SharedPreferences prefs, String taxCode)
  {
    final String prefix = _prefixOf(taxCode);

    return {
      for (final String key in prefs.getKeys())
        if (key.startsWith(prefix) && prefs.get(key) is int) key.substring(prefix.length): prefs.get(key)! as int,
    };
  }

  // Null while the server cannot be reached: the next check asks again.
  Future<Map<String, int>?> _fromServer(String taxCode)
  {
    if (_owner != taxCode)
    {
      _forget();
      _owner = taxCode;
    }

    final Map<String, int>? known = _server;

    if (known != null)
    {
      return Future.value(known);
    }

    return _loading ??= _fetch(taxCode).whenComplete(() => _loading = null);
  }

  Future<Map<String, int>?> _fetch(String taxCode) async
  {
    final Map<String, int> server;

    try
    {
      server = await ApiService().getSeenTours(platform.path);
    }
    catch (_)
    {
      return null;
    }

    if (_owner == taxCode)
    {
      _server = server;
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    moveAccountKeys(prefs, taxCode);
    final Map<String, int> local = _local(prefs, taxCode);
    final Iterable<String> pending =
        prefs.getBool(_sentKey(taxCode)) == true ? prefs.getStringList(_pendingKey(taxCode)) ?? const [] : local.keys;

    final Map<String, int> ahead = {
      for (final String slug in pending)
        if ((local[slug] ?? 0) > (server[slug] ?? 0)) slug: local[slug]!,
    };

    unawaited(_send(taxCode, ahead, catchUp: true));

    return server;
  }

  // catchUp: [seen] holds every mark the server lacked, so the local copy counts as sent.
  Future<void> _send(String taxCode, Map<String, int> seen, {bool catchUp = false}) async
  {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    moveAccountKeys(prefs, taxCode);

    try
    {
      if (seen.isNotEmpty)
      {
        await ApiService().markToursSeen(platform.path, seen);
      }

      await prefs.setStringList(
        _pendingKey(taxCode),
        [...?prefs.getStringList(_pendingKey(taxCode))]..removeWhere(seen.containsKey),
      );

      if (catchUp)
      {
        await prefs.setBool(_sentKey(taxCode), true);
      }
    }
    catch (_)
    {
      await prefs.setStringList(
        _pendingKey(taxCode),
        {...?prefs.getStringList(_pendingKey(taxCode)), ...seen.keys}.toList(),
      );
    }
  }

  Future<bool> hasSeen({required String taxCode, required String slug, required int version}) async
  {
    if (debugAllSeen)
    {
      return true;
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    moveAccountKeys(prefs, taxCode);

    // A stored bool, not an int version, is ignored here.
    final Object? local = prefs.get(_key(taxCode, slug));

    if (local is int && local >= version)
    {
      return true;
    }

    if (!_following)
    {
      return false;
    }

    final Map<String, int>? server = await _fromServer(taxCode);

    return (server?[slug] ?? 0) >= version;
  }

  Future<void> markSeen(String taxCode, Map<String, int> seen) async
  {
    if (seen.isEmpty)
    {
      return;
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    moveAccountKeys(prefs, taxCode);

    for (final MapEntry<String, int> entry in seen.entries)
    {
      await prefs.setInt(_key(taxCode, entry.key), entry.value);
    }

    if (_following)
    {
      unawaited(_send(taxCode, seen));
    }
  }

  // Every tour slugged after these sections shows again; null sections: every tour.
  Future<void> reset(String taxCode, [Iterable<String>? sections]) async
  {
    final List<String>? chosen = sections?.toList();

    if (chosen != null && chosen.isEmpty)
    {
      return;
    }

    bool under(String slug) => chosen == null || chosen.any((section) => slug == section || slug.startsWith('$section.'));

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    moveAccountKeys(prefs, taxCode);
    final String prefix = _prefixOf(taxCode);

    for (final String key in prefs.getKeys().toList())
    {
      if (key.startsWith(prefix) && under(key.substring(prefix.length)))
      {
        await prefs.remove(key);
      }
    }

    final List<String>? pending = prefs.getStringList(_pendingKey(taxCode));

    if (pending != null)
    {
      await prefs.setStringList(_pendingKey(taxCode), [...pending]..removeWhere(under));
    }

    if (!_following)
    {
      return;
    }

    if (_owner == taxCode)
    {
      _server?.removeWhere((slug, _) => under(slug));
    }

    try
    {
      await ApiService().resetTours(platform.path, chosen);
    }
    catch (_)
    {
      // Shown again on this device all the same; the server keeps the old marks.
    }
  }
}
