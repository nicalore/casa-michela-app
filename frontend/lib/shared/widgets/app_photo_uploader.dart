import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/api_config.dart';
import '../../core/theme/app_theme.dart';
import 'app_check_mark.dart';
import 'snackbar.dart';

// A person's photo: the circle holding the current one, and the two commands to
// change or remove it.

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
  bool _isHoveringUpload = false;
  bool _isHoveringTrash = false;
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

    final Widget avatar = Container(
      width: 110,
      height: 110,
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

    // The buttons row has a minimum intrinsic width (~155px) that can exceed the
    // available space even when stacked, and horizontal scroll would clip it with
    // no visual cue. FittedBox scales the whole row as one block so it stays fully
    // visible and clickable.
    final Widget buttonsRow = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: SizedBox(
        height: 48,
        child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_)
            {
              setState(()
              {
                _isHoveringUpload = true;
              });
            },
            onExit: (_)
            {
              setState(()
              {
                _isHoveringUpload = false;
              });
            },
            child: GestureDetector(
              onTap: _pickImage,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: _isHoveringUpload ? AppTheme.trialGold : AppTheme.trialLine,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.upload_rounded,
                      size: 20,
                      color: AppTheme.trialTealDeep,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      !hasImage ? 'Carica foto' : 'Cambia foto',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.trialTealDeep,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (hasImage) ...[
            const SizedBox(width: 12),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_)
              {
                setState(()
                {
                  _isHoveringTrash = true;
                });
              },
              onExit: (_)
              {
                setState(()
                {
                  _isHoveringTrash = false;
                });
              },
              child: GestureDetector(
                onTap: _removeImage,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _isHoveringTrash
                        ? AppTheme.trialGoldSurface
                        : Colors.white,
                    // A rounded square, like every other delete button in the
                    // app: a gold circle here next to a gold rectangle elsewhere
                    // would be two answers to the same question.
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 22,
                    color: AppTheme.trialDanger,
                  ),
                ),
              ),
            ),
          ],
        ],
        ),
      ),
    );

    // The row wants avatar (110) + spacing (24) + buttons (~150-190) of width,
    // which the labelled form row above rarely grants, so on narrow screens it
    // stacks vertically instead of overflowing to the right.
    return LayoutBuilder(
      builder: (context, constraints)
      {
        final bool isCompact = constraints.maxWidth < 320;

        if (isCompact)
        {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              avatar,
              const SizedBox(height: 16),
              buttonsRow,
            ],
          );
        }

        return Row(
          children: [
            avatar,
            const SizedBox(width: 24),
            Flexible(child: buttonsRow),
          ],
        );
      },
    );
  }
}
