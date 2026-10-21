import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_message.dart';
import '../../routing/app_router.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/app_empty_card.dart';
import '../../shared/widgets/app_filter_pill.dart';
import '../../shared/widgets/app_page_container.dart';
import '../../shared/widgets/corner_glow.dart';
import '../../shared/widgets/filter_menu.dart';
import '../../shared/widgets/page_transition.dart';
import '../../shared/widgets/page_watermark.dart';
import '../../shared/widgets/snackbar.dart';
import 'report_item.dart';
import 'report_strings.dart';
import 'reports_board.dart';
import 'widgets/report_card.dart';
import 'widgets/report_dialog.dart';

const double _columnWidth = 1080;
const double _cardGap = 14;
const double _shadowRoom = 20;
const double _titleHeight = 52;
const double _menuWidth = 230;

// The back button's width and a gap.
const double _backRoom = 84 + 36;
const double _belowBackGap = 24;

// The reports of the kinds the reader receives, until somebody resolves them.
class ReportsPage extends StatefulWidget
{
  final String? origin;

  const ReportsPage({super.key, this.origin});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage>
{
  final ReportsBoard _board = ReportsBoard.instance;
  final ScrollController _scroll = ScrollController();

  ReportKind? _kind;

  @override
  void initState()
  {
    super.initState();
    _board.addListener(_onBoard);
    _load();
  }

  @override
  void dispose()
  {
    _board.removeListener(_onBoard);
    _scroll.dispose();
    super.dispose();
  }

  void _onBoard()
  {
    if (mounted)
    {
      setState(() {});
    }
  }

  Future<void> _load() async
  {
    try
    {
      await _board.load();
    }
    catch (error)
    {
      if (mounted)
      {
        CustomSnackBar.show(context: context, message: readableApiError(error), isError: true);
      }
    }
  }

  String get _origin
  {
    final String? origin = widget.origin;

    return origin != null && origin.startsWith('/')
        ? origin
        : homeForRole(ApiService().lastKnownIdentity?.activeRole);
  }

  // Kinds the reader receives, in the server's order.
  List<ReportKind> get _kinds
  {
    final List<String> codes = ApiService().lastKnownIdentity?.reportKinds ?? const [];

    return [for (final kind in ReportKind.values) if (codes.contains(kind.code)) kind];
  }

  List<ReportItem> get _shown
  {
    final ReportKind? kind = _kind;

    return [for (final report in _board.reports) if (kind == null || report.kind == kind) report];
  }

  Widget _filter()
  {
    return AppFilterPill<ReportKind>.filter(
      prefix: kKindPrefix,
      hint: kAllKinds,
      icon: Icons.category_outlined,
      value: _kind,
      menuWidth: _menuWidth,
      options: [for (final kind in _kinds) FilterOption(value: kind, label: kind.plural)],
      onChanged: (kind) => setState(() => _kind = kind),
      onClear: () => setState(() => _kind = null),
    );
  }

  List<Widget> _header(int count)
  {
    return [
      PageTransitionItem(
        slot: PageTransitionItem.header,
        child: SizedBox(
          height: _titleHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              kReportsTitle,
              style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w700, color: AppTheme.trialOcean),
            ),
          ),
        ),
      ),
      // Whoever receives one kind alone has nothing to choose.
      if (_kinds.length > 1) ...[
        const SizedBox(height: 22),
        PageTransitionItem(
          slot: PageTransitionItem.header,
          child: Align(alignment: Alignment.centerLeft, child: _filter()),
        ),
      ],
      // Nothing to solve: the card in the middle says it instead.
      if (!_board.loaded || count > 0) ...[
        const SizedBox(height: 20),
        PageTransitionItem(
          slot: PageTransitionItem.header,
          child: Text(
            _board.loaded ? reportCountLabel(count) : '',
            style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.trialMutedText),
          ),
        ),
      ],
      const SizedBox(height: 16),
    ];
  }

  Widget _list(List<ReportItem> reports)
  {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -_shadowRoom,
          right: -_shadowRoom,
          top: -_shadowRoom,
          bottom: 0,
          child: PageTransitionScrollView.slivers(
            controller: _scroll,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(_shadowRoom),
                sliver: SliverList.separated(
                  itemCount: reports.length,
                  separatorBuilder: (context, index) => const SizedBox(height: _cardGap),
                  itemBuilder: (context, index) => PageTransitionItem(
                    slot: PageTransitionItem.list,
                    child: ReportCard(
                      key: ValueKey(reports[index].id),
                      report: reports[index],
                      onTap: () => openReport(context, reports[index].id),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final List<ReportItem> reports = _shown;

    return Scaffold(
      body: AppPageContainer(
        minWidth: AppDimensions.minDashboardWidth,
        minHeight: AppDimensions.minDashboardHeight,
        builder: (context, width, height)
        {
          final AppWindowSize size = AppBreakpoints.of(context);
          final double margin = AppBreakpoints.pageMargin(size);

          return Container(
            width: width,
            height: height,
            color: AppTheme.trialPaper,
            child: Stack(
              children: [
                const CornerGlow(
                  corner: GlowCorner.topRight,
                  tint: AppTheme.trialDeepWater,
                  edgeTint: AppTheme.trialOcean,
                  intensity: 1.25,
                ),
                const CornerGlow(
                  corner: GlowCorner.bottomLeft,
                  tint: AppTheme.trialSeaGreen,
                  edgeTint: AppTheme.trialTealDeep,
                ),
                const PageWatermark(),
                SafeArea(
                  child: Padding(
                    padding: EdgeInsets.only(left: margin, right: margin, top: 24),
                    child: Stack(
                      children: [
                        Align(
                          alignment: Alignment.topLeft,
                          child: AppBackButton(
                            tooltip: 'Torna indietro',
                            onTap: () => context.go(_origin),
                          ),
                        ),
                        LayoutBuilder(
                          builder: (context, constraints)
                          {
                            // Centred, and clear of the back button on both sides; below it where that leaves too little.
                            final bool below = size.isNarrow;
                            final double side = below ? 0 : math.max(_backRoom, (constraints.maxWidth - _columnWidth) / 2);

                            return Padding(
                              padding: EdgeInsets.only(left: side, right: side, top: below ? AppBackButton.height + _belowBackGap : 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ..._header(reports.length),
                                  Expanded(
                                    child: _board.loaded && reports.isEmpty
                                        ? const Center(
                                            child: PageTransitionItem(
                                              slot: PageTransitionItem.list,
                                              child: AppEmptyCard(icon: Icons.task_alt_rounded, message: kNoReports),
                                            ),
                                          )
                                        : _list(reports),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
