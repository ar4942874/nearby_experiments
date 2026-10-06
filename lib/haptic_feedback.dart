import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Haptic extends StatefulWidget {
  const Haptic({super.key});

  @override
  State<Haptic> createState() => _HapticState();
}

class _HapticState extends State<Haptic> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Center(
          child: Column(
            children: [
              Text(
                'Haptic Feedback Page',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                },
                child: const Text('Medium Impact Haptic Feedback'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
