/// A Play an extension's own full-screen screen took (a game: Phase 7c's §4): the resolver says so, and the player leaves
/// without a word once it's on top again, never popping or removing the screen above it (Review Focus 1).
library;

import 'dart:async';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/domain/entity/multimedia_item.dart';
import 'package:skystream/core/extensions/base_provider.dart';
import 'package:skystream/core/extensions/extension_manager.dart';
import 'package:skystream/features/player/presentation/vlc/vlc_player_screen.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';

import 'vlc_screen_harness.dart';

/// A game's provider: its links come once its own screen has gone, and there are none.
class _Game implements SkyStreamProvider {
  final links = Completer<List<StreamResult>>();

  @override
  Future<List<StreamResult>> loadStreams(String url) => links.future;

  @override
  String get packageName => 'cs3:ayu/Pokemon/Pokemon';
  @override
  String get name => 'Pokemon';
  @override
  String get mainUrl => 'https://ayu.test';
  @override
  String get version => '1';
  @override
  List<String> get languages => const ['en'];
  @override
  Set<ProviderType> get supportedTypes => const {ProviderType.other};
  @override
  bool get hasSearch => false;
  @override
  bool get isDebug => false;
  @override
  String? get checkSource => null;
  @override
  void cancelInit() {}
  @override
  Future<List<MultimediaItem>> search(String query, {CancelToken? cancelToken}) async => const [];
  @override
  Future<Map<String, List<MultimediaItem>>> getHome() async => const {};
  @override
  Future<HomeSectionPage?> getHomeSection(String section, int page) async =>
      null;
  @override
  Future<MultimediaItem> getDetails(String url) async => throw UnimplementedError();
}

void main() {
  setUp(installEngineMocks);
  tearDown(removeEngineMocks);

  final game = MultimediaItem(title: 'Pokemon', url: 'https://ayu.test/pokemon', posterUrl: '');

  testWidgets(
    'under the game the player waits, then leaves once the game has gone: no "No streams found"',
    variant: texturePlatform,
    (tester) async {
      final provider = _Game();
      await pumpPlayer(
        tester,
        pushed: true,
        item: game,
        videoUrl: 'cs3data:cG9rZW1vbg==',
        overrides: [activeProviderProvider.overrideWithValue(provider)],
      );
      final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
      unawaited(navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Game')))));
      await settle(tester);
      provider.links.completeError(const ExtensionScreenEnded());
      await settle(tester);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text('Game'), findsOneWidget, reason: 'the game stays up');
      expect(find.byType(VlcPlayerScreen, skipOffstage: false), findsOneWidget, reason: 'the player waits under it');
      expect(find.text(l10n.playerNoStreamsFound, skipOffstage: false), findsNothing);
      navigator.pop();
      await settle(tester);
      expect(find.byType(VlcPlayerScreen, skipOffstage: false), findsNothing, reason: 'it left once on top');
    },
  );

  testWidgets('with nothing over it, the player leaves at once', variant: texturePlatform, (tester) async {
    final provider = _Game();
    await pumpPlayer(
      tester,
      pushed: true,
      item: game,
      videoUrl: 'cs3data:cG9rZW1vbg==',
      overrides: [activeProviderProvider.overrideWithValue(provider)],
    );
    provider.links.completeError(const ExtensionScreenEnded());
    await settle(tester);
    expect(find.byType(VlcPlayerScreen, skipOffstage: false), findsNothing);
  });
}
