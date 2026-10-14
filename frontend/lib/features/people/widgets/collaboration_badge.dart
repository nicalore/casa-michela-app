import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/platform/visual_effects.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_tooltip.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../association/tabs/opening_hours/lost_calendars.dart';
import '../models/person_item.dart';
import '../tabs/person_account_shared.dart';

const double _height = 34;
const double _padding = 14;
const double _iconSize = 18;
const double _iconGap = 8;
const double _labelTravel = 22;
const double _ringWidth = 2;
const double _pulseReach = 9;
const double _pressedScale = 0.96;

const Duration _hoverDuration = Duration(milliseconds: 150);
const Duration _flipDuration = Duration(milliseconds: 400);
const Duration _pulseDuration = Duration(milliseconds: 400);
const Duration _pressDuration = Duration(milliseconds: 100);

const Color _activeSurface = Color(0xFFE8F7F5);
const Color _activeHoverSurface = Color(0xFFD6F0EC);
const Color _inactiveSurface = AppTheme.trialPaper;
const Color _inactiveHoverSurface = Color(0xFFDFE5EA);

String collaborationStatusLabel({required bool isActive, required bool isFemale})
{
  return isActive
      ? (isFemale ? 'Collaboratrice attiva' : 'Collaboratore attivo')
      : 'Non collaborante';
}

String _clickTip({required bool isActive, required bool isFemale})
{
  if (isActive)
  {
    return isFemale ? 'Clicca per renderla non collaborante.' : 'Clicca per renderlo non collaborante.';
  }

  return isFemale
      ? 'Clicca per renderla collaboratrice attiva.'
      : 'Clicca per renderlo collaboratore attivo.';
}

// Why a badge that cannot change stays as it is.
String collaborationLockedTip({required bool isRevoked, required bool isFemale})
{
  final String active = isFemale ? 'collaboratrice attiva' : 'collaboratore attivo';

  return isRevoked
      ? "Con l'iscrizione revocata non può diventare $active."
      : "Senza un'iscrizione in corso non può essere $active.";
}

// The sentence on lessons only when some would go; pupils' lessons go with their bookings.
String _stopConsequences(LostHours hours)
{
  final bool teaches = hours.availabilities > 0;
  final bool attends = hours.presences > 0;
  final bool lessons = hours.lessons > 0;

  if (teaches && attends)
  {
    return ' diventerà non collaborante e le sue disponibilità e presenze non ancora iniziate '
        'verranno eliminate definitivamente, insieme alle prenotazioni.'
        '${lessons ? ' Le lezioni già pianificate verranno tolte dal calendario.' : ''}';
  }

  if (attends)
  {
    return ' diventerà non collaborante e le sue presenze non ancora iniziate verranno eliminate '
        'definitivamente, insieme alle prenotazioni${lessons ? ' e alle lezioni già pianificate' : ''}.';
  }

  return ' diventerà non collaborante e le sue disponibilità non ancora iniziate verranno eliminate '
      'definitivamente.'
      '${lessons ? ' Le lezioni già pianificate verranno tolte dal calendario e dovranno essere '
          'nuovamente pianificate.' : ''}';
}

// Shows and toggles the collaboration; with [lockedTip] it only shows it and says why.
class CollaborationBadge extends StatefulWidget
{
  final PersonItem person;
  final bool isActive;

  final String? lockedTip;

  // After a change the server accepted, to refresh the record.
  final VoidCallback? onChanged;

  const CollaborationBadge({
    super.key,
    required this.person,
    required this.isActive,
    this.lockedTip,
    this.onChanged,
  });

  @override
  State<CollaborationBadge> createState() => _CollaborationBadgeState();
}

class _CollaborationBadgeState extends State<CollaborationBadge> with TickerProviderStateMixin
{
  late final AnimationController _hover = AnimationController(vsync: this, duration: _hoverDuration);
  late final AnimationController _flip = AnimationController(vsync: this, duration: _flipDuration, value: 1);
  late final AnimationController _pulse = AnimationController(vsync: this, duration: _pulseDuration);

  late bool _shown = widget.isActive;
  late bool _previous = widget.isActive;

  bool _busy = false;
  bool _pressed = false;

  final Map<bool, double> _widths = {};

  bool get _isFemale => widget.person.gender == 'F';

  bool get _clickable => widget.lockedTip == null;

  @override
  void didChangeDependencies()
  {
    super.didChangeDependencies();
    _widths.clear();
  }

  @override
  void didUpdateWidget(CollaborationBadge oldWidget)
  {
    super.didUpdateWidget(oldWidget);

    _widths.clear();

    // A change from elsewhere (a reload, the automatic return) is shown as it is.
    if (widget.isActive != oldWidget.isActive && widget.isActive != _shown && !_busy)
    {
      _shown = widget.isActive;
      _previous = widget.isActive;
      _flip.value = 1;
    }

    if (!_clickable)
    {
      _hover.value = 0;
    }
  }

  @override
  void dispose()
  {
    _hover.dispose();
    _flip.dispose();
    _pulse.dispose();
    super.dispose();
  }

  TextStyle _labelStyle(Color color)
  {
    return GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: color);
  }

  Color _foreground(bool active) => active ? AppTheme.trialTealDeep : AppTheme.trialMutedText;

  Color _surface(bool active, double hover)
  {
    return active
        ? Color.lerp(_activeSurface, _activeHoverSurface, hover)!
        : Color.lerp(_inactiveSurface, _inactiveHoverSurface, hover)!;
  }

  String _label(bool active) => collaborationStatusLabel(isActive: active, isFemale: _isFemale);

  // Measured, so the width can glide from one label to the other.
  double _width(bool active)
  {
    return _widths.putIfAbsent(active, ()
    {
      final TextPainter painter = TextPainter(
        text: TextSpan(
          text: _label(active),
          style: DefaultTextStyle.of(context).style.merge(_labelStyle(Colors.black)),
        ),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();

      final double width = _padding * 2 + _iconSize + _iconGap + painter.width.ceilToDouble();

      painter.dispose();

      return width;
    });
  }

  Future<bool> _confirmStop(LostHours hours)
  {
    return askPersonConfirmation(
      context,
      eyebrow: 'Collaborazione',
      message: [
        TextSpan(
          text: '${widget.person.firstName} ${widget.person.lastName}',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        TextSpan(text: _stopConsequences(hours)),
      ],
      confirmLabel: 'DISATTIVA',
      confirmIcon: Icons.work_off_rounded,
      danger: true,
    );
  }

  // False when the user declined what switching off would drop.
  Future<bool> _write(bool active) async
  {
    final String fiscalCode = widget.person.fiscalCode;

    try
    {
      await ApiService().setCollaboration(fiscalCode, active: active);

      return true;
    }
    on WriteWouldTakeAway catch (refusal)
    {
      if (!mounted)
      {
        return false;
      }

      // No spinner behind the dialog.
      setState(() => _busy = false);

      if (!await _confirmStop(refusal.hours) || !mounted)
      {
        return false;
      }

      setState(() => _busy = true);

      // Behind the closing dialog the change would go unseen.
      await Future.wait([
        ApiService().setCollaboration(fiscalCode, active: active, confirm: true),
        blurredDialogsGone(),
      ]);

      return true;
    }
  }

  Future<void> _toggle() async
  {
    final bool target = !_shown;

    setState(() => _busy = true);

    try
    {
      if (!await _write(target) || !mounted)
      {
        return;
      }

      _show(target);

      CustomSnackBar.show(
        context: context,
        message: target ? 'Collaborazione attivata!' : 'Collaborazione disattivata!',
        isError: false,
      );

      widget.onChanged?.call();
    }
    catch (e)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(e), isError: true);
      }
    }
    finally
    {
      if (mounted)
      {
        setState(() => _busy = false);
      }
    }
  }

  void _show(bool active)
  {
    setState(()
    {
      _previous = _shown;
      _shown = active;
    });

    if (!VisualEffects.of(context))
    {
      _flip.value = 1;

      return;
    }

    _flip.forward(from: 0).whenComplete(()
    {
      if (mounted)
      {
        _pulse.forward(from: 0);
      }
    });
  }

  Widget _buildIcon(double progress)
  {
    final Color color = _foreground(_shown);

    final Widget icon = Icon(
      _shown ? Icons.handshake_rounded : Icons.work_off_rounded,
      size: _iconSize,
      color: color,
    );

    final Widget spinner = Center(
      child: SizedBox(
        width: _iconSize - 3,
        height: _iconSize - 3,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          color: color,
          backgroundColor: color.withValues(alpha: 0.2),
        ),
      ),
    );

    if (_busy)
    {
      return spinner;
    }

    if (progress >= 1)
    {
      return icon;
    }

    // The spinner leaves in the first quarter, the new icon spins in after it.
    final double leaving = (1 - progress / 0.25).clamp(0.0, 1.0);
    final double arriving = Curves.easeOutBack.transform(((progress - 0.25) / 0.75).clamp(0.0, 1.0));

    return Stack(
      children: [
        if (leaving > 0) Opacity(opacity: leaving, child: spinner),
        Opacity(
          opacity: (arriving * 1.6).clamp(0.0, 1.0),
          child: Transform.rotate(
            angle: -math.pi / 2 * (1 - arriving),
            child: Transform.scale(scale: 0.4 + 0.6 * arriving, child: icon),
          ),
        ),
      ],
    );
  }

  // The old label rises out, the new one rises in from below.
  Widget _buildLabels(double eased)
  {
    final double leaving = (eased / 0.55).clamp(0.0, 1.0);
    final double arriving = ((eased - 0.45) / 0.55).clamp(0.0, 1.0);

    Widget label(bool active, double shift, double opacity)
    {
      return Transform.translate(
        offset: Offset(0, shift),
        child: Opacity(
          opacity: opacity,
          child: Text(
            _label(active),
            maxLines: 1,
            softWrap: false,
            style: _labelStyle(_foreground(active)),
          ),
        ),
      );
    }

    if (eased >= 1 || _previous == _shown)
    {
      return label(_shown, 0, 1);
    }

    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        if (leaving < 1) label(_previous, -_labelTravel * leaving, 1 - leaving),
        if (arriving > 0) label(_shown, _labelTravel * (1 - arriving), arriving),
      ],
    );
  }

  Widget _buildBadge(BuildContext context, Widget? child)
  {
    final double progress = _flip.value;
    final double eased = Curves.easeInOutCubic.transform(progress);
    final double hover = Curves.easeOut.transform(_hover.value);
    final double pulse = _pulse.value;

    final Color surface = Color.lerp(
      _surface(_previous, hover),
      _surface(_shown, hover),
      eased,
    )!;

    return Container(
      width: lerpDouble(_width(_previous), _width(_shown), eased),
      height: _height,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(_height / 2),
        boxShadow: [
          if (pulse > 0 && pulse < 1)
            BoxShadow(
              color: _foreground(_shown).withValues(alpha: 0.3 * (1 - pulse)),
              spreadRadius: _ringWidth + _pulseReach * Curves.easeOut.transform(pulse),
            ),
          if (hover > 0)
            BoxShadow(
              color: AppTheme.trialGold.withValues(alpha: hover),
              spreadRadius: _ringWidth,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_height / 2),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _padding),
          child: Row(
            children: [
              SizedBox(width: _iconSize, height: _iconSize, child: _buildIcon(progress)),
              const SizedBox(width: _iconGap),
              Expanded(child: _buildLabels(eased)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final Widget badge = AnimatedBuilder(
      animation: Listenable.merge([_hover, _flip, _pulse]),
      builder: _buildBadge,
    );

    final String? lockedTip = widget.lockedTip;

    if (lockedTip != null)
    {
      return AppTooltip(message: lockedTip, child: badge);
    }

    final bool enabled = !_busy;

    return AppTooltip(
      message: _clickTip(isActive: _shown, isFemale: _isFemale),
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => _hover.forward(),
        onExit: (_) => _hover.reverse(),
        child: GestureDetector(
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          onTap: enabled ? _toggle : null,
          child: AnimatedScale(
            scale: _pressed ? _pressedScale : 1,
            duration: _pressDuration,
            curve: Curves.easeOut,
            child: badge,
          ),
        ),
      ),
    );
  }
}
