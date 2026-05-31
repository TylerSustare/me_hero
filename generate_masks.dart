import 'package:image/image.dart' as img;
import 'dart:io';

void main() async {
  final maskDir = Directory('assets/masks');
  if (!await maskDir.exists()) {
    await maskDir.create(recursive: true);
  }

  // Use a stick figure color with some opacity (transparent black)
  final color = img.ColorRgba8(0, 0, 0, 180);
  final int t = 16; // thickness

  // Helper to draw limbs more cleanly
  void drawLimb(img.Image canvas, int x1, int y1, int x2, int y2) {
    img.drawLine(canvas, x1: x1, y1: y1, x2: x2, y2: y2, color: color, thickness: t, antialias: true);
  }

  // --- IDLE (Straight standing profile, used for both idle steps) ---
  img.Image idle = img.Image(width: 640, height: 640, numChannels: 4);
  img.fill(idle, color: img.ColorRgba8(0, 0, 0, 0));
  img.fillCircle(idle, x: 320, y: 160, radius: 50, color: color, antialias: true); // Head
  drawLimb(idle, 320, 220, 320, 560); // Torso + Legs straight down
  drawLimb(idle, 320, 560, 360, 560); // Foot pointing forward
  await File('assets/masks/idle_mask.png').writeAsBytes(img.encodePng(idle));

  // --- RUN (Legs apart, arms swinging like uploaded image) ---
  img.Image run1 = img.Image(width: 640, height: 640, numChannels: 4);
  img.fill(run1, color: img.ColorRgba8(0, 0, 0, 0));
  img.fillCircle(run1, x: 320, y: 160, radius: 50, color: color, antialias: true); // Head
  drawLimb(run1, 320, 210, 320, 380); // Torso straight down
  
  drawLimb(run1, 320, 240, 240, 240); // Back Arm top (straight back horizontally)
  drawLimb(run1, 240, 240, 220, 340); // Back Arm bottom (straight down)
  
  drawLimb(run1, 320, 240, 400, 300); // Front Arm top (forward and down)
  drawLimb(run1, 400, 300, 480, 240); // Front Arm bottom (forward and up)
  
  drawLimb(run1, 320, 380, 260, 480); // Back Leg top (back and down)
  drawLimb(run1, 260, 480, 140, 460); // Back Leg bottom (straight back horizontally)
  
  drawLimb(run1, 320, 380, 420, 440); // Front Leg top (forward and down)
  drawLimb(run1, 420, 440, 460, 580); // Front Leg bottom (down and slightly forward)
  await File('assets/masks/run_mask.png').writeAsBytes(img.encodePng(run1));

  // --- JUMP (Matched to uploaded image) ---
  img.Image jump = img.Image(width: 640, height: 640, numChannels: 4);
  img.fill(jump, color: img.ColorRgba8(0, 0, 0, 0));
  img.fillCircle(jump, x: 340, y: 160, radius: 50, color: color, antialias: true); // Head
  drawLimb(jump, 340, 210, 300, 380); // Torso slightly angled
  
  drawLimb(jump, 340, 210, 260, 250); // Back Arm top (back and down)
  drawLimb(jump, 260, 250, 230, 330); // Back Arm bottom (down and slightly back)
  
  drawLimb(jump, 340, 210, 390, 150); // Front Arm top (forward and up)
  drawLimb(jump, 390, 150, 430, 90); // Front Arm bottom (forward and up)
  
  drawLimb(jump, 300, 380, 250, 460); // Back Leg top (back and down)
  drawLimb(jump, 250, 460, 190, 530); // Back Leg bottom (back and down)
  
  drawLimb(jump, 300, 380, 420, 380); // Front Leg top (horizontal forward)
  drawLimb(jump, 420, 380, 380, 480); // Front Leg bottom (down and slightly back)
  await File('assets/masks/jump_mask.png').writeAsBytes(img.encodePng(jump));
}
