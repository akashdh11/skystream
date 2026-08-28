import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final isDark = theme.brightness == Brightness.dark;

      return AlertDialog(
        surfaceTintColor: Colors.transparent,
        title: const Text('Explore Source'),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: SizedBox(
          width: 480,
          child: RadioGroup<ExploreModeType>(
            groupValue: currentMode,
            onChanged: (mode) {
              if (mode != null) {
                ref.read(exploreModeProvider.notifier).setMode(mode);
                Navigator.pop(dialogContext);
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
                  autofocus: currentMode == ExploreModeType.movies,
                  onTap: () {
                    ref
                        .read(exploreModeProvider.notifier)
                        .setMode(ExploreModeType.movies);
                    Navigator.pop(dialogContext);
                  },
                ),
                _ModeOptionTile(
                  value: ExploreModeType.anime,
                  customIcon: SizedBox(
                    width: 22,
                    height: 22,
                    child: CustomPaint(
                      painter: AnimeLogoPainter(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  title: 'Anime',
                  subtitle: 'Browse anime catalogs via AniList',
                  isSelected: currentMode == ExploreModeType.anime,
                  autofocus: currentMode == ExploreModeType.anime,
                  onTap: () {
                    ref
                        .read(exploreModeProvider.notifier)
                        .setMode(ExploreModeType.anime);
                    Navigator.pop(dialogContext);
                  },
                ),
                _ModeOptionTile(
                  value: ExploreModeType.stremio,
                  icon: Icons.dashboard_customize_outlined,
                  title: 'Stremio Add-ons',
                  subtitle:
                      'Explore catalogs from your installed Stremio add-ons',
                  isSelected: currentMode == ExploreModeType.stremio,
                  autofocus: currentMode == ExploreModeType.stremio,
                  onTap: () {
                    ref
                        .read(exploreModeProvider.notifier)
                        .setMode(ExploreModeType.stremio);
                    Navigator.pop(dialogContext);
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          CustomButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

class _ModeOptionTile extends StatefulWidget {
  final ExploreModeType value;
  final IconData? icon;
  final Widget? customIcon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final bool autofocus;
  final VoidCallback onTap;

  const _ModeOptionTile({
    required this.value,
    this.icon,
    this.customIcon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    this.autofocus = false,
    required this.onTap,
  });

  @override
  State<_ModeOptionTile> createState() => _ModeOptionTileState();
}

class _ModeOptionTileState extends State<_ModeOptionTile> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final active = widget.isSelected || _isFocused;

    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: _isFocused
              ? cs.primary.withValues(alpha: 0.15)
              : (widget.isSelected
                  ? cs.primary.withValues(alpha: 0.08)
                  : Colors.transparent),
          border: Border.all(
            color: _isFocused
                ? cs.primary
                : (widget.isSelected
                    ? cs.primary.withValues(alpha: 0.4)
                    : Colors.transparent),
            width: _isFocused ? 2 : 1,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active
                          ? cs.primary.withValues(alpha: 0.18)
                          : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: widget.customIcon ??
                        Icon(
                          widget.icon,
                          size: 22,
                          color: active ? cs.primary : cs.onSurface,
                        ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight:
                                active ? FontWeight.bold : FontWeight.w600,
                            color: active ? cs.primary : cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ExcludeFocus(
                    child: Radio<ExploreModeType>(
                      value: widget.value,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
