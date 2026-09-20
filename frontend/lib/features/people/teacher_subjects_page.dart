import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_dimensions.dart';
import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_message.dart';
import '../../routing/app_router.dart';
import '../../services/api_service.dart';
import '../../shared/widgets/app_page_container.dart';
import '../../shared/widgets/app_top_bar.dart';
import '../../shared/widgets/corner_glow.dart';
import '../../shared/widgets/page_transition.dart';
import '../../shared/widgets/page_watermark.dart';
import 'models/person_item.dart';
import 'tabs/person_subjects_tab.dart';

const String _teacherRole = 'TEACHER';

const String _intro =
    'Qui puoi indicare le discipline che desideri insegnare e i percorsi di '
    'studio per i quali sei disponibile. Ti chiediamo di mantenere queste '
    'informazioni sempre aggiornate e corrette, poiché verranno utilizzate '
    'per assegnarti le lezioni.';

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
      });
    }
  }

  Widget _buildContent()
  {
    if (_isLoading)
    {
      return const Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise));
    }

    final PersonItem? person = _person;

    if (_failed || person == null)
    {
      return Center(
        child: Text(
          'Non è stato possibile caricare le discipline.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            fontStyle: FontStyle.italic,
            color: AppTheme.trialMutedText,
          ),
        ),
      );
    }

    return PersonSubjectsTab(
      person: person,
      intro: _buildIntro(),
      onUpdate: () => _load(quiet: true),
    );
  }

  Widget _buildIntro()
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Text(
        _intro,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.45,
          color: AppTheme.trialInk,
        ),
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
                  animated: true,
                ),
                const CornerGlow(
                  corner: GlowCorner.bottomLeft,
                  tint: AppTheme.trialSeaGreen,
                  edgeTint: AppTheme.trialTealDeep,
                  animated: true,
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
