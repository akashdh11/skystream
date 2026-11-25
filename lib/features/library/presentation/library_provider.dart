import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/storage/library_repository.dart';
import '../../profile_sync/profile_sync_hooks.dart';

import './library_state.dart';

part 'library_provider.g.dart';

@Riverpod(keepAlive: true)
class Library extends _$Library {
  @override
  LibraryState build() {
    return refresh();
  }

  LibraryState refresh() {
    final repository = ref.read(libraryRepositoryProvider);
    final items = repository.getLibraryItems();
    if (items.isEmpty) {
      state = const LibraryEmpty();
    } else {
      state = LibrarySuccess(items);
    }
    return state;
  }

  Future<void> addItem(MultimediaItem item) async {
    final repository = ref.read(libraryRepositoryProvider);
    await repository.addToLibrary(item);
    refresh();
    ref.read(profileSyncHooksProvider).onLocalChange?.call();
  }

  Future<void> removeItem(String url) async {
    final repository = ref.read(libraryRepositoryProvider);
    await repository.removeFromLibrary(url);
    refresh();
    ref.read(profileSyncHooksProvider).onLocalChange?.call();
  }

  bool isBookmarked(String url) {
    final repository = ref.read(libraryRepositoryProvider);
    return repository.isInLibrary(url);
  }

  Future<void> clearAll() async {
    // repository.clearAll() if it exists
  }
}
