import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/api_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_badged_face.dart';
import '../../../shared/widgets/app_dialog_footer.dart';
import '../../../shared/widgets/app_dialog_stack.dart';
import '../../../shared/widgets/app_gradient_button.dart';
import '../../../shared/widgets/dialog_components.dart';
import '../../../shared/widgets/snackbar.dart';

const double _defaultSize = 90;

class ProfileAvatar extends StatefulWidget 
{
  final String?      profileImageUrl;
  final String       firstName;
  final String       lastName;
  final VoidCallback onImageUpdated;

  final bool canEdit;

  final double size;

  const ProfileAvatar({
    super.key,
    required this.onImageUpdated, 
    required this.firstName,
    required this.lastName,
    this.profileImageUrl,
    this.canEdit = true,
    this.size = _defaultSize,
  });

  @override
  State<ProfileAvatar> createState() => ProfileAvatarState();
}

class ProfileAvatarState extends State<ProfileAvatar> 
{
  bool _isUploading = false;
  bool _isDeleting  = false;

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

    // The shared version moves only on upload, so the browser keeps the file.
    return '\$url?v=\${ApiService().profileImageVersion}';
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
        setState(() => _isUploading = false);
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
        setState(() => _isDeleting = false);
      }
    }
  }

  Widget _buildFace(String? imageUrl, bool isBusy)
  {
    final bool hasImage = imageUrl != null;

    return SizedBox(
      width:  widget.size,
      height: widget.size,
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
                        fontSize:   widget.size * 32 / _defaultSize,
                        fontWeight: FontWeight.w700,
                        color:      Colors.white,
                      ),
                    )
                  : null,
            ),
          ),
          if (isBusy)
            const DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SizedBox(
                  width:  24,
                  height: 24,
                  child:  CircularProgressIndicator(
                    color:       Colors.white,
                    strokeWidth: 3,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) 
  {
    final String? imageUrl = _absoluteImageUrl;
    final bool    isBusy   = _isUploading || _isDeleting;

    final Widget face = _buildFace(imageUrl, widget.canEdit && isBusy);

    if (!widget.canEdit)
    {
      return face;
    }

    return AppBadgedFace(
      face:     face,
      size:     widget.size,
      hasImage: imageUrl != null,
      onPick:   isBusy ? null : _pickAndUploadImage,
      onRemove: isBusy ? null : _confirmAndDeleteImage,
    );
  }
}
