import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../features/association/notices/notice_format.dart';
import '../../../features/association/notices/notice_strings.dart' show noticeSentLabel;
import '../../../features/auth/models/me_response.dart';
import '../../../features/reports/report_item.dart';
import '../../../features/reports/report_strings.dart';
import '../../../features/reports/reports_board.dart';
import '../../../shared/widgets/descender_room.dart';
import '../../layout/mobile_breakpoints.dart';
import '../../shared/mobile_palette.dart';
import '../../shared/widgets/mobile_choice_sheet.dart';
import '../../shared/widgets/mobile_empty_card.dart';
import '../../shared/widgets/mobile_filter_chip.dart';
import '../../shared/widgets/mobile_glass_panel.dart';
import '../../shared/widgets/mobile_load_switcher.dart';
import '../../shared/widgets/mobile_current_card.dart';
import '../../shared/widgets/mobile_nav_sheet.dart';
import 'mobile_report_details_sheet.dart';

const double _phoneMargin = 20;
const double _tabletMargin = 44;
const double _topRoom = 16;
const double _handleClearance = 16;
const double _radius = 22;
const double _cardGap = 10;
const double _columnGap = 12;

// As the notices: narrower than this a card wraps too much.
const double _minCardWidth = 340;
const int _maxColumns = 3;

// The reports of the kinds the reader receives, until somebody resolves them.
class MobileReportsPage extends StatefulWidget
{
  final MeResponse user;

  const MobileReportsPage({super.key, required this.user});

  @override
  State<MobileReportsPage> createState() => _MobileReportsPageState();
}

class _MobileReportsPageState extends State<MobileReportsPage>
{
  final ReportsBoard _board = ReportsBoard.instance;

  // Kept across the move to the filling sliver, so the empty card still rises.
  final GlobalKey _switcher = GlobalKey();

  ReportKind? _kind;
  String? _failure;
  bool _opening = false;

  @override
  void initState()
  {
    super.initState();
    _load();
  }

  Future<void> _load() async
  {
    try
    {
      await _board.load();

      if (mounted)
      {
        setState(() => _failure = null);
      }
    }
    catch (e)
    {
      if (mounted)
      {
        setState(() => _failure = readableApiError(e));
      }
    }
  }

  List<ReportKind> get _kinds
  {
    return [for (final kind in ReportKind.values) if (widget.user.reportKinds.contains(kind.code)) kind];
  }

  List<ReportItem> get _shown
  {
    final ReportKind? kind = _kind;

    return [for (final report in _board.reports) if (kind == null || report.kind == kind) report];
  }

  Future<void> _pickKind() async
  {
    final MobileChoice<ReportKind?>? choice = await showMobileChoiceSheet<ReportKind?>(
      context: context,
      eyebrow: kReportsEyebrow,
      title: kKindSheetTitle,
      value: _kind,
      choices: [
        const MobileChoice<ReportKind?>(value: null, label: kAllKinds),
        for (final kind in _kinds) MobileChoice<ReportKind?>(value: kind, label: kind.plural),
      ],
    );

    if (choice != null && mounted)
    {
      setState(() => _kind = choice.value);
    }
  }

  Future<void> _open(ReportItem report) async
  {
    if (_opening)
    {
      return;
    }

    _opening = true;

    try
    {
      await showMobileReport(context, report.id);
    }
    finally
    {
      _opening = false;
    }
  }

  Widget _status(String text)
  {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
          height: 1.4,
          color: Colors.white.withValues(alpha: 0.75),
        ),
      ),
    );
  }

  Widget _cards(List<ReportItem> reports, {required bool tablet, required double margin})
  {
    final double room = MediaQuery.sizeOf(context).width - margin * 2;
    final int columns = tablet ? (room / _minCardWidth).floor().clamp(1, _maxColumns) : 1;

    // Side by side, every card is as tall as the others.
    final double? block = columns > 1 ? _ReportCard.fixedBlock(MediaQuery.textScalerOf(context)) : null;

    final List<Widget> cards = [
      for (final report in reports) _ReportCard(report: report, block: block, onTap: () => _open(report)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < cards.length; i += columns) ...[
          if (i > 0) const SizedBox(height: _cardGap),
          if (columns == 1)
            cards[i]
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var j = 0; j < columns; j++) ...[
                  if (j > 0) const SizedBox(width: _columnGap),
                  Expanded(child: i + j < cards.length ? cards[i + j] : const SizedBox.shrink()),
                ],
              ],
            ),
        ],
      ],
    );
  }

  Widget _body({required bool tablet, required double margin})
  {
    final String? failure = _failure;

    if (!_board.loaded)
    {
      return failure == null ? const MobileWaiting() : _status(failure);
    }

    final List<ReportItem> reports = _shown;

    if (reports.isEmpty)
    {
      return Center(child: MobileEmptyCard(icon: Icons.task_alt_rounded, message: kNoReports, tablet: tablet));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
          child: Text(
            reportShortCountLabel(reports.length),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ),
        _cards(reports, tablet: tablet, margin: margin),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final bool tablet = MobileBreakpoints.of(context).isTablet;
    final double margin = tablet ? _tabletMargin : _phoneMargin;
    final double bottom = MobileNavSheet.collapsedHeightFor(context) + _handleClearance;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppTheme.trialGold,
        backgroundColor: AppTheme.trialDeepWater,
        onRefresh: _load,
        child: ListenableBuilder(
          listenable: _board,
          builder: (context, _)
          {
            final EdgeInsets sides = EdgeInsets.fromLTRB(margin, 0, margin, bottom);
            final Widget body = MobileLoadSwitcher(key: _switcher, child: _body(tablet: tablet, margin: margin));

            return CustomScrollView(
              clipBehavior: Clip.none,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.only(top: 4),
                  sliver: SliverList.list(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: margin),
                        child: Text(
                          kReportsTitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: tablet ? 36 : 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            height: 1.05,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: _topRoom),
                      // Whoever receives one kind alone has nothing to choose.
                      if (_kinds.length > 1) ...[
                        MobileFilterChips(
                          margin: margin,
                          chips: [
                            MobileFilterChip(
                              icon: Icons.category_outlined,
                              label: _kind?.plural ?? kAllKinds,
                              active: _kind != null,
                              onTap: _pickKind,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],
                    ],
                  ),
                ),
                // Nothing to solve: the card stands in the middle of the room left.
                if (_board.loaded && _shown.isEmpty)
                  SliverFillRemaining(hasScrollBody: false, child: Padding(padding: sides, child: body))
                else
                  SliverPadding(padding: sides, sliver: SliverToBoxAdapter(child: body)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget
{
  final ReportItem report;

  // The words' fixed height on tablets; null lets the card grow with them.
  final double? block;

  final VoidCallback onTap;

  const _ReportCard({required this.report, required this.block, required this.onTap});

  static const double _titleSize = 15.5;
  static const double _titleHeight = 1.25;
  static const double _previewSize = 13.5;
  static const double _previewHeight = 1.4;
  static const double _wordsSize = 14;
  static const double _wordsHeight = 1.4;
  static const double _previewGap = 4;

  // Title and two lines, or three lines of a problem's words, whichever is taller.
  static double fixedBlock(TextScaler scaler)
  {
    final double titled =
        scaler.scale(_titleSize) * _titleHeight + _previewGap + 2 * scaler.scale(_previewSize) * _previewHeight;
    final double words = 3 * scaler.scale(_wordsSize) * _wordsHeight;

    return math.max(titled, words).ceilToDouble();
  }

  String? get _preview => switch (report.kind)
  {
    ReportKind.appProblem => null,
    ReportKind.personalData => reportCorrectionsPreview(report),
    ReportKind.missingSubject => report.description,
  };

  Widget _main()
  {
    final String? preview = _preview;
    final bool fixed = block != null;

    if (report.kind == ReportKind.appProblem)
    {
      return Text(
        report.description ?? '',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.plusJakartaSans(
          fontSize: _wordsSize,
          fontWeight: FontWeight.w700,
          height: _wordsHeight,
          color: AppTheme.trialInk,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DescenderRoom(
          child: Text(
            reportTitle(report),
            maxLines: fixed ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: _titleSize,
              fontWeight: FontWeight.w800,
              height: _titleHeight,
              letterSpacing: -0.1,
              color: AppTheme.trialInk,
            ),
          ),
        ),
        if (preview != null && preview.isNotEmpty) ...[
          const SizedBox(height: _previewGap),
          Text(
            preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: _previewSize,
              fontWeight: FontWeight.w500,
              height: _previewHeight,
              color: AppTheme.trialInk.withValues(alpha: 0.8),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    const BorderRadius radius = BorderRadius.all(Radius.circular(_radius));
    final double? block = this.block;
    final String? role = report.reporterRole;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: radius,
          // Not opened yet by this reader.
          border: report.read
              ? null
              : const Border.fromBorderSide(
                  BorderSide(
                    color: AppTheme.trialGold,
                    width: MobileCurrentCard.rimWidth,
                    strokeAlign: BorderSide.strokeAlignOutside,
                  ),
                ),
        ),
        child: MobileGlassPanel(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
          borderRadius: radius,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      report.kind.label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppTheme.trialOcean,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    noticeSentLabel(
                      noticeLongDay(report.createdAt, today: DateTime.now()),
                      noticeHour(report.createdAt),
                    ),
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: MobilePalette.mutedText),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              if (block == null) _main() else SizedBox(height: block, child: ClipRect(child: _main())),
              const SizedBox(height: 9),
              Text(
                role == null ? report.reporterName : '${report.reporterName} · $role',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.trialTealDeep),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
