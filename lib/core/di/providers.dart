import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/permissions/permission_service.dart';
import '../../data/database/app_database.dart';
import '../../data/datasources/device_media_scanner.dart';
import '../../data/repositories/library_repository_impl.dart';
import '../../data/repositories/media_repository_impl.dart';
import '../../data/repositories/playlist_repository_impl.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../domain/repositories/repositories.dart';

/// Central dependency-injection container (MVVM "Model" wiring).
/// Feature controllers depend only on these provider instances.

final permissionServiceProvider = Provider<PermissionService>(
  (ref) => const PermissionService(),
);

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final deviceMediaScannerProvider = Provider<DeviceMediaScanner>(
  (ref) => const DeviceMediaScanner(),
);

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return MediaRepositoryImpl(
    db: ref.watch(appDatabaseProvider),
    deviceScanner: ref.watch(deviceMediaScannerProvider),
    permissions: ref.watch(permissionServiceProvider),
  );
});

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return LibraryRepositoryImpl(db: ref.watch(appDatabaseProvider));
});

final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) {
  return PlaylistRepositoryImpl(db: ref.watch(appDatabaseProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepositoryImpl(db: ref.watch(appDatabaseProvider));
});
