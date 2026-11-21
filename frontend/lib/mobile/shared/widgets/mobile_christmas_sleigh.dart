import 'package:flutter/material.dart';

import '../../../core/utils/festivities.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../features/auth/models/me_response.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_state.dart';
import '../../../shared/widgets/sleigh_flight.dart';

// Santa's sleigh in the shell above the pages, once per launch on Christmas while the home is on show.
class MobileChristmasSleigh extends StatefulWidget
{
  // Leaving the home ends the show.
  final bool onHome;

  const MobileChristmasSleigh({super.key, required this.onHome});

  // Tax code already greeted this launch.
  static String? _celebrated;

  @visibleForTesting
  static void debugReset() => _celebrated = null;

  @override
  State<MobileChristmasSleigh> createState() => _MobileChristmasSleighState();
}

class _MobileChristmasSleighState extends State<MobileChristmasSleigh>
{
  final ApiService _apiService = ApiService();

  SleighFlight? _show;

  @override
  void initState()
  {
    super.initState();

    _apiService.identity.addListener(_onIdentity);
    _apiService.authState.addListener(_onIdentity);
  }

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();

    _start(notify: false);
  }

  @override
  void didUpdateWidget(MobileChristmasSleigh oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (!widget.onHome)
    {
      _show?.end();
    }
    else if (!oldWidget.onHome)
    {
      _start(notify: false);
    }
  }

  @override
  void dispose()
  {
    _apiService.identity.removeListener(_onIdentity);
    _apiService.authState.removeListener(_onIdentity);
    _show?.removeListener(_onShow);
    _show?.end();

    super.dispose();
  }

  void _onIdentity() => _start(notify: true);

  void _start({required bool notify})
  {
    final MeResponse? user = _apiService.identity.value;

    if (!widget.onHome ||
        MediaQuery.disableAnimationsOf(context) ||
        _apiService.authState.value != AuthState.authenticated ||
        user == null ||
        festivityFor(user.birthDate, romeNow()) != Festivity.christmas ||
        MobileChristmasSleigh._celebrated == user.taxCode)
    {
      return;
    }

    MobileChristmasSleigh._celebrated = user.taxCode;

    _show?.removeListener(_onShow);
    _show?.end();
    _show = SleighFlight()..addListener(_onShow);

    if (notify)
    {
      setState(() {});
    }
  }

  // Ticks repaint through the painter; only the end needs a rebuild, to drop it.
  void _onShow()
  {
    if (_show!.done && mounted)
    {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final SleighFlight? show = _show;

    if (show == null || show.done)
    {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints)
          {
            final SleighSpec spec = SleighSpec.mobile(constraints.biggest, MediaQuery.viewPaddingOf(context).top);

            return SizedBox.expand(child: CustomPaint(painter: SleighPainter(flight: show, spec: spec)));
          },
        ),
      ),
    );
  }
}
