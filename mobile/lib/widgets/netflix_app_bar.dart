// lib/widgets/netflix_app_bar.dart
import 'package:flutter/material.dart';

class NetflixAppBar extends StatelessWidget implements PreferredSizeWidget {
  const NetflixAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(56.0);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56.0,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xCC000000), // Semi-transparent black at top
            Color(0x00000000), // Fully transparent at bottom
          ],
        ),
      ),
      child: Row(
        children: [
          // Logo
          Image.asset(
            'assets/images/logo.png', // Placeholder for logo
            height: 32,
            width: 120,
            fit: BoxFit.contain,
          ),
          const Spacer(),

          // Navigation icons
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              // Navigate to search screen
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {
              // Navigate to notifications
            },
          ),
          Container(
            margin: const EdgeInsets.only(left: 8.0),
            child: const CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage(
                'https://example.com/user-avatar.jpg', // Placeholder for user avatar
              ),
              child: Icon(
                Icons.person,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
