import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/responsive_breakpoints.dart';

import '../../../../shared/widgets/multimedia_card.dart';
import '../../../../shared/widgets/shimmer_placeholder.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/utils/image_utils.dart';
import 'controllers/view_all_controller.dart';

enum ViewAllCategory {
  popularMovies,
  popularTV,
  nowPlayingMovies,
  onTheAirTV,
  topRatedMovies,
  topRatedTV,
  airingTodayTV,
  trending,
  trendingTV,

  /// Provider-sourced content from the home screen.
  /// No TMDB pagination — shows only the initial list.
  providerContent,
}

class ViewAllScreen extends ConsumerStatefulWidget {
  final String title;
  final List<MultimediaItem> initialMediaList;
  final ViewAllCategory category;

  /// Custom tap handler for items (used by provider content to go to
  /// DetailsRoute instead of TmdbDetailsRoute).
  final void Function(MultimediaItem item)? onTap;

  const ViewAllScreen({
    super.key,
    required this.title,
    required this.initialMediaList,
    required this.category,
    this.onTap,
  });

  @override
  ConsumerState<ViewAllScreen> createState() => _ViewAllScreenState();
}

class _ViewAllScreenState extends ConsumerState<ViewAllScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isPortrait = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (widget.initialMediaList.isNotEmpty) {
      _checkAspectRatio();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(viewAllControllerProvider(widget.category).notifier)
          .init(widget.initialMediaList);
      _checkInitialFill();
    });
  }

  Future<void> _checkAspectRatio() async {
    if (widget.initialMediaList.isEmpty) return;
    final url = widget.initialMediaList.first.posterImageUrl;
    if (url.isEmpty) return;
    final isPortrait = await ImageUtils.isImagePortrait(url);
    if (mounted && _isPortrait != isPortrait) {
      setState(() {
        _isPortrait = isPortrait;
      });
    }
  }

  void _checkInitialFill() {
    if (!context.mounted) return;
    if (_scrollController.hasClients &&
        _scrollController.position.maxScrollExtent <= 0) {
      final state = ref.read(viewAllControllerProvider(widget.category));
      if (state.hasMore && !state.isLoading) {
        ref
            .read(viewAllControllerProvider(widget.category).notifier)
            .fetchNextPage()
            .then((_) {
              if (context.mounted) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _checkInitialFill(),
                );
              }
            });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref
          .read(viewAllControllerProvider(widget.category).notifier)
          .fetchNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ViewAllState state = ref.watch(
      viewAllControllerProvider(widget.category),
    );

    // Calculate aspect ratio dynamically
    final isDesktop = context.isDesktop;
    final maxExtent = isDesktop
        ? (_isPortrait ? 240.0 : 340.0)
        : (_isPortrait ? 150.0 : 220.0);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final crossAxisCount = (screenWidth / maxExtent).ceil();
    final childAspectRatio = _isPortrait ? 0.55 : 1.35;

    ref.listen(viewAllControllerProvider(widget.category), (previous, next) {
      if (next.items.isEmpty && !next.isLoading && next.page == 1) {
        _checkInitialFill();
      }
    });

    final scaffold = Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.8),
              Theme.of(context).scaffoldBackgroundColor,
            ],
            stops: const [0.0, 0.3],
          ),
        ),
        child: GridView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: maxExtent,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount:
              state.items.length + (state.isLoading ? crossAxisCount : 0),
          itemBuilder: (context, index) {
            if (index >= state.items.length) {
              return ShimmerPlaceholder(borderRadius: 12);
            }

            final item = state.items[index];
            final imageUrl = item.posterImageUrl;
            final itemTitle = item.title;
            final uniqueTag =
                'view_all_${widget.category.name}_${item.id}_$index';

            return MultimediaCard(
              imageUrl: imageUrl,
              title: itemTitle,
              heroTag: uniqueTag,
              isPortrait: _isPortrait,
              onTap: () {
                if (widget.onTap != null) {
                  widget.onTap!(item);
                } else {
                  TmdbDetailsRoute(
                    movieId: item.id,
                    mediaType: item.tmdbMediaType,
                    heroTag: uniqueTag,
                    placeholderPoster: imageUrl,
                    source: item.source,
                  ).push<void>(context);
                }
              },
            );
          },
        ),
      ),
    );

    return scaffold;
  }
}
