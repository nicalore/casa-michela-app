// The server keeps 512 px anyway (backend/app/core/storage.py): shrinking on the
// device keeps a phone photo light enough to upload on mobile data.
abstract final class ProfilePhoto
{
  static const double maxSide = 1024;

  static const int quality = 85;
}
