import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/services/download_manager.dart';
import '../../../../core/services/downloader_limits.dart';
import '../../../../core/services/downloader_settings.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../controllers/video_downloader_notifier.dart';
import '../widgets/download_status_badge.dart';

const _youtubeSignedInKey = 'downloads_youtube_signed_in_v1';

enum _DownloadFilter { all, videos, music, active, private }

enum _DownloadSort { newest, oldest, name, size, status }

final Map<String, Future<Uint8List?>> _videoThumbnailCache = {};

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key, this.focusDownloading = false});

  /// When opened from the Downloads tab icon, keep Downloading above Downloaded
  /// and scroll that section into view.
  final bool focusDownloading;

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen>
    with WidgetsBindingObserver {
  _DownloadFilter _filter = _DownloadFilter.all;
  final _sort = _DownloadSort.newest;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _listScrollController = ScrollController();
  final _downloadingKey = GlobalKey();
  String _searchQuery = '';
  bool _showSearch = false;
  bool _showBanner = true;
  String? _lastClipboardPrompt;
  static const _bannerKey = 'downloads_promo_banner_dismissed_v1';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkClipboard();
      if (widget.focusDownloading) _scrollToDownloading();
    });
    _loadBannerPreference();
  }

  void _scrollToDownloading() {
    final context = _downloadingKey.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  Future<void> _loadBannerPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _showBanner = !(prefs.getBool(_bannerKey) ?? false));
  }

  Future<void> _dismissBanner() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_bannerKey, true);
    if (mounted) setState(() => _showBanner = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkClipboard();
  }

  Future<void> _checkClipboard() async {
    if (!mounted ||
        !ref.read(downloaderSettingsValueProvider).clipboardDetection) {
      return;
    }
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboard?.text?.trim();
    if (text == null || text.isEmpty || text == _lastClipboardPrompt) return;
    final uri = Uri.tryParse(text);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return;
    if (ref.read(downloadManagerProvider).findByUri(text) != null) return;
    _lastClipboardPrompt = text;
    if (!mounted) return;
    final shouldDownload = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download link detected'),
        content: const Text(
          'Would you like to open this link in the downloader?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Download'),
          ),
        ],
      ),
    );
    if (shouldDownload == true && mounted) {
      ref.read(videoDownloaderProvider.notifier).reset();
      context.push(AppRouter.videoDownloader, extra: text);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  bool _isInProgress(DownloadItem item) =>
      item.isActive || item.isPaused || item.status == DownloadStatus.failed;

  bool _isDownloaded(DownloadItem item) => item.isCompleted;

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final state = ref.watch(downloadManagerProvider);
    final preferences = ref.watch(downloaderSettingsValueProvider);
    final colors = Theme.of(context).colorScheme;
    ref.listen(downloadManagerProvider, (previous, next) {
      if (!preferences.notifyOnComplete || previous == null) return;
      final previousCompleted = previous.items
          .where((item) => item.isCompleted)
          .map((item) => item.id)
          .toSet();
      final finished = next.items.where(
        (item) => item.isCompleted && !previousCompleted.contains(item.id),
      );
      for (final item in finished) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${item.title ?? item.fileName} downloaded')),
        );
      }
    });
    final query = _searchQuery.trim().toLowerCase();
    final visibleItems = state.items.where((item) {
      if (!preferences.showHiddenFiles && item.fileName.startsWith('.')) {
        return false;
      }
      final matchesSearch =
          query.isEmpty ||
          (item.title ?? '').toLowerCase().contains(query) ||
          item.fileName.toLowerCase().contains(query);
      if (!matchesSearch) return false;
      switch (_filter) {
        case _DownloadFilter.all:
          return !item.isPrivate;
        case _DownloadFilter.videos:
          return !item.isPrivate && _isVideo(item);
        case _DownloadFilter.music:
          return !item.isPrivate && _isAudioItem(item);
        case _DownloadFilter.active:
          return !item.isPrivate && (item.isActive || item.isPaused);
        case _DownloadFilter.private:
          return item.isPrivate;
      }
    }).toList();
    visibleItems.sort((a, b) {
      switch (_sort) {
        case _DownloadSort.newest:
          return b.createdAt.compareTo(a.createdAt);
        case _DownloadSort.oldest:
          return a.createdAt.compareTo(b.createdAt);
        case _DownloadSort.name:
          return (a.title ?? a.fileName).toLowerCase().compareTo(
            (b.title ?? b.fileName).toLowerCase(),
          );
        case _DownloadSort.size:
          return b.totalBytes.compareTo(a.totalBytes);
        case _DownloadSort.status:
          return a.status.index.compareTo(b.status.index);
      }
    });

    // Downloading = queue + active + paused + failed (videos & audios).
    // Downloaded = completed files only.
    final downloadingItems = visibleItems
        .where(_isInProgress)
        .toList(growable: false);
    final downloadedItems = visibleItems
        .where(_isDownloaded)
        .toList(growable: false);
    final downloadedCount = downloadedItems.length;
    final usedBytes = state.items.fold<int>(
      0,
      (sum, item) => sum + (item.isCompleted ? item.totalBytes : 0),
    );

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text(
          'My Files',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: colors.onSurface,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Download from URL',
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: () {
              ref.read(videoDownloaderProvider.notifier).reset();
              context.push(AppRouter.videoDownloader);
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            offset: const Offset(0, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            onSelected: (value) {
              final notifier = ref.read(downloadManagerProvider.notifier);
              switch (value) {
                case 'search':
                  setState(() => _showSearch = true);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _searchFocusNode.requestFocus();
                  });
                  break;
                case 'pause_all':
                  final activeBefore = ref
                      .read(downloadManagerProvider)
                      .items
                      .where((item) => item.isActive)
                      .length;
                  notifier.pauseAll();
                  _toast(
                    activeBefore == 0
                        ? 'No active downloads to pause'
                        : 'All downloads paused',
                  );
                  break;
                case 'resume_all':
                  final resumed = notifier.resumeAll();
                  _toast(
                    resumed == 0
                        ? 'No paused downloads to resume'
                        : 'Resumed $resumed download${resumed == 1 ? '' : 's'}',
                  );
                  break;
                case 'delete':
                  _confirmDeleteCompleted(context, notifier);
                  break;
                case 'storage':
                  context.push(AppRouter.storage);
                  break;
                case 'help':
                  _showDownloadHelp(context);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'search',
                child: _MenuLabel(Icons.search, 'Search'),
              ),
              const PopupMenuItem(
                value: 'pause_all',
                child: _MenuLabel(Icons.pause_circle_outline, 'Pause All'),
              ),
              const PopupMenuItem(
                value: 'resume_all',
                child: _MenuLabel(
                  Icons.download_for_offline_outlined,
                  'Resume All',
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: _MenuLabel(Icons.delete_outline, 'Delete'),
              ),
              PopupMenuItem(
                value: 'storage',
                child: _MenuLabel(
                  Icons.phone_android_outlined,
                  '${_formatStorage(usedBytes)} USED/${_formatStorage(DownloaderLimits.maxStorageBytes)}',
                ),
              ),
              const PopupMenuItem(
                value: 'help',
                child: _MenuLabel(Icons.help_outline, 'Download help'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showBanner) _downloadBanner(context),
          if (_showSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search downloads',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      tooltip: 'Close search',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() {
                        _showSearch = false;
                        _searchQuery = '';
                        _searchController.clear();
                      }),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          Expanded(
            child: state.items.isEmpty
                ? _buildEmptyState(context)
                : visibleItems.isEmpty
                ? _buildFilterEmptyState(context)
                : ListView(
                    controller: _listScrollController,
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      // Always keep Downloading above Downloaded.
                      KeyedSubtree(
                        key: _downloadingKey,
                        child: _sectionHeading(
                          context,
                          'Downloading',
                          downloadingItems.length,
                          subtitle: downloadingItems.isEmpty
                              ? null
                              : 'Videos & audio in progress',
                        ),
                      ),
                      if (downloadingItems.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                          child: Text(
                            'No downloads in progress. Start one from search or a URL.',
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        )
                      else
                        for (final item in downloadingItems)
                          _DownloadTile(item: item),
                      _sectionHeading(
                        context,
                        'Downloaded',
                        downloadedCount,
                        action: _downloadFilterMenu(colors),
                      ),
                      if (downloadedItems.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          child: Text(
                            'No completed downloads yet.',
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        )
                      else
                        for (final item in downloadedItems)
                          _DownloadTile(item: item),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeading(
    BuildContext context,
    String title,
    int count, {
    Widget? action,
    String? subtitle,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              const Spacer(),
              if (action != null) action,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12.5, color: colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  Widget _downloadFilterMenu(ColorScheme colors) =>
      PopupMenuButton<_DownloadFilter>(
        tooltip: 'Filter files',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _filter == _DownloadFilter.all
                  ? 'All Files'
                  : _filter == _DownloadFilter.active
                  ? 'In progress'
                  : _filter.name[0].toUpperCase() + _filter.name.substring(1),
              style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant),
            ),
            Icon(Icons.arrow_drop_down, color: colors.onSurfaceVariant),
          ],
        ),
        onSelected: _selectFilter,
        itemBuilder: (_) => const [
          PopupMenuItem(value: _DownloadFilter.all, child: Text('All Files')),
          PopupMenuItem(value: _DownloadFilter.videos, child: Text('Videos')),
          PopupMenuItem(value: _DownloadFilter.music, child: Text('Music')),
          PopupMenuItem(
            value: _DownloadFilter.active,
            child: Text('In progress'),
          ),
          PopupMenuItem(value: _DownloadFilter.private, child: Text('Private')),
        ],
      );

  bool _isVideo(DownloadItem item) =>
      (item.mediaType ?? '').toLowerCase().contains('video') ||
      [
        'mp4',
        'mkv',
        'avi',
        'mov',
        'webm',
      ].contains(item.fileName.split('.').last.toLowerCase());

  bool _isAudioItem(DownloadItem item) =>
      (item.mediaType ?? '').toLowerCase().contains('audio') ||
      [
        'mp3',
        'm4a',
        'aac',
        'wav',
        'flac',
        'ogg',
        'opus',
      ].contains(item.fileName.split('.').last.toLowerCase());

  Widget _downloadBanner(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: () {
          ref.read(videoDownloaderProvider.notifier).reset();
          context.push(AppRouter.videoDownloader);
        },
        child: SizedBox(
          height: 64,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 44, 8),
                child: Row(
                  children: [
                    const AppLogo(size: 48, radius: 8, showShadow: false),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'VolticPlayer for Android',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E88E5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  tooltip: 'Dismiss',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  onPressed: _dismissBanner,
                  icon: Icon(
                    Icons.close,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectFilter(_DownloadFilter filter) async {
    setState(() => _filter = filter);
    if (filter != _DownloadFilter.private) return;
    final prefs = await SharedPreferences.getInstance();
    final signedIn = prefs.getBool(_youtubeSignedInKey) ?? false;
    if (signedIn || !mounted) return;
    await context.push<bool>(AppRouter.youtubeSignIn);
  }

  Widget _buildFilterEmptyState(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (_filter == _DownloadFilter.private) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 56,
                color: Color(0xFF9E9E9E),
              ),
              const SizedBox(height: 16),
              const Text(
                'Private files are empty',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in with YouTube and move downloads here to keep them private.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.push(AppRouter.youtubeSignIn),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE62117),
                ),
                child: const Text('Sign in with YouTube'),
              ),
            ],
          ),
        ),
      );
    }
    final isVideos = _filter == _DownloadFilter.videos;
    final isMusic = _filter == _DownloadFilter.music;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isVideos
                  ? Icons.movie_outlined
                  : isMusic
                  ? Icons.library_music_outlined
                  : Icons.cloud_download_outlined,
              size: 56,
              color: const Color(0xFF9E9E9E),
            ),
            const SizedBox(height: 16),
            Text(
              isVideos
                  ? 'No video downloads'
                  : isMusic
                  ? 'No music downloads'
                  : 'No downloads',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isVideos
                  ? 'Downloaded videos will appear here.'
                  : isMusic
                  ? 'Downloaded audio will appear here.'
                  : 'Try another filter or download a file.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_download_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No downloads yet',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Download videos and audio from URLs\nfor offline playback',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                context.push(AppRouter.videoDownloader);
              },
              icon: const Icon(Icons.download),
              label: const Text('Download from URL'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                context.push(AppRouter.networkStream);
              },
              icon: const Icon(Icons.wifi),
              label: const Text('Stream from URL'),
            ),
          ],
        ),
      ),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _confirmDeleteCompleted(BuildContext context, DownloadManager notifier) {
    final removable = ref
        .read(downloadManagerProvider)
        .items
        .where(
          (item) =>
              item.isCompleted ||
              item.status == DownloadStatus.cancelled ||
              item.status == DownloadStatus.failed,
        )
        .length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete downloaded files?'),
        content: Text(
          removable == 0
              ? 'There are no completed downloads to delete.'
              : 'Remove $removable completed/failed download record${removable == 1 ? '' : 's'}? Active downloads will stay in progress.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (removable == 0) {
                _toast('Nothing to delete');
                return;
              }
              notifier.clearCompleted();
              _toast('Deleted $removable item${removable == 1 ? '' : 's'}');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDownloadHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download help'),
        content: const Text(
          'Use the download icon near the search bar to open My Files.\n\n'
          '• Tabs filter Downloads, Videos, Music, and Private\n'
          '• ⋮ menu: Search, Pause/Resume All, Delete, Storage, Help\n'
          '• File ⋮ menu: Play, Rename, Share, Private, Details, Delete',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatStorage(int bytes) {
    final gib = bytes / (1024 * 1024 * 1024);
    return '${gib.toStringAsFixed(1)} GB';
  }
}

class _MenuLabel extends StatelessWidget {
  const _MenuLabel(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        icon,
        size: 20,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(label)),
    ],
  );
}

class _DownloadTile extends ConsumerWidget {
  final DownloadItem item;
  const _DownloadTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(downloadManagerProvider.notifier);
    final ext = item.fileName.split('.').last.toUpperCase();
    final date = item.createdAt.year <= 1970
        ? ''
        : item.createdAt.toLocal().toString().substring(0, 10);
    final quality = _qualityLabel(item);
    final showCc =
        item.hasCaptions ||
        (item.format?.toLowerCase().contains('cc') ?? false) ||
        (item.format?.toLowerCase().contains('subtitle') ?? false);

    return Material(
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: item.isCompleted && item.filePath != null
            ? () => _playFile(context, item)
            : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 0, 10),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _Thumbnail(
                    item: item,
                    quality: quality,
                    showCc: showCc && !_isAudio,
                    isAudio: _isAudio,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayTitle(item),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (!item.isCompleted) ...[
                          DownloadStatusBadge(status: item.status),
                          const SizedBox(height: 4),
                        ],
                        if (item.isCompleted)
                          Row(
                            children: [
                              Icon(
                                Icons.play_arrow,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  [
                                    if (item.totalBytes > 0)
                                      _formatBytes(item.totalBytes),
                                    if (ext.isNotEmpty) ext,
                                    if (date.isNotEmpty) date,
                                  ].join(' | '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          )
                        else if (item.totalBytes > 0)
                          Text(
                            '${_formatBytes(item.bytesReceived)} / ${_formatBytes(item.totalBytes)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        if (item.status == DownloadStatus.downloading &&
                            item.speed > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              item.formattedSpeed,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (item.status == DownloadStatus.downloading)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Pause',
                      icon: const Icon(Icons.pause_rounded),
                      onPressed: () => notifier.pause(item.uri),
                    )
                  else if (item.status == DownloadStatus.paused)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Resume',
                      icon: const Icon(Icons.play_arrow_rounded),
                      onPressed: () => notifier.resume(item.uri),
                    ),
                  IconButton(
                    tooltip: 'More',
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.more_vert,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 22,
                    ),
                    onPressed: () => _showItemActions(context, ref, item),
                  ),
                ],
              ),
              if (item.status == DownloadStatus.downloading ||
                  item.status == DownloadStatus.processing) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: item.progress > 0 ? item.progress : null,
                      minHeight: 3,
                    ),
                  ),
                ),
              ],
              if (item.status == DownloadStatus.paused) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: item.progress,
                      minHeight: 3,
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                ),
              ],
              if (item.status == DownloadStatus.failed && item.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.error!,
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _displayTitle(DownloadItem item) {
    final raw = (item.title ?? item.fileName).trim();
    if (item.fileName.isNotEmpty) {
      final stem = item.fileName.contains('.')
          ? item.fileName.substring(0, item.fileName.lastIndexOf('.'))
          : item.fileName;
      if (stem.length >= 8) return stem;
    }
    return raw;
  }

  String? _qualityLabel(DownloadItem item) {
    final source = '${item.format ?? ''} ${item.title ?? ''}';
    final match = RegExp(r'(\d{3,4})\s*[pP]').firstMatch(source);
    if (match != null) return '${match.group(1)}P HD';
    if (_isVideo(item) && item.isCompleted) return '720P HD';
    return null;
  }

  bool _isVideo(DownloadItem item) =>
      (item.mediaType ?? '').toLowerCase().contains('video') ||
      [
        'mp4',
        'mkv',
        'avi',
        'mov',
        'webm',
      ].contains(item.fileName.split('.').last.toLowerCase());

  Future<void> _showItemActions(
    BuildContext context,
    WidgetRef ref,
    DownloadItem item,
  ) async {
    final notifier = ref.read(downloadManagerProvider.notifier);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  _displayTitle(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(item.fileName),
              ),
              const Divider(height: 1),
              if (item.isCompleted && item.filePath != null)
                ListTile(
                  leading: const Icon(Icons.play_arrow_rounded),
                  title: const Text('Play'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _playFile(context, item);
                  },
                ),
              if (item.isCompleted)
                ListTile(
                  leading: const Icon(Icons.drive_file_rename_outline),
                  title: const Text('Rename'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _renameItem(context, notifier, item);
                  },
                ),
              if (item.isCompleted && item.filePath != null)
                ListTile(
                  leading: const Icon(Icons.share_outlined),
                  title: const Text('Share'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    try {
                      await SharePlus.instance.share(
                        ShareParams(files: [XFile(item.filePath!)]),
                      );
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not share file')),
                        );
                      }
                    }
                  },
                ),
              if (item.isCompleted)
                ListTile(
                  leading: Icon(
                    item.isPrivate
                        ? Icons.lock_open_outlined
                        : Icons.lock_outline_rounded,
                  ),
                  title: Text(
                    item.isPrivate ? 'Remove from Private' : 'Move to Private',
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    if (!item.isPrivate) {
                      final prefs = await SharedPreferences.getInstance();
                      final signedIn =
                          prefs.getBool(_youtubeSignedInKey) ?? false;
                      if (!signedIn && context.mounted) {
                        final ok = await context.push<bool>(
                          AppRouter.youtubeSignIn,
                        );
                        if (ok != true) return;
                      }
                    }
                    final makingPrivate = !item.isPrivate;
                    notifier.setPrivate(item.uri, value: makingPrivate);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            makingPrivate
                                ? 'Moved to Private'
                                : 'Removed from Private',
                          ),
                        ),
                      );
                    }
                  },
                ),
              if (item.isCompleted)
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Details'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showDetails(context, item);
                  },
                ),
              if (item.status == DownloadStatus.failed)
                ListTile(
                  leading: const Icon(Icons.refresh_rounded),
                  title: const Text('Retry'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    notifier.download(
                      uri: item.uri,
                      fileName: item.fileName,
                      title: item.title,
                      sourceUrl: item.sourceUrl,
                      format: item.format,
                      mediaType: item.mediaType,
                      thumbnailUrl: item.thumbnailUrl,
                      durationMs: item.durationMs,
                      hasCaptions: item.hasCaptions,
                      expectedBytes: item.totalBytes > 0
                          ? item.totalBytes
                          : null,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Retrying download')),
                    );
                  },
                ),
              if (item.isCompleted)
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('Download again'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    notifier.downloadAgain(item);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Download started again')),
                    );
                  },
                ),
              if (item.sourceUrl != null)
                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('Copy source URL'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await Clipboard.setData(
                      ClipboardData(text: item.sourceUrl!),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link copied')),
                      );
                    }
                  },
                ),
              if (item.status == DownloadStatus.pending ||
                  item.status == DownloadStatus.downloading ||
                  item.status == DownloadStatus.processing)
                ListTile(
                  leading: const Icon(Icons.cancel_outlined),
                  title: const Text('Cancel'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    notifier.cancel(item.uri);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Download cancelled')),
                    );
                  },
                ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Delete',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  notifier.remove(item.uri);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Deleted')));
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _renameItem(
    BuildContext context,
    DownloadManager notifier,
    DownloadItem item,
  ) async {
    final controller = TextEditingController(
      text: p.basenameWithoutExtension(item.fileName),
    );
    final next = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'File name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (next == null || next.trim().isEmpty) return;
    final ok = await notifier.rename(item.uri, next);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Renamed' : 'Could not rename file')),
    );
  }

  void _showDetails(BuildContext context, DownloadItem item) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('File details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${item.fileName}'),
            if (item.format != null) Text('Format: ${item.format}'),
            if (item.totalBytes > 0)
              Text('Size: ${_formatBytes(item.totalBytes)}'),
            if (item.filePath != null) Text('Path: ${item.filePath}'),
            if (item.sourceUrl != null) Text('Source: ${item.sourceUrl}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _playFile(BuildContext context, DownloadItem item) {
    final path = item.filePath!;
    final ext = path.split('.').last.toLowerCase();
    final isVideo = ['mp4', 'mkv', 'avi', 'mov', 'webm'].contains(ext);
    final uri = path.startsWith('file://') ? path : Uri.file(path).toString();
    if (isVideo) {
      context.push(
        AppRouter.videoPlayer,
        extra: {'uri': uri, 'title': item.title ?? 'Video'},
      );
    } else {
      context.push(
        AppRouter.audioPlayer,
        extra: {'uri': uri, 'title': item.title ?? 'Audio'},
      );
    }
  }

  bool get _isAudio =>
      (item.mediaType ?? '').toLowerCase().contains('audio') ||
      [
        'mp3',
        'm4a',
        'aac',
        'wav',
        'flac',
        'ogg',
      ].contains(item.fileName.split('.').last.toLowerCase());

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.item,
    required this.quality,
    required this.showCc,
    required this.isAudio,
  });

  final DownloadItem item;
  final String? quality;
  final bool showCc;
  final bool isAudio;

  String? _formatDuration(int? ms) {
    if (ms == null || ms <= 0) return null;
    final total = Duration(milliseconds: ms);
    final hours = total.inHours;
    final minutes = total.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = total.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final knownDuration = _formatDuration(item.durationMs);
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        width: 120,
        height: 68,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.thumbnailUrl != null)
              Image.network(
                item.thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(theme),
              )
            else
              _fallback(theme),
            if (showCc)
              Positioned(
                right: 3,
                top: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 1,
                  ),
                  color: const Color(0xFF7B1FA2),
                  child: const Text(
                    'CC',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            if (quality != null)
              Positioned(
                left: 3,
                bottom: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEB3B),
                    border: Border.all(
                      color: const Color(0xFFF9A825),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    quality!,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            if (knownDuration != null)
              Positioned(
                right: 3,
                bottom: 3,
                child: _DurationChip(label: knownDuration),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fallback(ThemeData theme) {
    final placeholder = Icon(
      isAudio ? Icons.music_note_rounded : Icons.play_arrow_rounded,
      size: 28,
      color: theme.colorScheme.onSurfaceVariant,
    );
    if (isAudio || !item.isCompleted || item.filePath == null) {
      return ColoredBox(
        color: theme.colorScheme.surfaceContainerHighest,
        child: placeholder,
      );
    }
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: FutureBuilder<Uint8List?>(
        future: _videoThumbnailCache.putIfAbsent(item.filePath!, () async {
          try {
            return await VideoThumbnail.thumbnailData(
              video: item.filePath!,
              imageFormat: ImageFormat.JPEG,
              maxWidth: 240,
              quality: 72,
            );
          } catch (_) {
            return null;
          }
        }),
        builder: (context, snapshot) {
          if (snapshot.hasError || snapshot.data == null) return placeholder;
          return Image.memory(snapshot.data!, fit: BoxFit.cover);
        },
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      color: Colors.black.withValues(alpha: 0.72),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
    );
  }
}
