import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/addons/models/addon_meta.dart';

/// A meta payload is only ever as well-typed as the add-on that served it, and
/// the meta fetch loop in `addon_providers.dart` answers a [TypeError] by
/// moving on to the next add-on. A parse that throws therefore shows up as an
/// add-on that quietly stops appearing, so these cover the shapes real
/// manifests send rather than the shapes the Stremio docs promise.
void main() {
  Map<String, dynamic> meta(Map<String, dynamic> extra) => {
    'id': 'tt0111161',
    'type': 'movie',
    'name': 'The Shawshank Redemption',
    ...extra,
  };

  group('AddonMeta.fromJson moviedb_id', () {
    test('reads a JSON number', () {
      expect(AddonMeta.fromJson(meta({'moviedb_id': 278})).moviedbId, 278);
    });

    test('reads a number that was quoted as a string', () {
      expect(AddonMeta.fromJson(meta({'moviedb_id': '278'})).moviedbId, 278);
      expect(AddonMeta.fromJson(meta({'moviedb_id': ' 278 '})).moviedbId, 278);
      expect(AddonMeta.fromJson(meta({'moviedb_id': '278.0'})).moviedbId, 278);
    });

    test('is null when absent or explicitly null', () {
      expect(AddonMeta.fromJson(meta(const {})).moviedbId, isNull);
      expect(AddonMeta.fromJson(meta({'moviedb_id': null})).moviedbId, isNull);
    });

    test('is null for garbage instead of throwing', () {
      for (final garbage in <Object>[
        'not-an-id',
        '',
        true,
        <String>['278'],
        {'id': 278},
        double.nan,
        double.infinity,
      ]) {
        expect(
          AddonMeta.fromJson(meta({'moviedb_id': garbage})).moviedbId,
          isNull,
          reason: 'moviedb_id: $garbage',
        );
      }
    });

    test('falls through to tmdb_id, then to a tmdb: prefixed id', () {
      final viaTmdbId = meta({'moviedb_id': 'x', 'tmdb_id': '278'});
      expect(AddonMeta.fromJson(viaTmdbId).moviedbId, 278);

      final viaPrefixedId = meta({'id': 'tmdb:278', 'moviedb_id': 'x'});
      expect(AddonMeta.fromJson(viaPrefixedId).moviedbId, 278);
    });
  });

  group('AddonMeta.fromJson string fields', () {
    test('stringifies numbers found in text fields', () {
      final parsed = AddonMeta.fromJson({
        'id': 550,
        'type': 'movie',
        'name': 2012,
        'description': 42,
        'releaseInfo': 1999,
        'imdbRating': 8.3,
        'runtime': 142,
        'country': 1984,
        'awards': 7,
      });

      expect(parsed.id, '550');
      expect(parsed.name, '2012');
      expect(parsed.description, '42');
      expect(parsed.releaseInfo, '1999');
      expect(parsed.year, 1999);
      expect(parsed.imdbRating, '8.3');
      expect(parsed.runtime, '142');
      expect(parsed.country, '1984');
      expect(parsed.awards, '7');
    });

    test('drops structured values rather than printing them at the user', () {
      final parsed = AddonMeta.fromJson(meta({
        'poster': <String>['a.jpg'],
        'background': {'url': 'b.jpg'},
        'description': true,
      }));

      expect(parsed.poster, isNull);
      expect(parsed.background, isNull);
      expect(parsed.description, isNull);
    });

    test('keeps a whole meta parsing when nested text fields are numbers', () {
      final parsed = AddonMeta.fromJson(meta({
        'genres': [1980, 'Drama'],
        'cast': [
          {'name': 7, 'character': 12, 'profile_path': 3},
          {'name': 'Tim Robbins', 'character': 'Andy'},
        ],
        'director': ['Frank Darabont', 99],
        'writer': [42],
        'links': [
          {'category': 'cast', 'name': 1234},
          {'category': 'director', 'name': 'Frank Darabont'},
        ],
        'productionCompanies': [
          {'name': 5, 'logo_path': 6},
        ],
        'trailers': [
          {'source': 12345, 'type': 9, 'name': 10},
        ],
      }));

      expect(parsed.genres, ['1980', 'Drama']);
      expect(parsed.cast, ['7', 'Tim Robbins', '1234']);
      expect(parsed.castMembers.first.character, '12');
      expect(parsed.castMembers.first.profilePath, '3');
      expect(parsed.directors, ['Frank Darabont', '99']);
      expect(parsed.writers, ['42']);
      expect(parsed.productionCompanies.single.name, '5');
      expect(parsed.productionCompanies.single.logoPath, '6');
      expect(parsed.trailers.single.key, '12345');
      expect(parsed.trailers.single.type, '9');
      expect(parsed.trailers.single.name, '10');
    });
  });

  group('streamRequestType', () {
    test('preserves other/tv so multi-provider bridges get the right /stream', () {
      expect(
        AddonMeta.fromJson(meta({'type': 'other', 'id': 'cnc:x'})).streamRequestType,
        'other',
      );
      expect(
        AddonMeta.fromJson(meta({'type': 'tv', 'id': 'cnc:y'})).streamRequestType,
        'tv',
      );
      expect(
        AddonMeta.fromJson(meta({'type': 'movie', 'id': 'tt1'})).streamRequestType,
        'movie',
      );
      expect(
        AddonMeta.fromJson(meta({'type': 'series', 'id': 'tt2'})).streamRequestType,
        'series',
      );
    });
  });

  group('AddonVideo.fromJson', () {
    test('accepts season and episode numbers sent as strings', () {
      final parsed = AddonMeta.fromJson(meta({
        'type': 'series',
        'videos': [
          {
            'id': 'tt0111161:1:2',
            'season': '1',
            'episode': '2',
            'title': 'Two',
          },
          {'id': 'tt0111161:1:1', 'season': 1, 'number': 1, 'name': 3},
        ],
      }));

      expect(parsed.videos.map((v) => v.id), [
        'tt0111161:1:1',
        'tt0111161:1:2',
      ]);
      expect(parsed.videos.first.title, '3');
      expect(parsed.videos.last.season, 1);
      expect(parsed.videos.last.episode, 2);
      expect(parsed.seasons, [1]);
    });

    test('names an episode from its number when the title is unusable', () {
      final parsed = AddonMeta.fromJson(meta({
        'videos': [
          {'id': 'x', 'episode': '4', 'title': <String>[]},
        ],
      }));

      expect(parsed.videos.single.title, 'Episode 4');
    });
  });
}
