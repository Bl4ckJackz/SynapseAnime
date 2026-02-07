import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/repositories/user_repository.dart';
import '../widgets/app_loader.dart';
import '../widgets/app_navigation_drawer.dart';
import '../../domain/providers/watchlist_provider.dart';

// Provider moved to domain/providers/watchlist_provider.dart

class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final watchlistAsync = ref.watch(watchlistProvider);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Watchlist'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Anime'),
            Tab(text: 'Manga'),
          ],
        ),
      ),
      endDrawer: const AppNavigationDrawer(),
      body: watchlistAsync.when(
        data: (items) {
          final animeItems = items.where((item) => item.anime != null).toList();
          final mangaItems = items.where((item) => item.manga != null).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildList(animeItems, isAnime: true),
              _buildList(mangaItems, isAnime: false),
            ],
          );
        },
        loading: () => const Center(child: AppLoader()),
        error: (err, stack) => Center(child: Text('Errore: $err')),
      ),
    );
  }

  Widget _buildList(List<WatchlistItem> items, {required bool isAnime}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isAnime ? Icons.movie_outlined : Icons.book_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              isAnime
                  ? 'Nessun anime nella watchlist'
                  : 'Nessun manga nella watchlist',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.refresh(watchlistProvider.future),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final title = isAnime ? item.anime?.title : item.manga?.title;
          final image = isAnime ? item.anime?.coverUrl : item.manga?.coverUrl;
          final id = isAnime ? item.anime?.id : item.manga?.id;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: AppTheme.surfaceColor,
            child: ListTile(
              contentPadding: const EdgeInsets.all(8),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: _getProxiedUrl(image),
                  width: 50,
                  height: 75,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(color: Colors.grey),
                ),
              ),
              title: Text(
                title ?? 'Sconosciuto',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Aggiunto il ${_formatDate(item.addedAt)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () {
                  if (id == null) return;
                  if (isAnime) {
                    ref
                        .read(userRepositoryProvider)
                        .removeFromWatchlist(id)
                        .then((_) => ref.refresh(watchlistProvider));
                  } else {
                    ref
                        .read(userRepositoryProvider)
                        .removeMangaFromWatchlist(id)
                        .then((_) => ref.refresh(watchlistProvider));
                  }
                },
              ),
              onTap: () {
                if (id == null) return;
                if (isAnime) {
                  context.push('/anime/$id');
                } else {
                  context.push('/manga/$id');
                }
              },
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getProxiedUrl(String? url) {
    if (url == null || url.isEmpty) {
      return 'https://upload.wikimedia.org/wikipedia/commons/c/ca/1x1.png';
    }
    if (url.contains('animeunity.so') ||
        url.contains('img.animeunity') ||
        url.contains('cdn.noitatnemucod.net') ||
        url.contains('mangaworld.mx')) {
      return '${AppConstants.apiBaseUrl}/stream/proxy-image?url=${Uri.encodeComponent(url)}';
    }
    return url;
  }
}
