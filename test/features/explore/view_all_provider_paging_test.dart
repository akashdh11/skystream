import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/domain/entity/multimedia_item.dart';
import 'package:skystream/core/extensions/base_provider.dart';
import 'package:skystream/features/explore/data/explore_language_provider.dart';
import 'package:skystream/features/explore/presentation/controllers/view_all_controller.dart';
import 'package:skystream/features/explore/presentation/view_all_screen.dart';

/// A provider's home row, opened in full, goes on to the provider's next pages
/// as the list nears its end, while the provider says one follows.
void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [languageProvider.overrideWith(_English.new)],
    );
    addTearDown(container.dispose);
    container.listen(
      viewAllControllerProvider(ViewAllCategory.providerContent),
      (_, _) {},
    );
  });

  ViewAllController controller() => container.read(
    viewAllControllerProvider(ViewAllCategory.providerContent).notifier,
  );

  ViewAllState state() => container.read(
    viewAllControllerProvider(ViewAllCategory.providerContent),
  );

  List<String> urls() => [for (final item in state().items) item.url];

  test('without pages, only the row home has', () async {
    controller().init([_item('a')]);
    expect(state().hasMore, isFalse);
    await controller().fetchNextPage();
    expect(urls(), ['a']);
  });

  test(
    'pages follow the row until the provider says the last, without repeats',
    () async {
      final asked = <int>[];
      controller().init(
        [_item('a'), _item('b')],
        loadPage: (page) async {
          asked.add(page);
          return switch (page) {
            2 => HomeSectionPage(
              items: [_item('b'), _item('c')],
              hasNext: true,
            ),
            _ => HomeSectionPage(items: [_item('d')], hasNext: false),
          };
        },
      );
      expect(state().hasMore, isTrue);

      await controller().fetchNextPage();
      expect(urls(), ['a', 'b', 'c']);
      expect(state().hasMore, isTrue);

      await controller().fetchNextPage();
      expect(urls(), ['a', 'b', 'c', 'd']);
      expect(state().hasMore, isFalse);
      expect(state().isLoading, isFalse);

      await controller().fetchNextPage();
      expect(asked, [2, 3]);
    },
  );

  test('a page asked for twice at once is asked once', () async {
    var calls = 0;
    controller().init(
      [_item('a')],
      loadPage: (page) async {
        calls++;
        return HomeSectionPage(items: [_item('b')], hasNext: true);
      },
    );
    await Future.wait([
      controller().fetchNextPage(),
      controller().fetchNextPage(),
    ]);
    expect(calls, 1);
  });

  test('a page with nothing new ends it: a provider ignoring the page number repeats itself', () async {
    controller().init(
      [_item('a')],
      loadPage: (page) async =>
          HomeSectionPage(items: [_item('a')], hasNext: true),
    );
    await controller().fetchNextPage();
    expect(urls(), ['a']);
    expect(state().hasMore, isFalse);
  });

  test('a provider that answers it has no pages ends it', () async {
    controller().init([_item('a')], loadPage: (page) async => null);
    await controller().fetchNextPage();
    expect(urls(), ['a']);
    expect(state().hasMore, isFalse);
  });

  test('a failed page keeps the list and stops asking', () async {
    var calls = 0;
    controller().init(
      [_item('a')],
      loadPage: (page) async {
        calls++;
        throw Exception('offline');
      },
    );
    await controller().fetchNextPage();
    await controller().fetchNextPage();
    expect(urls(), ['a']);
    expect(state().isLoading, isFalse);
    expect(state().hasMore, isFalse);
    expect(calls, 1);
  });
}

MultimediaItem _item(String url) => MultimediaItem(
  title: url,
  url: url,
  posterUrl: '',
  contentType: MultimediaContentType.movie,
);

class _English extends Language {
  @override
  String build() => 'en-US';
}
