import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/layout_constants.dart';
import '../../../core/utils/responsive_breakpoints.dart';
import '../../../core/providers/device_info_provider.dart';
import 'search_provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'widgets/search_result_section.dart';
import 'widgets/search_header_bar.dart';
import 'widgets/bouncy_entry_animation.dart';
import '../../../shared/widgets/loading_indicator.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final FocusNode _clearButtonFocusNode = FocusNode();
  final FocusNode _moviesShowsFocusNode = FocusNode();
  final FocusNode _liveTvFocusNode = FocusNode();
  final FocusNode _firstSuggestionFocusNode = FocusNode();
  final FocusNode _firstResultFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Restore any previously committed query into the text field.
    _controller.text = ref.read(searchQueryProvider);
    _controller.addListener(_onTextChanged);

    _focusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          if (_controller.text.isNotEmpty &&
              _controller.selection.extentOffset == _controller.text.length) {
            _clearButtonFocusNode.requestFocus();
            return KeyEventResult.handled;
          }
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          final filter = ref.read(searchFilterProvider);
          if (filter == SearchFilter.live) {
            _liveTvFocusNode.requestFocus();
          } else {
            _moviesShowsFocusNode.requestFocus();
          }
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };

    _clearButtonFocusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _focusNode.requestFocus();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          final filter = ref.read(searchFilterProvider);
          if (filter == SearchFilter.live) {
            _liveTvFocusNode.requestFocus();
          } else {
            _moviesShowsFocusNode.requestFocus();
          }
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };

    _moviesShowsFocusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _focusNode.requestFocus();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _liveTvFocusNode.requestFocus();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          final suggestionState = ref.read(searchSuggestionControllerProvider);
          final typedLongEnough = suggestionState.query.trim().length >= 2;
          final hasSuggestionContent =
              suggestionState.isLoading ||
              suggestionState.suggestions.isNotEmpty;

          if (typedLongEnough && hasSuggestionContent) {
            _firstSuggestionFocusNode.requestFocus();
            return KeyEventResult.handled;
          } else {
            final resultsState = ref.read(searchResultsProvider).asData?.value;
            final hasResults =
                resultsState != null &&
                resultsState.results.any((r) => r.results.isNotEmpty);
            if (hasResults) {
              _firstResultFocusNode.requestFocus();
              return KeyEventResult.handled;
            }
          }
        }
      }
      return KeyEventResult.ignored;
    };

    _liveTvFocusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _focusNode.requestFocus();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _moviesShowsFocusNode.requestFocus();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          final suggestionState = ref.read(searchSuggestionControllerProvider);
          final typedLongEnough = suggestionState.query.trim().length >= 2;
          final hasSuggestionContent =
              suggestionState.isLoading ||
              suggestionState.suggestions.isNotEmpty;

          if (typedLongEnough && hasSuggestionContent) {
            _firstSuggestionFocusNode.requestFocus();
            return KeyEventResult.handled;
          } else {
            final resultsState = ref.read(searchResultsProvider).asData?.value;
            final hasResults =
                resultsState != null &&
                resultsState.results.any((r) => r.results.isNotEmpty);
            if (hasResults) {
              _firstResultFocusNode.requestFocus();
              return KeyEventResult.handled;
            }
          }
        }
      }
      return KeyEventResult.ignored;
    };

    _firstResultFocusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.arrowUp) {
        final filter = ref.read(searchFilterProvider);
        if (filter == SearchFilter.live) {
          _liveTvFocusNode.requestFocus();
        } else {
          _moviesShowsFocusNode.requestFocus();
        }
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _clearButtonFocusNode.dispose();
    _moviesShowsFocusNode.dispose();
    _liveTvFocusNode.dispose();
    _firstSuggestionFocusNode.dispose();
    _firstResultFocusNode.dispose();
    super.dispose();
  }

  void _submitSearch(String val) {
    final trimmed = val.trim();
    _controller.value = TextEditingValue(
      text: trimmed,
      selection: TextSelection.collapsed(offset: trimmed.length),
    );
    ref.read(searchSuggestionControllerProvider.notifier).clear();
    ref.read(searchQueryProvider.notifier).set(trimmed);
    // Dismiss keyboard after submitting, just like YouTube / browser.
    _focusNode.unfocus();
  }

  void _fillSuggestion(String suggestion) {
    _controller.value = TextEditingValue(
      text: suggestion,
      selection: TextSelection.collapsed(offset: suggestion.length),
    );
    ref
        .read(searchSuggestionControllerProvider.notifier)
        .onQueryChanged(suggestion);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(deviceProfileProvider).asData?.value;
    final isTv = profile?.isTv == true || context.isTv;
    final isWidescreen = isTv || context.isTabletOrLarger;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (isWidescreen) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Stack(
          children: [
            // Cinematic Background Image - Local Asset (Dark Mode only)
            if (isDark)
              Positioned.fill(
                child: Image.asset(
                  'assets/images/search_background.jpg',
                  fit: BoxFit.cover,
                  // 2000x1125 = 8.6 MB decoded for a backdrop. 1280 is ~3.5 MB
                  // and BoxFit.cover scales from there.
                  cacheWidth: 1280,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            // Rich Architectural Stage Overlay (Vignette + Dark overlay - Dark Mode only)
            if (isDark)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(
                      alpha: 0.7,
                    ), // Rich dark overlay
                  ),
                ),
              ),
            // Radial Vignette Overlay centered on search area (Dark Mode only)
            if (isDark)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.1,
                      colors: [
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.85),
                        Colors.black.withValues(alpha: 0.98),
                      ],
                      stops: const [0.0, 0.65, 1.0],
                    ),
                  ),
                ),
              ),
            // Left-to-right fade to blend backdrop image with the sidebar / background (Dark Mode only)
            if (isDark)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 320, // Wide fanning width to ease the transition
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          theme.scaffoldBackgroundColor,
                          theme.scaffoldBackgroundColor.withValues(alpha: 0.85),
                          theme.scaffoldBackgroundColor.withValues(alpha: 0.50),
                          theme.scaffoldBackgroundColor.withValues(alpha: 0.18),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.25, 0.55, 0.8, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            // Top-to-bottom edge vignette to mask out top/bottom image boundaries/black letterboxing (Dark Mode only)
            if (isDark)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          theme.scaffoldBackgroundColor,
                          theme.scaffoldBackgroundColor.withValues(alpha: 0.8),
                          Colors.transparent,
                          Colors.transparent,
                          theme.scaffoldBackgroundColor.withValues(alpha: 0.8),
                          theme.scaffoldBackgroundColor,
                        ],
                        stops: const [0.0, 0.08, 0.2, 0.8, 0.92, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            // Focus Spotlight (Stage Lighting - Soft fanning semi-circle)
            Positioned(
              top:
                  76, // Anchored immediately below the search bar (24 top padding + 52 height)
              left: 0,
              right: 0,
              height: 250,
              child: ListenableBuilder(
                listenable: _focusNode,
                builder: (context, child) {
                  if (!_focusNode.hasFocus) return const SizedBox.shrink();
                  final spotlightColor = isDark
                      ? const Color(0xFF1E40AF)
                      : theme.colorScheme.primary;
                  return IgnorePointer(
                    child: Center(
                      child: Container(
                        width: 900, // Broader fanning footprint
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment
                                .topCenter, // Fanning downward from the bottom edge of the search bar
                            radius: 1.3,
                            colors: [
                              spotlightColor.withValues(
                                alpha: isDark ? 0.35 : 0.22,
                              ), // Soft center source point
                              spotlightColor.withValues(
                                alpha: isDark ? 0.18 : 0.10,
                              ), // Smooth bleed
                              spotlightColor.withValues(
                                alpha: isDark ? 0.06 : 0.03,
                              ), // Gentle falloff
                              spotlightColor.withValues(
                                alpha: 0.0,
                              ), // Fade to transparent
                            ],
                            stops: const [0.0, 0.35, 0.70, 1.0],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Content layout in Column: Still header and Body directly below it
            Positioned.fill(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  SearchHeaderBar(
                    textController: _controller,
                    searchFocusNode: _focusNode,
                    clearButtonFocusNode: _clearButtonFocusNode,
                    moviesShowsFocusNode: _moviesShowsFocusNode,
                    liveTvFocusNode: _liveTvFocusNode,
                    isCompact: false,
                    onSubmitted: _submitSearch,
                    onChanged: (val) {
                      ref
                          .read(searchSuggestionControllerProvider.notifier)
                          .onQueryChanged(val);
                    },
                  ),
                  Expanded(
                    child: Padding(
                      // Fixed top padding below the top search bar (24px)
                      padding: const EdgeInsets.only(top: 24.0),
                      child: _buildBody(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Mobile layout: existing AppBar
    return _buildMobileLayout(context);
  }

  Widget _buildMobileLayout(BuildContext context) {
    final searchResultsAsync = ref.watch(searchResultsProvider);
    final filter = ref.watch(searchFilterProvider);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isLive = filter == SearchFilter.live;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: PopupMenuButton<SearchFilter>(
              tooltip: 'Search scope',
              onSelected: (value) {
                ref.read(searchFilterProvider.notifier).set(value);
                // Sync current text to search query instantly on scope switch
                final text = _controller.text.trim();
                ref.read(searchQueryProvider.notifier).set(text);
              },
              offset: const Offset(0, 48),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: SearchFilter.content,
                  child: Row(
                    children: [
                      const Text('🍿', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('Non Livestreams')),
                      if (!isLive)
                        Icon(
                          Icons.check,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: SearchFilter.live,
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: Center(child: WaveformEqualizer(isActive: true)),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('Livestreams')),
                      if (isLive)
                        Icon(
                          Icons.check,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                    ],
                  ),
                ),
              ],
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: isLive
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: Center(child: WaveformEqualizer(isActive: true)),
                      )
                    : const Text('🍿', style: TextStyle(fontSize: 18)),
              ),
            ),
          ),
        ],
        title: GestureDetector(
          onTap: () => _focusNode.requestFocus(),
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            height: 42,
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, child) {
                final isSearching = searchResultsAsync.maybeWhen(
                  data: (state) => state.isLoading,
                  loading: () => true,
                  orElse: () => false,
                );

                Widget? suffix;
                if (isSearching) {
                  suffix = Padding(
                    padding: const EdgeInsets.all(12),
                    child: AppLoadingIndicator(
                      color: theme.colorScheme.primary,
                      constraints: BoxConstraints.tight(const Size(18, 18)),
                    ),
                  );
                } else if (value.text.isNotEmpty) {
                  suffix = IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(32, 32),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      _controller.clear();
                      ref
                          .read(searchSuggestionControllerProvider.notifier)
                          .clear();
                      ref.read(searchQueryProvider.notifier).set('');
                    },
                  );
                }

                return TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: false,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlignVertical: TextAlignVertical.center,
                  textInputAction: TextInputAction.search,
                  onChanged: (val) {
                    ref
                        .read(searchSuggestionControllerProvider.notifier)
                        .onQueryChanged(val);
                  },
                  onSubmitted: _submitSearch,
                  decoration: InputDecoration(
                    hintText: l10n.searchHint,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        LayoutConstants.radiusPill,
                      ),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        LayoutConstants.radiusPill,
                      ),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        LayoutConstants.radiusPill,
                      ),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 42,
                    ),
                    suffixIcon: suffix,
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 42,
                      minHeight: 42,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final searchResultsAsync = ref.watch(searchResultsProvider);
    final suggestionState = ref.watch(searchSuggestionControllerProvider);
    final l10n = AppLocalizations.of(context)!;
    final typedLongEnough = suggestionState.query.trim().length >= 2;
    final hasSuggestionContent =
        suggestionState.isLoading || suggestionState.suggestions.isNotEmpty;
    final showSuggestions = typedLongEnough && hasSuggestionContent;

    return showSuggestions
        ? _buildSuggestionsView(context, suggestionState)
        : searchResultsAsync.when(
            data: (state) {
              final allResults = state.results
                  .expand((e) => e.results)
                  .toList();

              if (allResults.isEmpty && !state.isLoading) {
                return _buildEmptyState(context);
              } else if (allResults.isEmpty && state.isLoading) {
                return const Center(child: AppLoadingIndicator());
              }

              // RepaintBoundary isolates list repaints from the rest of the
              // screen (app bar, background) so each incremental result update
              // only repaints the list — not the entire scaffold.
              return RepaintBoundary(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: state.results.length,
                  itemBuilder: (context, index) {
                    final pResult = state.results[index];
                    return SearchResultSection(
                      key: ValueKey(pResult.providerId),
                      providerName: pResult.providerName,
                      providerId: pResult.providerId,
                      results: pResult.results,
                      firstCardFocusNode: index == 0
                          ? _firstResultFocusNode
                          : null,
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: AppLoadingIndicator()),
            error: (err, stack) =>
                Center(child: Text(l10n.errorPrefix(err.toString()))),
          );
  }

  Widget _buildSuggestionsView(
    BuildContext context,
    SearchSuggestionState suggestionState,
  ) {
    if (suggestionState.isLoading) {
      return const Center(child: AppLoadingIndicator());
    }

    if (suggestionState.suggestions.isEmpty) {
      return Center(
        child: Text(
          'No results found',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: suggestionState.suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = suggestionState.suggestions[index];
        return BouncyEntryAnimation(
          delay: Duration(milliseconds: index * 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: _SuggestionCard(
              suggestion: suggestion,
              focusNode: index == 0 ? _firstSuggestionFocusNode : null,
              isFirst: index == 0,
              onFocusSearch: () {
                final filter = ref.read(searchFilterProvider);
                if (filter == SearchFilter.live) {
                  _liveTvFocusNode.requestFocus();
                } else {
                  _moviesShowsFocusNode.requestFocus();
                }
              },
              onTap: () => _submitSearch(suggestion),
              onFill: () => _fillSuggestion(suggestion),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final query = ref.watch(searchQueryProvider);
    final isInputEmpty = _controller.text.trim().isEmpty;

    if (query.isEmpty || isInputEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.movie_filter_rounded,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
            ),
            const SizedBox(height: LayoutConstants.spacingMd),
            Text(
              l10n.searchFavoriteContent,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.pressSearchOrEnter,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    final nativeFont = Theme.of(context).textTheme.bodyLarge?.fontFamily;
    final profile = ref.watch(deviceProfileProvider).asData?.value;
    final isTv = profile?.isTv == true || context.isTv;
    final isWidescreen = isTv || context.isTabletOrLarger;
    final imageWidth = isWidescreen ? 320.0 : 200.0;

    // No search results found: display No Results Found text and the image grouped vertically
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'No Results Found',
            style: TextStyle(
              fontFamily: nativeFont,
              fontSize: 16.0,
              fontWeight: FontWeight.w400,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Image.asset(
            'assets/images/no_results.png',
            fit: BoxFit.contain,
            width: imageWidth,
            // Source is 1613x1929 — 11.9 MB decoded — for an illustration
            // shown at 320 logical px at most. 640 covers 2x density.
            cacheWidth: 640,
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatefulWidget {
  final String suggestion;
  final VoidCallback onTap;
  final VoidCallback onFill;
  final FocusNode? focusNode;
  final bool isFirst;
  final VoidCallback onFocusSearch;

  const _SuggestionCard({
    required this.suggestion,
    required this.onTap,
    required this.onFill,
    required this.isFirst,
    required this.onFocusSearch,
    this.focusNode,
  });

  @override
  State<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<_SuggestionCard> {
  bool _isBodyHovered = false;
  bool _isButtonHovered = false;

  late final FocusNode _bodyNode;
  late final FocusNode _buttonNode;

  @override
  void initState() {
    super.initState();
    _bodyNode = widget.focusNode ?? FocusNode();
    _bodyNode.addListener(_onFocusChange);
    _buttonNode = FocusNode();
    _buttonNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _bodyNode.dispose();
    } else {
      if (_bodyNode.hasFocus) {
        _bodyNode.unfocus();
      }
      _bodyNode.removeListener(_onFocusChange);
    }
    _buttonNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final nativeFont = theme.textTheme.bodyLarge?.fontFamily;

    final isBodyHighlighted = _isBodyHovered || _bodyNode.hasFocus;
    final isButtonHighlighted = _isButtonHovered || _buttonNode.hasFocus;
    final isAnyHighlighted = isBodyHighlighted || isButtonHighlighted;

    final baseBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : theme.colorScheme.outlineVariant;
    final highlightColor = isDark
        ? const Color(0xFF1F80E0)
        : theme.colorScheme.primary;

    final borderColor = isAnyHighlighted
        ? highlightColor.withValues(alpha: 0.85)
        : baseBorderColor;

    final cardBgColor = isDark
        ? Colors.black.withValues(alpha: 0.65)
        : theme.colorScheme.surfaceContainer;

    final bodyHighlightBg = isDark
        ? const Color(0xFF1F80E0).withValues(alpha: 0.25)
        : theme.colorScheme.primary.withValues(alpha: 0.12);

    final buttonHighlightBg = isDark
        ? const Color(0xFF1F80E0).withValues(alpha: 0.35)
        : theme.colorScheme.primary.withValues(alpha: 0.18);

    final iconColor = isDark
        ? Colors.white70
        : theme.colorScheme.onSurfaceVariant;

    final textColor = isDark ? Colors.white : theme.colorScheme.onSurface;

    final buttonIconColor = isDark
        ? Colors.white54
        : theme.colorScheme.onSurfaceVariant;

    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : theme.colorScheme.outlineVariant;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: cardBgColor, // Theme-aware card background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: isAnyHighlighted
            ? [
                BoxShadow(
                  color: highlightColor.withValues(alpha: 0.2),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Main Body Focus (Search text)
          Expanded(
            child: Focus(
              focusNode: _bodyNode,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
                      widget.isFirst) {
                    widget.onFocusSearch();
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                    _buttonNode.requestFocus();
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.select ||
                      event.logicalKey == LogicalKeyboardKey.enter ||
                      event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                      event.logicalKey == LogicalKeyboardKey.space) {
                    widget.onTap();
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: MouseRegion(
                onEnter: (_) => setState(() => _isBodyHovered = true),
                onExit: (_) => setState(() => _isBodyHovered = false),
                child: GestureDetector(
                  onTap: widget.onTap,
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isBodyHighlighted
                          ? bodyHighlightBg
                          : Colors.transparent,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(11),
                        bottomLeft: Radius.circular(11),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: isBodyHighlighted ? highlightColor : iconColor,
                          size: 20,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            widget.suggestion,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: nativeFont,
                              color: textColor,
                              fontSize: 16.0,
                              fontWeight: isBodyHighlighted
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Vertical divider line between text block and arrow button
          Container(width: 1.0, height: 24.0, color: dividerColor),
          // Fill Button Focus (Arrow icon button)
          Focus(
            focusNode: _buttonNode,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
                    widget.isFirst) {
                  widget.onFocusSearch();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  _bodyNode.requestFocus();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.select ||
                    event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                    event.logicalKey == LogicalKeyboardKey.space) {
                  widget.onFill();
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: MouseRegion(
              onEnter: (_) => setState(() => _isButtonHovered = true),
              onExit: (_) => setState(() => _isButtonHovered = false),
              child: GestureDetector(
                onTap: widget.onFill,
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isButtonHighlighted
                        ? buttonHighlightBg
                        : Colors.transparent,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(11),
                      bottomRight: Radius.circular(11),
                    ),
                  ),
                  child: Icon(
                    Icons.north_west_rounded,
                    color: isButtonHighlighted
                        ? highlightColor
                        : buttonIconColor,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
