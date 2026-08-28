import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skystream/features/explore/data/explore_mode_provider.dart';
import 'package:skystream/features/explore/presentation/widgets/hover_border_gradient.dart';
import 'package:skystream/shared/widgets/custom_widgets.dart';

Future<void> showExploreModeSelectorDialog(
  BuildContext context,
  WidgetRef ref,
) {
  final currentMode = ref.read(exploreModeProvider);

  return showDialog<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;

      return AlertDialog(
        title: const Text('Explore Source'),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        content: SizedBox(
          width: 480,
          child: RadioGroup<ExploreModeType>(
            groupValue: currentMode,
            onChanged: (mode) {
              if (mode != null) {
                ref.read(exploreModeProvider.notifier).setMode(mode);
                Navigator.pop(context);
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ModeOptionTile(
                  value: ExploreModeType.movies,
                  icon: Icons.movie_outlined,
                  title: 'Movies & Shows',
                  subtitle: 'Discover movies and series via TMDB',
                  isSelected: currentMode == ExploreModeType.movies,
                  onTap: () {
                    ref
                        .read(exploreModeProvider.notifier)
                        .setMode(ExploreModeType.movies);
                    Navigator.pop(context);
                  },
                ),
                _ModeOptionTile(
                  value: ExploreModeType.anime,
                  customIcon: SizedBox(
                    width: 20,
                    height: 20,
                    child: CustomPaint(
                      painter: AnimeLogoPainter(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  title: 'Anime',
                  subtitle: 'Browse anime catalogs via AniList',
                  isSelected: currentMode == ExploreModeType.anime,
                  onTap: () {
                    ref
                        .read(exploreModeProvider.notifier)
                        .setMode(ExploreModeType.anime);
                    Navigator.pop(context);
                  },
                ),
                _ModeOptionTile(
                  value: ExploreModeType.stremio,
                  icon: Icons.dashboard_customize_outlined,
                  title: 'Stremio Add-ons',
                  subtitle:
                      'Explore catalogs from your installed Stremio add-ons',
                  isSelected: currentMode == ExploreModeType.stremio,
                  onTap: () {
                    ref
                        .read(exploreModeProvider.notifier)
                        .setMode(ExploreModeType.stremio);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          CustomButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

class _ModeOptionTile extends StatelessWidget {
  final ExploreModeType value;
  final IconData? icon;
  final Widget? customIcon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeOptionTile({
    required this.value,
    this.icon,
    this.customIcon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading:
          customIcon ??
          Icon(
            icon,
            color:
                isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
          ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color:
              isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Radio<ExploreModeType>(
        value: value,
      ),
      onTap: onTap,
    );
  }
}
