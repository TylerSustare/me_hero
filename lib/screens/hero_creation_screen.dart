import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'sprite_capture_screen.dart';

class HeroCreationScreen extends StatefulWidget {
  const HeroCreationScreen({super.key});

  @override
  State<HeroCreationScreen> createState() => _HeroCreationScreenState();
}

class _HeroCreationScreenState extends State<HeroCreationScreen> {
  final _nameController = TextEditingController();

  void _startCaptureFlow() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a hero name')),
      );
      return;
    }

    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      
      // Navigate to the camera capture screen, asking for idle1, idle2, run1, run2, and jump
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SpriteCaptureScreen(
            cameras: cameras,
            heroName: name, // We pass the name so it can be saved at the end of capture
            requiredPoses: const [
              SpritePose.idle1,
              SpritePose.idle2,
              SpritePose.run1,
              SpritePose.run2,
              SpritePose.jump,
            ],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accessing camera: $e')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create New Hero')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_add, size: 80, color: Colors.deepPurpleAccent),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Hero Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _startCaptureFlow,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Ready to Pose?'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
