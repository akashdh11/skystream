import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/addons/data/addon_playback_launcher.dart';
import 'package:skystream/core/addons/models/addon_stream_source.dart';

void main() {
  const converter = AddonStreamConverter();

  AddonStreamSource source({
    required String addonName,
    String? name,
    String? title,
    String url = 'https://cdn.example/a.mp4',
  }) => AddonStreamSource(
    addonId: 'test',
    addonName: addonName,
    url: url,
    name: name,
    title: title,
  );

  test('player label carries add-on, provider and resolution', () {
    final stream = source(
      addonName: 'CNCVerse Bridge',
      name: 'MovieBox\n1080p',
      title: 'Waiting Hai',
    );
    final results = converter.toStreamResults([stream]);
    expect(results, hasLength(1));
    // providerName is the inner scraper; source still names the bridge + quality.
    expect(results.single.providerName, 'MovieBox');
    expect(results.single.source, contains('CNCVerse Bridge'));
    expect(results.single.source, contains('1080p'));
  });

  test('single-provider add-on keeps add-on as providerName', () {
    final stream = source(addonName: 'Torrentio', name: '1080p BluRay');
    final results = converter.toStreamResults([stream]);
    expect(results.single.providerName, 'Torrentio');
    expect(results.single.source, contains('1080p'));
  });
}
