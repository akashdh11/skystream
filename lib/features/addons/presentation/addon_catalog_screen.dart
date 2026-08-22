import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/addons/data/addon_client.dart';
import '../../../core/addons/data/addon_repository.dart';
import '../../../core/addons/data/builtin_addons.dart';
import '../../../core/addons/models/addon_manifest.dart';
import '../../../core/addons/models/addon_meta.dart';
import 'addons_screen.dart' show AddonPosterCard;

/// Full, paginated view of one add-on catalog.
///
/// Stremio catalogs page with an integer `skip` extra (100 per page by
/// convention) and can expose a `genre` filter, so both are wired here. Pages
/// load lazily as the grid scrolls, which also keeps the decoded-poster cache
/// bounded.
class AddonCatalogScreen extends ConsumerStatefulWidget {
  final String addonUrl;
  final String type;
  final String catalogId;
  final String title;

  const AddonCatalogScreen({
    super.key,
    required this.addonUrl,
    required this.type,
    required this.catalogId,
    required this.title,
  });

  @override
  ConsumerState<AddonCatalogScreen> createState() => _AddonCatalogScreenState();
}

class _AddonCatalogScreenState extends ConsumerState<AddonCatalogScreen> {
  static const int _pageSize = 100;

  final ScrollController _scrollController = ScrollController();
  final List<AddonMetaPreview> _items = [];

  bool _loading = false;
  bool _exhausted = false;
  String? _error;
  String? _genre;
  int _skip = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_loadMore()));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loading || _exhausted) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 600) {
      unawaited(_loadMore());
    }
  }

  ManagedAddon? get _addon {
    for (final addon in ref.read(addonRepositoryProvider).addons) {
      if (addon.manifestUrl == widget.addonUrl) return addon;
    }
    // Rows can come from the built-in Cinemeta fallback.
    if (widget.addonUrl == BuiltInAddons.cinemetaUrl) {
      return BuiltInAddons.cinemeta;
    }
    return null;
  }

  AddonCatalog? get _catalog {
    final manifest = _addon?.manifest;
    if (manifest == null) return null;
    for (final catalog in manifest.catalogs) {
      if (catalog.id == widget.catalogId && catalog.type == widget.type) {
        return catalog;
      }
    }
    return null;
  }

  Future<void> _loadMore() async {
    final addon = _addon;
    if (addon == null) {
      setState(() => _error = 'That add-on is no longer installed.');
      return;
    }
    if (_loading || _exhausted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final extra = <String, String>{
        if (_skip > 0) 'skip': '$_skip',
        'genre': ?_genre,
      };
      final page = await ref
          .read(addonClientProvider)
          .catalog(
            addon,
            type: widget.type,
            id: widget.catalogId,
            extra: extra.isEmpty ? null : extra,
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      setState(() {
        final seen = _items.map((e) => e.id).toSet();
        for (final item in page) {
          if (seen.add(item.id)) _items.add(item);
        }
        _skip += _pageSize;
        _exhausted = page.length < _pageSize;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _exhausted = true;
        _error = error.toString();
      });
    }
  }

  Future<void> _applyGenre(String? genre) async {
    setState(() {
      _genre = genre;
      _items.clear();
      _skip = 0;
      _exhausted = false;
    });
    await _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final genres = _catalog?.genres ?? const <String>[];

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          if (genres.isNotEmpty)
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 6),
                    child: ChoiceChip(
                      label: const Text('All'),
                      selected: _genre == null,
                      onSelected: (_) => unawaited(_applyGenre(null)),
                    ),
                  ),
                  for (final genre in genres)
                    Padding(
                      padding: const EdgeInsets.only(right: 8, top: 6),
                      child: ChoiceChip(
                        label: Text(genre),
                        selected: _genre == genre,
                        onSelected: (_) => unawaited(_applyGenre(genre)),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: _items.isEmpty && _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error ?? 'This catalog returned nothing.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  )
                : GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 140,
                          childAspectRatio: 0.55,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: _items.length + (_loading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _items.length) {
                        return const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }
                      return AddonPosterCard(
                        item: _items[index],
                        addonUrl: widget.addonUrl,
                        width: double.infinity,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
