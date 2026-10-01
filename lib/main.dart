import 'package:flutter/material.dart';

import 'pet_screen.dart';

void main() {
  runApp(const DigitalPetApp());
}

class DigitalPetApp extends StatelessWidget {
  const DigitalPetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digital Pet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3E7C6B)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

/// A tiny landing screen. Pushing and popping [PetScreen] from here lets us
/// verify that leaving the pet screen disposes its timers.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/pet.png',
                  width: 160,
                  semanticLabel: 'Your digital pet',
                ),
                const SizedBox(height: 16),
                Text(
                  'Digital Pet',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Keep happiness above 80 for three minutes straight to win. '
                  'Let hunger hit 100 while happiness drops to 10 and it is game over.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('visitPet'),
                  icon: const Icon(Icons.pets),
                  label: const Text('Visit your pet'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const PetScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
