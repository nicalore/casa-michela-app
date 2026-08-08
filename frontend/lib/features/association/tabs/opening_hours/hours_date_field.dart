import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/date_input_formatters.dart';

/// True for a real gg/mm/aaaa date — rejects both malformed input and
/// impossible days like 31/02, which DateTime would silently roll over into
/// the next month.
bool isValidDateString(String value)
{
  final parts = value.split('/');

  if (parts.length != 3)
  {
    return false;
  }

  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);

  if (day == null || month == null || year == null)
  {
    return false;
  }

  final parsed = DateTime(year, month, day);

  return parsed.year == year && parsed.month == month && parsed.day == day;
}

/// Only valid on a string isValidDateString has already accepted.
DateTime parseDateString(String value)
{
  final parts = value.split('/');

  return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
}

String formatDateString(DateTime date)
{
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

// Labelled gg/mm/aaaa field. No date picker anywhere in this app yet, so it
// follows the same typed-with-auto-slashes convention already used for birth
// dates in the person wizard — on the app's own field, so that a date in an
// Orari dialog is the same object as a name in an Associazione one.
class HoursDateField extends StatelessWidget
{
  final String label;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  const HoursDateField({
    super.key,
    required this.label,
    required this.controller,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context)
  {
    return AppTextField(
      controller: controller,
      label: label,
      hintText: 'gg/mm/aaaa',
      inputFormatters: [DateInputFormatter()],
      onChanged: onChanged,
    );
  }
}
