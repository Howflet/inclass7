# Digital Pet (In-Class Activity 07)

A small Flutter app where you take care of a pet named Pip. Feeding and playing change its happiness and hunger, hunger goes up on its own over time, and the pet's color, size, and message change with its mood. Everything is handled with a StatefulWidget and setState().

- Repository: https://github.com/Howflet/inclass7
- Team: Team Crispy
- APK: DigitalPet_TeamCrispy.apk
- Pathway: Undergraduate
- Advanced features I picked: Session controls, and Visual polish & accessible motion

## Team and roles

| Member | Pathway | Workstream | Roles |
|---|---|---|---|
| Howard Fletcher (002749646) | Undergraduate | Team 1 (Care Systems) and Team 2 (Pet Personality) | Everything: coordinator, state, UI, testing |

I did this one by myself, so I covered both workstreams. I still kept them separate in git. The pet asset and meter widget were built on a `team-2/pet-personality` branch, and the game logic and tests were built on `team-1/care-systems`. Each branch was merged into main with its own merge commit, so you can see the split with `git log --graph`. There wasn't another team to review my pull requests, so there are no cross-team reviews to link. Before each merge I ran `flutter analyze` and `flutter test`.

## Running it

```bash
flutter pub get
flutter run
flutter analyze
flutter test
flutter build apk --release
```

The release APK ends up in `build/app/outputs/flutter-apk/app-release.apk`. I used Flutter 3.47.2 and tested on an Android emulator (Pixel, 1080x2400).

## Game rules

The pet starts at 50 happiness and 50 hunger, and you can rename it at the top of the screen.

| Thing | What happens |
|---|---|
| Feed | Hunger goes down 10. Happiness goes up 10, unless hunger ends up under 30, in which case the pet is overfed and loses 20 happiness |
| Play | Happiness up 10, hunger up 5 |
| Tap the pet | It bounces and shows a heart, but the meters don't change. I did this on purpose so you can't just spam taps to win |
| Every 30 seconds | Hunger goes up 5. If that would go over 100, hunger stays at 100 and happiness drops 20 instead. So 95 to 100 is free, and the tick after that costs you |
| Limits | Every meter stays between 0 and 100. One `clampMeter()` function handles this |
| Mood | Above 70 is Happy (green, a little bigger). 30 to 70 is Neutral (yellow). Under 30 is Unhappy (red, a little smaller) |
| Winning | Keep happiness above 80 (81 or more) for 3 minutes straight. If it drops to 80 or lower, the countdown is cancelled, and the next time it goes over 80 it starts over from zero |
| Losing | Hunger hits 100 while happiness is 10 or lower |
| After you win or lose | The timers stop and Feed, Play, and Pause are disabled until you hit Play again |
| Reset | Puts the meters back to the starting values, cancels the win countdown, and starts one fresh hunger timer |

The real timings are the constants `kHungerInterval` (30 seconds) and `kWinDuration` (3 minutes) in `lib/pet_screen.dart`. The tests pass in shorter times through the PetScreen constructor instead. That way I never had to change the real values to test them and then remember to change them back.

## Files

- `lib/main.dart` holds the app and a simple home screen. Going from the home screen to the pet screen and back is how I tested that the timers get cleaned up.
- `lib/pet_screen.dart` holds all the pet state: meters, actions, timers, win/loss, and the derived mood, color, and message.
- `lib/widgets/meter_bar.dart` is the animated meter bar.
- `assets/pet.png` is the pet image. It's light gray on a transparent background so it tints well.
- `test/widget_test.dart` has the tests.

## Advanced features

### 1. Session controls

There's a pause button in the top right. When you pause, the pet takes a nap, the banner says the timers are stopped, and Feed and Play are greyed out. Pressing play resumes the game. The app also pauses automatically if you leave it, using `WidgetsBindingObserver`, so the pet doesn't starve while you're on another app. Reset (or Play again after a game ends) restarts everything.

When the game is paused, both the hunger timer and the win countdown are cancelled. Resuming starts a new hunger timer. `_startHungerTimer()` always cancels the old one first, so there's never more than one. I decided resuming should also restart the 3-minute countdown, because the assignment says the happiness has to stay up continuously, and a pause breaks that.

Tested by: "pause stops hunger ticks and disables actions; resume restarts" and "pausing cancels the win streak; resume starts a fresh one". Screenshot 4 shows the paused screen.

### 2. Visual polish and reduced motion

The effects I added:

- **Bounce:** the pet bounces when you feed it, play with it, or tap it (AnimatedScale).
- **Reaction emoji:** a small food, ball, heart, or sleep emoji floats up and fades out (AnimatedSlide and AnimatedOpacity).
- **Meter animation:** the bars slide to the new value instead of jumping (TweenAnimationBuilder). The number next to each bar is always the real value.
- **Speech bubble:** it fades between messages (AnimatedSwitcher). The message is computed from the current state each build instead of being stored, so it can't get out of sync.
- **Mood color and size:** both come from the same `moodFor()` function as the mood label.
- **Reduced motion:** if the phone has animations turned off (`MediaQuery.disableAnimations`), every duration becomes zero, the bounce is skipped, and the emoji doesn't slide. All the information is still shown.

The bounce and emoji each use a short timer. A new action cancels the old timer before starting a new one, so an old timer can't cut off a newer animation. Each timer also checks `mounted` before calling setState.

Tested by: the 29/30/70/71 mood tests, "reduced motion removes the action bounce", and "with motion enabled the pet bounces after an action". Screenshots 2, 3, and 5 show the three moods.

### How the features map to the learning outcomes

| Feature | Outcome | Evidence |
|---|---|---|
| Bounce | The UI reacts to state, and delayed callbacks respect the widget lifecycle | `_celebrate()` cancels the previous timers and checks `mounted`. `dispose()` cancels both timers |
| Mood color and size | Color, size, and label all use the same thresholds | 29 is Unhappy/red/0.94, 30 and 70 are Neutral/yellow/1.0, 71 is Happy/green/1.06. All four are checked in the tests |
| Animated meters | build() just reads state and has no side effects | The number shows the real value right away while the bar animates |
| Reduced motion | The app still works with animations off | The bounce scale stays at 1.0 and the durations are zero |
| Pause/resume | Timers start and stop with the game state | When paused, hunger doesn't move for 5 seconds. After resuming, one tick adds 5 |

## Testing

`flutter analyze` finds no issues, and `flutter test` passes all 21 tests.

| Scenario | Expected | What I got |
|---|---|---|
| Feed at hunger 5 | Hunger stops at 0, overfed penalty | Hunger 0, happiness 50 to 30 |
| Feed at hunger 95 | Hunger 85, happiness +10 | Hunger 85, happiness 60 |
| Play at happiness 95, hunger 98 | Both cap at 100 | 100 and 100 |
| Happiness 29, 30, 70, 71 | Red, yellow, yellow, green, with a text label | Correct for all four |
| Above 80 until just before the win, then drop to 80 | No win, countdown cancelled | No win, and still no win 5 seconds later |
| Back above 80 for the full time | Win right at the full time, hunger stops | No win 1 ms early, win on time, hunger didn't move after |
| Hunger 95, then two ticks | First tick goes to 100 with no penalty. Second tick costs 20 happiness | 100/50, then 100/30 |
| Hunger 100, happiness drops to 10 | Game over, nothing changes after | Game over, buttons disabled, values the same 10 seconds later |
| Reset twice after some ticks | Back to start, only one hunger timer | 60 back to 50, then one tick goes to 55 (not 60 or 65) |
| Leave the pet screen | Timer cancelled, no errors | Left the screen, waited 5 minutes on the test clock, no exceptions |
| Pause and resume | No ticks while paused | Worked |
| Change the name | New name shows, a blank name is ignored | "Biscuit the Pet", and a blank name kept "Pip" |
| Reduced motion on and off | No bounce when on, bounce when off | Worked both ways |

The timer tests use a 10 second win and a 1 second hunger tick so they run fast with Flutter's fake test clock. The real app still uses 30 seconds and 3 minutes.

I also installed the release APK on the emulator and played through it. I renamed the pet to Biscuit, played until happiness was 90 (green, countdown banner showing), paused and resumed, then fed it all the way down to 0/0 (red, "Play with me?"). The screenshots below are from that run. I didn't wait the roughly 10 minutes it takes to reach game over in real time, so the game over state is covered by the tests instead.

## Screenshots

| Home | Neutral (50) | Happy (90) | Paused | Unhappy (0) |
|---|---|---|---|---|
| ![](screenshots/01-home.png) | ![](screenshots/02-neutral.png) | ![](screenshots/03-happy-streak.png) | ![](screenshots/04-paused.png) | ![](screenshots/05-unhappy.png) |

## Accessibility

- Mood isn't shown only by color. There's also a text label ("Mood: Happy"), a face icon, and the pet's size changes.
- Screen readers hear the meters as "Happiness 90 out of 100", and the pet as "Biscuit, mood Happy. Tap to pet." The status banner is a live region, so changes get announced.
- Reduced motion is supported (see above).
- The page scrolls and is limited to 480 dp wide, so it works on small screens and sideways.

## Asset credit

I made `assets/pet.png` myself for this project. I drew it with a short Python script, so no outside images were used. Anyone can use it (CC0).

## Links

- Commit history: https://github.com/Howflet/inclass7/commits/main
- The `team-2/pet-personality` and `team-1/care-systems` work shows up as the two merge commits on main.
