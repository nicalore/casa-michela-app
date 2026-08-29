import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/config/api_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/phone_number.dart';
import '../../../core/utils/role_label_mapper.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/page_transition.dart';
import '../../../shared/widgets/app_entity_chip.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../auth/models/me_response.dart';
import '../../people/models/person_item.dart';
import '../../people/widgets/person_detail_widgets.dart' show kPersonWideCardLabelWidth;

enum ProfileSection
{
  personal,
  association,
}

class ProfileTab extends StatefulWidget
{
  final ProfileSection section;

  const ProfileTab({super.key, required this.section});

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

  @override
  Widget build(BuildContext context) 
  {
    // Part of the section handover: on their own these would paint over the
    // section still leaving.
    if (_isLoading) 
    {
      return const PageTransitionItem(
        slot:  PageTransitionItem.header,
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(top: 40.0),
            child:   CircularProgressIndicator(color: AppTheme.trialTealDeep),
          ),
        ),
      );
    }

    if (_errorMessage != null || _me == null || _person == null) 
    {
      return PageTransitionItem(
        slot:  PageTransitionItem.header,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 40.0),
            child:   Text(
              'Errore durante il caricamento del profilo. Riprova più tardi.',
              style: GoogleFonts.plusJakartaSans(
                fontSize:   18,
                fontWeight: FontWeight.w600,
                color:      AppTheme.trialMutedText,
              ),
            ),
          ),
        ),
      );
    }

    final me     = _me!;
    final person = _person!;

    final String firstNameValue    = me.firstName;
    final String lastNameValue = me.lastName;
    final String genderValue   = me.gender ?? '-';
    final String cf      = me.taxCode;

    final String email    = me.email ?? '-';
    final String phoneValue = me.phoneNumber == null ? '-' : formatPhoneNumber(me.phoneNumber);

    final String birthDateValue  = me.birthDate != null ? DateFormat('dd/MM/yyyy').format(me.birthDate!) : '-';
    final String birthCityValue = me.birthCity ?? '-';
    final String birthProvinceValue  = me.birthProvince ?? '-';

    final String addressValue      = me.address ?? '-';
    final String streetNumberValue         = me.addressNumber ?? '-';
    final String residenceCityValue = me.city ?? '-';
    final String residenceProvinceValue  = me.province ?? '-';
    final String postalCodeValue            = me.zipCode ?? '-';

    final rawRoles        = person.roles.map((r) => r.toUpperCase()).toSet();
    final translatedRoles = RoleLabelMapper.processRoles(person.roles);

    final bool isStaff = rawRoles.contains('AMMINISTRATORE') ||
                         rawRoles.contains('ADMIN') ||
                         rawRoles.contains('DOCENTE') ||
                         rawRoles.contains('TEACHER') ||
                         rawRoles.contains('PSICOLOGO') ||
                         rawRoles.contains('PSYCHOLOGIST');

    // Both rail entries are sections of this one tab: the profile loads once.
    Widget half(bool personal)
    {
      return PageTransitionScrollView(
        child: Padding(
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
                children: pageTransitionBlocks([
                  if (personal) ...[
                    // Never nest a LayoutBuilder inside IntrinsicHeight (same
                    // fix as PersonInfoTab).
                    _ResponsiveCardPair(
                      first: _ProfileSectionCard(
                        title:       'Identità',
                        labelWidth:  160,
                        leadingIcon: _ProfileAvatar(
                          profileImageUrl: me.profileImageUrl,
                          firstName:       firstNameValue,
                          lastName:        lastNameValue,
                          onImageUpdated:  () => _fetchProfile(isInitialLoad: false),
                        ),
                        rows: [
                          _InfoRowData('Nome',           firstNameValue),
                          _InfoRowData('Cognome',        lastNameValue),
                          _InfoRowData('Sesso',          genderValue),
                          _InfoRowData('Codice fiscale', cf),
                          null,
                        ],
                      ),
                      second: _ProfileSectionCard(
                        title:       'Residenza',
                        labelWidth:  110,
                        leadingIcon: const _StaticAvatar(icon: Icons.home_rounded),
                        rows: [
                          _InfoRowData('Indirizzo', addressValue),
                          _InfoRowData('N°',        streetNumberValue),
                          _InfoRowData('Città',     residenceCityValue),
                          _InfoRowData('Provincia', residenceProvinceValue),
                          _InfoRowData('CAP',       postalCodeValue),
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
                          _InfoRowData('Data di nascita',  birthDateValue),
                          _InfoRowData('Città di nascita', birthCityValue),
                          _InfoRowData('Provincia',        birthProvinceValue),
                        ],
                      ),
                      second: _ProfileSectionCard(
                        title:       'Contatti',
                        labelWidth:  110,
                        leadingIcon: const _StaticAvatar(icon: Icons.alternate_email_rounded),
                        rows: [
                          _InfoRowData('Email',    email),
                          _InfoRowData('Telefono', phoneValue),
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
                                  children:   translatedRoles.map((role) => AppEntityChip(label: role)).toList(),
                                )
                              : Text(
                                  'Nessun ruolo assegnato',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    color:    AppTheme.trialMutedText,
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
                          labelWidth:  kPersonWideCardLabelWidth,
                          leadingIcon: const _StaticAvatar(icon: Icons.account_balance_outlined),
                          rows: [
                            _InfoRowData('Tipo collaborazione', person.collaborationType ?? '-'),
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
                          labelWidth:  kPersonWideCardLabelWidth,
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
                          labelWidth:  kPersonWideCardLabelWidth,
                          leadingIcon: const _StaticAvatar(icon: Icons.school_outlined),
                          rows: [
                            _InfoRowData('Studente delle superiori', person.isHighSchoolStudent == null ? '-' : (person.isHighSchoolStudent! ? 'Sì' : 'No')),
                            _InfoRowData('Studi scolastici',   person.schoolEducation?.isNotEmpty == true ? person.schoolEducation! : '-'),
                            if (person.isHighSchoolStudent != true)
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
                          labelWidth:  kPersonWideCardLabelWidth,
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
                          labelWidth:  kPersonWideCardLabelWidth,
                          leadingIcon: const _StaticAvatar(icon: Icons.self_improvement_rounded),
                          rows: [
                            _InfoRowData('Tipo corso',            person.courseType?.isNotEmpty == true ? person.courseType! : '-'),
                            _InfoRowData('Scadenza certificato', person.medicalCertificateExpiration != null ? DateFormat('dd/MM/yyyy').format(person.medicalCertificateExpiration!) : '-'),
                          ],
                        ),
                      ),
                    ],
                  ],
                ]),
              ),
            ),
          ),
        ),
      );
    }

    return PageSections(
      index: widget.section == ProfileSection.personal ? 0 : 1,
      children: [half(true), half(false)],
    );
  }
}

class _ResponsiveCardPair extends StatelessWidget 
{
  final Widget first;
  final Widget second;

  const _ResponsiveCardPair({
    required this.first,
    required this.second,
  });

  @override
  Widget build(BuildContext context)
  {
    return LayoutBuilder(
      builder: (context, constraints)
      {
        final bool isCompact = constraints.maxWidth < 820.0;

        if (isCompact)
        {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              first,
              const SizedBox(height: 24),
              second,
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
    return AppCard(
      title:   title,
      leading: leadingIcon,
      child:   customContent ?? Column(
        mainAxisSize:       MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children:           _buildRows(),
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
          child:   AppInfoRow(
            label:      '-', 
            value:      '-',
            labelWidth: labelWidth,
          ),
        );
      } 
      else if (rowData.isSensitive)
      {
        rowWidget = _ObscurableInfoRow(
          label:      rowData.label,
          value:      rowData.value,
          labelWidth: labelWidth,
        );
      }
      else 
      {
        rowWidget = AppInfoRow(
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
    return AppCardBadge(icon: icon);
  }
}

// Stateful for its own hover state, independent of the parent avatar's.
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

  // Regenerated only when profileImageUrl changes: per-rebuild values made
  // every hover reload the NetworkImage and flash (as in DashboardHeader).
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
        CustomSnackBar.show(
          context: context,
          message: 'Errore durante il caricamento dell\'immagine.',
          isError: true,
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

  Future<void> _confirmAndDeleteImage() async
  {
    final bool? confirmed = await showBlurredDialog<bool>(
      context: context,
      barrierLabel: 'ConfirmProfileImageRemoval',
      builder: (dialogContext) => AppDialogStack(
        eyebrow: 'Foto profilo',
        title: 'Confermi?',
        showClose: false,
        maxWidth: 520,
        footer: AppDialogFooter(
          secondary: AppGradientButton(
            label:     'ANNULLA',
            icon:      Icons.close_rounded,
            gradient:  AppTheme.dismissGradient,
            accent:    AppTheme.trialViolet,
            height:    52,
            fontSize:  14,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          primary: AppGradientButton(
            label:     'RIMUOVI',
            icon:      Icons.delete_outline_rounded,
            gradient:  AppTheme.dangerGradient,
            accent:    AppTheme.trialDanger,
            height:    52,
            fontSize:  14,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ),
        children: [
          AppDialogPill(
            child: Text(
              'La foto verrà eliminata definitivamente. '
              'Potrai sempre caricarne una nuova in seguito.',
              style: GoogleFonts.plusJakartaSans(
                fontSize:   16,
                fontWeight: FontWeight.w500,
                height:     1.45,
                color:      AppTheme.trialInk,
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
        CustomSnackBar.show(
          context: context,
          message: 'Errore durante la rimozione dell\'immagine.',
          isError: true,
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
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: AppTheme.brandGradient,
              shape:    BoxShape.circle,
            ),
            child: CircleAvatar(
              key:             ValueKey(imageUrl),
              backgroundColor: Colors.transparent,
              backgroundImage: hasImage ? NetworkImage(imageUrl) : null,
              child:           !hasImage
                  ? Text(
                      _initials,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize:   32,
                        fontWeight: FontWeight.w700,
                        color:      Colors.white,
                      ),
                    )
                  : null,
            ),
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

  bool get _hasValue => widget.value.isNotEmpty && widget.value != '-';

  String get _maskedValue => widget.value.replaceAll(RegExp(r'[^\s]'), '•');

  @override
  Widget build(BuildContext context)
  {
    final String displayValue = !_hasValue
        ? widget.value
        : (_isVisible ? widget.value : _maskedValue);

    return AppInfoRow(
      label:              widget.label,
      value:              displayValue,
      labelWidth:         widget.labelWidth,
      valueLetterSpacing: (_hasValue && !_isVisible) ? 3 : 0,
      trailing: !_hasValue
          ? null
          : IconButton(
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
                color: AppTheme.trialMutedText,
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