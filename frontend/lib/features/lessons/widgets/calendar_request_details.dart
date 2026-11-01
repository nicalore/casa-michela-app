import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/platform/visual_effects.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/week_range.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../association/models/ministry_subject_item.dart';
import '../../calendar/widgets/own_lesson_dialog.dart' show studentCertificationsOf;
import '../../people/models/person_item.dart';
import '../../people/models/school_enrollment_item.dart';
import '../models/booking_summary_item.dart';
import 'booking_fields_section.dart';
import 'subject_request_tile.dart';

// The pointer held this long on a card or a lesson, without moving, opens its details.
const Duration kRequestDetailsWait = Duration(milliseconds: 1500);

const double _width = 380;
const double _gap = 12;
const double _margin = 8;

// Movement smaller than this still counts as holding still.
const double _stillness = 4;

// From the card to the details: long enough to cross the gap between them.
const Duration _leaveGrace = Duration(milliseconds: 180);

const String _empty = '—';

// The pupil's school above the fields of the day page's request details, with its labels;
// the card already says whose and when. A lesson holds one pupil and one discipline.
class CalendarRequestDetails extends StatelessWidget
{
  final BookingSummaryItem booking;
  final PersonItem? student;
  final List<MinistrySubjectItem> ministrySubjects;
  final Map<String, String> teacherNames;

  const CalendarRequestDetails({
    super.key,
    required this.booking,
    this.student,
    required this.ministrySubjects,
    this.teacherNames = const {},
  });

  String _said(String? value) => value == null || value.trim().isEmpty ? _empty : value.trim();

  Widget _buildVoice(String label, String value)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFieldLabel(label),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.4,
            color: value == _empty ? AppTheme.trialMutedText : AppTheme.trialInk,
          ),
        ),
      ],
    );
  }

  Widget _buildPair(Widget first, Widget second)
  {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 22),
        Expanded(child: second),
      ],
    );
  }

  // One voice per row: school, programme and certifications run long.
  List<Widget> _buildStudent(PersonItem student)
  {
    final String? program = student.studyProgram;

    return [
      _buildVoice('Scuola', _said(student.schoolName)),
      const SizedBox(height: 14),
      _buildVoice('Percorso di studi', _said(program == null ? null : studyProgramNameOnlyOf(program))),
      const SizedBox(height: 14),
      _buildVoice('Classe', _said(student.schoolClass)),
      const SizedBox(height: 14),
      _buildVoice('Certificazioni', studentCertificationsOf(student)),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Divider(height: 1, thickness: 1, color: AppTheme.trialLine),
      ),
    ];
  }

  @override
  Widget build(BuildContext context)
  {
    final PersonItem? student = this.student;
    final String preferred = [
      for (final code in booking.preferredTeacherTaxCodes) ?teacherNames[code],
    ].join(', ');

    final String subject = booking.serviceName ?? ministrySubjectName(ministrySubjects, booking.ministrySubjectId);
    final String? discipline = booking.serviceName == null
        ? dividedDisciplineName(ministrySubjects, booking.ministrySubjectId, booking.associationSubjects.map((option) => option.id))
        : null;

    return Container(
      width: _width,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x3D0B3350), blurRadius: 48, offset: Offset(0, 18)),
          BoxShadow(color: Color(0x140B3350), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      // Taller than the window: cut at the bottom, never scrolled.
      child: UnconstrainedBox(
        constrainedAxis: Axis.horizontal,
        alignment: Alignment.topLeft,
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (student != null) ..._buildStudent(student),
            const AppEyebrow('Disciplina richiesta'),
            const SizedBox(height: 2),
            Text(
              discipline ?? subject,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                height: 1.3,
                color: AppTheme.trialOcean,
              ),
            ),
            const SizedBox(height: 14),
            // As the day page: the subject said apart when divided in disciplines.
            if (discipline != null) ...[
              _buildVoice('Materia', subject),
              const SizedBox(height: 14),
            ],
            _buildPair(
              _buildVoice('Durata', formatMinutes(booking.duration)),
              _buildVoice('Tipo di lezione', _said(bookingTagLabels(booking.tags).join(', '))),
            ),
            const SizedBox(height: 14),
            _buildVoice('Argomento', _said(booking.topic)),
            const SizedBox(height: 14),
            _buildVoice('Mi sono trovato meglio con...', _said(preferred)),
            const SizedBox(height: 14),
            _buildVoice('Note per il docente', _said(booking.notes)),
          ],
        ),
      ),
    );
  }
}

// Places the details beside what opened them where there is room, above it near the bottom of
// the window, below as a last resort; always inside the window.
class _DetailsPlace extends SingleChildLayoutDelegate
{
  final Rect anchor;

  const _DetailsPlace(this.anchor);

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints)
  {
    return BoxConstraints.loose(constraints.biggest).deflate(const EdgeInsets.all(_margin));
  }

  @override
  Offset getPositionForChild(Size room, Size child)
  {
    final bool roomLeft = anchor.left - _gap - child.width >= _margin;
    final bool roomRight = anchor.right + _gap + child.width <= room.width - _margin;
    final bool roomAbove = anchor.top - _gap - child.height >= _margin;
    final bool low = anchor.center.dy > room.height * 2 / 3;
    final bool upper = anchor.center.dy < room.height / 2;
    final bool leftHalf = anchor.center.dx < room.width / 2;

    final double alignedX = leftHalf ? anchor.left : anchor.right - child.width;
    final Offset at;

    if (low && roomAbove)
    {
      at = Offset(alignedX, anchor.top - _gap - child.height);
    }
    else if (roomLeft || roomRight)
    {
      final bool left = roomLeft && (!roomRight || !leftHalf);

      at = Offset(
        left ? anchor.left - _gap - child.width : anchor.right + _gap,
        upper ? anchor.top : anchor.bottom - child.height,
      );
    }
    else if (roomAbove)
    {
      at = Offset(alignedX, anchor.top - _gap - child.height);
    }
    else
    {
      at = Offset(alignedX, anchor.bottom + _gap);
    }

    return Offset(
      at.dx.clamp(_margin, math.max(_margin, room.width - _margin - child.width)),
      at.dy.clamp(_margin, math.max(_margin, room.height - _margin - child.height)),
    );
  }

  @override
  bool shouldRelayout(_DetailsPlace oldDelegate) => oldDelegate.anchor != anchor;
}

// Opens [details] beside [child] once the pointer has rested on it for [kRequestDetailsWait];
// leaving both, or pressing to drag, closes them.
class CalendarDetailsHover extends StatefulWidget
{
  final WidgetBuilder details;
  final Widget child;

  const CalendarDetailsHover({super.key, required this.details, required this.child});

  @override
  State<CalendarDetailsHover> createState() => _CalendarDetailsHoverState();
}

class _CalendarDetailsHoverState extends State<CalendarDetailsHover> with SingleTickerProviderStateMixin
{
  final OverlayPortalController _portal = OverlayPortalController();

  late final AnimationController _fade;

  Timer? _wait;
  Timer? _grace;
  Offset? _restingAt;

  @override
  void initState()
  {
    super.initState();

    _fade = AnimationController(vsync: this, duration: VisualEffects.plainFade);
  }

  @override
  void dispose()
  {
    _wait?.cancel();
    _grace?.cancel();
    _fade.dispose();
    super.dispose();
  }

  void _rest(Offset position)
  {
    _grace?.cancel();

    if (_portal.isShowing && !_fade.isAnimating)
    {
      return;
    }

    final Offset? restingAt = _restingAt;

    if (restingAt != null && (position - restingAt).distance <= _stillness)
    {
      return;
    }

    _restingAt = position;
    _wait?.cancel();
    _wait = Timer(kRequestDetailsWait, _show);
  }

  void _show()
  {
    if (!mounted)
    {
      return;
    }

    _portal.show();

    if (VisualEffects.on)
    {
      _fade.forward();
    }
    else
    {
      _fade.value = 1;
    }
  }

  void _leave()
  {
    _wait?.cancel();
    _restingAt = null;

    if (_portal.isShowing)
    {
      _grace?.cancel();
      _grace = Timer(_leaveGrace, _hide);
    }
  }

  void _stay() => _grace?.cancel();

  void _hide()
  {
    _wait?.cancel();
    _grace?.cancel();
    _restingAt = null;

    if (!_portal.isShowing)
    {
      return;
    }

    if (!VisualEffects.on)
    {
      _fade.value = 0;
      _portal.hide();

      return;
    }

    _fade.reverse().whenComplete(()
    {
      if (mounted && _fade.isDismissed)
      {
        _portal.hide();
      }
    });
  }

  @override
  Widget build(BuildContext context)
  {
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _portal,
      overlayChildBuilder: (context, info) => CustomSingleChildLayout(
        delegate: _DetailsPlace(MatrixUtils.transformRect(info.childPaintTransform, Offset.zero & info.childSize)),
        child: MouseRegion(
          onEnter: (_) => _stay(),
          onExit: (_) => _leave(),
          child: FadeTransition(opacity: _fade, child: widget.details(context)),
        ),
      ),
      child: Listener(
        onPointerDown: (_) => _hide(),
        child: MouseRegion(
          onHover: (event) => _rest(event.position),
          onExit: (_) => _leave(),
          child: widget.child,
        ),
      ),
    );
  }
}
