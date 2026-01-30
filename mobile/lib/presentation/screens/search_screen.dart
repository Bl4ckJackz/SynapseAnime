import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../domain/providers/anime_provider.dart';
import '../../domain/providers/manga_provider.dart';
import '../widgets/anime_card.dart';
import '../widgets/manga_card.dart';

enum MediaType { anime, manga }

enum SearchSource { jikan, mangaDex }

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  String _query = '';
  MediaType _selectedType = MediaType.anime;
  SearchSource _selectedSource = SearchSource.jikan;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.length >= 2) {
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        setState(() {
          _query = query;
        });
      });
    } else if (query.isEmpty) {
      setState(() {
        _query = '';
      });
    }
  }

  void _onTypeChanged(MediaType type) {
    setState(() {
      _selectedType = type;
      // Reset source to default for the type
      if (type == MediaType.anime) {
        _selectedSource = SearchSource.jikan;
      } else {
        _selectedSource = SearchSource.jikan;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Cerca...',
            border: InputBorder.none,
            suffixIcon: Icon(Icons.search),
          ),
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
          onSubmitted: (value) {
            _onSearchChanged(value);
          },
        ),
      ),
      body: Column(
        children: [
          _buildFilters(),
          const Divider(),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          // Media Type Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTypeChip('Anime', MediaType.anime),
              const SizedBox(width: 12),
              _buildTypeChip('Manga', MediaType.manga),
            ],
          ),
          const SizedBox(height: 12),
          // Source Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (_selectedType == MediaType.anime) ...[
                  _buildSourceChip('MyAnimeList (Dati)', SearchSource.jikan),
                ] else ...[
                  _buildSourceChip('MyAnimeList (Dati)', SearchSource.jikan),
                  const SizedBox(width: 8),
                  _buildSourceChip('MangaDex (Lettura)', SearchSource.mangaDex),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String label, MediaType type) {
    final isSelected = _selectedType == type;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) _onTypeChanged(type);
      },
      selectedColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildSourceChip(String label, SearchSource source) {
    final isSelected = _selectedSource == source;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedSource = source;
          });
        }
      },
      checkmarkColor: Colors.white,
      selectedColor: AppTheme.primaryColor.withOpacity(0.8),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
        fontSize: 12,
      ),
    );
  }

  Widget _buildResults() {
    if (_query.length < 2) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Digita almeno 2 caratteri',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_selectedType == MediaType.anime) {
      return _JikanAnimeResults(query: _query);
    } else {
      if (_selectedSource == SearchSource.mangaDex) {
        return _MangaDexResults(query: _query);
      }
      return _JikanMangaResults(query: _query);
    }
  }
}

class _JikanAnimeResults extends ConsumerWidget {
  final String query;
  const _JikanAnimeResults({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = AnimeFilter(type: FilterType.search, search: query);
    final asyncValue = ref.watch(animeListProvider(filter));

    return asyncValue.when(
      data: (animes) => _buildGrid(animes, (anime) => AnimeCard(anime: anime)),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Errore: $e')),
    );
  }
}

class _JikanMangaResults extends ConsumerWidget {
  final String query;
  const _JikanMangaResults({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncValue = ref.watch(mangaSearchProvider(query));

    return asyncValue.when(
      data: (mangaList) =>
          _buildGrid(mangaList, (manga) => MangaCard(manga: manga)),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Errore: $e')),
    );
  }
}

class _MangaDexResults extends ConsumerWidget {
  final String query;
  const _MangaDexResults({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncValue = ref.watch(mangaDexSearchProvider(query));

    return asyncValue.when(
      data: (mangaList) {
        if (mangaList.isEmpty)
          return const Center(child: Text('Nessun risultato su MangaDex'));
        return _buildGrid(mangaList, (manga) => MangaCard(manga: manga));
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Errore: $e')),
    );
  }
}

Widget _buildGrid<T>(List<T> items, Widget Function(T) builder) {
  if (items.isEmpty) {
    return const Center(child: Text('Nessun risultato'));
  }
  return GridView.builder(
    padding: const EdgeInsets.all(16),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.7,
    ),
    itemCount: items.length,
    itemBuilder: (context, index) => builder(items[index]),
  );
}
