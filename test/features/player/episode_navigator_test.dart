import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/domain/entity/multimedia_item.dart';
import 'package:skystream/features/player/domain/episode_navigator.dart';

void main() {
  Episode ep(
    int season,
    int number, {
    DubStatus dub = DubStatus.none,
    String? url,
  }) => Episode(
    name: 'S${season}E$number',
    url: url ?? 's${season}e$number-${dub.name}',
    season: season,
    episode: number,
    dubStatus: dub,
  );

  MultimediaItem show(
    List<Episode> episodes, {
    MultimediaContentType type = MultimediaContentType.series,
  }) => MultimediaItem(
    title: 'Show',
    url: 'https://example.com/show',
    posterUrl: '',
    contentType: type,
    episodes: episodes,
  );

  group('nextEpisodeFor', () {
    test('advances within a season', () {
      final episodes = [ep(1, 1), ep(1, 2), ep(1, 3)];
      final r = nextEpisodeFor(
        item: show(episodes),
        current: episodes[0],
        videoUrl: '',
      );
      expect(r.next?.episode, 2);
      expect(r.currentFound, isTrue);
      expect(r.isFinalEpisode, isFalse);
    });

    test('crosses a season boundary in list order', () {
      final episodes = [ep(1, 1), ep(1, 2), ep(2, 1)];
      final r = nextEpisodeFor(
        item: show(episodes),
        current: episodes[1],
        videoUrl: '',
      );
      expect(r.next?.season, 2);
      expect(r.next?.episode, 1);
    });

    test('the last episode is final, not unknown', () {
      final episodes = [ep(1, 1), ep(1, 2)];
      final r = nextEpisodeFor(
        item: show(episodes),
        current: episodes[1],
        videoUrl: '',
      );
      expect(r.next, isNull);
      expect(r.isFinalEpisode, isTrue);
    });

    // The distinction the old path collapsed: it returned null for both, and
    // its caller deleted the whole series from history on null.
    test('an unlocatable current episode is unknown, NOT final', () {
      final r = nextEpisodeFor(
        item: show([ep(1, 1), ep(1, 2)]),
        current: ep(9, 9, url: 'nowhere'),
        videoUrl: 'also-nowhere',
      );
      expect(r.next, isNull);
      expect(r.currentFound, isFalse);
      expect(r.isFinalEpisode, isFalse);
    });

    test('falls back to the route token when no episode was passed', () {
      final episodes = [ep(1, 1), ep(1, 2)];
      final r = nextEpisodeFor(
        item: show(episodes),
        current: null,
        videoUrl: episodes[0].url,
      );
      expect(r.next?.episode, 2);
    });

    test('falls back to season/episode numbers when the url does not match', () {
      final episodes = [ep(1, 1), ep(1, 2), ep(1, 3)];
      final r = nextEpisodeFor(
        item: show(episodes),
        current: Episode(
          name: 'other copy',
          url: 'a-different-url',
          season: 1,
          episode: 2,
        ),
        videoUrl: '',
      );
      expect(r.next?.episode, 3);
    });

    test('a movie has no next episode and is never final', () {
      final r = nextEpisodeFor(
        item: show(const [], type: MultimediaContentType.movie),
        current: null,
        videoUrl: '',
      );
      expect(r.next, isNull);
      expect(r.isFinalEpisode, isFalse);
    });

    test('an item with no episode list is unknown, not final', () {
      final r = nextEpisodeFor(item: show(const []), current: null, videoUrl: '');
      expect(r.isFinalEpisode, isFalse);
    });
  });

  group('mixed sub/dub lists', () {
    // Episodes sort by (season, episode) only, so both copies of episode 1 sit
    // adjacent. A naive index+1 would advance subbed 1 -> dubbed 1: the same
    // episode in the wrong language.
    final mixed = [
      ep(1, 1, dub: DubStatus.subbed),
      ep(1, 1, dub: DubStatus.dubbed),
      ep(1, 2, dub: DubStatus.subbed),
      ep(1, 2, dub: DubStatus.dubbed),
    ];

    test('stays on the subbed track', () {
      final r = nextEpisodeFor(
        item: show(mixed),
        current: mixed[0],
        videoUrl: '',
      );
      expect(r.next?.episode, 2);
      expect(r.next?.dubStatus, DubStatus.subbed);
    });

    test('stays on the dubbed track', () {
      final r = nextEpisodeFor(
        item: show(mixed),
        current: mixed[1],
        videoUrl: '',
      );
      expect(r.next?.episode, 2);
      expect(r.next?.dubStatus, DubStatus.dubbed);
    });

    test('the last of a track is final, not a jump to the other track', () {
      final r = nextEpisodeFor(
        item: show(mixed),
        current: mixed[3],
        videoUrl: '',
      );
      expect(r.isFinalEpisode, isTrue);
    });

    test('an unclassified current episode keeps the whole list', () {
      expect(effectiveEpisodes(show(mixed), ep(1, 1)), hasLength(4));
    });

    test('a single-track list is never filtered', () {
      final subbedOnly = [
        ep(1, 1, dub: DubStatus.subbed),
        ep(1, 2, dub: DubStatus.subbed),
      ];
      expect(effectiveEpisodes(show(subbedOnly), subbedOnly[0]), hasLength(2));
    });
  });
}
