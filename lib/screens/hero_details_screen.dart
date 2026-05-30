import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/hero_character.dart';

class HeroDetailsScreen extends StatefulWidget {
  final HeroCharacter hero;

  const HeroDetailsScreen({super.key, required this.hero});

  @override
  State<HeroDetailsScreen> createState() => _HeroDetailsScreenState();
}

class _HeroDetailsScreenState extends State<HeroDetailsScreen> {
  int _currentFrame = 0;
  Timer? _animationTimer;
  static const int _frameCount = 2; // idle1 and idle2
  static const double _spriteSize = 64.0; 

  @override
  void initState() {
    super.initState();
    // Start a 500ms loop to alternate between the two frames
    _animationTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() {
          _currentFrame = (_currentFrame + 1) % _frameCount;
        });
      }
    });
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Idle Animation",
              style: TextStyle(color: Colors.white70, fontSize: 18, letterSpacing: 2),
            ),
            const SizedBox(height: 20),
            
            // Loop player
            Container(
              width: 256,
              height: 256,
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: Colors.deepPurpleAccent, width: 4),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.deepPurpleAccent, blurRadius: 20, spreadRadius: 2)
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
                               // CRITICAL: FilterQuality.none enforces hard pixel edges when scaling up
                               filterQuality: FilterQuality.none, 
                               width: _spriteSize * _frameCount,
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
                filterQuality: FilterQuality.none,
                width: 128 * 2, // Scale up exactly 2x
                height: 64 * 2,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
