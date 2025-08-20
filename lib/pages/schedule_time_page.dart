import 'package:flutter/material.dart';

/// 作息时间展示页：展示静态图片 `lib/assets/images/zxb.jpg`
class ScheduleTimePage extends StatelessWidget {
  const ScheduleTimePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('作息时间', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
      ),
      body: InteractiveViewer(
        minScale: 0.8,
        maxScale: 4.0,
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Image.asset(
                'lib/assets/images/zxb.jpg',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}


