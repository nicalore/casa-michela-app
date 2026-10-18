import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/layout/app_breakpoints.dart';
import '../../core/state/entity_writes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_message.dart';
import '../../routing/app_router.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/app_gradient_button.dart';
import '../../shared/widgets/app_page_container.dart';
import '../../shared/widgets/corner_glow.dart';
import '../../shared/widgets/page_heading.dart';
import '../../shared/widgets/page_transition.dart';
import '../../shared/widgets/page_watermark.dart';
import '../../shared/widgets/snackbar.dart';
import '../association/notices/notice_embeds.dart';
import 'update_composer_dialog.dart';
import 'update_details_dialog.dart';
import 'update_item.dart';
import 'update_reading.dart';
import 'update_strings.dart';
import 'widgets/update_card.dart';

const double _columnWidth = 1080;
const double _cardGap = 14;
const double _shadowRoom = 20;
const double _titleHeight = 52;
const double _bottomMargin = 24;

const double _buttonWidth = 330;
const double _buttonHeight = 52;
const double _buttonFontSize = 14;
// The last card scrolls clear of the floating button.
const double _listBottomRoom = _buttonHeight + 40;

const double _yearHeight = 28;
const double _yearGapAbove = 30;
const double _yearGapBelow = 12;

// The back button's width and a gap.
const double _backRoom = 84 + 36;

// The IT managers' updates, newest first, each opened to be edited or deleted.
class UpdatesPage extends StatefulWidget
{
  final String? origin;

  const UpdatesPage({super.key, this.origin});

  @override
  State<UpdatesPage> createState() => _UpdatesPageState();
}

class _UpdatesPageState extends State<UpdatesPage> with EntityWrites
{
  final ApiService _apiService = ApiService();
  final ScrollController _scroll = ScrollController();

  // Kept in the server's order, newest first.
  List<UpdateSummaryItem> _updates = [];
  bool _loaded = false;

  @override
  void initState()
  {
    super.initState();
    _load();
  }

  @override
  void dispose()
  {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async
  {
    try
    {
      final List<UpdateSummaryItem> updates = await _apiService.getUpdates();

      if (mounted)
      {
        setState(()
        {
          _updates = updates;
          _loaded = true;
        });
      }
    }
    catch (error)
    {
      if (!mounted)
      {
        return;
      }

      setState(() => _loaded = true);
      CustomSnackBar.show(context: context, message: readableApiError(error), isError: true);
    }
  }

  String get _origin
  {
    final String? origin = widget.origin;

    return origin != null && origin.startsWith('/')
        ? origin
        : homeForRole(_apiService.lastKnownIdentity?.activeRole);
  }

  void _put(UpdateSummaryItem update)
  {
    _updates = [update, ..._updates.where((other) => other.id != update.id)]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  void _refuse(String message)
  {
    if (mounted)
    {
      CustomSnackBar.show(context: context, message: message, isError: true);
    }
  }

  Future<bool> _create(UpdateDraft draft, void Function(String) onError)
  {
    return write(
      call: () => _apiService.createUpdate(draft, version: kUpdateVersion),
      apply: _put,
      done: kUpdatePublished,
      onError: onError,
    );
  }

  Future<bool> _edit(UpdateItem update, UpdateDraft draft, void Function(String) onError)
  {
    return write(
      call: () => _apiService.editUpdate(update, draft),
      apply: _put,
      done: kUpdateEdited,
      onError: onError,
    );
  }

  Future<void> _delete(UpdateSummaryItem update)
  {
    return erase(
      call: () => _apiService.deleteUpdate(update.id),
      apply: ()
      {
        _updates = _updates.where((other) => other.id != update.id).toList();
      },
      done: kUpdateDeleted,
      onError: _refuse,
    );
  }

  void _compose()
  {
    showUpdateComposer(context, images: NoticeImages(), onSave: _create);
  }

  Future<void> _open(int id) async
  {
    final UpdateItem update;

    try
    {
      update = await _apiService.getUpdate(id);
    }
    catch (error)
    {
      _refuse(readableApiError(error));

      return;
    }

    if (!mounted)
    {
      return;
    }

    final NoticeImages images = (await preloadUpdateImages(context, [UpdateReadingItem.of(update)]))[update.id]!;

    if (!mounted)
    {
      return;
    }

    await showUpdateDetails(
      context,
      update,
      images: images,
      // The composer stacks over the details, which close once the edit is saved.
      onEdit: (onSaved) => showUpdateComposer(
        context,
        update: update,
        images: images.copy(),
        onSave: (draft, onError) => _edit(update, draft, onError),
        onEditSaved: onSaved,
      ),
      onDelete: () => _delete(update),
    );
  }

  // A year's heading before its updates.
  List<Widget> _entries()
  {
    final List<Widget> entries = [];
    int? year;

    for (final update in _updates)
    {
      if (update.createdAt.year != year)
      {
        year = update.createdAt.year;
        entries.add(
          Padding(
            padding: EdgeInsets.only(top: entries.isEmpty ? 0 : _yearGapAbove, bottom: _yearGapBelow),
            child: SizedBox(
              height: _yearHeight,
              child: Align(alignment: Alignment.centerLeft, child: PageHeading('$year', large: true)),
            ),
          ),
        );
      }
      else
      {
        entries.add(const SizedBox(height: _cardGap));
      }

      entries.add(UpdateCard(key: ValueKey(update.id), update: update, onTap: () => _open(update.id)));
    }

    return entries;
  }

  List<Widget> _header()
  {
    return [
      PageTransitionItem(
        slot: PageTransitionItem.header,
        child: SizedBox(
          height: _titleHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              kUpdatesTitle,
              style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w700, color: AppTheme.trialOcean),
            ),
          ),
        ),
      ),
      // Nothing published: the line in the middle says it instead.
      if (!_loaded || _updates.isNotEmpty) ...[
        const SizedBox(height: 20),
        PageTransitionItem(
          slot: PageTransitionItem.header,
          child: Text(
            _loaded ? updateCountLabel(_updates.length) : '',
            style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.trialMutedText),
          ),
        ),
      ],
      const SizedBox(height: 16),
    ];
  }

  Widget _list()
  {
    if (_loaded && _updates.isEmpty)
    {
      return const Center(
        child: PageTransitionItem(slot: PageTransitionItem.list, child: _NoUpdates()),
      );
    }

    final List<Widget> entries = _entries();

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
                padding: const EdgeInsets.fromLTRB(_shadowRoom, _shadowRoom, _shadowRoom, _listBottomRoom),
                sliver: SliverList.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) => PageTransitionItem(
                    slot: PageTransitionItem.list,
                    child: entries[index],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _button()
  {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x2E0B3350), offset: Offset(0, 10), blurRadius: 28)],
      ),
      child: AppGradientButton(
        label: kNewUpdateButton,
        icon: Icons.add_rounded,
        width: _buttonWidth,
        height: _buttonHeight,
        fontSize: _buttonFontSize,
        onPressed: _compose,
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      body: AppPageContainer(
        minWidth: AppDimensions.minDashboardWidth,
        minHeight: AppDimensions.minDashboardHeight,
        builder: (context, width, height)
        {
          final AppWindowSize size = AppBreakpoints.fromWidth(width);
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
                    padding: EdgeInsets.only(left: margin, right: margin, top: 24, bottom: _bottomMargin),
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
                            // Centred, and clear of the back button on both sides.
                            final double side = math.max(_backRoom, (constraints.maxWidth - _columnWidth) / 2);

                            return Padding(
                              padding: EdgeInsets.symmetric(horizontal: side),
                              child: Stack(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      ..._header(),
                                      Expanded(child: _list()),
                                    ],
                                  ),
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: Center(
                                      child: PageTransitionItem(slot: PageTransitionItem.header, child: _button()),
                                    ),
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

// As the psychologist's home card.
class _NoUpdates extends StatelessWidget
{
  const _NoUpdates();

  @override
  Widget build(BuildContext context)
  {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.update_rounded, size: 30, color: AppTheme.trialTealDeep),
          const SizedBox(width: 16),
          Text(
            kNoUpdates,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppTheme.trialTealDeep,
            ),
          ),
        ],
      ),
    );
  }
}
