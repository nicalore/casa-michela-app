import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../features/association/association_strings.dart';
import '../../../../features/association/teacher_opinions.dart';
import '../../../../features/people/models/person_item.dart';
import '../../../shared/mobile_palette.dart';
import '../../../shared/widgets/mobile_avatar.dart';
import '../../../shared/widgets/mobile_filter_chip.dart';
import '../../../shared/widgets/mobile_glass_panel.dart';
import '../../../shared/widgets/mobile_load_switcher.dart';
import '../../../shared/widgets/mobile_nav_sheet.dart';
import '../../../shared/widgets/mobile_search_field.dart';
import '../../../shared/widgets/mobile_swipe_page.dart';
import '../mobile_teachers_directory.dart';
import 'mobile_association_status.dart';
import 'mobile_teacher_choice_sheets.dart';
import 'mobile_teacher_sheet.dart';

const double _radius = 22;

const double _topRoom = 16;

// Pages end this far above the sheet they scroll under.
const double _handleClearance = 16;

const double _chipsHeight = 32;
const double _chipGap = 8;

const double _rowGap = 9;
const double _columnGap = 12;

// Narrower than this a row cannot fit a full name beside the face.
const double _minRowWidth = 340;
const int _maxColumns = 3;

const double _faceSize = 46;

class MobileTeachersTab extends StatefulWidget
{
  final MobileTeachersDirectory directory;

  final double margin;
  final bool tablet;

  const MobileTeachersTab({
    super.key,
    required this.directory,
    required this.margin,
    required this.tablet,
  });

  @override
  State<MobileTeachersTab> createState() => _MobileTeachersTabState();
}

class _MobileTeachersTabState extends State<MobileTeachersTab>
{
  MobileTeachersDirectory get _directory => widget.directory;

  bool get _ready => !_directory.loading && !_directory.failed;

  @override
  void initState()
  {
    super.initState();
    _directory.ensureLoaded();
  }

  Future<void> _pickSort() async
  {
    final TeacherSort? sort = await showMobileTeacherSortSheet(context: context, current: _directory.sort);

    if (sort != null)
    {
      _directory.sortBy(sort);
    }
  }

  Future<void> _pickSubjects() async
  {
    if (!_ready)
    {
      return;
    }

    final Set<int>? ids = await showMobileSubjectFilterSheet(
      context: context,
      options: _directory.subjectOptions,
      selected: _directory.subjectIds,
    );

    if (ids != null)
    {
      _directory.filterBySubjects(ids);
    }
  }

  Widget _buildChips()
  {
    final int chosen = _directory.subjectIds.length;

    return SizedBox(
      height: _chipsHeight,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: widget.margin),
        children: [
          MobileFilterChip(
            icon: Icons.swap_vert_rounded,
            label: _directory.sort.label,
            active: _directory.sort != TeacherSort.nameAsc,
            onTap: _pickSort,
          ),
          const SizedBox(width: _chipGap),
          MobileFilterChip(
            icon: Icons.auto_stories_rounded,
            label: chosen == 0 ? kSubjectsFilterLabel : '$kSubjectsFilterLabel · $chosen',
            active: chosen > 0,
            onTap: _pickSubjects,
          ),
          if (_directory.canReport) ...[
            const SizedBox(width: _chipGap),
            MobileFilterChip(
              icon: Icons.thumb_down_rounded,
              label: kOnlyDislikedLabel,
              active: _directory.onlyDisliked,
              onTap: _directory.toggleOnlyDisliked,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody()
  {
    if (_directory.loading)
    {
      return const MobileWaiting();
    }

    if (_directory.failed)
    {
      return const MobileAssociationStatus(kAssociationLoadFailed);
    }

    final List<PersonItem> teachers = _directory.shown;
    final double room = MediaQuery.sizeOf(context).width - widget.margin * 2;
    final int columns = widget.tablet ? (room / _minRowWidth).floor().clamp(1, _maxColumns) : 1;

    final List<Widget> rows = [
      for (final teacher in teachers)
        _TeacherRow(
          teacher: teacher,
          disliked: _directory.isDisliked(teacher),
          onTap: () => showMobileTeacherSheet(context: context, directory: _directory, teacher: teacher),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
          child: Text(
            teachersFoundLabel(teachers.length),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ),
        _Grid(rows: rows, columns: columns),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final double bottom = MobileNavSheet.collapsedHeightFor(context) + _handleClearance;

    // Margin inside the scroll view so card shadows are not clipped while paging.
    return MobileSwipePage(
      child: RefreshIndicator(
        color: AppTheme.trialGold,
        backgroundColor: AppTheme.trialDeepWater,
        onRefresh: () => _directory.load(quiet: true),
        child: ListView(
          clipBehavior: Clip.none,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(top: _topRoom, bottom: bottom),
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.margin),
              child: MobileSearchField(
                controller: _directory.search,
                hintText: kTeachersSearchHint,
                onChanged: (_) => _directory.searched(),
              ),
            ),
            const SizedBox(height: 12),
            ListenableBuilder(
              listenable: _directory,
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildChips(),
                  const SizedBox(height: 18),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: widget.margin),
                    child: _buildBody(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget
{
  final List<Widget> rows;
  final int columns;

  const _Grid({required this.rows, required this.columns});

  @override
  Widget build(BuildContext context)
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i += columns) ...[
          if (i > 0) const SizedBox(height: _rowGap),
          if (columns == 1)
            rows[i]
          else
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < columns; j++) ...[
                    if (j > 0) const SizedBox(width: _columnGap),
                    Expanded(child: i + j < rows.length ? rows[i + j] : const SizedBox.shrink()),
                  ],
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _TeacherRow extends StatelessWidget
{
  final PersonItem teacher;

  // By whoever the reader answers for.
  final bool disliked;

  final VoidCallback onTap;

  const _TeacherRow({required this.teacher, required this.disliked, required this.onTap});

  @override
  Widget build(BuildContext context)
  {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MobileGlassPanel(
        padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
        borderRadius: const BorderRadius.all(Radius.circular(_radius)),
        child: Row(
          children: [
            MobileAvatar(
              firstName: teacher.firstName,
              lastName: teacher.lastName,
              imageUrl: teacher.profileImageUrl,
              size: _faceSize,
              gold: false,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${teacher.firstName} ${teacher.lastName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.1,
                      color: AppTheme.trialInk,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    taughtSubjectsLabel(subjectsOf(teacher).length),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: MobilePalette.mutedText,
                    ),
                  ),
                ],
              ),
            ),
            if (disliked) ...[
              const SizedBox(width: 8),
              const Icon(Icons.thumb_down_rounded, size: 20, color: AppTheme.trialDanger),
            ],
            const SizedBox(width: 2),
            Icon(
              Icons.chevron_right_rounded,
              size: 26,
              color: AppTheme.trialInk.withValues(alpha: 0.36),
            ),
          ],
        ),
      ),
    );
  }
}
