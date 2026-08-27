// Mirrored from backend/app/core/field_lengths.py: the server refuses
// anything longer.
abstract final class FieldLimits
{
  static const int name = 255;

  static const int description = 1000;

  static const int notes = 1000;

  static const int topic = 255;

  static const int personName = 100;
  static const int taxCode = 16;
  static const int city = 100;
  static const int nation = 100;

  static const int province = 2;
  static const int postalCode = 5;

  static const int residenceType = 100;
  static const int address = 255;
  static const int streetNumber = 20;

  static const int email = 255;
  static const int phone = 20;

  static const int contactName = 200;

  static const int iban = 27;

  static const int education = 500;

  static const int otherRole = 100;
  static const int otherDetail = 255;
  static const int dsaDetail = 255;

  static const int pickupReason = 500;

  static const int reportValue = 255;

  static const int mechanographicCode = 100;
  static const int sector = 100;

  static const int username = 50;
}
