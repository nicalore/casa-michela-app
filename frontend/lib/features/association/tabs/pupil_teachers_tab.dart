import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_message.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_field_label.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/app_search_field.dart';
import '../../../shared/widgets/app_selectable_chip.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/filter_menu.dart';
import '../../../shared/widgets/multi_select_filter_dialog.dart';
import '../../../shared/widgets/scroll_edge_fade.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/tab_layout.dart';
import '../../lessons/widgets/person_avatar.dart';
import '../../people/models/person_item.dart';
import '../association_strings.dart';
import '../models/subject_taxonomy.dart';
import '../teacher_opinions.dart';
import '../widgets/teacher_card.dart';

const String _parentRole = 'PARENT';

const double _dialogWidth = 620;

const double _voiceGap = 18;

const double _areaGap = 18;
const double _tagGap = 8;

// Past this the disciplines scroll inside their card, not the dialog.
const double _subjectsMaxHeight = 280;

const Color _tagSurface = Color(0xFFE8F7F5);

const String _empty = '—';

class PupilTeachersTab extends StatefulWidget
{
  final String role;

  // False for a pupil a parent answers for.
  final bool canReport;

  const PupilTeachersTab({super.key, required this.role, required this.canReport});

  @override
  State<PupilTeachersTab> createState() => _PupilTeachersTabState();
}

class _PupilTeachersTabState extends State<PupilTeachersTab>
{
  final ApiService _apiService = ApiService();

  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  List<PersonItem> _teachers = [];
  List<OpinionPupil> _pupils = [];

  String _searchText = '';
  TeacherSort _sort = TeacherSort.nameAsc;
  bool _onlyDisliked = false;
  Set<int> _selectedSubjectIds = {};

  bool get _isParent => widget.role == _parentRole;

  @override
  void initState()
  {
    super.initState();
    _load();
  }

  @override
  void dispose()
  {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async
  {
    try
    {
      final teachers = await _apiService.getTeachers();
      final pupils = widget.canReport ? await readOpinionPupils(parent: _isParent) : const <OpinionPupil>[];

      if (!mounted)
      {
        return;
      }

      setState(()
      {
        _teachers = teachers;
        _pupils = pupils;
        _isLoading = false;
      });
    }
    catch (e)
    {
      if (!mounted)
      {
        return;
      }

      setState(() => _isLoading = false);
      CustomSnackBar.show(context: context, message: kAssociationLoadFailed, isError: true);
    }
  }

  bool _isDisliked(PersonItem teacher) => _pupils.any((pupil) => pupil.dislikes(teacher));

  String get _introText
  {
    if (!widget.canReport || _pupils.isEmpty)
    {
      return teachersIntro(verb: 'Cliccando');
    }

    final String intro = teachersIntro(verb: 'Cliccando', whoGotOn: whoGotOn(_pupils, parent: _isParent));

    return '$intro $kTeachersOpinionNote';
  }

  Widget _buildIntro()
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Text(
        _introText,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.45,
          color: AppTheme.trialInk,
        ),
      ),
    );
  }

  List<MultiSelectFilterOption<int>> get _subjectOptions
  {
    final options = [
      for (final subject in taughtSubjectsOf(_teachers).values)
        MultiSelectFilterOption(value: subject.subjectId, label: subject.subjectName),
    ];

    options.sort((a, b) => a.label.compareTo(b.label));

    return options;
  }

  List<PersonItem> get _filteredTeachers
  {
    final query = _searchText.toLowerCase();

    final result = _teachers.where((teacher)
    {
      final name = '${teacher.firstName} ${teacher.lastName}'.toLowerCase();

      return name.contains(query) &&
          (!_onlyDisliked || _isDisliked(teacher)) &&
          (_selectedSubjectIds.isEmpty || teachesOneOf(teacher, _selectedSubjectIds));
    }).toList();

    result.sort(_sort.compare);

    return result;
  }

  Future<OpinionPupil> _setOpinion(OpinionPupil pupil, PersonItem teacher, bool disliked) async
  {
    final fresh = await saveTeacherOpinion(pupil, teacher, disliked);

    if (mounted)
    {
      setState(()
      {
        _pupils = [for (final each in _pupils) each.taxCode == fresh.taxCode ? fresh : each];
      });
    }

    return fresh;
  }

  void _openTeacher(PersonItem teacher)
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'TeacherDetails',
      builder: (_) => _TeacherDialog(
        teacher: teacher,
        pupils: _pupils,
        speaksForSelf: !_isParent,
        onOpinion: (pupil, disliked) => _setOpinion(pupil, teacher, disliked),
      ),
    );
  }

  void _showSubjectFilterDialog()
  {
    showBlurredDialog(
      context: context,
      barrierLabel: 'SubjectFilterDialog',
      builder: (context) => MultiSelectFilterDialog<int>(
        title: kSubjectsFilterTitle,
        hint: kSubjectsFilterHint,
        options: _subjectOptions,
        initialSelected: _selectedSubjectIds,
        onApply: (ids) => setState(() => _selectedSubjectIds = ids),
      ),
    );
  }

  Widget _buildSortPill()
  {
    return AppFilterPill<TeacherSort>.setting(
      prefix: 'Ordina',
      hint: kTeachersSortHint,
      icon: Icons.swap_vert_rounded,
      value: _sort,
      menuWidth: 220,
      onChanged: (value) => setState(() => _sort = value),
      options: TeacherSort.values
          .map((sort) => FilterOption(value: sort, label: sort.label))
          .toList(),
    );
  }

  Widget _buildDislikedPill()
  {
    return AppTogglePill(
      label: kOnlyDislikedLabel,
      icon: Icons.thumb_down_outlined,
      active: _onlyDisliked,
      onChanged: (active) => setState(() => _onlyDisliked = active),
    );
  }

  List<Widget> _buildHeader(int count)
  {
    return [
      _buildIntro(),
      TabHeaderRow(
        search: AppSearchField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchText = value),
          hintText: kTeachersSearchHint,
        ),
      ),
      const SizedBox(height: 28),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildSortPill(),
          const FilterGroupDivider(),
          AppCountFilterPill(
            icon: Icons.auto_stories_outlined,
            label: kSubjectsFilterLabel,
            count: _selectedSubjectIds.length,
            onOpen: _showSubjectFilterDialog,
            onClear: () => setState(() => _selectedSubjectIds = {}),
          ),
          if (widget.canReport) _buildDislikedPill(),
        ],
      ),
      const SizedBox(height: 20),
      Text(
        teachersFoundLabel(count),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppTheme.trialMutedText,
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  @override
  Widget build(BuildContext context)
  {
    if (_isLoading)
    {
      return const Center(child: CircularProgressIndicator(color: AppTheme.trialTurquoise));
    }

    final teachers = _filteredTeachers;

    return TabContent(
      header: _buildHeader(teachers.length),
      body: EntityCardGrid(
        cardWidth: TeacherCard.width,
        children: [
          for (final teacher in teachers)
            TeacherCard(
              teacher: teacher,
              disliked: _isDisliked(teacher),
              onTap: () => _openTeacher(teacher),
            ),
        ],
      ),
    );
  }
}

class _TeacherDialog extends StatefulWidget
{
  final PersonItem teacher;
  final List<OpinionPupil> pupils;

  final bool speaksForSelf;

  final Future<OpinionPupil> Function(OpinionPupil pupil, bool disliked) onOpinion;

  const _TeacherDialog({
    required this.teacher,
    required this.pupils,
    required this.speaksForSelf,
    required this.onOpinion,
  });

  @override
  State<_TeacherDialog> createState() => _TeacherDialogState();
}

class _TeacherDialogState extends State<_TeacherDialog>
{
  late List<OpinionPupil> _pupils = widget.pupils;

  bool _isSaving = false;

  Future<void> _toggle(OpinionPupil pupil, bool disliked) async
  {
    if (_isSaving)
    {
      return;
    }

    setState(() => _isSaving = true);

    try
    {
      final fresh = await widget.onOpinion(pupil, disliked);

      if (mounted)
      {
        setState(()
        {
          _pupils = [for (final each in _pupils) each.taxCode == fresh.taxCode ? fresh : each];
        });
      }
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
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildVoice(String label, String? value)
  {
    final text = value?.trim();
    final shown = text == null || text.isEmpty ? _empty : text;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFieldLabel(label),
        const SizedBox(height: 6),
        Text(
          shown,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.45,
            color: shown == _empty ? AppTheme.trialMutedText : AppTheme.trialInk,
          ),
        ),
      ],
    );
  }

  Widget _buildProfile()
  {
    final age = widget.teacher.age;

    return AppDialogPill(
      expand: true,
      child: SelectionArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVoice('Età', age == null ? null : '$age anni'),
            const SizedBox(height: _voiceGap),
            _buildVoice('Studi scolastici', widget.teacher.schoolEducation),
            const SizedBox(height: _voiceGap),
            _buildVoice('Studi universitari', widget.teacher.universityEducation),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String name)
  {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: _tagSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        name,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppTheme.trialTealDeep,
        ),
      ),
    );
  }

  Widget _buildArea(String title, List<String> names)
  {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(child: AppEyebrow(title)),
              Text(
                '${names.length}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.trialMutedText,
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: _tagGap,
          runSpacing: _tagGap,
          children: [for (final name in names) _buildTag(name)],
        ),
      ],
    );
  }

  Widget _buildSubjects()
  {
    final subjects = subjectsOf(widget.teacher);

    final areas = [
      for (final group in groupByArea(subjects, (subject) => subject.subjectArea))
        (title: group.title, names: [for (final subject in group.items) subject.subjectName]..sort()),
    ];

    return AppDialogPill(
      expand: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: subjects.isEmpty ? 0 : _areaGap),
            child: Text(
              taughtSubjectsLabel(subjects.length),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: subjects.isEmpty ? AppTheme.trialMutedText : AppTheme.trialTealDeep,
                fontStyle: subjects.isEmpty ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: _subjectsMaxHeight),
            child: ScrollEdgeFade(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < areas.length; index++) ...[
                      if (index > 0) const SizedBox(height: _areaGap),
                      _buildArea(areas[index].title, areas[index].names),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumb(OpinionPupil pupil, String label)
  {
    return AppSelectableChip(
      icon: Icons.thumb_down_rounded,
      label: label,
      selected: pupil.dislikes(widget.teacher),
      onSelected: (disliked) => _toggle(pupil, disliked),
    );
  }

  Widget _buildOpinions()
  {
    if (_pupils.length == 1)
    {
      final pupil = _pupils.single;
      final sentence = opinionSentence(pupil, widget.teacher, forSelf: widget.speaksForSelf);

      return Align(alignment: Alignment.centerLeft, child: _buildThumb(pupil, sentence));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          opinionQuestion(widget.teacher),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.4,
            color: AppTheme.trialInk,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [for (final pupil in _pupils) _buildThumb(pupil, pupil.firstName)],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context)
  {
    final teacher = widget.teacher;

    return AppDialogStack(
      eyebrow: 'Docente',
      title: '${teacher.firstName} ${teacher.lastName}',
      leading: PersonAvatar(person: teacher, size: PersonAvatar.titleSize),
      maxWidth: _dialogWidth,
      children: [
        _buildProfile(),
        _buildSubjects(),
        if (_pupils.isNotEmpty) AppDialogPill(expand: true, child: _buildOpinions()),
      ],
    );
  }
}
