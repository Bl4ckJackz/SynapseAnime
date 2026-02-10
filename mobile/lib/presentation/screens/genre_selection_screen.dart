import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../domain/providers/user_profile_provider.dart';

class GenreSelectionScreen extends ConsumerStatefulWidget {
  const GenreSelectionScreen({super.key});

  @override
  ConsumerState<GenreSelectionScreen> createState() =>
      _GenreSelectionScreenState();
}

class _GenreSelectionScreenState extends ConsumerState<GenreSelectionScreen> {
  // Common Anime/Manga Genres
  final List<String> _availableGenres = [
    'Action',
    'Adventure',
    'Comedy',
    'Drama',
    'Fantasy',
    'Horror',
    'Mecha',
    'Mystery',
    'Psychological',
    'Romance',
    'Sci-Fi',
    'Slice of Life',
    'Sports',
    'Supernatural',
    'Thriller',
    'Isekai',
    'Magic',
    'School',
    'Harem',
    'Ecchi',
  ];

  final Set<String> _selectedGenres = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize selected genres from user profile
    final userState = ref.read(userProfileProvider);
    userState.whenData((user) {
      if (user.preference?.preferredGenres != null) {
        _selectedGenres.addAll(user.preference!.preferredGenres);
      }
    });
  }

  Future<void> _savePreferences() async {
    setState(() => _isLoading = true);
    try {
      print('Saving preferences: ${_selectedGenres.toList()}');
      await ref.read(userProfileProvider.notifier).updatePreferences(
            preferredGenres: _selectedGenres.toList(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferenze salvate con successo!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore nel salvataggio: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generi Preferiti'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _savePreferences,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Seleziona i generi che ti piacciono 👇',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Il nostro AI userà queste informazioni per consigliarti anime e manga su misura.',
              style: TextStyle(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _availableGenres.map((genre) {
                final isSelected = _selectedGenres.contains(genre);
                return FilterChip(
                  label: Text(genre),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedGenres.add(genre);
                      } else {
                        _selectedGenres.remove(genre);
                      }
                    });
                  },
                  selectedColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                  checkmarkColor: AppTheme.primaryColor,
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.primaryColor : null,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  tooltip: "Seleziona $genre", // Accessibility
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
