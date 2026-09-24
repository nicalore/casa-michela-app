import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'session_store_stub.dart' as legacy;

// IndexedDB, not localStorage: once a write has committed every tab reads it,
// while a tab's copy of localStorage can lag behind another tab's write.
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
  try
  {
    return (await _database()).transaction(_storeName.toJS, mode);
  }
  catch (_)
  {
    // Private modes of some browsers refuse IndexedDB: localStorage it is.
    return null;
  }
}

Future<({String? accessToken, String? refreshToken})> readSessionImpl() async
{
  final web.IDBTransaction? transaction = await _transaction('readonly');

  if (transaction == null)
  {
    return legacy.readSessionImpl();
  }

  final web.IDBObjectStore store = transaction.objectStore(_storeName);
  final web.IDBRequest access = store.get(_accessTokenKey.toJS);
  final web.IDBRequest refresh = store.get(_refreshTokenKey.toJS);

  await _committed(transaction);

  final String? refreshToken = (refresh.result as JSString?)?.toDart;

  if (refreshToken == null)
  {
    return _moveOverFromLocalStorage();
  }

  return (accessToken: (access.result as JSString?)?.toDart, refreshToken: refreshToken);
}

// A session opened before this store existed sits in localStorage.
Future<({String? accessToken, String? refreshToken})> _moveOverFromLocalStorage() async
{
  final stored = await legacy.readSessionImpl();
  final String? accessToken = stored.accessToken;
  final String? refreshToken = stored.refreshToken;

  if (accessToken == null || refreshToken == null)
  {
    return (accessToken: null, refreshToken: null);
  }

  await writeSessionImpl(accessToken, refreshToken);
  await legacy.clearSessionImpl();

  return stored;
}

Future<void> writeSessionImpl(String accessToken, String refreshToken) async
{
  final web.IDBTransaction? transaction = await _transaction('readwrite');

  if (transaction == null)
  {
    return legacy.writeSessionImpl(accessToken, refreshToken);
  }

  final web.IDBObjectStore store = transaction.objectStore(_storeName);

  store.put(accessToken.toJS, _accessTokenKey.toJS);
  store.put(refreshToken.toJS, _refreshTokenKey.toJS);

  await _committed(transaction);
}

Future<void> clearSessionImpl() async
{
  final web.IDBTransaction? transaction = await _transaction('readwrite');

  if (transaction == null)
  {
    return legacy.clearSessionImpl();
  }

  final web.IDBObjectStore store = transaction.objectStore(_storeName);

  store.delete(_accessTokenKey.toJS);
  store.delete(_refreshTokenKey.toJS);

  await _committed(transaction);
}
