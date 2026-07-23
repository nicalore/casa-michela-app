import 'dart:async';

import 'package:flutter/material.dart';

class LiveClock extends StatefulWidget
{
  const LiveClock({super.key});

  @override
  State<LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<LiveClock>
{
  // Both lists are indexed from zero, so the one-based values returned by
  // DateTime.month and DateTime.weekday are shifted before lookup.
  static const List<String> _months = [
    'GENNAIO',
    'FEBBRAIO',
    'MARZO',
    'APRILE',
    'MAGGIO',
    'GIUGNO',
    'LUGLIO',
    'AGOSTO',
    'SETTEMBRE',
    'OTTOBRE',
    'NOVEMBRE',
    'DICEMBRE',
  ];

  static const List<String> _weekdays = [
    'LUNEDÌ',
    'MARTEDÌ',
    'MERCOLEDÌ',
    'GIOVEDÌ',
    'VENERDÌ',
    'SABATO',
    'DOMENICA',
  ];

  late DateTime _now;
  Timer? _timer;

  @override
  void initState()
  {
    super.initState();

    _now = DateTime.now();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _now = DateTime.now()),
    );
  }

  @override
  void dispose()
  {
    _timer?.cancel();
    super.dispose();
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context)
  {
    final weekday = _weekdays[_now.weekday - 1];
    final month = _months[_now.month - 1];
    final time = '${_twoDigits(_now.hour)}:${_twoDigits(_now.minute)}:${_twoDigits(_now.second)}';

    return Text(
      '$weekday ${_now.day} $month ${_now.year} | $time',
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w400,
        color: Colors.black,
      ),
    );
  }
}