import 'browser_tabs_stub.dart' if (dart.library.js_interop) 'browser_tabs_web.dart';

// The tabs of one browser share the stored session. A native build runs one
// copy of the app: the lock is always free and no message goes anywhere.

// Runs body while no other tab of this browser holds the lock of that name.
Future<T> inTurnWithOtherTabs<T>(String lock, Future<T> Function() body) =>
    inTurnWithOtherTabsImpl(lock, body);

void tellOtherTabs(Map<String, String> message) => tellOtherTabsImpl(message);

void listenToOtherTabs(void Function(Map<String, String> message) onMessage) =>
    listenToOtherTabsImpl(onMessage);
