/// The Sources tab.
///
/// What the bottom sheet it replaces showed was `displaySource` in a bare
/// [ListTile] — one unlocalised string per row, no quality, no size, no marker
/// for the source actually playing. Everything added here was already in the
/// app and going unread: [qualityBadgeLabel] had no call sites anywhere,
/// `ResolvedPlayback.qualityFilteredFallback` was computed and never shown, and
/// the probe outcomes the resolving screen displays vanished the moment
/// playback started.
///
/// QUALITY FILTER. Above the list is a strip of one pill per quality tier the
/// list actually contains, and tapping one narrows the list to that tier.
/// Forty sources of which six are 1080p is the ordinary case, and scrolling
/// past thirty-four of them to compare the six is what the strip exists to
/// stop. It is a view over [sources] and never a second copy of it: rows keep
/// their original index, so the tick, the probes, the failure set and
/// [PlayerSourcesTab.onPick] all go on meaning the same thing.
library;

import 'player_anchored_list.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/domain/entity/multimedia_item.dart';
import '../../../../../l10n/generated/app_localizations.dart';
import '../../widgets/hotstar_player_style.dart';
import '../../../domain/source_row_status.dart';
import '../../../domain/stream_resolver.dart';
import 'player_panel_labels.dart';
import 'player_panel_metrics.dart';
import 'player_panel_row.dart';
import '../../../../../shared/focus/app_focus.dart';

/// The filter strip, so a test can tell a pill from the identical badge on the
/// row below it — `1080p` is both, and only the ancestor says which.
const Key kQualityFilterStripKey = Key('player-panel-quality-filter');

/// The tiers a pill can stand for, in the order the strip shows them.
///
/// Fixed rather than derived from the data's own order, which is the resolver's
/// ranking and puts whatever played first at the top. A filter strip that
/// reorders itself between titles is one a viewer has to read every time.
/// `Auto` is not a tier — [SourceFacts.quality] is already null for it — so a
/// source of unknown quality is reachable only with no filter set, which is
/// what the strip opens on.
const List<String> _kTierOrder = <String>[
  '4K',
  '2K',
  '1080p',
  '720p',
  '480p',
  '360p',
];

class PlayerSourcesTab extends StatefulWidget {
  const PlayerSourcesTab({
    required this.sources,
    required this.currentIndex,
    required this.onPick,
    this.probes = const <int, ProbeOutcome>{},
    this.failed = const <int>{},
    this.played = const <int>{},
    this.qualityFilteredFallback = false,
    this.anchorIndex,
    this.autofocus = false,
    super.key,
  });

  final List<StreamResult> sources;

  /// Index into [sources] of the stream the engine is playing. Drives the tick
  /// and the `Now playing` badge, and follows live data.
  final int currentIndex;

  /// Index into [sources] of the row the list opens on and, with [autofocus],
  /// focuses. Defaults to [currentIndex]; the panel passes the value it saw at
  /// open so a failover after that ticks a new row without scrolling the list.
  final int? anchorIndex;

  /// Live health of each candidate, keyed the same way [sources] is indexed.
  final Map<int, ProbeOutcome> probes;

  /// Sources that were played and would not play, keyed the same way.
  final Set<int> failed;

  /// Sources that have shown a picture, keyed the same way. They read
  /// reachable whatever the probe said: the one playing never says "not
  /// checked" under its own picture.
  final Set<int> played;

  /// Whether the quality filter matched nothing and was dropped, which is why
  /// sources below the viewer's preference are in this list.
  final bool qualityFilteredFallback;

  final ValueChanged<int> onPick;

  /// Whether the current source's row should take focus as the panel opens.
  final bool autofocus;

  @override
  State<PlayerSourcesTab> createState() => _PlayerSourcesTabState();
}

class _PlayerSourcesTabState extends State<PlayerSourcesTab> {
  /// The tier the viewer asked for, or null for the whole list. Session state,
  /// deliberately not persisted and deliberately not lifted to the screen: it
  /// is a way of reading this list, not a preference about sources.
  ///
  /// What the list is actually narrowed by is [_activeFilter], never this.
  String? _filter;

  /// The tiers present in [PlayerSourcesTab.sources], in [_kTierOrder].
  ///
  /// Derived from the live list rather than cached, because a failover or a
  /// late plugin result can add a source while the panel is open, and a strip
  /// missing the tier a new row belongs to would hide that row behind a pill
  /// that does not exist.
  List<String> get _tiers {
    final present = <String>{
      for (final source in widget.sources) ?sourceFactsOf(source).quality,
    };
    return <String>[
      for (final tier in _kTierOrder)
        if (present.contains(tier)) tier,
    ];
  }

  /// The filter actually in force: [_filter], but only while the strip still
  /// has a pill that undoes it.
  ///
  /// The data is live. A failover, a re-resolve or a plugin answering late can
  /// take away the last source of the tier the viewer picked, and then the
  /// pill that cleared the filter is gone while the filter itself is not: an
  /// empty list, a strip that no longer mentions the tier hiding it, and on a
  /// remote nothing left to press. So a filter no tier backs is no filter.
  /// Answered here rather than by writing [_filter] back, because this is
  /// reached from `build` — where a setState is a rebuild inside a build —
  /// and because the viewer's choice should come back if the tier does.
  String? get _activeFilter {
    final filter = _filter;
    if (filter == null) return null;
    return _tiers.contains(filter) ? filter : null;
  }

  /// Indices into [PlayerSourcesTab.sources] of the rows the filter lets
  /// through, in the list's own order.
  ///
  /// Indices, not sources: every other input this tab takes — the tick, the
  /// probe map, the failure and played sets, and the callback that changes
  /// stream — is keyed by position in the unfiltered list, and remapping five
  /// of them is five chances to get one wrong.
  List<int> get _visible {
    final filter = _activeFilter;
    return <int>[
      for (var i = 0; i < widget.sources.length; i++)
        if (filter == null ||
            sourceFactsOf(widget.sources[i]).quality == filter)
          i,
    ];
  }

  void _toggle(String tier) =>
      setState(() => _filter = _filter == tier ? null : tier);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (widget.sources.isEmpty) {
      return PanelEmpty(text: l10n.playerNoStreamsFound);
    }

    final tiers = _tiers;
    // One tier is not a choice, and a strip with a single pill in it reads as
    // a filter already applied.
    final showStrip = tiers.length > 1;
    final filter = _activeFilter;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (showStrip)
          _QualityStrip(tiers: tiers, selected: filter, onTap: _toggle),
        Expanded(
          // A new filter is a new list: [PanelAnchoredList] decides its anchor
          // once, at open, so without a fresh element the narrowed list would
          // scroll to whatever position the old anchor happened to be at.
          child: KeyedSubtree(
            key: ValueKey<String?>(filter),
            child: _list(l10n),
          ),
        ),
      ],
    );
  }

  Widget _list(AppLocalizations l10n) {
    final visible = _visible;
    if (visible.isEmpty) return PanelEmpty(text: l10n.playerNoStreamsFound);
    final metrics = PlayerPanelMetrics.of(context);

    // Where the list opens and focus lands. The row playing now, or the first
    // one when nothing is playing yet - which is the failed stage, and the one
    // place a remote most needs somewhere to land. Sought in the visible rows,
    // since a filter can have hidden the row it names.
    final wanted = widget.anchorIndex ?? widget.currentIndex;
    final wantedPosition = visible.indexOf(wanted);
    final anchor = wantedPosition >= 0 ? wantedPosition : 0;
    // The banner only explains the list the resolver handed over, so it is
    // withheld once the viewer has narrowed that list themselves.
    final showBanner = widget.qualityFilteredFallback && _activeFilter == null;
    // The anchor as the builder counts, which is one on from the row's own
    // position whenever the banner is riding at the top of the list. One
    // value, so the list's opening scroll and the row that autofocuses can
    // never name different rows.
    final anchorPosition = showBanner ? anchor + 1 : anchor;

    return PanelAnchoredList(
      anchorIndex: anchorPosition,
      // Every row carries a reachability chip - "Not checked" where the probe
      // never looked - so a torrent row's badges run to a second line.
      estimatedRowExtent: 98,
      autofocus: widget.autofocus,
      itemCount: visible.length + (showBanner ? 1 : 0),
      itemBuilder: (context, position) {
        // The banner rides in the list rather than above it so it scrolls away
        // with the rows it is describing.
        if (showBanner && position == 0) {
          return _FallbackBanner(text: l10n.playerQualityFilterDropped);
        }
        final index = visible[showBanner ? position - 1 : position];
        final stream = widget.sources[index];
        final facts = sourceFactsOf(stream);
        final selected = index == widget.currentIndex;
        final reachability = sourceReachabilityOf(
          stream,
          widget.probes[index],
          hasPlayed: widget.played.contains(index),
        );
        // Only a failure is worth a second chip here. The row being played
        // already wears `Now playing`, and one being opened is the same row -
        // the startup view is where "Opening" is said.
        final hasFailed = widget.failed.contains(index);

        return PanelRow(
          label: facts.title,
          detail: sourceProvider(stream),
          badges: <String>[
            ?facts.quality,
            ?facts.size,
            if (facts.seeders != null) l10n.playerSeeders(facts.seeders!),
          ],
          neutralBadges: true,
          selected: selected,
          selectedLabel: l10n.playerNowPlaying,
          selectedLabelIcon: Icons.play_arrow_rounded,
          status: sourceReachabilityLabel(l10n, reachability),
          statusIcon: _reachabilityIcon(reachability),
          statusColor: _reachabilityColor(reachability),
          outcome: hasFailed ? l10n.playerSourceUnplayable : null,
          outcomeIcon: Icons.error_outline_rounded,
          outcomeColor: const Color(0xFFCF9292),
          autofocus: widget.autofocus && position == anchorPosition,
          // PanelRow adds 10 dp after a custom leading. Another 10 here
          // matches the 20 dp from the panel edge to the icon (8 + 10 + 2).
          leading: Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Icon(
              selected ? Icons.check_rounded : Icons.dns_outlined,
              size: metrics.iconSize,
              color: selected
                  ? HotstarPlayerStyle.accent
                  : metrics.secondaryText,
            ),
          ),
          onTap: () => widget.onPick(index),
        );
      },
    );
  }

  static IconData _reachabilityIcon(SourceReachability status) =>
      switch (status) {
        SourceReachability.reachable => Icons.check_circle_outline_rounded,
        SourceReachability.checking => Icons.sync_rounded,
        SourceReachability.unseekable => Icons.info_outline_rounded,
        SourceReachability.unreachable => Icons.help_outline_rounded,
        SourceReachability.notVideo => Icons.error_outline_rounded,
        SourceReachability.notChecked => Icons.radio_button_unchecked_rounded,
      };

  static Color? _reachabilityColor(SourceReachability status) =>
      switch (status) {
        SourceReachability.reachable => const Color(0xFF8DBAA0),
        SourceReachability.unseekable ||
        SourceReachability.unreachable => const Color(0xFFC5AD83),
        SourceReachability.notVideo => const Color(0xFFCF9292),
        SourceReachability.checking || SourceReachability.notChecked => null,
      };
}

/// The row of quality pills above the source list.
///
/// A [Wrap], not a horizontal [Scrollable]: the panel keeps every strip above
/// its lists scrollable-free because a [Scrollable] traps directional focus,
/// and six pills of four characters fit a drawer in one run at every ramp. A
/// seventh tier would fall onto a second line, which is the right failure.
class _QualityStrip extends StatelessWidget {
  const _QualityStrip({
    required this.tiers,
    required this.selected,
    required this.onTap,
  });

  final List<String> tiers;

  /// The tier in force, or null for the unfiltered list.
  final String? selected;

  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: kQualityFilterStripKey,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: <Widget>[
          for (final tier in tiers)
            _QualityChip(
              label: tier,
              selected: tier == selected,
              onTap: () => onTap(tier),
            ),
        ],
      ),
    );
  }
}

/// One quality pill. A filter, so it is a toggle: pressing the pill in force
/// clears it and shows the whole list again.
///
/// One focus stop, activated by tap and by the same keys a [PanelRow] takes,
/// because the panel's rule is that everything in it is reachable by remote
/// and that nothing in it needs two presses to reach.
class _QualityChip extends StatefulWidget {
  const _QualityChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_QualityChip> createState() => _QualityChipState();
}

class _QualityChipState extends State<_QualityChip> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final metrics = PlayerPanelMetrics.of(context);
    final active = widget.selected;
    // Focus outranks selection: on a remote the pill the viewer is standing on
    // has to be findable whether or not it is the one already applied.
    final showFocus = showFocusIndicator(context, _focused);
    final Color background = active
        ? HotstarPlayerStyle.accent
        : (showFocus || _hovered
              ? HotstarPlayerStyle.panelElevated
              : Colors.transparent);
    return Semantics(
      button: true,
      selected: active,
      label: widget.label,
      child: Focus(
        onFocusChange: (value) => setState(() => _focused = value),
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.space ||
              key == LogicalKeyboardKey.gameButtonA) {
            widget.onTap();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: HotstarPlayerStyle.fastMotionDuration,
              constraints: BoxConstraints(minHeight: metrics.chipMinHeight),
              padding: EdgeInsets.symmetric(
                horizontal: metrics.chipHorizontalPadding,
              ),
              decoration: BoxDecoration(
                color: background,
                // A pill, not a chip: fully rounded, so it cannot be mistaken
                // for a badge on a row below it.
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  // Focus is white and selection is the accent, so a pill
                  // that is both still says which is which - the old pair
                  // painted the same colour for either.
                  color: showFocus
                      ? HotstarPlayerStyle.focusRing
                      : (active ? HotstarPlayerStyle.accent : metrics.divider),
                  width: showFocus ? HotstarPlayerStyle.focusRingWidth : 1,
                ),
              ),
              child: Center(
                widthFactor: 1,
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: active ? Colors.white : metrics.secondaryText,
                    fontSize: metrics.chipLabelSize,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Says why sources the viewer's quality preference excludes are in the list.
///
/// Without it the filter looks broken: somebody who asked for 1080p and is
/// handed a 480p list has no way to know the title simply had nothing better.
class _FallbackBanner extends StatelessWidget {
  const _FallbackBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    // The banner is prose, and it sits directly above the row a remote lands
    // on, so it is the first thing a viewer's eye goes to on the tab they read
    // longest. It was the one panel descendant still drawn from literals -
    // 11 sp is 22 physical pixels on a 1080p set at dp 2.0.
    final metrics = PlayerPanelMetrics.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x1FFFC107),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x66FFC107)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.filter_alt_off_rounded,
            size: metrics.bannerIconSize,
            color: const Color(0xFFFFC107),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: const Color(0xFFFFE082),
                fontSize: metrics.bannerTextSize,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
