import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/role_label_mapper.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/casa_michela_loader.dart';
import '../../auth/models/me_response.dart';
import '../../people/models/person_item.dart';

import '../../../core/config/api_config.dart';

class ProfileTab extends StatefulWidget 
{
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> 
{
  final ApiService _apiService = ApiService();

  MeResponse? _me;
  PersonItem? _person;
  bool        _isLoading    = true;
  String?     _errorMessage;

  int _selectedSubTab = 0;

  final List<String> _subTabs = [
    'Informazioni personali',
    'Informazioni associative',
  ];

  @override
  void initState() 
  {
    super.initState();
    _fetchProfile(isInitialLoad: true);
  }

  Future<void> _fetchProfile({bool isInitialLoad = false}) async 
  {
    if (isInitialLoad) 
    {
      setState(() 
      {
        _isLoading    = true;
        _errorMessage = null;
      });
    }

    try 
    {
      final meResponse     = await _apiService.me();
      final personResponse = await _apiService.getPerson(meResponse.taxCode);

      if (mounted) 
      {
        setState(() 
        {
          _me        = meResponse;
          _person    = personResponse;
          _isLoading = false;
        });
      }
    } 
    catch (e) 
    {
      if (mounted) 
      {
        setState(() 
        {
          _isLoading    = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  String _getAdminRoleText(PersonItem person) 
  {
    final role = person.adminRole;

    if (role == null) 
    {
      return '-';
    }

    if (role == 'OTHER' || role.toUpperCase() == 'ALTRO') 
    {
      return person.adminOtherRole ?? '-';
    }

    if (role == 'PRESIDENT' || role == 'Presidente') 
    {
      return 'Presidente';
    }

    if (role == 'VICE_PRESIDENT' || role == 'Vicepresidente') 
    {
      return 'Vicepresidente';
    }

    if (role == 'TREASURER' || role == 'Tesoriere') 
    {
      return 'Tesoriere';
    }

    return role;
  }

  //StacksToNewLineInsteadOfOverflowing_WasAPlainRowBeforeWithNoWrapAndNoScroll
  Widget _buildSubNavigation() 
  {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32.0),
      child:   Wrap(
        spacing:    12,
        runSpacing: 12,
        children:   List.generate(_subTabs.length, (index) 
        {
          final isSelected = _selectedSubTab == index;

          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child:  GestureDetector(
              onTap: () 
              {
                setState(() 
                {
                  _selectedSubTab = index;
                });
              },
              child: AnimatedContainer(
                duration:   const Duration(milliseconds: 250),
                curve:      Curves.easeInOut,
                padding:    const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical:   10,
                ),
                decoration: BoxDecoration(
                  color:  isSelected ? const Color(0xFF003C82) : Colors.white,
                  border: Border.all(
                    color: isSelected ? const Color(0xFF003C82) : const Color(0xFFE2E8F0),
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  curve:    Curves.easeInOut,
                  style:    GoogleFonts.plusJakartaSans(
                    fontSize:   14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color:      isSelected ? Colors.white : const Color(0xFF64748B),
                  ),
                  child: Text(_subTabs[index]),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) 
  {
    if (_isLoading) 
    {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 40.0),
          child:   CasaMichelaLoader(),
        ),
      );
    }

    if (_errorMessage != null || _me == null || _person == null) 
    {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 40.0),
          child:   Text(
            'Errore durante il caricamento del profilo. Riprova più tardi.',
            style: GoogleFonts.plusJakartaSans(
              fontSize:   18,
              fontWeight: FontWeight.w600,
              color:      const Color( 0xFF94A3B8),
            ),
          ),
        ),
      );
    }

    final me     = _me!;
    final person = _person!;

    final String nome    = me.firstName;
    final String cognome = me.lastName;
    final String sesso   = me.gender ?? '-';
    final String cf      = me.taxCode;

    final String email    = me.email ?? '-';
    final String telefono = me.phoneNumber ?? '-';

    final String dataNascita  = me.birthDate != null ? DateFormat('dd/MM/yyyy').format(me.birthDate!) : '-';
    final String cittaNascita = me.birthCity ?? '-';
    final String provNascita  = me.birthProvince ?? '-';

    final String indirizzo      = me.address ?? '-';
    final String civico         = me.addressNumber ?? '-';
    final String cittaResidenza = me.city ?? '-';
    final String provResidenza  = me.province ?? '-';
    final String cap            = me.zipCode ?? '-';

    final rawRoles        = person.roles.map((r) => r.toUpperCase()).toSet();
    final translatedRoles = RoleLabelMapper.processRoles(person.roles);

    final bool isStaff = rawRoles.contains('AMMINISTRATORE') ||
                         rawRoles.contains('ADMIN') ||
                         rawRoles.contains('DOCENTE') ||
                         rawRoles.contains('TEACHER') ||
                         rawRoles.contains('PSICOLOGO') ||
                         rawRoles.contains('PSYCHOLOGIST');

    return SingleChildScrollView(
      padding: const EdgeInsets.only(
        top:    16, 
        left:   0, 
        right:  0, 
        bottom: 32,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSubNavigation(),

              if (_selectedSubTab == 0) ...[
                //StacksVerticallyBelowTheBreakpoint_LayoutBuilderStaysOutsideIntrinsicHeight
                //SameFixAppliedInPersonInfoTab_NeverNestLayoutBuilderInsideIntrinsicHeight
                _ResponsiveCardPair(
                  first: _ProfileSectionCard(
                    title:       'Identità',
                    labelWidth:  160,
                    leadingIcon: _ProfileAvatar(
                      profileImageUrl: me.profileImageUrl,
                      onImageUpdated:  () => _fetchProfile(isInitialLoad: false),
                    ),
                    rows: [
                      _InfoRowData('Nome',           nome),
                      _InfoRowData('Cognome',        cognome),
                      _InfoRowData('Sesso',          sesso),
                      _InfoRowData('Codice fiscale', cf),
                      null,
                    ],
                  ),
                  second: _ProfileSectionCard(
                    title:       'Residenza',
                    labelWidth:  110,
                    leadingIcon: const _StaticAvatar(icon: Icons.home_rounded),
                    rows: [
                      _InfoRowData('Indirizzo', indirizzo),
                      _InfoRowData('N°',        civico),
                      _InfoRowData('Città',     cittaResidenza),
                      _InfoRowData('Provincia', provResidenza),
                      _InfoRowData('CAP',       cap),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _ResponsiveCardPair(
                  first: _ProfileSectionCard(
                    title:       'Dati anagrafici',
                    labelWidth:  160,
                    leadingIcon: const _StaticAvatar(icon: Icons.cake_rounded),
                    rows: [
                      _InfoRowData('Data di nascita',  dataNascita),
                      _InfoRowData('Città di nascita', cittaNascita),
                      _InfoRowData('Provincia',        provNascita),
                    ],
                  ),
                  second: _ProfileSectionCard(
                    title:       'Contatti',
                    labelWidth:  110,
                    leadingIcon: const _StaticAvatar(icon: Icons.alternate_email_rounded),
                    rows: [
                      _InfoRowData('Email',    email),
                      _InfoRowData('Telefono', telefono),
                      null,
                    ],
                  ),
                ),
              ] 
              else ...[
                SizedBox(
                  width: double.infinity,
                  child: _ProfileSectionCard(
                    title:       'Ruoli',
                    labelWidth:  160,
                    leadingIcon: const _StaticAvatar(icon: Icons.admin_panel_settings_rounded),
                    customContent: Align(
                      alignment: Alignment.topLeft,
                      child:     translatedRoles.isNotEmpty
                          ? Wrap(
                              spacing:    8,
                              runSpacing: 8,
                              children:   translatedRoles.map((role) => _RoleChip(label: role)).toList(),
                            )
                          : Text(
                              'Nessun ruolo assegnato',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                color:    const Color(0xFF7A7A7A),
                              ),
                            ),
                    ),
                  ),
                ),

                if (isStaff) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: _ProfileSectionCard(
                      title:       'Dettagli collaborazione',
                      labelWidth:  205,
                      leadingIcon: const _StaticAvatar(icon: Icons.account_balance_outlined),
                      rows: [
                        _InfoRowData('Tipo collaborazione', person.collaborationType ?? '-'),
                        _InfoRowData('IBAN',                person.iban?.isNotEmpty == true ? person.iban! : '-'),
                      ],
                    ),
                  ),
                ],

                if (rawRoles.contains('AMMINISTRATORE') || rawRoles.contains('ADMIN')) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: _ProfileSectionCard(
                      title:       'Dettagli amministratore',
                      labelWidth:  205,
                      leadingIcon: const _StaticAvatar(icon: Icons.computer_outlined),
                      rows: [
                        _InfoRowData('Ruolo', _getAdminRoleText(person)),
                      ],
                    ),
                  ),
                ],

                if (rawRoles.contains('DOCENTE') || rawRoles.contains('TEACHER')) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: _ProfileSectionCard(
                      title:       'Dettagli docente',
                      labelWidth:  205,
                      leadingIcon: const _StaticAvatar(icon: Icons.school_outlined),
                      rows: [
                        _InfoRowData('Studi scolastici',   person.schoolEducation?.isNotEmpty == true ? person.schoolEducation! : '-'),
                        _InfoRowData('Studi universitari', person.universityEducation?.isNotEmpty == true ? person.universityEducation! : '-'),
                      ],
                    ),
                  ),
                ],

                if (rawRoles.contains('STUDENTE') || rawRoles.contains('STUDENT')) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: _ProfileSectionCard(
                      title:       'Dettagli studente',
                      labelWidth:  205,
                      leadingIcon: const _StaticAvatar(icon: Icons.menu_book_outlined),
                      rows: [
                        _InfoRowData(
                          'Uscita anticipata',
                          person.earlyExit == null
                              ? '-'
                              : (person.earlyExit! ? 'Autorizzata' : 'Non autorizzata'),
                        ),
                      ],
                    ),
                  ),
                ],

                if (rawRoles.contains('CORSISTA') || rawRoles.contains('COURSE_PARTICIPANT')) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: _ProfileSectionCard(
                      title:       'Dettagli corsista',
                      labelWidth:  205,
                      leadingIcon: const _StaticAvatar(icon: Icons.self_improvement_rounded),
                      rows: [
                        _InfoRowData('Tipo corso',            person.courseType?.isNotEmpty == true ? person.courseType! : '-'),
                        _InfoRowData('Scadenza cert. medico', person.medicalCertificateExpiration != null ? DateFormat('dd/MM/yyyy').format(person.medicalCertificateExpiration!) : '-'),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ResponsiveCardPair extends StatelessWidget 
{
  final Widget first;
  final Widget second;
  final double breakpoint;

  const _ResponsiveCardPair
  ({
    required this.first,
    required this.second,
    this.breakpoint = 820.0,
  });

  @override
  Widget build(BuildContext context) 
  {
    return LayoutBuilder
    (
      builder: (context, constraints) 
      {
        final bool isCompact = constraints.maxWidth < breakpoint;

        if (isCompact) 
        {
          return Column
          (
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: 
            [
              first,
              const SizedBox(height: 24),
              second,
            ],
          );
        }

        return IntrinsicHeight
        (
          child: Row
          (
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: 
            [
              Expanded(child: first),
              const SizedBox(width: 24),
              Expanded(child: second),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileSectionCard extends StatelessWidget 
{
  final String               title;
  final Widget               leadingIcon;
  final double               labelWidth;
  final List<_InfoRowData?>? rows;
  final Widget?              customContent;

  const _ProfileSectionCard({
    required this.title,
    required this.leadingIcon,
    this.labelWidth = 160,
    this.rows,
    this.customContent,
  });

  @override
  Widget build(BuildContext context) 
  {
    //Card selection area
    return SelectionArea(
      child: Container(
        padding:    const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(40),
          boxShadow:    const [
            BoxShadow(
              color:      Color(0x0A000000),
              offset:     Offset(0, 4),
              blurRadius: 16,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize:       MainAxisSize.min,
          children: [
            SizedBox(
              height: 90,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  leadingIcon,
                  const SizedBox(width: 24),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize:   26,
                        fontWeight: FontWeight.w700,
                        color:      const Color(0xFF003C82),
                        height:     1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child:   Divider(
                height:    1, 
                thickness: 1, 
                color:     Color(0xFFF1F5F9),
              ),
            ),
            customContent ?? Column(
              mainAxisSize:       MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children:           _buildRows(),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRows() 
  {
    if (rows == null) 
    {
      return const [];
    }

    final List<Widget> widgets = [];

    for (int i = 0; i < rows!.length; i++) 
    {
      final bool isLast  = i == rows!.length - 1;
      final      rowData = rows![i];

      Widget rowWidget;

      if (rowData == null) 
      {
        rowWidget = Opacity(
          opacity: 0.0,
          child:   _ProfileInfoRow(
            label:      '-', 
            value:      '-',
            labelWidth: labelWidth,
          ),
        );
      } 
      else 
      {
        rowWidget = _ProfileInfoRow(
          label:      rowData.label, 
          value:      rowData.value,
          labelWidth: labelWidth,
        );
      }

      if (!isLast) 
      {
        rowWidget = Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child:   rowWidget,
        );
      }

      widgets.add(rowWidget);
    }

    return widgets;
  }
}

class _StaticAvatar extends StatelessWidget 
{
  final IconData icon;

  const _StaticAvatar({
    required this.icon,
  });

  @override
  Widget build(BuildContext context) 
  {
    return Container(
      width:  90,
      height: 90,
      decoration: const BoxDecoration(
        color: Color(0xFFE8EEF7),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon, 
        size:  44, 
        color: const Color(0xFF003C82),
      ),
    );
  }
}

class _ProfileAvatar extends StatefulWidget 
{
  final String?      profileImageUrl;
  final VoidCallback onImageUpdated;

  const _ProfileAvatar({
    required this.onImageUpdated, 
    this.profileImageUrl,
  });

  @override
  State<_ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<_ProfileAvatar> 
{
  bool _isHovering  = false;
  bool _isUploading = false;

  final ImagePicker _picker = ImagePicker();

  String? get _absoluteImageUrl 
  {
    if (widget.profileImageUrl == null || widget.profileImageUrl!.isEmpty) 
    {
      return null;
    }

    String url = widget.profileImageUrl!;

    if (!url.startsWith('http://') && !url.startsWith('https://')) 
    {
      url = '${ApiConfig.baseUrl}$url';
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    return '$url?v=$timestamp';
  }

  Future<void> _pickAndUploadImage() async 
  {
    try 
    {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

      if (image == null) 
      {
        return;
      }

      setState(() 
      {
        _isUploading = true;
      });

      final bytes = await image.readAsBytes();

      await ApiService().uploadProfileImage(bytes, image.name);

      widget.onImageUpdated();
    } 
    catch (e) 
    {
      if (mounted) 
      {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:         Text('Errore durante il caricamento: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    } 
    finally 
    {
      if (mounted) 
      {
        setState(() 
        {
          _isUploading = false;
          _isHovering  = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) 
  {
    final imageUrl = _absoluteImageUrl;

    return MouseRegion(
      cursor:  _isUploading ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit:  (_) => setState(() => _isHovering = false),
      child:   GestureDetector(
        onTap: _isUploading ? null : _pickAndUploadImage,
        child: SizedBox(
          width:  90,
          height: 90,
          child:  Stack(
            fit:      StackFit.expand,
            children: [
              CircleAvatar(
                key:             ValueKey(imageUrl),
                backgroundColor: const Color(0xFFE8EEF7),
                backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
                child:           imageUrl == null
                    ? const Icon(
                        Icons.person,
                        size:  48,
                        color: Color(0xFF003C82),
                      )
                    : null,
              ),
              
              if (_isUploading)
                AnimatedContainer(
                  duration:   const Duration(milliseconds: 300),
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width:  24,
                      height: 24,
                      child:  CircularProgressIndicator(
                        color:       Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                )
              else
                AnimatedContainer(
                  duration:   const Duration(milliseconds: 350),
                  curve:      Curves.easeOut,
                  decoration: BoxDecoration(
                    color: _isHovering ? Colors.black54 : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: AnimatedScale(
                      scale:    _isHovering ? 1.0 : 0.4,
                      duration: const Duration(milliseconds: 350),
                      curve:    Curves.easeOutBack,
                      child:    AnimatedOpacity(
                        opacity:  _isHovering ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        child:    const Icon(
                          Icons.edit_rounded,
                          color: Colors.white,
                          size:  28,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget 
{
  final String label;
  final String value;
  final double labelWidth;

  const _ProfileInfoRow({
    required this.label, 
    required this.value,
    required this.labelWidth,
  });

  @override
  Widget build(BuildContext context) 
  {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize:   18,
              fontWeight: FontWeight.w500,
              color:      const Color(0xFF7A7A7A),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize:   18,
              fontWeight: FontWeight.w600,
              color:      const Color(0xFF2A2A2A),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoleChip extends StatelessWidget 
{
  final String label;

  const _RoleChip({
    required this.label,
  });

  @override
  Widget build(BuildContext context) 
  {
    return Container(
      padding:    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color:        const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: const Color(0xFFE0E5EC)),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize:   14,
          fontWeight: FontWeight.w600,
          color:      const Color(0xFF64748B),
        ),
      ),
    );
  }
}

class _InfoRowData 
{
  final String label;
  final String value;

  const _InfoRowData(this.label, this.value);
}