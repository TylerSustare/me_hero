import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import 'hero_creation_screen.dart';
import 'hero_details_screen.dart';

class HeroesListPage extends ConsumerWidget {
  const HeroesListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heroesAsyncValue = ref.watch(heroesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Heroes'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: heroesAsyncValue.when(
        data: (heroes) {
          if (heroes.isEmpty) {
            return const Center(
              child: Text(
                'No heroes yet.\nTap the + button to create one!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(heroesProvider.future),
            child: ListView.builder(
              itemCount: heroes.length,
              itemBuilder: (context, index) {
                final hero = heroes[index];
                return ListTile(
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(hero.spriteSheetPath),
                        fit: BoxFit.cover,
                        alignment: Alignment.centerLeft, // Show the first frame
                        filterQuality: FilterQuality.none, // Keep it pixelated in the thumbnail!
                      ),
                    ),
                  ),
                  title: Text(
                    hero.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Created: ${hero.createdAt.toLocal().toString().split('.')[0]}'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HeroDetailsScreen(hero: hero),
                      ),
                    );
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      ref.read(heroesProvider.notifier).deleteHero(hero.id);
                    },
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HeroCreationScreen()),
          );
        },
        tooltip: 'Create Hero',
        child: const Icon(Icons.add),
      ),
    );
  }
}
