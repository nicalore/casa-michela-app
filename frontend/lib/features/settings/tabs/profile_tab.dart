import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/role_label_mapper.dart';
import '../../../services/api_service.dart';
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
          child:   CircularProgressIndicator(color: Color(0xFF003C82)),
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
                      firstName:       nome,
                      lastName:        cognome,
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
                        //IbanNascostoDiDefault_MostratoSoloAlTapSull'iconaOcchio_VediIsSensitiveInInfoRowData
                        _InfoRowData(
                          'IBAN',
                          person.iban?.isNotEmpty == true ? person.iban! : '-',
                          isSensitive: true,
                        ),
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
                        _InfoRowData('Scadenza certificato', person.medicalCertificateExpiration != null ? DateFormat('dd/MM/yyyy').format(person.medicalCertificateExpiration!) : '-'),
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
      else if (rowData.isSensitive)
      {
        //RigaMascherataDiDefault_ToggleGestitoInternamenteDaObscurableInfoRow
        rowWidget = _ObscurableInfoRow(
          label:      rowData.label,
          value:      rowData.value,
          labelWidth: labelWidth,
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

//SingolaIconaCliccabileMostrataDentroL'OverlayScuroSull'Avatar
//OraStatefulPerchéServeUnHoverIndipendenteDallo_isHoveringDell'AvatarPadre_
//CheGestisceSoloComparsa/ScomparsaDell'IntestCoppiaDiIcone
class _AvatarIconButton extends StatefulWidget
{
  final IconData      icon;
  final VoidCallback  onTap;
  final double        iconSize;

  const _AvatarIconButton({
    required this.icon,
    required this.onTap,
    this.iconSize = 20,
  });

  @override
  State<_AvatarIconButton> createState() => _AvatarIconButtonState();
}

class _AvatarIconButtonState extends State<_AvatarIconButton>
{
  bool _isHoveringIcon = false;

  @override
  Widget build(BuildContext context)
  {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHoveringIcon = true),
      onExit:  (_) => setState(() => _isHoveringIcon = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap:    widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: AnimatedScale(
            scale:    _isHoveringIcon ? 1.2 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve:    Curves.easeOut,
            child: Icon(
              widget.icon,
              color: Colors.white,
              size:  widget.iconSize,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatefulWidget 
{
  final String?      profileImageUrl;
  final String       firstName;
  final String       lastName;
  final VoidCallback onImageUpdated;

  const _ProfileAvatar({
    required this.onImageUpdated, 
    required this.firstName,
    required this.lastName,
    this.profileImageUrl,
  });

  @override
  State<_ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<_ProfileAvatar> 
{
  bool _isHovering = false;
  bool _isUploading = false;
  bool _isDeleting  = false;

  final ImagePicker _picker = ImagePicker();

  //FIX_SFARFALLIO_HOVER: il cache buster viene generato una sola volta
  //(initState) e rigenerato SOLO quando profileImageUrl cambia davvero
  //(didUpdateWidget), non ad ogni rebuild. Prima il getter lo ricalcolava
  //ogni volta: ogni hover faceva setState -> rebuild -> nuovo timestamp ->
  //nuova ValueKey -> CircleAvatar ricreato da zero -> flash del
  //backgroundColor mentre la NetworkImage ripartiva. Stessa causa/fix già
  //presente in DashboardHeader (_sessionCacheBuster).
  late String _cacheBuster;

  @override
  void initState() 
  {
    super.initState();
    _cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
  }

  @override
  void didUpdateWidget(covariant _ProfileAvatar oldWidget) 
  {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.profileImageUrl != widget.profileImageUrl) 
    {
      _cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
    }
  }

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

    return '$url?v=$_cacheBuster';
  }

  //StessaLogicaDiPersonCard_PrimaLetteraNomeEPrimaLetteraCognome
  String get _initials 
  {
    final String first = widget.firstName.isNotEmpty ? widget.firstName[0] : '';
    final String last  = widget.lastName.isNotEmpty  ? widget.lastName[0]  : '';

    return '$first$last'.toUpperCase();
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

  //StileAllineatoAlDialogDiConfermaUsatoInPersonParentsTab_PerRimuoviResponsabilitàGenitoriali
  //StessoShape_StessiColori_StessoButtonStyleSenzaOverlayDiHover
  Future<void> _confirmAndDeleteImage() async 
  {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Rimuovi Foto Profilo',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color:      const Color(0xFF003C82),
          ),
        ),
        content: Text(
          'La foto verrà eliminata definitivamente. Potrai sempre caricarne una nuova in seguito.',
          style: GoogleFonts.plusJakartaSans(fontSize: 16),
        ),
        actions: [
          TextButton(
            style: ButtonStyle(
              overlayColor: WidgetStateProperty.all(Colors.transparent),
            ),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'ANNULLA',
              style: GoogleFonts.plusJakartaSans(
                color:      const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            style: ButtonStyle(
              overlayColor: WidgetStateProperty.all(Colors.transparent),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'RIMUOVI',
              style: GoogleFonts.plusJakartaSans(
                color:      const Color(0xFFE53935),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) 
    {
      return;
    }

    await _deleteImage();
  }

  Future<void> _deleteImage() async 
  {
    try 
    {
      setState(() 
      {
        _isDeleting = true;
      });

      await ApiService().deleteProfileImage();

      widget.onImageUpdated();
    } 
    catch (e) 
    {
      if (mounted) 
      {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:         Text('Errore durante la rimozione: $e'),
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
          _isDeleting  = false;
          _isHovering  = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) 
  {
    final String? imageUrl = _absoluteImageUrl;
    final bool    hasImage = imageUrl != null;
    final bool    isBusy   = _isUploading || _isDeleting;

    return SizedBox(
      width:  90,
      height: 90,
      child:  Stack(
        fit:      StackFit.expand,
        children: [
          CircleAvatar(
            key:             ValueKey(imageUrl),
            backgroundColor: const Color(0xFFE8EEF7),
            backgroundImage: hasImage ? NetworkImage(imageUrl) : null,
            child:           !hasImage
                ? Text(
                    _initials,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize:   32,
                      fontWeight: FontWeight.w700,
                      color:      const Color(0xFF003C82),
                    ),
                  )
                : null,
          ),

          if (isBusy)
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
            //OverlayUnicoSull'InteroCerchio_MatitaECestinoCompaionoInsiemeAlHover
            MouseRegion(
              cursor:  SystemMouseCursors.click,
              onEnter: (_) => setState(() => _isHovering = true),
              onExit:  (_) => setState(() => _isHovering = false),
              child: AnimatedContainer(
                duration:   const Duration(milliseconds: 350),
                curve:      Curves.easeOut,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isHovering ? Colors.black54 : Colors.transparent,
                ),
                child: Center(
                  child: AnimatedScale(
                    scale:    _isHovering ? 1.0 : 0.4,
                    duration: const Duration(milliseconds: 350),
                    curve:    Curves.easeOutBack,
                    child:    AnimatedOpacity(
                      opacity:  _isHovering ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      child: hasImage
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _AvatarIconButton(
                                  icon:  Icons.edit_rounded,
                                  onTap: _pickAndUploadImage,
                                ),
                                const SizedBox(width: 4),
                                _AvatarIconButton(
                                  icon:  Icons.delete_outline_rounded,
                                  onTap: _confirmAndDeleteImage,
                                ),
                              ],
                            )
                          : _AvatarIconButton(
                              icon:     Icons.edit_rounded,
                              onTap:    _pickAndUploadImage,
                              iconSize: 26,
                            ),
                    ),
                  ),
                ),
              ),
            ),
        ],
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

//StessaLogicaDelToggleUsataInLoginTextField_MaStatoLocaleAllaSingolaRigaInveceCheAlCampoDiInput
//DefaultNascosto__isVisibleParteFalse_ComeRichiesto
class _ObscurableInfoRow extends StatefulWidget
{
  final String label;
  final String value;
  final double labelWidth;

  const _ObscurableInfoRow({
    required this.label,
    required this.value,
    required this.labelWidth,
  });

  @override
  State<_ObscurableInfoRow> createState() => _ObscurableInfoRowState();
}

class _ObscurableInfoRowState extends State<_ObscurableInfoRow>
{
  bool _isVisible = false;

  //NessunaIconaDaMostrareSeIlValoreEAssente_NonHaSensoUnToggleSuUnTrattino
  bool get _hasValue => widget.value.isNotEmpty && widget.value != '-';

  //SostituisceOgniCarattereNonSpazioConUnPallino_CosìLaStrutturaAGruppiRestaLeggibile
  String get _maskedValue => widget.value.replaceAll(RegExp(r'[^\s]'), '•');

  @override
  Widget build(BuildContext context)
  {
    final String displayValue = !_hasValue
        ? widget.value
        : (_isVisible ? widget.value : _maskedValue);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: widget.labelWidth,
          child: Text(
            widget.label,
            style: GoogleFonts.plusJakartaSans(
              fontSize:   18,
              fontWeight: FontWeight.w500,
              color:      const Color(0xFF7A7A7A),
            ),
          ),
        ),
        Expanded(
          child: Text(
            displayValue,
            style: GoogleFonts.plusJakartaSans(
              fontSize:   18,
              fontWeight: FontWeight.w600,
              color:      const Color(0xFF2A2A2A),
              letterSpacing: (_hasValue && !_isVisible) ? 3 : 0,
            ),
          ),
        ),
        if (_hasValue)
          IconButton(
            onPressed: ()
            {
              setState(()
              {
                _isVisible = !_isVisible;
              });
            },
            splashColor:    Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor:     Colors.transparent,
            focusColor:     Colors.transparent,
            padding:        EdgeInsets.zero,
            constraints:    const BoxConstraints(),
            icon: Icon(
              _isVisible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size:  22,
              color: const Color(0xFF6B7280),
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
  final bool   isSensitive;

  const _InfoRowData(this.label, this.value, {this.isSensitive = false});
}