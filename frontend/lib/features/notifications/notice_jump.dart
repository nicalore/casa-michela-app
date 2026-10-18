import 'package:flutter/foundation.dart';

// A notification asking Comunicazioni e avvisi to open a notice: a page not built yet takes it when
// it starts, one already shown hears of it.
class NoticeJumpChannel
{
  int? _pending;

  // The role whose page it is for: another role's, still open while the area switches, leaves it.
  String? _role;

  // Bumped on every request.
  final ValueNotifier<int> asked = ValueNotifier<int>(0);

  bool get isPending => _pending != null;

  void request(int id, {String? role})
  {
    _pending = id;
    _role = role;
    asked.value++;
  }

  int? take({String? role})
  {
    if (_role != null && role != null && role != _role)
    {
      return null;
    }

    final int? id = _pending;
    _pending = null;

    return id;
  }
}

abstract final class NoticeJumps
{
  // Every role's Comunicazioni e avvisi, the administrator's on the desktop only.
  static final NoticeJumpChannel reading = NoticeJumpChannel();
}
