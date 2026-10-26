import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'session_store_prefs.dart' as local_storage;

// IndexedDB, not localStorage: every tab sees a committed write; a tab's localStorage copy can lag.
const String _databaseName = 'casa-michela';
const String _storeName = 'session';
const String _accessTokenKey = 'access_token';
const String _refreshTokenKey = 'refresh_token';

Future<web.IDBDatabase>? _opening;

Future<web.IDBDatabase> _database()
{
  return _opening ??= _open();
}

Future<web.IDBDatabase> _open()
{
  final completer = Completer<web.IDBDatabase>();
  final web.IDBOpenDBRequest request = web.window.indexedDB.open(_databaseName, 1);

  request.onupgradeneeded = (web.Event _)
  {
    (request.result as web.IDBDatabase).createObjectStore(_storeName);
  }.toJS;

  request.onsuccess = (web.Event _)
  {
    completer.complete(request.result as web.IDBDatabase);
  }.toJS;

  request.onerror = (web.Event _)
  {
    completer.completeError(StateError('IndexedDB unavailable'));
  }.toJS;

  return completer.future;
}

Future<void> _committed(web.IDBTransaction transaction)
{
  final completer = Completer<void>();

  transaction.oncomplete = (web.Event _)
  {
    completer.complete();
  }.toJS;

  transaction.onerror = (web.Event _)
  {
    if (!completer.isCompleted)
    {
      completer.completeError(StateError('IndexedDB transaction failed'));
    }
  }.toJS;

  transaction.onabort = (web.Event _)
  {
    if (!completer.isCompleted)
    {
      completer.completeError(StateError('IndexedDB transaction aborted'));
    }
  }.toJS;

  return completer.future;
}

Future<web.IDBTransaction?> _transaction(String mode) async
{
  // A failed open is not kept, and a connection the browser closed is opened again.
  for (var attempt = 0; attempt < 2; attempt++)
  {
    try
    {
      return (await _database()).transaction(_storeName.toJS, mode);
    }
    catch (_)
    {
      _opening = null;
    }
  }

  // Private modes of some browsers refuse IndexedDB: localStorage it is.
  return null;
}

// Null when IndexedDB cannot be read: localStorage answers instead.
Future<({String? accessToken, String? refreshToken})?> _readDatabase() async
{
  final web.IDBTransaction? transaction = await _transaction('readonly');

  if (transaction == null)
  {
    return null;
  }

  try
  {
    final web.IDBObjectStore store = transaction.objectStore(_storeName);
    final web.IDBRequest access = store.get(_accessTokenKey.toJS);
    final web.IDBRequest refresh = store.get(_refreshTokenKey.toJS);

    await _committed(transaction);

    return (
      accessToken: (access.result as JSString?)?.toDart,
      refreshToken: (refresh.result as JSString?)?.toDart,
    );
  }
  catch (_)
  {
    _opening = null;

    return null;
  }
}

Future<({String? accessToken, String? refreshToken})> readSessionImpl() async
{
  final stored = await _readDatabase();

  if (stored == null)
  {
    return local_storage.readSessionImpl();
  }

  if (stored.refreshToken == null)
  {
    return _restoreFromCopy();
  }

  return stored;
}

// Browsers have lost a site's IndexedDB alone, keeping its localStorage: the copy there brings the pair back.
Future<({String? accessToken, String? refreshToken})> _restoreFromCopy() async
{
  final stored = await local_storage.readSessionImpl();
  final String? accessToken = stored.accessToken;
  final String? refreshToken = stored.refreshToken;

  if (accessToken == null || refreshToken == null)
  {
    return (accessToken: null, refreshToken: null);
  }

  try
  {
    await _writeDatabase(accessToken, refreshToken);
  }
  catch (_)
  {
    // The copy still holds the pair: the next write tries IndexedDB again.
  }

  return stored;
}

// The copy is read only when IndexedDB holds no pair, so its lag across tabs does no harm.
Future<void> writeSessionImpl(String accessToken, String refreshToken) async
{
  await local_storage.writeSessionImpl(accessToken, refreshToken);
  await _writeDatabase(accessToken, refreshToken);
}

Future<void> _writeDatabase(String accessToken, String refreshToken) async
{
  final web.IDBTransaction? transaction = await _transaction('readwrite');

  if (transaction == null)
  {
    return;
  }

  final web.IDBObjectStore store = transaction.objectStore(_storeName);

  store.put(accessToken.toJS, _accessTokenKey.toJS);
  store.put(refreshToken.toJS, _refreshTokenKey.toJS);

  await _committed(transaction);
}

// The copy first: a pair left behind in it would come back at the next start.
Future<void> clearSessionImpl() async
{
  await local_storage.clearSessionImpl();

  final web.IDBTransaction? transaction = await _transaction('readwrite');

  if (transaction == null)
  {
    return;
  }

  final web.IDBObjectStore store = transaction.objectStore(_storeName);

  store.delete(_accessTokenKey.toJS);
  store.delete(_refreshTokenKey.toJS);

  await _committed(transaction);
}
