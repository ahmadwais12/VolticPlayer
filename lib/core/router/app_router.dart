import 'package:go_router/go_router.dart';

import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/library/presentation/screens/videos_screen.dart';
import '../../features/library/presentation/screens/music_screen.dart';
import '../../features/library/presentation/screens/media_folder_screen.dart';
import '../../features/folders/presentation/screens/folders_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/playback_settings_screen.dart';
import '../../features/settings/presentation/screens/subtitle_settings_screen.dart';
import '../../features/settings/presentation/screens/gesture_settings_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/favorites/presentation/screens/favorites_screen.dart';
import '../../features/history/presentation/screens/history_screen.dart';
import '../../features/bookmarks/presentation/screens/bookmarks_screen.dart';
import '../../features/downloads/presentation/screens/downloads_screen.dart';
import '../../features/downloads/presentation/screens/video_downloader_screen.dart';
import '../../features/downloads/presentation/screens/youtube_sign_in_screen.dart';
import '../../features/settings/presentation/screens/downloader_settings_screen.dart';
import '../../features/network/presentation/screens/network_stream_screen.dart';
import '../../features/playlists/presentation/screens/playlists_screen.dart';
import '../../features/playlists/presentation/screens/playlist_detail_screen.dart';
import '../../features/video_player/presentation/screens/video_player_screen.dart';
import '../../features/audio_player/presentation/screens/audio_player_screen.dart';
import '../../features/equalizer/presentation/screens/equalizer_screen.dart';
import '../../features/audio_player/presentation/screens/audio_effects_screen.dart';
import '../../features/queue/presentation/screens/queue_screen.dart';
import '../../features/playlists/presentation/screens/smart_playlists_screen.dart';
import '../../features/video_player/presentation/screens/video_filters_screen.dart';
import '../../features/folders/presentation/screens/folder_exclusion_screen.dart';
import '../../features/iptv/presentation/screens/iptv_screen.dart';
import '../../features/settings/presentation/screens/about_screen.dart';
import '../../features/settings/presentation/screens/backup_restore_screen.dart';
import '../../features/settings/presentation/screens/storage_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/more/presentation/screens/more_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/web_search/domain/web_search_models.dart';
import '../../features/web_search/presentation/screens/channel_detail_screen.dart';
import '../../features/web_search/presentation/screens/web_search_screen.dart';
import '../../features/web_search/presentation/screens/sites_screen.dart';
import '../../features/web_search/presentation/screens/website_screen.dart';
import '../widgets/app_shell.dart';

class AppRouter {
  AppRouter._();

  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String videos = '/videos';
  static const String music = '/music';
  static const String folders = '/folders';

  /// Contents of one device folder, opened from the Videos/Music folders view.
  static const String mediaFolder = '/media-folder';
  static const String settings = '/settings';
  static const String more = '/more';
  static const String profile = '/profile';
  static const String search = '/search';
  static const String favorites = '/favorites';
  static const String history = '/history';
  static const String bookmarks = '/bookmarks';
  static const String downloads = '/downloads';
  static const String sites = '/sites';
  static const String website = '/website';
  static const String downloadDetails = '/downloads/manage';
  static const String youtubeSignIn = '/downloads/youtube-sign-in';
  static const String networkStream = '/network';
  static const String playlists = '/playlists';
  static const String playlistDetail = '/playlist/:id';
  static const String videoPlayer = '/video';
  static const String audioPlayer = '/audio';
  static const String equalizer = '/equalizer';
  static const String audioEffects = '/audio-effects';
  static const String queue = '/queue';
  static const String smartPlaylists = '/smart-playlists';
  static const String videoFilters = '/video-filters';
  static const String folderExclusions = '/folder-exclusions';
  static const String playbackSettings = '/settings/playback';
  static const String subtitleSettings = '/settings/subtitles';
  static const String gestureSettings = '/settings/gestures';
  static const String backupRestore = '/settings/backup';
  static const String iptv = '/iptv';
  static const String about = '/about';
  static const String storage = '/storage';
  static const String videoDownloader = '/download-url';

  /// SEO-friendly public landing route for the downloader (prompt §27).
  static const String videoDownloaderLanding = '/video-downloader';

  /// Admin controls for the downloader (prompt §25).
  static const String downloaderSettings = '/settings/downloader';

  static const String channelDetail = '/channel/:id';
  static String channelPath(String id) => '/channel/$id';

  static final GoRouter router = GoRouter(
    initialLocation: splash,
    debugLogDiagnostics: false,
    routes: [
      GoRoute(path: splash, builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(path: search, builder: (context, state) => const SearchScreen()),
      GoRoute(
        path: favorites,
        builder: (context, state) => const FavoritesScreen(),
      ),
      GoRoute(
        path: history,
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: bookmarks,
        builder: (context, state) => const BookmarksScreen(),
      ),
      GoRoute(
        path: networkStream,
        builder: (context, state) => const NetworkStreamScreen(),
      ),
      GoRoute(
        path: folders,
        builder: (context, state) => const FoldersScreen(),
      ),
      GoRoute(
        path: playlistDetail,
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          return PlaylistDetailScreen(playlistId: id ?? 0);
        },
      ),
      GoRoute(
        path: videoPlayer,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return VideoPlayerScreen(
            uri: extra['uri'] as String? ?? '',
            title: extra['title'] as String? ?? 'Video',
            positionMs: extra['positionMs'] as int? ?? 0,
            thumbnailPath: extra['thumbnailPath'] as String?,
            webResult: extra['webResult'] as WebResult?,
            recommendations:
                (extra['recommendations'] as List?)
                    ?.whereType<WebResult>()
                    .toList() ??
                const [],
          );
        },
      ),
      GoRoute(
        path: audioPlayer,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return AudioPlayerScreen(
            uri: extra['uri'] as String? ?? '',
            title: extra['title'] as String? ?? 'Audio',
            artist: extra['artist'] as String?,
            artworkPath: extra['artworkPath'] as String?,
          );
        },
      ),
      GoRoute(
        path: equalizer,
        builder: (context, state) => const EqualizerScreen(),
      ),
      GoRoute(
        path: audioEffects,
        builder: (context, state) => const AudioEffectsScreen(),
      ),
      GoRoute(path: queue, builder: (context, state) => const QueueScreen()),
      GoRoute(
        path: smartPlaylists,
        builder: (context, state) => const SmartPlaylistsScreen(),
      ),
      GoRoute(
        path: videoFilters,
        builder: (context, state) => const VideoFiltersScreen(),
      ),
      GoRoute(
        path: folderExclusions,
        builder: (context, state) => const FolderExclusionScreen(),
      ),
      GoRoute(
        path: mediaFolder,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return MediaFolderScreen(
            folderPath: extra['path'] as String? ?? '',
            folderName: extra['name'] as String? ?? 'Folder',
            isAudio: extra['isAudio'] as bool? ?? false,
          );
        },
      ),
      GoRoute(
        path: playbackSettings,
        builder: (context, state) => const PlaybackSettingsScreen(),
      ),
      GoRoute(
        path: subtitleSettings,
        builder: (context, state) => const SubtitleSettingsScreen(),
      ),
      GoRoute(
        path: gestureSettings,
        builder: (context, state) => const GestureSettingsScreen(),
      ),
      GoRoute(path: iptv, builder: (context, state) => const IPTVScreen()),
      GoRoute(
        path: backupRestore,
        builder: (context, state) => const BackupRestoreScreen(),
      ),
      GoRoute(
        path: videoDownloader,
        builder: (context, state) =>
            VideoDownloaderScreen(initialUrl: state.extra as String?),
      ),
      GoRoute(
        path: videoDownloaderLanding,
        builder: (context, state) =>
            VideoDownloaderScreen(initialUrl: state.extra as String?),
      ),
      GoRoute(
        path: downloaderSettings,
        builder: (context, state) => const DownloaderSettingsScreen(),
      ),
      GoRoute(
        path: downloadDetails,
        builder: (context, state) {
          final extra = state.extra;
          final focusDownloading = extra == 'downloading' ||
              (extra is Map && extra['focus'] == 'downloading');
          return DownloadsScreen(focusDownloading: focusDownloading);
        },
      ),
      GoRoute(
        path: youtubeSignIn,
        builder: (context, state) => const YoutubeSignInScreen(),
      ),
      GoRoute(path: sites, builder: (context, state) => const SitesScreen()),
      GoRoute(
        path: website,
        builder: (context, state) => WebsiteScreen(url: state.extra as String),
      ),
      GoRoute(
        path: settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: channelDetail,
        builder: (context, state) => ChannelDetailScreen(
          channelId: state.pathParameters['id'] ?? '',
          preview: state.extra as WebResult?,
        ),
      ),
      GoRoute(path: about, builder: (context, state) => const AboutScreen()),
      GoRoute(
        path: storage,
        builder: (context, state) => const StorageScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: videos,
                builder: (context, state) => const VideosScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: music,
                builder: (context, state) => const MusicScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: playlists,
                builder: (context, state) => const PlaylistsScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      final id = int.tryParse(state.pathParameters['id'] ?? '');
                      return PlaylistDetailScreen(playlistId: id ?? 0);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: downloads,
                builder: (context, state) => const WebSearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: more,
                builder: (context, state) => const MoreScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
