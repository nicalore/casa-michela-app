Future<T> inTurnWithOtherTabsImpl<T>(String lock, Future<T> Function() body) => body();

void tellOtherTabsImpl(Map<String, String> message) {}

void listenToOtherTabsImpl(void Function(Map<String, String> message) onMessage) {}
