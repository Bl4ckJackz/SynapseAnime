// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import '../widgets/netflix_app_bar.dart';
import '../widgets/content_row.dart';
import '../widgets/hero_banner.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const NetflixAppBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                children: [
                  // Hero banner with featured anime
                  const HeroBanner(),

                  const SizedBox(height: 20),

                  // Continue watching row
                  const ContentRow(
                    title: 'Continue Watching',
                    contentType: ContentType.continueWatching,
                  ),

                  const SizedBox(height: 20),

                  // Trending now
                  const ContentRow(
                    title: 'Trending Now',
                    contentType: ContentType.trending,
                  ),

                  const SizedBox(height: 20),

                  // Top picks for you
                  const ContentRow(
                    title: 'Top Picks For You',
                    contentType: ContentType.topPicks,
                  ),

                  const SizedBox(height: 20),

                  // New releases
                  const ContentRow(
                    title: 'New Releases',
                    contentType: ContentType.newReleases,
                  ),

                  const SizedBox(height: 20),

                  // Anime by genre
                  const ContentRow(
                    title: 'Action',
                    contentType: ContentType.genre,
                    genre: 'action',
                  ),

                  const SizedBox(height: 20),

                  const ContentRow(
                    title: 'Comedy',
                    contentType: ContentType.genre,
                    genre: 'comedy',
                  ),

                  const SizedBox(height: 20),

                  const ContentRow(
                    title: 'Drama',
                    contentType: ContentType.genre,
                    genre: 'drama',
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
