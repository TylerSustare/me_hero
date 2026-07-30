import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/hero_character.dart';

enum AnimationState { idle, run, jump }

class HeroDetailsScreen extends StatefulWidget {
  final HeroCharacter hero;

  const HeroDetailsScreen({super.key, required this.hero});

  @override
  State<HeroDetailsScreen> createState() => _HeroDetailsScreenState();
}

class _HeroDetailsScreenState extends State<HeroDetailsScreen> {
  int _currentFrame = 0;
  Timer? _animationTimer;
  static const double _spriteSize = 64.0;
  AnimationState _currentState = AnimationState.idle;
  int _frameIndex = 0;

  List<int> get _activeFrames {
    switch (_currentState) {
      case AnimationState.idle:
        return [0, 1];
      case AnimationState.run:
        return [2, 3];
      case AnimationState.jump:
        return [4];
    }
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _animationTimer?.cancel();
    int interval = _currentState == AnimationState.run ? 250 : 500;
    _animationTimer = Timer.periodic(Duration(milliseconds: interval), (timer) {
      if (mounted) {
        setState(() {
          _frameIndex = (_frameIndex + 1) % _activeFrames.length;
          _currentFrame = _activeFrames[_frameIndex];
        });
      }
    });
  }

  void _setAnimationState(AnimationState state) {
    if (_currentState == state) return;
    setState(() {
      _currentState = state;
      _frameIndex = 0;
      _currentFrame = _activeFrames.first;
    });
    _startTimer();
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900], // Dark background for retro feel
      appBar: AppBar(
        title: Text(widget.hero.name),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          const contentPadding = 24.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(contentPadding),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(
                  0,
                  constraints.maxHeight - (contentPadding * 2),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "${_currentState.name.toUpperCase()} ANIMATION",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Loop player
                  Container(
                    width: 256,
                    height: 256,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      border: Border.all(
                        color: Colors.deepPurpleAccent,
                        width: 4,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.deepPurpleAccent,
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 256,
                        height: 256,
                        child: FittedBox(
                          fit: BoxFit.fill,
                          child: SizedBox(
                            width: _spriteSize,
                            height: _spriteSize,
                            child: Stack(
                              children: [
                                Positioned(
                                  // Shift the sprite sheet left based on current frame to show only 64x64 at a time
                                  left: -(_currentFrame * _spriteSize),
                                  top: 0,
                                  child: Image.file(
                                    File(widget.hero.spriteSheetPath),
                                    filterQuality: FilterQuality.medium,
                                    width:
                                        _spriteSize *
                                        5, // We now support up to 5 frames
                                    height: _spriteSize,
                                    fit: BoxFit.fill,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // State selectors
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStateButton(AnimationState.idle, "Idle"),
                      const SizedBox(width: 10),
                      _buildStateButton(AnimationState.run, "Run"),
                      const SizedBox(width: 10),
                      _buildStateButton(AnimationState.jump, "Jump"),
                    ],
                  ),

                  const SizedBox(height: 60),

                  const Text(
                    "Raw Spritesheet",
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  const SizedBox(height: 10),

                  // Whole sprite sheet
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.black54,
                    child: Image.file(
                      File(widget.hero.spriteSheetPath),
                      filterQuality: FilterQuality.medium,
                      width: 320, // Scaled for 5 frames (64 * 5)
                      height: 64,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStateButton(AnimationState state, String label) {
    final isActive = _currentState == state;
    return ElevatedButton(
      onPressed: () => _setAnimationState(state),
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? Colors.deepPurpleAccent : Colors.grey[800],
        foregroundColor: Colors.white,
      ),
      child: Text(label),
    );
  }
}
