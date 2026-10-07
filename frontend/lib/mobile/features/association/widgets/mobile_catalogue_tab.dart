import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../features/association/association_strings.dart';
import '../../../../features/association/models/association_subject_item.dart';
import '../../../../features/association/models/subject_taxonomy.dart';
import '../../../../features/association/tabs/pupil_subjects_tab.dart'
    show kMissingSubjectAction, kSubjectsSearchHint, subjectsFoundLabel;
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_dismiss_button.dart';
import '../../../shared/widgets/mobile_glass_panel.dart';
import '../../../shared/widgets/mobile_load_switcher.dart';
import '../../../shared/widgets/mobile_nav_sheet.dart';
import '../../../shared/widgets/mobile_search_field.dart';
import '../../../shared/widgets/mobile_swipe_page.dart';
import '../mobile_catalogue.dart';
import 'mobile_association_status.dart';
import 'mobile_missing_subject_sheet.dart';

const double _radius = 22;

const double _topRoom = 16;

// Pages end this far above what floats over them.
const double _handleClearance = 16;

const double _reportLift = 12;
const double _reportHeight = 58;

const double _columnGap = 16;

// Column balancing: a heading and a description weigh about this many rows.
const double _headingWeight = 2;
const double _descriptionWeight = 1.5;

class MobileCatalogueTab extends StatefulWidget
{
  final MobileCatalogue catalogue;

  // False for a pupil a parent answers for: no report button.
  final bool canReport;

  final double margin;
  final bool tablet;
  final bool landscape;

  const MobileCatalogueTab({
    super.key,
    required this.catalogue,
    required this.canReport,
    required this.margin,
    required this.tablet,
    required this.landscape,
  });

  @override
  State<MobileCatalogueTab> createState() => _MobileCatalogueTabState();
}

class _MobileCatalogueTabState extends State<MobileCatalogueTab>
{
  MobileCatalogue get _catalogue => widget.catalogue;

  @override
  void initState()
  {
    super.initState();
    _catalogue.ensureLoaded();
  }

  Widget _buildBody()
  {
    if (_catalogue.loading)
    {
      return const MobileWaiting();
    }

    if (_catalogue.failed)
    {
      return const MobileAssociationStatus(kAssociationLoadFailed);
    }

    if (_catalogue.isEmpty)
    {
      return MobileAssociationStatus(subjectsFoundLabel(0));
    }

    final List<MobileSubjectGroup> groups = _catalogue.groups;

    if (groups.isEmpty)
    {
      return const MobileAssociationStatus(kMobileNoSearchMatch);
    }

    return _Groups(
      groups: groups,
      columns: widget.tablet ? (widget.landscape ? 3 : 2) : 1,
      tablet: widget.tablet,
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final double bar = MobileNavSheet.collapsedHeightFor(context);
    final double bottom =
        bar + _handleClearance + (widget.canReport ? _reportLift + _reportHeight : 0);

    return Stack(
      children: [
        // Margin inside the scroll view so card shadows are not clipped while paging.
        MobileSwipePage(
          child: RefreshIndicator(
            color: AppTheme.trialGold,
            backgroundColor: AppTheme.trialDeepWater,
            onRefresh: () => _catalogue.load(quiet: true),
            child: ListView(
              clipBehavior: Clip.none,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(widget.margin, _topRoom, widget.margin, bottom),
              children: [
                MobileSearchField(
                  controller: _catalogue.search,
                  hintText: kSubjectsSearchHint,
                  onChanged: (_) => _catalogue.searched(),
                ),
                SizedBox(height: widget.tablet ? 30 : 26),
                ListenableBuilder(
                  listenable: _catalogue,
                  builder: (context, _) => _buildBody(),
                ),
              ],
            ),
          ),
        ),
        // Part of the tab from its first frame: it slides with the page, never rises.
        if (widget.canReport)
          Positioned(
            left: widget.margin,
            right: widget.margin,
            bottom: bar + _reportLift,
            child: _ReportButton(tablet: widget.tablet),
          ),
      ],
    );
  }
}

class _ReportButton extends StatelessWidget
{
  final bool tablet;

  const _ReportButton({required this.tablet});

  @override
  Widget build(BuildContext context)
  {
    final Widget button = MobileDismissButton(
      label: kMissingSubjectAction,
      icon: Icons.flag_rounded,
      onPressed: () => showMobileMissingSubjectSheet(context),
    );

    return tablet
        ? Center(child: SizedBox(width: MobileNavSheet.tabletWidth, child: button))
        : button;
  }
}

class _Groups extends StatelessWidget
{
  final List<MobileSubjectGroup> groups;
  final int columns;
  final bool tablet;

  const _Groups({required this.groups, required this.columns, required this.tablet});

  static double _weightOf(MobileSubjectGroup group)
  {
    return _headingWeight +
        group.items.fold<double>(
          0,
          (sum, subject) => sum + 1 + (descriptionOrNull(subject.description) == null ? 0 : _descriptionWeight),
        );
  }

  // In area order, each group to the lightest column so far.
  List<List<MobileSubjectGroup>> get _columns
  {
    final List<List<MobileSubjectGroup>> columns = [for (var i = 0; i < this.columns; i++) []];
    final List<double> weights = List<double>.filled(this.columns, 0);

    for (final group in groups)
    {
      int lightest = 0;

      for (var i = 1; i < weights.length; i++)
      {
        if (weights[i] < weights[lightest])
        {
          lightest = i;
        }
      }

      columns[lightest].add(group);
      weights[lightest] += _weightOf(group);
    }

    return columns;
  }

  Widget _buildColumn(List<MobileSubjectGroup> column)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < column.length; i++) _AreaGroup(group: column[i], tablet: tablet, first: i == 0),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    if (columns == 1)
    {
      return _buildColumn(groups);
    }

    final List<List<MobileSubjectGroup>> split = _columns;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < split.length; i++) ...[
          if (i > 0) const SizedBox(width: _columnGap),
          Expanded(child: _buildColumn(split[i])),
        ],
      ],
    );
  }
}

class _AreaGroup extends StatelessWidget
{
  final MobileSubjectGroup group;
  final bool tablet;
  final bool first;

  const _AreaGroup({required this.group, required this.tablet, required this.first});

  @override
  Widget build(BuildContext context)
  {
    final List<AssociationSubjectItem> subjects = group.items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(2, first ? 0 : (tablet ? 34 : 30), 2, tablet ? 14 : 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  group.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: tablet ? 20 : 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${subjects.length}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: tablet ? 15 : 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        MobileGlassPanel(
          padding: const EdgeInsets.symmetric(vertical: 4),
          borderRadius: const BorderRadius.all(Radius.circular(_radius)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < subjects.length; i++)
                _SubjectRow(subject: subjects[i], tablet: tablet, first: i == 0),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubjectRow extends StatelessWidget
{
  final AssociationSubjectItem subject;
  final bool tablet;
  final bool first;

  const _SubjectRow({required this.subject, required this.tablet, required this.first});

  @override
  Widget build(BuildContext context)
  {
    final String? description = descriptionOrNull(subject.description);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: AppTheme.trialInk.withValues(alpha: 0.09))),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subject.name,
              style: GoogleFonts.plusJakartaSans(
                fontSize: tablet ? 16 : 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.1,
                height: 1.3,
                color: AppTheme.trialInk,
              ),
            ),
            if (description != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  description,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: tablet ? 13.5 : 13,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: MobilePalette.mutedText,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
