import 'package:flutter/material.dart';

import '../../core/utils/birthday.dart';
import '../../core/utils/rome_clock.dart';
import '../../features/auth/models/me_response.dart';
import 'confetti_shower.dart';
import 'page_transition.dart';

// One shower per launch, shared by every bar; a page without a bar ends it.
class BirthdayConfetti extends StatefulWidget
{
  final MeResponse user;

  // Page coordinates; painted under the bar so pieces emerge from its lower edge.
  final Rect source;

  const BirthdayConfetti({super.key, required this.user, required this.source});

  // Tax code already celebrated this launch.
  static String? _celebrated;

  static ConfettiShower? _shower;

  // Bars currently painting; the shower ends when none is left.
  static final Set<_BirthdayConfettiState> _hosts = {};

  static void _startFor(MeResponse user)
  {
    if (!isBirthdayToday(user.birthDate, romeNow()) || _celebrated == user.taxCode)
    {
      return;
    }

    _celebrated = user.taxCode;
    _shower = ConfettiShower(shouldEnd: () => _hosts.isEmpty);
  }

  @visibleForTesting
  static void debugReset()
  {
    _shower?.end();
    _shower = null;
    _celebrated = null;
  }

  @visibleForTesting
  static double? get debugElapsed => _shower == null || _shower!.done ? null : _shower!.elapsed;

  @visibleForTesting
  static int get debugHosts => _hosts.length;

  @override
  State<BirthdayConfetti> createState() => _BirthdayConfettiState();
}

class _BirthdayConfettiState extends State<BirthdayConfetti>
{
  bool _hosting = false;

  ConfettiShower? _shower;

  bool get _shown
  {
    return isDestinationShown(context) &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
  }

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();

    final bool shown = _shown;

    if (shown != _hosting)
    {
      _hosting = shown;

      if (shown)
      {
        BirthdayConfetti._hosts.add(this);
      }
      else
      {
        BirthdayConfetti._hosts.remove(this);
      }
    }

    if (shown)
    {
      BirthdayConfetti._startFor(widget.user);
    }

    _listen(BirthdayConfetti._shower);
  }

  @override
  void didUpdateWidget(BirthdayConfetti oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (_hosting && oldWidget.user.taxCode != widget.user.taxCode)
    {
      BirthdayConfetti._startFor(widget.user);
      _listen(BirthdayConfetti._shower);
    }
  }

  void _listen(ConfettiShower? shower)
  {
    if (identical(shower, _shower))
    {
      return;
    }

    _shower?.removeListener(_onShower);
    _shower = shower;
    _shower?.addListener(_onShower);
  }

  // Ticks repaint through the painter; only the end needs a rebuild, to drop it.
  void _onShower()
  {
    if (_shower!.done)
    {
      setState(() {});
    }
  }

  @override
  void dispose()
  {
    BirthdayConfetti._hosts.remove(this);
    _shower?.removeListener(_onShower);
    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    final ConfettiShower? shower = _shower;

    if (shower == null || shower.done)
    {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints)
      {
        shower.noteDrop(constraints.maxHeight - widget.source.top);

        return IgnorePointer(
          child: RepaintBoundary(
            child: SizedBox.expand(
              child: CustomPaint(
                painter: ConfettiPainter(shower: shower, source: widget.source),
              ),
            ),
          ),
        );
      },
    );
  }
}
