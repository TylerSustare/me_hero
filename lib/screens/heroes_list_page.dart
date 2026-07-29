import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import 'hero_creation_screen.dart';
import 'hero_details_screen.dart';

class HeroesListPage extends ConsumerStatefulWidget {
  const HeroesListPage({super.key});

  @override
  ConsumerState<HeroesListPage> createState() => _HeroesListPageState();
}

class _HeroesListPageState extends ConsumerState<HeroesListPage> {
  bool _isCreatingDemoHero = false;

  Future<void> _createDemoHero() async {
    if (_isCreatingDemoHero) return;
    setState(() => _isCreatingDemoHero = true);

    try {
      final demoHero = await ref.read(demoHeroServiceProvider).createDemoHero();
      await ref.read(heroesProvider.notifier).addHero(demoHero);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nova is ready for gameplay.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create the demo hero: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isCreatingDemoHero = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final heroesAsyncValue = ref.watch(heroesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Heroes'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (kDebugMode)
            IconButton(
              key: const Key('create-demo-hero-button'),
              onPressed: _isCreatingDemoHero ? null : _createDemoHero,
              tooltip: 'Create Demo Hero',
              icon: _isCreatingDemoHero
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.science_outlined),
            ),
        ],
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
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                  title: Text(
                    hero.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Created: ${hero.createdAt.toLocal().toString().split('.')[0]}',
                  ),
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
