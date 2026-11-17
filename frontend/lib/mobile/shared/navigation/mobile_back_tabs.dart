import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

// A page strip as the system back sees it.
abstract interface class MobileBackTab
{
  bool get onFirst;

  void goFirst();
}

// The strips of the shell's sections: the system back takes them to their first page before leaving.
class MobileBackTabs extends ChangeNotifier
{
  final Set<MobileBackTab> _tabs = {};

  bool _allFirst = true;
  bool _scheduled = false;
  bool _disposed = false;

  bool get allFirst => _allFirst;

  void add(MobileBackTab tab)
  {
    if (_tabs.add(tab))
    {
      changed();
    }
  }

  void remove(MobileBackTab tab)
  {
    if (_tabs.remove(tab))
    {
      changed();
    }
  }

  // False when every strip already shows its first page.
  bool goFirst()
  {
    bool moved = false;

    for (final MobileBackTab tab in _tabs.toList())
    {
      if (!tab.onFirst)
      {
        tab.goFirst();
        moved = true;
      }
    }

    return moved;
  }

  // Cheap enough per scroll tick. Strips mount and unmount mid-frame, when the shell cannot rebuild.
  void changed()
  {
    if (_disposed)
    {
      return;
    }

    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.persistentCallbacks)
    {
      _recount();

      return;
    }

    if (_scheduled)
    {
      return;
    }

    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_)
    {
      _scheduled = false;

      if (!_disposed)
      {
        _recount();
      }
    });
  }

  void _recount()
  {
    final bool allFirst = _tabs.every((tab) => tab.onFirst);

    if (allFirst != _allFirst)
    {
      _allFirst = allFirst;
      notifyListeners();
    }
  }

  @override
  void dispose()
  {
    _disposed = true;

    super.dispose();
  }
}

class MobileBackTabsScope extends InheritedWidget
{
  final MobileBackTabs tabs;

  const MobileBackTabsScope({super.key, required this.tabs, required super.child});

  // Null in sheets: they are routes of their own.
  static MobileBackTabs? maybeOf(BuildContext context)
  {
    return context.getInheritedWidgetOfExactType<MobileBackTabsScope>()?.tabs;
  }

  @override
  bool updateShouldNotify(MobileBackTabsScope oldWidget) => tabs != oldWidget.tabs;
}
