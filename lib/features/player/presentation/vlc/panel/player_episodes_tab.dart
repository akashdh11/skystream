/// The Episodes tab.
///
/// The player it replaces offered a next arrow and nothing else: to reach
/// episode 7 from episode 3 a viewer had to leave playback, find the series and
/// start again. The list is the same one [effectiveEpisodes] navigates, so what
/// this offers and what the next arrow does can never disagree — including the
/// dub filter, which is why episode 5 appears once on a series carrying both a
/// subbed and a dubbed copy of it.
///
/// WATCH PROGRESS: sixty rows of an anime are otherwise visually identical, and
/// the details screen answers "which of these have I seen" for the very same
/// list. So a seen episode's still is dimmed the same 28 % black the details
/// screen dims it by and carries a `Watched` chip, and a part-watched one gets
/// a bar across the foot of its still. It is read-only here: this is a list a
/// viewer is picking from mid-playback, not the place to change history.
///
/// It arrives as an [EpisodeProgressLookup] asked once per built row, never as
/// a map on [PanelData] — see the typedef for why.
library;

import 'player_anchored_list.dart';

import 'package:flutter/material.dart';

import '../../../../../core/domain/entity/multimedia_item.dart';
import '../../../../../l10n/generated/app_localizations.dart';
import '../../widgets/hotstar_player_style.dart';
import 'player_panel_data.dart';
import 'player_panel_row.dart';

class PlayerEpisodesTab extends StatelessWidget {
  const PlayerEpisodesTab({
    required this.episodes,
    required this.onPick,
    this.currentEpisode,
    this.anchorIndex,
    this.autofocus = false,
    this.episodeProgress,
    super.key,
  });

  final List<Episode> episodes;

  /// The episode playing now: the ticked row, and the one the panel opens on
  /// unless [anchorIndex] says otherwise.
  final Episode? currentEpisode;

  /// Position in [episodes] of the row the list opens on and, with
  /// [autofocus], focuses. Defaults to [currentEpisode]'s position; the panel
  /// passes the value it saw at open so the list does not scroll when the
  /// player moves on to the next episode underneath it.
  final int? anchorIndex;

  final ValueChanged<Episode> onPick;
  final bool autofocus;

  /// Where the viewer got to in each episode. Asked once per row the list
  /// actually builds, so a 200-episode season costs the visible rows and no
  /// more. Null - the panel opened without one - leaves every row plain, which
  /// is exactly what the tab looked like before.
  final EpisodeProgressLookup? episodeProgress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (episodes.isEmpty) return PanelEmpty(text: l10n.noEpisodesFound);

    // The episode playing, or the first, so focus always has a row to land on.
    final wanted =
        anchorIndex ?? episodes.indexOf(currentEpisode ?? episodes.first);
    final anchor = wanted >= 0 && wanted < episodes.length ? wanted : 0;

    return PanelAnchoredList(
      anchorIndex: anchor,
      // A 54 px thumbnail row with its margins and border; measured in
      // player_anchored_list_test.dart.
      estimatedRowExtent: 84,
      autofocus: autofocus,
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: episodes.length,
      itemBuilder: (context, index) {
        final episode = episodes[index];
        final current = episode == currentEpisode;
        // Once per built row. The lookup hashes and reads storage, so calling
        // it twice - or for rows nobody scrolled to - is the whole cost this
        // shape exists to avoid.
        final progress = episodeProgress?.call(episode) ?? EpisodeProgress.none;
        return PanelRow(
          label: _title(l10n, episode),
          detail: _detail(l10n, episode),
          badges: <String>[?_dubBadge(l10n, episode)],
          badgeIcon: switch (episode.dubStatus) {
            DubStatus.dubbed => Icons.mic_rounded,
            DubStatus.subbed => Icons.subtitles_rounded,
            DubStatus.none => null,
          },
          badgeColor: const Color(0xFFA0ADC5),
          neutralBadges: true,
          selected: current,
          selectedLabel: l10n.playing,
          selectedLabelIcon: Icons.play_arrow_rounded,
          // The chip is not suppressed on the playing row, where the dim and
          // the bar are: it says something the play glyph does not - that this
          // is a re-watch - and unlike a position it cannot go stale under the
          // viewer, because the row is about to make it true anyway.
          status: progress.watched ? l10n.watched : null,
          statusIcon: Icons.check_circle_outline_rounded,
          statusColor: const Color(0xFF8DBAA0),
          autofocus: autofocus && index == anchor,
          leading: _EpisodeThumbnail(
            posterUrl: episode.posterUrl,
            isCurrent: current,
            // Two suppressions, both about not contradicting a stronger
            // signal already on the row.
            //
            // Nothing is painted over the still of the episode that is on
            // now: its stored position lags by up to 5 % of the duration -
            // the recorder only writes on that threshold - so a stale
            // half-bar under a `Playing` badge is worse than no bar, and a
            // second dim over the play scrim only makes the picture harder to
            // read.
            //
            // And a watched episode gets the dim and the chip, never a bar as
            // well: `watched` is the repository's answer and outranks a
            // position, so an episode marked seen by hand at 40 % must not be
            // labelled `Watched` and drawn 40 % through in the same breath.
            progress: current || progress.watched ? 0 : progress.fraction,
            watched: !current && progress.watched,
          ),
          onTap: () => onPick(episode),
        );
      },
    );
  }

  /// `S2 E4 · The Body`. The number leads because that is what a viewer is
  /// looking for, and plenty of plugins give every episode the same name.
  String _title(AppLocalizations l10n, Episode episode) {
    final name = episode.name.trim();
    final number = episode.season > 0
        ? l10n.playerSeasonEpisode(episode.season, episode.episode)
        : (episode.episode > 0
              ? l10n.playerEpisodeNumber(episode.episode)
              : '');
    if (number.isEmpty) return name.isEmpty ? l10n.unknown : name;
    return name.isEmpty ? number : '$number · $name';
  }

  String? _detail(AppLocalizations l10n, Episode episode) {
    final runtime = episode.runtime;
    final aired = episode.airDate?.trim();
    final parts = <String>[
      if (aired != null && aired.isNotEmpty) aired,
      if (runtime != null && runtime > 0) l10n.playerRuntimeMinutes(runtime),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String? _dubBadge(AppLocalizations l10n, Episode episode) =>
      switch (episode.dubStatus) {
        DubStatus.dubbed => l10n.dub.toUpperCase(),
        DubStatus.subbed => l10n.sub.toUpperCase(),
        DubStatus.none => null,
      };
}

/// Poster still, with a play marker on the episode that is on now, a dim on one
/// already seen and a bar across the foot of one part-way through.
///
/// The inner [Stack] is a leaf decoration on one 96x54 image, not panel layout:
/// it never grows, so it cannot become one of the window-sized layers the
/// compositing rules are about. Everything added here is a [ColoredBox] or a
/// 3 px bar — no opacity layer, no filter.
class _EpisodeThumbnail extends StatelessWidget {
  const _EpisodeThumbnail({
    required this.posterUrl,
    required this.isCurrent,
    this.progress = 0,
    this.watched = false,
  });

  final String? posterUrl;
  final bool isCurrent;

  /// 0..1 of the episode reached. Only painted inside a dead band — see
  /// [build].
  final double progress;

  /// Seen. Dims the still, the same 28 % black the details screen uses.
  final bool watched;

  @override
  Widget build(BuildContext context) {
    final poster = posterUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 96,
        height: 54,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (poster != null && poster.isNotEmpty)
              Image.network(
                poster,
                fit: BoxFit.cover,
                // A still that will not load is not worth an error box in a
                // list somebody is trying to read.
                errorBuilder: (_, _, _) => const _ThumbPlaceholder(),
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : const _ThumbPlaceholder(),
              )
            else
              const _ThumbPlaceholder(),
            // 0x47 is 28 % black: the same dim the details screen puts over a
            // seen episode, so the two lists agree at a glance.
            if (watched) const ColoredBox(color: Color(0x47000000)),
            if (isCurrent)
              const ColoredBox(
                color: Color(0x66000000),
                child: Center(
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            // A dead band at both ends. Below 2 % is a false start - a wrong
            // pick, a stream that never played - and a sliver of a bar there
            // reads as "you began this" when nobody did. Above 98 % the bar is
            // indistinguishable from full, and a full bar on a row that is not
            // marked watched reads as a bug rather than as information.
            if (progress > 0.02 && progress < 0.98)
              Align(
                alignment: Alignment.bottomCenter,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    HotstarPlayerStyle.accent,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ThumbPlaceholder extends StatelessWidget {
  const _ThumbPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0x14FFFFFF),
      child: Center(
        child: Icon(
          Icons.movie_outlined,
          color: HotstarPlayerStyle.mutedText,
          size: 20,
        ),
      ),
    );
  }
}
