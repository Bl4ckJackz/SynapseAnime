import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';

class ShareAnimeSheet extends ConsumerWidget {
  final String animeTitle;
  final String animeId;
  final String imageUrl;
  final String description;

  const ShareAnimeSheet({
    super.key,
    required this.animeTitle,
    required this.animeId,
    required this.imageUrl,
    required this.description,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shareText =
        'Guarda questo anime: $animeTitle\n\n$description\n\nhttps://anime-player.app/anime/$animeId';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Condividi $animeTitle',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),

          // Share options
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _ShareOption(
                icon: Icons.share,
                label: 'Tutti',
                onTap: () async {
                  await Share.share(shareText,
                      subject: 'Condividi questo anime');
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              _ShareOption(
                icon: Icons.sms,
                label: 'Messaggio',
                onTap: () async {
                  await Share.share(shareText, subject: 'Guarda questo anime!');
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              _ShareOption(
                icon: Icons.mail,
                label: 'Email',
                onTap: () async {
                  final Uri emailLaunchUri = Uri(
                    scheme: 'mailto',
                    path: '',
                    queryParameters: {
                      'subject': 'Guarda questo anime: $animeTitle',
                      'body': shareText,
                    },
                  );
                  if (await canLaunchUrl(emailLaunchUri)) {
                    await launchUrl(emailLaunchUri);
                  } else {
                    await Share.share(shareText,
                        subject: 'Guarda questo anime: $animeTitle');
                  }
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              _ShareOption(
                icon: Icons.copy,
                label: 'Copia Link',
                onTap: () async {
                  await Clipboard.setData(ClipboardData(
                      text: 'https://anime-player.app/anime/$animeId'));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Link copiato negli appunti')),
                    );
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Close button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.textMuted),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Chiudi'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ShareOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              child: Icon(
                icon,
                color: AppTheme.primaryColor,
                size: 24,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// Helper function to show the share sheet
Future<void> showShareAnimeSheet(
  BuildContext context, {
  required String animeTitle,
  required String animeId,
  required String imageUrl,
  required String description,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ShareAnimeSheet(
      animeTitle: animeTitle,
      animeId: animeId,
      imageUrl: imageUrl,
      description: description,
    ),
  );
}
