import 'browser_tabs_stub.dart' if (dart.library.js_interop) 'browser_tabs_web.dart';

// Tabs of one browser share the stored session; on native the lock is always free and messages go nowhere.

Future<T> inTurnWithOtherTabs<T>(String lock, Future<T> Function() body) =>
    inTurnWithOtherTabsImpl(lock, body);

void tellOtherTabs(Map<String, String> message) => tellOtherTabsImpl(message);

void listenToOtherTabs(void Function(Map<String, String> message) onMessage) =>
    listenToOtherTabsImpl(onMessage);
