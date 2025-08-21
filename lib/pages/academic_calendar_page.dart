import 'package:flutter/material.dart';

class AcademicCalendar extends StatelessWidget {
  const AcademicCalendar({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('校历', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
      ),
      body: InteractiveViewer(
        minScale: 0.8,
        maxScale: 4.0,
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Image.asset(
                'lib/assets/images/xl.jpg',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}


