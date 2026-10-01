import 'dart:async';

import 'package:flutter/material.dart';

import 'widgets/meter_bar.dart';

/// Production timings. Tests pass shorter values through the constructor.
const Duration kHungerInterval = Duration(seconds: 30);
const Duration kWinDuration = Duration(minutes: 3);

/// Care rules (documented in the README).
const int kFeedHunger = -10;
const int kFeedHappy = 10;
const int kOverfedPenalty = -20; // applied when feeding leaves hunger below 30
const int kPlayHappy = 10;
const int kPlayHunger = 5;
const int kTickHunger = 5;
const int kOverflowPenalty = -20; // tick that would push hunger past 100

int clampMeter(int value) => value.clamp(0, 100).toInt();

enum Mood { unhappy, neutral, happy }

/// Mood bands shared by the label, coat tint, and pet size.
Mood moodFor(int happiness) {
  if (happiness > 70) return Mood.happy;
  if (happiness >= 30) return Mood.neutral;
  return Mood.unhappy;
}

class PetScreen extends StatefulWidget {
  const PetScreen({
    super.key,
    this.initialName = 'Pip',
    this.initialHappiness = 50,
    this.initialHunger = 50,
    this.hungerInterval = kHungerInterval,
    this.winDuration = kWinDuration,
  });

  // Immutable configuration: the starting point Reset returns to.
  final String initialName;
  final int initialHappiness;
  final int initialHunger;
  final Duration hungerInterval;
  final Duration winDuration;

  @override
  State<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends State<PetScreen> with WidgetsBindingObserver {
  // ---- Game state (Team 1: care systems) ----
  late String _petName;
  late int _happiness;
  late int _hunger;
  bool _gameOver = false;
  bool _hasWon = false;
  bool _paused = false;

  Timer? _hungerTimer;
  Timer? _highMoodTimer;

  late final TextEditingController _nameController;

  // ---- Short-lived presentation state (Team 2: pet personality) ----
  bool _bouncing = false;
  Timer? _bounceTimer;
  String? _reaction;
  bool _reactionVisible = false;
  Timer? _reactionTimer;

  bool get _isOver => _gameOver || _hasWon;
  bool get _canAct => !_isOver && !_paused;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _petName = widget.initialName;
    _nameController = TextEditingController(text: _petName);
    _happiness = clampMeter(widget.initialHappiness);
    _hunger = clampMeter(widget.initialHunger);
    _startHungerTimer();
    // The initial meters may already satisfy a win/loss condition.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateOutcome();
      setState(() {}); // reflect a newly started streak timer
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hungerTimer?.cancel();
    _highMoodTimer?.cancel();
    _bounceTimer?.cancel();
    _reactionTimer?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  /// Session control: backgrounding the app pauses the game so the pet is
  /// not neglected while the user is away and no timer runs unseen.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _pause();
    }
  }

  // ------------------------------------------------------------------
  // Timers
  // ------------------------------------------------------------------

  /// Cancels any previous hunger timer first, so exactly one is ever active.
  void _startHungerTimer() {
    _hungerTimer?.cancel();
    _hungerTimer = Timer.periodic(widget.hungerInterval, (timer) {
      if (!mounted || _isOver || _paused) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_hunger + kTickHunger > 100) {
          _hunger = 100;
          _happiness = clampMeter(_happiness + kOverflowPenalty);
        } else {
          _hunger += kTickHunger;
        }
      });
      _updateOutcome();
    });
  }

  void _clearWinTimer() {
    _highMoodTimer?.cancel();
    _highMoodTimer = null;
  }

  void _stopGameTimers() {
    _clearWinTimer();
    _hungerTimer?.cancel();
    _hungerTimer = null;
  }

  /// Re-evaluated after every action and every hunger tick.
  void _updateOutcome() {
    if (_isOver) return;

    if (_hunger == 100 && _happiness <= 10) {
      _stopGameTimers();
      setState(() => _gameOver = true);
      return;
    }

    if (_paused) return;

    // "Above 80" is strictly greater than 80.
    if (_happiness <= 80) {
      _clearWinTimer();
      return;
    }

    _highMoodTimer ??= Timer(widget.winDuration, () {
      _highMoodTimer = null;
      if (!mounted || _isOver || _paused || _happiness <= 80) return;
      _stopGameTimers();
      setState(() => _hasWon = true);
    });
  }

  // ------------------------------------------------------------------
  // Care actions
  // ------------------------------------------------------------------

  void _feedPet() {
    if (!_canAct) return;
    final nextHunger = clampMeter(_hunger + kFeedHunger);
    final happyChange = nextHunger < 30 ? kOverfedPenalty : kFeedHappy;
    final nextHappiness = clampMeter(_happiness + happyChange);
    setState(() {
      _hunger = nextHunger;
      _happiness = nextHappiness;
    });
    _updateOutcome();
    _celebrate('🍖');
  }

  void _playWithPet() {
    if (!_canAct) return;
    final nextHappiness = clampMeter(_happiness + kPlayHappy);
    final nextHunger = clampMeter(_hunger + kPlayHunger);
    setState(() {
      _happiness = nextHappiness;
      _hunger = nextHunger;
    });
    _updateOutcome();
    _celebrate('🎾');
  }

  /// Tapping the pet is pure feedback; it never changes meters, so it cannot
  /// be spammed to make the three-minute win trivial.
  void _petThePet() {
    if (_isOver) return;
    _celebrate('❤️');
  }

  void _resetGame() {
    _stopGameTimers();
    setState(() {
      _happiness = clampMeter(widget.initialHappiness);
      _hunger = clampMeter(widget.initialHunger);
      _gameOver = false;
      _hasWon = false;
      _paused = false;
    });
    _startHungerTimer();
    _updateOutcome();
  }

  // ------------------------------------------------------------------
  // Session controls
  // ------------------------------------------------------------------

  /// Pausing freezes the game: no hunger ticks and no win countdown. Because
  /// the win requires *continuous* happy time, resuming starts a fresh streak.
  void _pause() {
    if (_isOver || _paused) return;
    _stopGameTimers();
    setState(() => _paused = true);
    _celebrate('💤');
  }

  void _resume() {
    if (_isOver || !_paused) return;
    setState(() => _paused = false);
    _startHungerTimer();
    _updateOutcome();
  }

  void _confirmName() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _nameController.text = _petName;
      return;
    }
    setState(() => _petName = name);
    FocusScope.of(context).unfocus();
  }

  // ------------------------------------------------------------------
  // Presentation helpers (all derived from state)
  // ------------------------------------------------------------------

  void _celebrate(String emoji) {
    _bounceTimer?.cancel();
    _reactionTimer?.cancel();
    setState(() {
      _bouncing = true;
      _reaction = emoji;
      _reactionVisible = true;
    });
    // Replacing the timers means an older callback can never end a newer
    // bounce or hide a newer reaction.
    _bounceTimer = Timer(const Duration(milliseconds: 160), () {
      if (mounted) setState(() => _bouncing = false);
    });
    _reactionTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _reactionVisible = false);
    });
  }

  Mood get _mood => moodFor(_happiness);

  Color get _moodColor => switch (_mood) {
    Mood.happy => Colors.green,
    Mood.neutral => Colors.yellow,
    Mood.unhappy => Colors.red,
  };

  String get _moodLabel => switch (_mood) {
    Mood.happy => 'Happy',
    Mood.neutral => 'Neutral',
    Mood.unhappy => 'Unhappy',
  };

  IconData get _moodIcon => switch (_mood) {
    Mood.happy => Icons.sentiment_very_satisfied,
    Mood.neutral => Icons.sentiment_neutral,
    Mood.unhappy => Icons.sentiment_very_dissatisfied,
  };

  double get _petScale => switch (_mood) {
    Mood.happy => 1.06,
    Mood.neutral => 1.0,
    Mood.unhappy => 0.94,
  };

  String get _petMessage {
    if (_gameOver) return 'I need a rest.';
    if (_hasWon) return 'Best day ever!';
    if (_paused) return 'Zzz... taking a nap.';
    if (_hunger > 80) return "I'm starving!";
    if (_happiness <= 30) return 'Play with me?';
    if (_happiness > 80) return 'This is the best!';
    return "Hi, I'm $_petName!";
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('$_petName the Pet'),
        actions: [
          IconButton(
            key: const Key('pauseResume'),
            tooltip: _paused ? 'Resume' : 'Pause',
            icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
            onPressed: _isOver ? null : (_paused ? _resume : _pause),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildNameRow(),
                  const SizedBox(height: 16),
                  _buildSpeechBubble(theme, reduceMotion),
                  const SizedBox(height: 8),
                  _buildPet(reduceMotion),
                  const SizedBox(height: 8),
                  _buildMoodChip(theme),
                  const SizedBox(height: 16),
                  MeterBar(
                    key: const Key('happinessMeter'),
                    label: 'Happiness',
                    value: _happiness,
                    color: _moodColor,
                    reduceMotion: reduceMotion,
                  ),
                  const SizedBox(height: 12),
                  MeterBar(
                    key: const Key('hungerMeter'),
                    label: 'Hunger',
                    value: _hunger,
                    color: _hunger > 80 ? Colors.deepOrange : Colors.blueGrey,
                    reduceMotion: reduceMotion,
                  ),
                  const SizedBox(height: 12),
                  _buildStatusBanner(theme),
                  const SizedBox(height: 16),
                  _buildActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNameRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            key: const Key('nameField'),
            controller: _nameController,
            maxLength: 16,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _confirmName(),
            decoration: const InputDecoration(
              labelText: 'Pet name',
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.tonal(
          key: const Key('confirmName'),
          onPressed: _confirmName,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildSpeechBubble(ThemeData theme, bool reduceMotion) {
    return Center(
      child: AnimatedSwitcher(
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 300),
        child: Container(
          key: ValueKey(_petMessage),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _petMessage,
            style: theme.textTheme.titleMedium,
            semanticsLabel: '$_petName says: $_petMessage',
          ),
        ),
      ),
    );
  }

  Widget _buildPet(bool reduceMotion) {
    final bounce = (_bouncing && !reduceMotion) ? 1.1 : 1.0;
    return SizedBox(
      height: 230,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Semantics(
            label: '$_petName, mood $_moodLabel. Tap to pet.',
            button: true,
            child: GestureDetector(
              key: const Key('pet'),
              onTap: _petThePet,
              child: AnimatedScale(
                scale: _petScale * bounce,
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                child: ColorFiltered(
                  key: const Key('petTint'),
                  colorFilter: ColorFilter.mode(_moodColor, BlendMode.modulate),
                  child: Image.asset(
                    'assets/pet.png',
                    height: 200,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 40,
            child: ExcludeSemantics(
              child: AnimatedSlide(
                offset: (_reactionVisible || reduceMotion)
                    ? Offset.zero
                    : const Offset(0, 0.6),
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 250),
                child: AnimatedOpacity(
                  opacity: _reactionVisible ? 1 : 0,
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 250),
                  child: Text(
                    _reaction ?? '',
                    style: const TextStyle(fontSize: 40),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodChip(ThemeData theme) {
    return Center(
      child: Chip(
        key: const Key('moodChip'),
        avatar: Icon(_moodIcon, color: Colors.black87),
        label: Text('Mood: $_moodLabel'),
        backgroundColor: _moodColor.withValues(alpha: 0.35),
        side: BorderSide(color: _moodColor),
      ),
    );
  }

  Widget _buildStatusBanner(ThemeData theme) {
    final (String text, IconData icon, Color color) = _gameOver
        ? (
            'Game over — $_petName got too hungry and sad.',
            Icons.heart_broken,
            Colors.red,
          )
        : _hasWon
        ? (
            'You win! $_petName stayed happy for 3 minutes.',
            Icons.emoji_events,
            Colors.green,
          )
        : _paused
        ? ('Paused — timers are stopped.', Icons.pause_circle, Colors.blueGrey)
        : _highMoodTimer != null
        ? (
            'Happy streak running — keep happiness above 80!',
            Icons.timer,
            Colors.teal,
          )
        : (
            'Keep happiness above 80 for 3 minutes to win.',
            Icons.info_outline,
            Colors.grey,
          );
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('statusBanner'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: const Key('feedButton'),
                icon: const Icon(Icons.restaurant),
                label: const Text('Feed'),
                onPressed: _canAct ? _feedPet : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                key: const Key('playButton'),
                icon: const Icon(Icons.sports_baseball),
                label: const Text('Play'),
                onPressed: _canAct ? _playWithPet : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const Key('resetButton'),
          icon: const Icon(Icons.restart_alt),
          label: Text(_isOver ? 'Play again' : 'Reset'),
          onPressed: _resetGame,
        ),
      ],
    );
  }
}
