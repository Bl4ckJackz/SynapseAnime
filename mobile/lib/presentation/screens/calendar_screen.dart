import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../domain/entities/anime.dart';
import '../../features/anime/data/repositories/anime_repository.dart';
import '../widgets/anime_card.dart';

// Provider for schedule data per day
final scheduleProvider =
    FutureProvider.family<List<Anime>, String>((ref, day) async {
  final repository = ref.read(animeRepositoryProvider);
  return repository.getSchedule(day);
});

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _days = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  final Map<String, String> _dayLabels = {
    'monday': 'Lun',
    'tuesday': 'Mar',
    'wednesday': 'Mer',
    'thursday': 'Gio',
    'friday': 'Ven',
    'saturday': 'Sab',
    'sunday': 'Dom',
  };

  @override
  void initState() {
    super.initState();
    // Start on today's day
    final today = DateTime.now().weekday - 1; // 0 = Monday
    _tabController = TabController(
      length: _days.length,
      vsync: this,
      initialIndex: today.clamp(0, 6),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        title: const Text(
          'Calendario Anime',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: _days.map((day) => Tab(text: _dayLabels[day])).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _days.map((day) => _DayScheduleView(day: day)).toList(),
      ),
    );
  }
}

class _DayScheduleView extends ConsumerWidget {
  final String day;

  const _DayScheduleView({required this.day});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(scheduleProvider(day));

    return scheduleAsync.when(
      data: (animeList) {
        if (animeList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today,
                    size: 64, color: Colors.grey.shade600),
                const SizedBox(height: 16),
                Text(
                  'Nessun anime in programma',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.55,
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
          ),
          itemCount: animeList.length,
          itemBuilder: (context, index) {
            final anime = animeList[index];
            return AnimeCard(
              anime: anime,
              width: double.infinity,
              height: 140,
              showTitle: true,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Errore: $err',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(scheduleProvider(day)),
              child: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }
}
