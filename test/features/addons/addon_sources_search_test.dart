import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/addons/models/addon_stream_source.dart';

AddonStreamSource stream({
  required String addonName,
  String? name,
  String? title,
  String? description,
}) {
  return AddonStreamSource(
    addonId: 'test.$addonName',
    addonName: addonName,
    name: name,
    title: title,
    description: description,
    url: 'https://example.com/v.m3u8',
  );
}

void main() {
  test('empty query keeps every link', () {
    final s = stream(addonName: 'CNCVerse', name: 'VegaMovies');
    expect(s.matchesQuery(''), isTrue);
    expect(s.matchesQuery('   '), isTrue);
  });

  test('filters by add-on name', () {
    final a = stream(addonName: 'CNCVerse', name: 'VegaMovies · 1080p');
    final b = stream(addonName: 'Torrentio', name: '1080p BluRay');
    expect(a.matchesQuery('cncverse'), isTrue);
    expect(b.matchesQuery('cncverse'), isFalse);
    expect(b.matchesQuery('torrentio'), isTrue);
  });

  test('filters by inner provider (VegaMovies on CNCVerse)', () {
    final a = stream(addonName: 'CNCVerse', name: 'VegaMovies');
    final b = stream(addonName: 'CNCVerse', name: 'MovieBoxIN');
    expect(a.matchesQuery('vegamovies'), isTrue);
    expect(b.matchesQuery('vegamovies'), isFalse);
    expect(b.matchesQuery('moviebox'), isTrue);
  });

  test('filters by quality token in name', () {
    final a = stream(addonName: 'Torrentio', name: 'remux 2160p');
    final b = stream(addonName: 'Torrentio', name: 'web 720p');
    expect(a.matchesQuery('2160'), isTrue);
    expect(b.matchesQuery('2160'), isFalse);
    expect(a.matchesQuery('4k'), isTrue); // qualityLabel maps 2160 → 4K
  });

  test('provider labels prefer inner provider then add-on', () {
    final streams = [
      stream(addonName: 'CNCVerse', name: 'VegaMovies'),
      stream(addonName: 'CNCVerse', name: 'MovieBoxIN'),
      stream(addonName: 'Torrentio', name: '1080p BluRay'),
      stream(addonName: 'CNCVerse', name: 'VegaMovies'), // dup
    ];
    expect(addonStreamProviderLabels(streams), [
      'MovieBoxIN',
      'Torrentio',
      'VegaMovies',
    ]);
  });
}
