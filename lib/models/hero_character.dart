class HeroCharacter {
  final String id;
  final String name;
  final String spriteSheetPath;
  final DateTime createdAt;

  HeroCharacter({
    required this.id,
    required this.name,
    required this.spriteSheetPath,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'spriteSheetPath': spriteSheetPath,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory HeroCharacter.fromMap(Map<String, dynamic> map) {
    return HeroCharacter(
      id: map['id'],
      name: map['name'],
      spriteSheetPath: map['spriteSheetPath'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}
