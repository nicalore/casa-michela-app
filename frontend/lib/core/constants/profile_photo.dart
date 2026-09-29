// The server keeps 512 px anyway (backend/app/core/storage.py); shrinking here eases mobile uploads.
abstract final class ProfilePhoto
{
  static const double maxSide = 1024;

  static const int quality = 85;
}
