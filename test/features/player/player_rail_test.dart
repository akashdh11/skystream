import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/features/player/presentation/vlc/player_rail.dart';
import 'package:skystream/features/player/presentation/widgets/hotstar_player_style.dart';

void main() {
  Finder fill(Color color) => find.byWidgetPredicate(
    (widget) => widget is ColoredBox && widget.color == color,
  );

  Future<void> pumpRail(
    WidgetTester tester, {
    required double value,
    double maxValue = 2,
    bool brightness = false,
  }) => tester.pumpWidget(
    MaterialApp(
      home: SizedBox.expand(
        child: PlayerRail(
          icon: brightness
              ? Icons.brightness_6_rounded
              : Icons.volume_up_rounded,
          semanticLabel: brightness ? 'Brightness' : 'Volume',
          value: value,
          maxValue: maxValue,
          onLeft: !brightness,
        ),
      ),
    ),
  );

  for (final (value, maximum, normal, boost)
      in <(double, double, double, double)>[
        (0, 2, 0, 0),
        (0.5, 2, 0.5, 0),
        (1, 2, 1, 0),
        (1.5, 2, 1, 0.5),
        (2, 2, 1, 1),
        (1.25, 1.5, 1, 0.5),
        (2, 1.5, 1, 1),
        (1, 1, 1, 0),
      ]) {
    testWidgets('volume $value with ceiling $maximum fills in two passes', (
      tester,
    ) async {
      await pumpRail(tester, value: value, maxValue: maximum);
      final track = tester.getRect(find.byType(ClipRRect));
      final base = tester.getRect(fill(HotstarPlayerStyle.primaryText));
      expect(base.height, closeTo(track.height * normal, 0.01));
      expect(base.bottom, track.bottom);
      if (boost == 0) {
        expect(fill(PlayerRail.boostColor), findsNothing);
      } else {
        final boosted = tester.getRect(fill(PlayerRail.boostColor));
        expect(boosted.height, closeTo(track.height * boost, 0.01));
        expect(boosted.bottom, track.bottom);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('brightness has a top icon and an accessible, unprinted value', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpRail(tester, value: 0.75, maxValue: 1, brightness: true);
      final track = tester.getRect(find.byType(ClipRRect));
      final icon = tester.getRect(find.byIcon(Icons.brightness_6_rounded));
      expect(icon.bottom, lessThan(track.top));
      expect(track.width, 5);
      expect(
        tester.getSize(fill(HotstarPlayerStyle.primaryText)).height,
        closeTo(track.height * 0.75, 0.01),
      );
      expect(find.byType(Text), findsNothing);
      expect(fill(PlayerRail.boostColor), findsNothing);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Brightness')),
        matchesSemantics(label: 'Brightness', value: '75%'),
      );
    } finally {
      semantics.dispose();
    }
  });
}
