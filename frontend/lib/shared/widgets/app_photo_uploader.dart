import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/api_config.dart';
import '../../core/theme/app_theme.dart';
import 'app_badged_face.dart';
import 'app_check_mark.dart';
import 'snackbar.dart';

const double _size = 110;

class AppPhotoUploader extends StatefulWidget
{
  final Uint8List? imageBytes;
  final String? initialImageUrl;
  final ValueChanged<Uint8List?> onImagePicked;

  const AppPhotoUploader({
    super.key,
    required this.imageBytes,
    this.initialImageUrl,
    required this.onImagePicked,
  });

  @override
  State<AppPhotoUploader> createState() =>
      _AppPhotoUploaderState();
}

class _AppPhotoUploaderState
    extends State<AppPhotoUploader>
{
  final ImagePicker _picker = ImagePicker();
  bool _isDeleted = false;
  late String _cacheBustTimestamp;

  @override
  void initState()
  {
    super.initState();
    _cacheBustTimestamp = DateTime.now().millisecondsSinceEpoch.toString();
  }

  Future<void> _pickImage() async
  {
    try
    {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

      if (image == null)
      {
        return;
      }

      final Uint8List bytes = await image.readAsBytes();

      setState(()
      {
        _isDeleted = false;
      });

      widget.onImagePicked(bytes);
    }
    catch (e)
    {
      if (mounted)
      {
        CustomSnackBar.show(
          context: context,
          message: 'Errore durante la selezione dell\'immagine.',
          isError: true,
        );
      }
    }
  }

  void _removeImage()
  {
    setState(()
    {
      _isDeleted = true;
    });

    widget.onImagePicked(null);
  }

  @override
  Widget build(BuildContext context)
  {
    ImageProvider? imageProvider;

    if (widget.imageBytes != null)
    {
      imageProvider = MemoryImage(widget.imageBytes!);
    }
    else if (!_isDeleted &&
        widget.initialImageUrl != null &&
        widget.initialImageUrl!.isNotEmpty)
    {
      String url = widget.initialImageUrl!;

      if (url.startsWith('/'))
      {
        url = url = '${ApiConfig.buildUrl(url)}?v=$_cacheBustTimestamp';
      }

      imageProvider = NetworkImage(url);
    }

    final bool hasImage = imageProvider != null;

    final Widget face = Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: kPickedSurface,
        shape: BoxShape.circle,
        image: hasImage
            ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
            : null,
      ),
      child: !hasImage
          ? const Icon(
              Icons.person_outline,
              size: 48,
              color: AppTheme.trialTealDeep,
            )
          : null,
    );

    return AppBadgedFace(
      face: face,
      size: _size,
      hasImage: hasImage,
      onPick: _pickImage,
      onRemove: _removeImage,
    );
  }
}
