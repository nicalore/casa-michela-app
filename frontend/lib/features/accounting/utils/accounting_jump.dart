import '../../lessons/utils/calendar_jump.dart';

abstract final class AccountingJumps
{
  // A day and band of the teachers' summary, asked from a teacher's Compensi.
  static final CalendarJumpChannel teacherHours = CalendarJumpChannel();

  // A band of the pupils' summary, asked from their monthly summary.
  static final CalendarJumpChannel studentHours = CalendarJumpChannel();
}
