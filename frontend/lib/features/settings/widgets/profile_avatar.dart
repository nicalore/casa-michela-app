import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/api_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/snackbar.dart';

// The round, editable face: shown on the profile and on the first access,
// the one thing either screen lets the owner change.
class ProfileAvatar extends StatefulWidget 
{
  final String?      profileImageUrl;
  final String       firstName;
  final String       lastName;
  final VoidCallback onImageUpdated;

  // False on somebody else's record: the face is shown, not touched.
  final bool canEdit;

  const ProfileAvatar({
    super.key,
    required this.onImageUpdated, 
    required this.firstName,
    required this.lastName,
    this.profileImageUrl,
    this.canEdit = true,
  });

  @override
  State<ProfileAvatar> createState() => ProfileAvatarState();
}

class ProfileAvatarState extends State<ProfileAvatar> 
{
  bool _isHovering = false;
  bool _isUploading = false;
  bool _isDeleting  = false;

  final ImagePicker _picker = ImagePicker();

  // Regenerated only when profileImageUrl changes: a per-rebuild value reloads the image on hover.
  late String _cacheBuster;

  @override
  void initState() 
  {
    super.initState();
    _cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
  }

  @override
  void didUpdateWidget(covariant ProfileAvatar oldWidget) 
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

          if (!widget.canEdit)
            const SizedBox.shrink()
          else if (isBusy)
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
