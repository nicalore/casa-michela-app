import 'package:flutter/material.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_message.dart';
import '../../routing/app_router.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/app_load_failed.dart';
import '../../shared/widgets/app_page_container.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/corner_glow.dart';
import '../../shared/widgets/page_transition.dart';
import '../../shared/widgets/page_watermark.dart';
import 'models/person_item.dart';
import 'subjects_tour.dart';
import 'tabs/person_subjects_tab.dart';

const String _teacherRole = 'TEACHER';

class TeacherSubjectsPage extends StatefulWidget
{
  const TeacherSubjectsPage({super.key});

  @override
  State<TeacherSubjectsPage> createState() => _TeacherSubjectsPageState();
}

class _TeacherSubjectsPageState extends State<TeacherSubjectsPage> with DestinationRefresh
{
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  bool _failed = false;
  Object? _loadFailure;

  PersonItem? _person;

  @override
  void initState()
  {
    super.initState();
    _load();
  }

  @override
  void onDestinationShown()
  {
    _load(quiet: true);
  }

  Future<void> _load({bool quiet = false}) async
  {
    try
    {
      final me = _apiService.lastKnownIdentity ?? await _apiService.me();
      final person = await _apiService.getPerson(me.taxCode);

      if (!mounted)
      {
        return;
      }

      setState(()
      {
        _person = person;
        _isLoading = false;
        _failed = false;
      });

      startSubjectsTour(context, subjectsPageTour);
    }
    catch (e, stackTrace)
    {
      reportCaughtError(e, stackTrace, during: 'il caricamento delle discipline');

      if (!mounted)
      {
        return;
      }

      // A refresh that fails keeps what is shown.
      setState(()
      {
        _isLoading = false;
        _failed = !quiet || _person == null;
        _loadFailure = e;
      });
    }
  }

  Widget _buildContent()
  {
    if (_isLoading)
    {
      return Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise));
    }

    final PersonItem? person = _person;

    if (_failed || person == null)
    {
      return AppLoadFailedRoom(
        error: _loadFailure,
        message: 'Non è stato possibile caricare le discipline.',
        onRetry: _load,
      );
    }

    return PersonSubjectsTab(
      person: person,
      onUpdate: () => _load(quiet: true),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      body: AppPageContainer(
        minWidth: AppDimensions.minDashboardWidth,
        // Below the wide window the page is the window: the cards scroll, not the page.
        minHeight: AppBreakpoints.of(context).isDense ? 0 : AppDimensions.minDashboardHeight,
        builder: (context, width, height)
        {
          final AppWindowSize size = AppBreakpoints.of(context);
          final double margin = AppBreakpoints.pageMargin(size);

          return Container(
            width: width,
            height: height,
            color: AppTheme.pagePaper,
            child: Stack(
              children: [
                const CornerGlow(
                  corner: GlowCorner.topRight,
                  tint: AppTheme.trialDeepWater,
                  edgeTint: AppTheme.trialOcean,
                  intensity: 1.25,
                ),
                CornerGlow(
                  corner: GlowCorner.bottomLeft,
                  tint: AppTheme.trialSeaGreen,
                  edgeTint: AppTheme.trialTealDeep,
                ),
                const PageWatermark(),
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(margin, AppTopBar.contentTopInsetFor(size), margin, 28),
                    child: _buildContent(),
                  ),
                ),
                AppTopBar(currentRoute: '${homeForRole(_teacherRole)}/subjects'),
              ],
            ),
          );
        },
      ),
    );
  }
}
