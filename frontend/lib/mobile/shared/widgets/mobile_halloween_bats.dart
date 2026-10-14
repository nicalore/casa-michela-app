import 'package:flutter/material.dart';

import '../../../core/utils/halloween.dart';
import '../../../core/utils/rome_clock.dart';
import '../../../features/auth/models/me_response.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_state.dart';
import '../../../shared/widgets/bat_flight.dart';

const Color _far = Color(0xFF16252C);
const Color _near = Color(0xFF06080C);

// Lives in the shell above the pages, flying once per launch while the home is on show.
class MobileHalloweenBats extends StatefulWidget
{
  // Leaving the home ends the flight.
  final bool onHome;

  const MobileHalloweenBats({super.key, required this.onHome});

  // Tax code already greeted this launch.
  static String? _celebrated;

  @visibleForTesting
  static void debugReset() => _celebrated = null;

  @override
  State<MobileHalloweenBats> createState() => _MobileHalloweenBatsState();
}

class _MobileHalloweenBatsState extends State<MobileHalloweenBats>
{
  final ApiService _apiService = ApiService();

  BatFlight? _flight;

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
  void didUpdateWidget(MobileHalloweenBats oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    if (!widget.onHome)
    {
      _flight?.end();
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
    _flight?.removeListener(_onFlight);
    _flight?.end();

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
        !isHalloweenFor(user.birthDate, romeNow()) ||
        MobileHalloweenBats._celebrated == user.taxCode)
    {
      return;
    }

    MobileHalloweenBats._celebrated = user.taxCode;

    _flight?.removeListener(_onFlight);
    _flight?.end();
    _flight = BatFlight()..addListener(_onFlight);

    if (notify)
    {
      setState(() {});
    }
  }

  // Ticks repaint through the painter; only the end needs a rebuild, to drop it.
  void _onFlight()
  {
    if (_flight!.done && mounted)
    {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context)
  {
    final BatFlight? flight = _flight;

    if (flight == null || flight.done)
    {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints)
          {
            final List<FlyingBat> bats = flight.planFor(BatFlightSpec.mobile(constraints.biggest));

            return SizedBox.expand(
              child: CustomPaint(painter: BatsPainter(flight: flight, bats: bats, far: _far, near: _near)),
            );
          },
        ),
      ),
    );
  }
}
