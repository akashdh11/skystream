import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/providers/device_info_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/image_fallbacks.dart';
import '../../../../core/utils/layout_constants.dart';
import '../../../../core/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/multimedia_card.dart';
import '../library_provider.dart';

import '../library_state.dart';
import '../../../../shared/widgets/loading_indicator.dart';

/// Hands the D-pad highlight back to the cell a viewer opened, when they come
/// back to a lazily built collection — a grid, or a rail.
///
/// A route's focus scope remembers its own focused child, but that restoration
/// stops working the moment the collection rebuilds its cells while the viewer
/// is away: a bookmark toggled on the details page leaves the list one item
/// shorter, `SliverChildBuilderDelegate` sees a different [ValueKey] at that
/// index, the tile element is torn down and its [FocusNode] disposed, and the
/// next D-pad press starts from the top-left card.
///
/// The node lives here, owned by the collection's [State], so it outlives any
/// number of tile rebuilds. A per-tile node is disposed by the very rebuild it
/// would have to survive, and calling `requestFocus` on it afterwards throws.
/// One node, not one per cell: only one cell is ever the return target, and a
/// map keyed by item would have to be pruned on every list change.
///
/// Usage:
/// ```dart
/// late final _focusReturn = GridFocusReturn(onTargetChanged: () => setState(() {}));
/// // ... in the item builder:
/// Card(focusNode: _focusReturn.nodeFor(item.id), onTap: () => _open(item));
/// // ... after the push future completes, on a focus-driven device only:
/// _focusReturn.restoreTo(item.id);
/// ```
/// The cell must forward the node to whatever draws its focus ring
/// (`CardsWrapper` via `MultimediaCard.focusNode` here) and must not dispose
/// it: the node belongs to this object, which disposes it with the collection.
///
/// Nothing here is specific to bookmarks. Lift it into `lib/shared/widgets/`
/// as soon as a second collection needs it.
class GridFocusReturn {
  GridFocusReturn({required VoidCallback onTargetChanged, String? debugLabel})
    : _onTargetChanged = onTargetChanged,
      _node = FocusNode(debugLabel: debugLabel ?? 'GridFocusReturn');

  /// Rebuilds the collection so the target cell picks the node up. Normally
  /// `() => setState(() {})`.
  final VoidCallback _onTargetChanged;

  final FocusNode _node;

  /// Identity of the cell the highlight is owed to — an item id, a URL, any
  /// value that is stable across a rebuild. Never an index: an index is the
  /// one thing that moves when the list changes.
  Object? _target;

  bool _disposed = false;

  /// The node the cell identified by [id] should install, or null for every
  /// other cell.
  FocusNode? nodeFor(Object id) => _target == id ? _node : null;

  /// Aims at [id] and puts the highlight back on it after the next frame.
  ///
  /// Call it when the pushed route has been popped. A safe no-op when the cell
  /// is not there — scrolled out of the build, removed from the list, or
  /// disposed — all of which leave [FocusNode.context] null or unmounted.
  ///
  /// The null check is not decoration. `FocusNode.requestFocus` on a node with
  /// no parent does not fail loudly; it sets an internal
  /// `_requestFocusWhenReparented` flag and steals the highlight the instant
  /// that cell is built again, which on a grid is when the viewer scrolls past
  /// it long after they stopped caring.
  void restoreTo(Object id) {
    if (_disposed) return;
    _target = id;
    _onTargetChanged();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      final BuildContext? cell = _node.context;
      if (cell == null || !cell.mounted) return;
      if (!_node.canRequestFocus) return;
      _node.requestFocus();
    });
  }

  /// Call from the collection's `dispose`. The [_disposed] latch matters as
  /// much as the disposal: the viewer can leave the whole screen while a
  /// details page is open, and the pending post-frame callback would otherwise
  /// touch a dead node.
  void dispose() {
    _disposed = true;
    _node.dispose();
  }
}

class BookmarksTab extends ConsumerStatefulWidget {
  const BookmarksTab({super.key});

  @override
  ConsumerState<BookmarksTab> createState() => _BookmarksTabState();
}

class _BookmarksTabState extends ConsumerState<BookmarksTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final GridFocusReturn _focusReturn = GridFocusReturn(
    onTargetChanged: () {
      if (mounted) setState(() {});
    },
    debugLabel: 'bookmarks grid focus return',
  );

  @override
  void dispose() {
    _focusReturn.dispose();
    super.dispose();
  }

  /// Whether this device draws a focus highlight worth putting back.
  ///
  /// The mobile operating systems, minus the leanback boxes and Apple TVs that
  /// run them without a touchscreen. `DeviceProfile.isTv` is the single
  /// authority for "this is a television"; window shape never reaches this
  /// decision, so a phone in landscape is still a phone.
  ///
  /// On a touchscreen nothing was visibly focused when the viewer tapped the
  /// poster, so restoring a ring would paint one they never asked for and give
  /// the next hardware key press a different starting point.
  bool get _restoresFocus {
    final platform = Theme.of(context).platform;
    final profile = ref.read(deviceProfileProvider).asData?.value;
    final isTouchDevice =
        (platform == TargetPlatform.android ||
            platform == TargetPlatform.iOS) &&
        profile?.isTv != true;
    return !isTouchDevice;
  }

  /// Opens a bookmark and, on the way back, puts the highlight where the
  /// viewer left it.
  ///
  /// The await is the mechanism: `push` completes when the details page is
  /// popped, which is the moment the viewer is looking at this grid again.
  Future<void> _openDetails(MultimediaItem item) async {
    await DetailsRoute($extra: DetailsRouteExtra(item: item))
        .push<void>(context);
    if (!mounted) return;
    if (!_restoresFocus) return;
    _focusReturn.restoreTo(item.url);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final libraryState = ref.watch(libraryProvider);
    final isLarge = context.isTabletOrLarger;
    final double totalHeight = isLarge ? 180.0 : 150.0;

    return switch (libraryState) {
      LibraryLoading() => const Center(child: AppLoadingIndicator()),
      LibraryError(message: final msg) => Center(child: Text(msg)),
      LibraryEmpty() => _buildEmpty(context),
      LibrarySuccess(items: final items) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(
          LayoutConstants.spacingMd,
          LayoutConstants.spacingMd,
          LayoutConstants.spacingMd,
          0,
        ).copyWith(
          bottom: LayoutConstants.shellBottomContentPadding(context),
        ),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: totalHeight,
          childAspectRatio: 2 / 3.4,
          crossAxisSpacing: LayoutConstants.spacingMd,
          mainAxisSpacing: LayoutConstants.spacingMd,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return MultimediaCard(
            key: ValueKey(item.url),
            // Keyed by URL, not by index: the index is what moves when a
            // bookmark is added or removed while the viewer is away.
            focusNode: _focusReturn.nodeFor(item.url),
            imageUrl:
                AppImageFallbacks.poster(item.posterUrl, label: item.title) ??
                '',
            title: item.title,
            heroTag: 'lib_bookmark_${item.url}_$index',
            onTap: () => _openDetails(item),
          );
        },
      ),
    };
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_outline_rounded,
            size: 64,
            color: Theme.of(context).dividerColor,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.libraryEmpty,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
