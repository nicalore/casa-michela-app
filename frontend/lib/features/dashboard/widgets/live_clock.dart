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
  late DateTime now;
  Timer? timer;

  static const months = [
    '',
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

  static const weekdays = [
    'LUNEDÌ',
    'MARTEDÌ',
    'MERCOLEDÌ',
    'GIOVEDÌ',
    'VENERDÌ',
    'SABATO',
    'DOMENICA',
  ];

  @override
  void initState()
  {
    super.initState();

    //InitializeCurrentTime
    now = DateTime.now();

    //SetupPeriodicTimer
    timer = Timer.periodic(
      const Duration(seconds: 1),
      (_)
      {
        setState(()
        {
          now = DateTime.now();
        });
      },
    );
  }

  @override
  void dispose()
  {
    //ReleaseResources
    timer?.cancel();
    
    super.dispose();
  }

  String twoDigits(int value)
  {
    return value.toString().padLeft(2, '0');
  }

  @override
  Widget build(BuildContext context)
  {
    final weekday = weekdays[now.weekday - 1];

    return Text(
      '$weekday ${now.day} ${months[now.month]} ${now.year} | '
      '${twoDigits(now.hour)}:${twoDigits(now.minute)}:${twoDigits(now.second)}',
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w400,
        color: Colors.black,
      ),
    );
  }
}