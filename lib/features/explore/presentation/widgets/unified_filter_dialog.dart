import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/layout_constants.dart';
import '../../data/explore_filter_provider.dart';
import '../../data/explore_language_provider.dart';
import '../../data/explore_tmdb_provider.dart';
import '../../data/explore_mode_provider.dart';
import '../../../../shared/widgets/loading_indicator.dart';

class UnifiedFilterDialog extends ConsumerStatefulWidget {
  const UnifiedFilterDialog({super.key});

  @override
  ConsumerState<UnifiedFilterDialog> createState() =>
      _UnifiedFilterDialogState();
}

class _UnifiedFilterDialogState extends ConsumerState<UnifiedFilterDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAnime = ref.watch(exploreModeProvider) == ExploreModeType.anime;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 650, maxWidth: 500),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor.withValues(
              alpha: 0.9,
            ), // Glassmorphism base
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: 0.2,
                ), // Shadow always black
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header & Tabs
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.tune,
                              color: Theme.of(context).colorScheme.primary,
                              size: 28,
                            ),
                            const SizedBox(width: LayoutConstants.spacingSm),
                            Text(
                              "Filters",
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: Icon(
                                Icons.close,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              splashRadius: 24,
                            ),
                          ],
                        ),
                      ),
                      TabBar(
                        controller: _tabController,
                        indicatorColor: Theme.of(context).colorScheme.primary,
                        labelColor: Theme.of(context).colorScheme.primary,
                        unselectedLabelColor: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        tabs: [
                          if (isAnime)
                            const Tab(
                              text: "Title Lang",
                              icon: Icon(Icons.title, size: 20),
                            )
                          else
                            const Tab(
                              text: "Lang",
                              icon: Icon(Icons.translate, size: 20),
                            ),

                          // Genre Tab
                          Consumer(
                            builder: (c, ref, _) {
                              final hasFilter =
                                  ref
                                      .watch(exploreFilterProvider)
                                      .selectedGenre !=
                                  null;
                              return Tab(
                                text: "Genre",
                                icon: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    const Icon(
                                      Icons.category_outlined,
                                      size: 20,
                                    ),
                                    if (hasFilter)
                                      Positioned(
                                        right: -2,
                                        top: -2,
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Colors.redAccent,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),

                          // Year Tab
                          Consumer(
                            builder: (c, ref, _) {
                              final hasFilter =
                                  ref
                                      .watch(exploreFilterProvider)
                                      .selectedYear !=
                                  null;
                              return Tab(
                                text: "Year",
                                icon: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    const Icon(Icons.calendar_today, size: 20),
                                    if (hasFilter)
                                      Positioned(
                                        right: -2,
                                        top: -2,
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Colors.redAccent,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),

                          // Rating Tab
                          Consumer(
                            builder: (c, ref, _) {
                              final hasFilter =
                                  ref.watch(exploreFilterProvider).minRating !=
                                  null;
                              return Tab(
                                text: "Rating",
                                icon: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    const Icon(Icons.star_outline, size: 20),
                                    if (hasFilter)
                                      Positioned(
                                        right: -2,
                                        top: -2,
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Colors.redAccent,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tab View Content
                Flexible(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      if (isAnime)
                        const _TitleLanguageTab()
                      else
                        const _LanguageTab(),
                      const _GenreTab(),
                      const _YearTab(),
                      const _RatingTab(),
                    ],
                  ),
                ),

                // Footer
                Padding(
                  padding: const EdgeInsets.all(LayoutConstants.spacingMd),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: LayoutConstants.spacingMd,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Done",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ... _LanguageTab, _GenreTab, _YearTab ...

class _RatingTab extends ConsumerWidget {
  const _RatingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRating = ref.watch(exploreFilterProvider).minRating;

    final ratings = [null, 5.0, 6.0, 7.0, 8.0, 9.0];

    return ListView.builder(
      padding: const EdgeInsets.all(LayoutConstants.spacingMd),
      itemCount: ratings.length,
      itemBuilder: (context, index) {
        final rating = ratings[index];
        final isSelected = rating == selectedRating;

        final label = rating == null ? "Any Rating" : "$rating+ Stars";
        final subtitle = rating == null
            ? "Show all movies"
            : "Movies with $rating or higher (TMDB/User)";

        return ListTile(
          onTap: () {
            ref.read(exploreFilterProvider.notifier).setRating(rating);
          },
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          tileColor: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
              : null,
          focusColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.5),
          leading: Icon(
            Icons.star,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : (rating == null
                      ? Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.3)
                      : Colors.amber),
          ),
          title: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          trailing: isSelected
              ? Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                )
              : null,
        );
      },
    );
  }
}

class _LanguageTab extends ConsumerWidget {
  const _LanguageTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languages = ref.watch(languageListProvider);
    final currentLang = ref.watch(languageProvider);

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: languages.length,
      itemBuilder: (context, index) {
        final lang = languages[index];
        final isSelected = lang.code == currentLang;

        return InkWell(
          onTap: () {
            ref.read(languageProvider.notifier).setLanguage(lang.code);
          },
          borderRadius: BorderRadius.circular(16),
          focusColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.6),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: LayoutConstants.spacingMd,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).dividerColor.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.1),
                  ),
                  child: Text(
                    lang.code.split('-')[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: LayoutConstants.spacingSm),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        lang.nativeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.7)
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GenreTab extends ConsumerWidget {
  const _GenreTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final genresAsync = ref.watch(genresProvider);
    final selectedGenre = ref.watch(exploreFilterProvider).selectedGenre;

    return genresAsync.when(
      data: (genres) => ListView.builder(
        padding: const EdgeInsets.all(LayoutConstants.spacingMd),
        itemCount: genres.length + 1, // +1 for "All Genres"
        itemBuilder: (context, index) {
          if (index == 0) {
            // "All" Item
            final isSelected = selectedGenre == null;
            return ListTile(
              onTap: () {
                ref.read(exploreFilterProvider.notifier).setGenre(null);
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              tileColor: isSelected
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                  : null,
              leading: Icon(
                Icons.category, // Distinct icon for All
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white24,
              ),
              title: Text(
                "All Genres",
                style: TextStyle(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          }

          final genre = genres[index - 1]; // Offset index
          final isSelected =
              selectedGenre != null && selectedGenre.id == genre.id;
          return ListTile(
            onTap: () {
              ref.read(exploreFilterProvider.notifier).setGenre(genre);
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            tileColor: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                : null,
            focusColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.5),
            leading: Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            title: Text(
              genre.name,
              style: TextStyle(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (_, _) => const Center(
        child: Text(
          "Failed to load genres",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

class _YearTab extends ConsumerWidget {
  const _YearTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedYear = ref.watch(exploreFilterProvider).selectedYear;
    final currentYear = DateTime.now().year;
    final years = List.generate(50, (index) => currentYear - index);

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.0,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: years.length + 1, // +1 for "All"
      itemBuilder: (context, index) {
        if (index == 0) {
          // "All" Item
          final isSelected = selectedYear == null;
          return InkWell(
            onTap: () {
              ref.read(exploreFilterProvider.notifier).setYear(null);
            },
            borderRadius: BorderRadius.circular(8),
            focusColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.6),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.2)
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                ),
              ),
              child: Text(
                "All",
                style: TextStyle(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 16,
                ),
              ),
            ),
          );
        }

        final year = years[index - 1]; // Offset
        final isSelected = year == selectedYear;

        return InkWell(
          onTap: () {
            ref.read(exploreFilterProvider.notifier).setYear(year);
          },
          borderRadius: BorderRadius.circular(8),
          focusColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.4),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
              ),
            ),
            child: Text(
              year.toString(),
              style: TextStyle(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 16,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TitleLanguageTab extends ConsumerWidget {
  const _TitleLanguageTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(animeTitleLanguageProvider);
    final titleLangs = [
      {'code': 'english', 'name': 'English Title', 'native': 'English'},
      {'code': 'japanese', 'name': 'Japanese Title', 'native': '日本語 (Native)'},
      {'code': 'romaji', 'name': 'Romaji Title', 'native': 'Rōmaji'},
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: titleLangs.length,
      itemBuilder: (context, index) {
        final lang = titleLangs[index];
        final isSelected = lang['code'] == currentLang;

        return InkWell(
          onTap: () {
            ref
                .read(animeTitleLanguageProvider.notifier)
                .setLanguage(lang['code']!);
          },
          borderRadius: BorderRadius.circular(16),
          focusColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.6),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: LayoutConstants.spacingMd,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).dividerColor.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.1),
                  ),
                  child: Text(
                    lang['code']!.substring(0, 2).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: LayoutConstants.spacingSm),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang['name']!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        lang['native']!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.7)
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
