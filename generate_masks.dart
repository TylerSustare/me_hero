import 'package:image/image.dart' as img;
import 'dart:io';

void main() async {
  final maskDir = Directory('assets/masks');
  if (!await maskDir.exists()) {
    await maskDir.create(recursive: true);
  }

  // Draw exactly on a 64x64 native retro grid to guarantee blocky pixel aesthetics
  final silhouetteColor = img.ColorRgba8(255, 255, 255, 180);

  // --- IDLE 1 (Neutral Side Profile) ---
  img.Image tiny1 = img.Image(width: 64, height: 64, numChannels: 4);
  img.fill(tiny1, color: img.ColorRgba8(0, 0, 0, 0));

  // Head (blocky 7x7 square roughly)
  img.fillRect(tiny1, x1: 28, y1: 10, x2: 36, y2: 18, color: silhouetteColor);
  // Nose extending right
  img.fillRect(tiny1, x1: 36, y1: 12, x2: 38, y2: 15, color: silhouetteColor);

  // Torso
  img.fillRect(tiny1, x1: 27, y1: 19, x2: 34, y2: 38, color: silhouetteColor);

  // Arm (straight down)
  img.fillRect(tiny1, x1: 30, y1: 21, x2: 33, y2: 36, color: silhouetteColor);

  // Legs  
  img.fillRect(tiny1, x1: 27, y1: 38, x2: 30, y2: 56, color: silhouetteColor); // Left leg
  img.fillRect(tiny1, x1: 32, y1: 38, x2: 35, y2: 56, color: silhouetteColor); // Right leg

  // Scale up exactly 10x using Nearest Neighbor to preserve the stark blocky edges
  img.Image scaled1 = img.copyResize(tiny1, width: 640, height: 640, interpolation: img.Interpolation.nearest);
  await File('assets/masks/idle1_mask.png').writeAsBytes(img.encodePng(scaled1));


  // --- IDLE 2 (Chest Puffed Side Profile) ---
  img.Image tiny2 = img.Image(width: 64, height: 64, numChannels: 4);
  img.fill(tiny2, color: img.ColorRgba8(0, 0, 0, 0));

  // Head
  img.fillRect(tiny2, x1: 28, y1: 10, x2: 36, y2: 18, color: silhouetteColor);
  img.fillRect(tiny2, x1: 36, y1: 12, x2: 38, y2: 15, color: silhouetteColor);

  // Torso (Puffed forward to the right)
  img.fillRect(tiny2, x1: 26, y1: 19, x2: 36, y2: 38, color: silhouetteColor);

  // Arm (pulled slightly back from the chest)
  img.fillRect(tiny2, x1: 28, y1: 21, x2: 31, y2: 36, color: silhouetteColor);

  // Legs (staggered slightly more from breathing)
  img.fillRect(tiny2, x1: 26, y1: 38, x2: 29, y2: 56, color: silhouetteColor);
  img.fillRect(tiny2, x1: 33, y1: 38, x2: 36, y2: 56, color: silhouetteColor);

  img.Image scaled2 = img.copyResize(tiny2, width: 640, height: 640, interpolation: img.Interpolation.nearest);
  await File('assets/masks/idle2_mask.png').writeAsBytes(img.encodePng(scaled2));
}
