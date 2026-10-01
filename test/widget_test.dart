import 'package:digital_pet/main.dart';
import 'package:digital_pet/pet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const long = Duration(hours: 1);

Future<void> pumpPet(
  WidgetTester tester, {
  int happiness = 50,
  int hunger = 50,
  Duration hungerInterval = long,
  Duration winDuration = long,
  bool reduceMotion = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: PetScreen(
          initialHappiness: happiness,
          initialHunger: hunger,
          hungerInterval: hungerInterval,
          winDuration: winDuration,
        ),
      ),
    ),
  );
  await tester.pump(); // run the post-frame outcome check
}

int meter(WidgetTester tester, String label) {
  final text = tester.widget<Text>(find.byKey(ValueKey('$label-value')));
  return int.parse(text.data!);
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
}

bool enabled(WidgetTester tester, String key) =>
    tester.widget<ButtonStyleButton>(find.byKey(Key(key))).onPressed != null;

void main() {
  group('Clamping and care actions', () {
    testWidgets('feed at hunger 5 clamps to 0 and applies overfed penalty', (
      tester,
    ) async {
      await pumpPet(tester, hunger: 5, happiness: 50);
      await tapKey(tester, 'feedButton');
      expect(meter(tester, 'Hunger'), 0);
      expect(meter(tester, 'Happiness'), 30);
    });

    testWidgets('feed at hunger 95 lowers hunger and raises happiness', (
      tester,
    ) async {
      await pumpPet(tester, hunger: 95, happiness: 50);
      await tapKey(tester, 'feedButton');
      expect(meter(tester, 'Hunger'), 85);
      expect(meter(tester, 'Happiness'), 60);
    });

    testWidgets('play at happiness 95 clamps to 100', (tester) async {
      await pumpPet(tester, happiness: 95, hunger: 98);
      await tapKey(tester, 'playButton');
      expect(meter(tester, 'Happiness'), 100);
      expect(meter(tester, 'Hunger'), 100);
    });

    testWidgets('tapping the pet never changes meters', (tester) async {
      await pumpPet(tester);
      for (var i = 0; i < 5; i++) {
        await tapKey(tester, 'pet');
      }
      expect(meter(tester, 'Happiness'), 50);
      expect(meter(tester, 'Hunger'), 50);
    });
  });

  group('Mood thresholds (29 / 30 / 70 / 71)', () {
    final cases = {
      29: ('Unhappy', Colors.red, 0.94),
      30: ('Neutral', Colors.yellow, 1.0),
      70: ('Neutral', Colors.yellow, 1.0),
      71: ('Happy', Colors.green, 1.06),
    };
    cases.forEach((happiness, expected) {
      testWidgets('happiness $happiness → ${expected.$1}', (tester) async {
        await pumpPet(tester, happiness: happiness);
        expect(find.text('Mood: ${expected.$1}'), findsOneWidget);
        final tint = tester.widget<ColorFiltered>(
          find.byKey(const Key('petTint')),
        );
        expect(
          tint.colorFilter,
          ColorFilter.mode(expected.$2, BlendMode.modulate),
        );
        final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
        expect(scale.scale, closeTo(expected.$3, 1e-9));
      });
    });
  });

  group('Win timer', () {
    const win = Duration(seconds: 10);

    testWidgets(
      'no win at 2:59-equivalent, drop to 80 cancels, fresh timer wins',
      (tester) async {
        // Start above 80; hunger 35 so feeding drops hunger below 30 (-20 happy).
        await pumpPet(tester, happiness: 90, hunger: 35, winDuration: win);
        expect(find.textContaining('Happy streak running'), findsOneWidget);

        await tester.pump(win - const Duration(milliseconds: 1));
        expect(find.textContaining('You win'), findsNothing);

        await tapKey(tester, 'feedButton'); // 90 → 70: streak cancelled
        expect(meter(tester, 'Happiness'), 70);
        await tapKey(tester, 'playButton'); // 80: exactly 80 does not qualify
        expect(meter(tester, 'Happiness'), 80);
        expect(find.textContaining('Happy streak running'), findsNothing);

        await tester.pump(
          const Duration(seconds: 5),
        ); // old timer would fire here
        expect(find.textContaining('You win'), findsNothing);

        await tapKey(tester, 'playButton'); // 90: fresh streak starts
        await tester.pump(win - const Duration(milliseconds: 1));
        expect(find.textContaining('You win'), findsNothing);
        await tester.pump(const Duration(milliseconds: 1));
        expect(find.textContaining('You win'), findsOneWidget);

        expect(enabled(tester, 'feedButton'), isFalse);
        expect(enabled(tester, 'playButton'), isFalse);
      },
    );

    testWidgets('win stops the hunger timer', (tester) async {
      await pumpPet(
        tester,
        happiness: 95,
        hunger: 0,
        winDuration: win,
        hungerInterval: const Duration(seconds: 3),
      );
      await tester.pump(win);
      expect(find.textContaining('You win'), findsOneWidget);
      final hungerAtWin = meter(tester, 'Hunger');
      await tester.pump(const Duration(seconds: 30));
      expect(meter(tester, 'Hunger'), hungerAtWin);
    });
  });

  group('Hunger timer, loss, and reset', () {
    const tick = Duration(seconds: 1);

    testWidgets('95 → 100 without penalty, then overflow tick costs 20', (
      tester,
    ) async {
      await pumpPet(tester, hunger: 95, happiness: 50, hungerInterval: tick);
      await tester.pump(tick);
      expect(meter(tester, 'Hunger'), 100);
      expect(meter(tester, 'Happiness'), 50);
      await tester.pump(tick);
      expect(meter(tester, 'Hunger'), 100);
      expect(meter(tester, 'Happiness'), 30);
    });

    testWidgets('hunger 100 and happiness 10 is game over and freezes state', (
      tester,
    ) async {
      await pumpPet(tester, hunger: 100, happiness: 30, hungerInterval: tick);
      await tester.pump(tick); // overflow: happiness 30 → 10
      expect(meter(tester, 'Happiness'), 10);
      expect(find.textContaining('Game over'), findsOneWidget);
      expect(enabled(tester, 'feedButton'), isFalse);
      expect(enabled(tester, 'playButton'), isFalse);

      await tester.pump(const Duration(seconds: 10));
      expect(meter(tester, 'Happiness'), 10);
      expect(meter(tester, 'Hunger'), 100);
    });

    testWidgets('reset restores meters and leaves exactly one hunger timer', (
      tester,
    ) async {
      await pumpPet(tester, hunger: 50, happiness: 50, hungerInterval: tick);
      await tester.pump(tick);
      await tester.pump(tick);
      expect(meter(tester, 'Hunger'), 60);

      await tapKey(tester, 'resetButton');
      await tapKey(tester, 'resetButton');
      expect(meter(tester, 'Hunger'), 50);

      await tester.pump(tick);
      expect(meter(tester, 'Hunger'), 55); // not 60 or 65: one timer only
    });

    testWidgets('reset after game over re-enables actions', (tester) async {
      await pumpPet(tester, hunger: 100, happiness: 30, hungerInterval: tick);
      await tester.pump(tick);
      expect(find.textContaining('Game over'), findsOneWidget);
      await tapKey(tester, 'resetButton');
      expect(find.textContaining('Game over'), findsNothing);
      expect(enabled(tester, 'feedButton'), isTrue);
    });
  });

  group('Session controls', () {
    const tick = Duration(seconds: 1);

    testWidgets(
      'pause stops hunger ticks and disables actions; resume restarts',
      (tester) async {
        await pumpPet(tester, hunger: 50, hungerInterval: tick);
        await tapKey(tester, 'pauseResume');
        expect(find.textContaining('Paused'), findsOneWidget);
        expect(enabled(tester, 'feedButton'), isFalse);

        await tester.pump(const Duration(seconds: 5));
        expect(meter(tester, 'Hunger'), 50);

        await tapKey(tester, 'pauseResume');
        expect(enabled(tester, 'feedButton'), isTrue);
        await tester.pump(tick);
        expect(meter(tester, 'Hunger'), 55);
      },
    );

    testWidgets('pausing cancels the win streak; resume starts a fresh one', (
      tester,
    ) async {
      const win = Duration(seconds: 10);
      await pumpPet(tester, happiness: 90, winDuration: win);
      await tester.pump(const Duration(seconds: 8));
      await tapKey(tester, 'pauseResume');
      await tester.pump(const Duration(seconds: 20));
      expect(find.textContaining('You win'), findsNothing);

      await tapKey(tester, 'pauseResume');
      await tester.pump(const Duration(seconds: 9));
      expect(find.textContaining('You win'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('You win'), findsOneWidget);
    });
  });

  group('Name, lifecycle, and reduced motion', () {
    testWidgets('user can enter and confirm a pet name', (tester) async {
      await pumpPet(tester);
      await tester.enterText(find.byKey(const Key('nameField')), 'Biscuit');
      await tapKey(tester, 'confirmName');
      expect(find.text('Biscuit the Pet'), findsOneWidget);
    });

    testWidgets('blank name is rejected', (tester) async {
      await pumpPet(tester);
      await tester.enterText(find.byKey(const Key('nameField')), '   ');
      await tapKey(tester, 'confirmName');
      expect(find.text('Pip the Pet'), findsOneWidget);
    });

    testWidgets('leaving the pet screen disposes timers cleanly', (
      tester,
    ) async {
      await tester.pumpWidget(const DigitalPetApp());
      await tester.tap(find.byKey(const Key('visitPet')));
      await tester.pumpAndSettle();
      expect(find.text('Pip the Pet'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(minutes: 5));
      expect(tester.takeException(), isNull);
      expect(find.byType(PetScreen), findsNothing);
    });

    testWidgets('reduced motion removes the action bounce', (tester) async {
      await pumpPet(tester, happiness: 50, reduceMotion: true);
      await tapKey(tester, 'playButton');
      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.scale, 1.0);
      expect(scale.duration, Duration.zero);
    });

    testWidgets('with motion enabled the pet bounces after an action', (
      tester,
    ) async {
      await pumpPet(tester, happiness: 50);
      await tapKey(tester, 'playButton');
      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.scale, greaterThan(1.0));
      await tester.pump(const Duration(milliseconds: 200));
      final settled = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(settled.scale, 1.0);
    });
  });
}
