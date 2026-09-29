import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/profile_photo.dart';
import '../../../core/utils/error_message.dart';
import '../../../features/auth/models/me_response.dart';
import '../../../services/api_service.dart';
import '../../shared/widgets/mobile_confirm_sheet.dart';
import '../../shared/widgets/mobile_notice.dart';
import 'widgets/mobile_own_face.dart';

const String _uploadFailed = "Errore durante il caricamento dell'immagine.";
const String _removalFailed = "Errore durante la rimozione dell'immagine.";
const String _cameraDenied = 'Concedi il permesso a utilizzare la fotocamera dalle impostazioni.';

// What image_picker reports, on iOS and Android alike, once camera access is refused.
const String _cameraDeniedCode = 'camera_access_denied';

// True once the photo changed; the identity has been fetched again by then.
Future<bool> editMobileFace({
  required BuildContext context,
  required MeResponse user,
  required ValueChanged<bool> onBusy,
}) async
{
  final MobilePhotoAction? action = await showMobilePhotoSheet(context: context, user: user);

  if (!context.mounted || action == null)
  {
    return false;
  }

  return switch (action)
  {
    MobilePhotoAction.gallery => _pickFace(context, ImageSource.gallery, onBusy),
    MobilePhotoAction.camera => _pickFace(context, ImageSource.camera, onBusy),
    MobilePhotoAction.remove => _removeFace(context, onBusy),
  };
}

// No metadata requested, which spares the photo-library permission on iOS.
Future<bool> _pickFace(BuildContext context, ImageSource source, ValueChanged<bool> onBusy) async
{
  try
  {
    final XFile? image = await ImagePicker().pickImage(
      source: source,
      maxWidth: ProfilePhoto.maxSide,
      maxHeight: ProfilePhoto.maxSide,
      imageQuality: ProfilePhoto.quality,
      preferredCameraDevice: CameraDevice.front,
      requestFullMetadata: false,
    );

    if (image == null || !context.mounted)
    {
      return false;
    }

    onBusy(true);

    final ApiService api = ApiService();

    await api.uploadProfileImage(await image.readAsBytes(), image.name);
    await api.me();

    return true;
  }
  catch (e, stackTrace)
  {
    // A refused camera is the owner's to allow, not a fault to report.
    final bool denied = e is PlatformException && e.code == _cameraDeniedCode;

    if (!denied)
    {
      reportCaughtError(e, stackTrace, during: "il caricamento dell'immagine");
    }

    if (context.mounted)
    {
      MobileNotice.show(context, denied ? _cameraDenied : _uploadFailed, error: true);
    }

    return false;
  }
  finally
  {
    onBusy(false);
  }
}

// The confirmation replaces the photo sheet, never stacks over it.
Future<bool> _removeFace(BuildContext context, ValueChanged<bool> onBusy) async
{
  final bool confirmed = await showMobileConfirmSheet(
    context: context,
    eyebrow: 'Foto profilo',
    title: 'Confermi?',
    message: const TextSpan(
      text: 'La foto verrà eliminata definitivamente. '
          'Potrai sempre caricarne una nuova in seguito.',
    ),
    confirmLabel: 'Rimuovi',
    confirmIcon: Icons.delete_outline_rounded,
  );

  if (!confirmed || !context.mounted)
  {
    return false;
  }

  onBusy(true);

  try
  {
    final ApiService api = ApiService();

    await api.deleteProfileImage();
    await api.me();

    return true;
  }
  catch (e, stackTrace)
  {
    reportCaughtError(e, stackTrace, during: "la rimozione dell'immagine");

    if (context.mounted)
    {
      MobileNotice.show(context, _removalFailed, error: true);
    }

    return false;
  }
  finally
  {
    onBusy(false);
  }
}
