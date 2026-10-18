import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/ui_helper.dart';
import '../../../../core/router/app_router.dart';
import '../../domain/web_search_models.dart';
import '../controllers/web_search_providers.dart';
import '../widgets/download_options_sheet.dart';

/// YouTube channel page with Home, Videos, Playlists and More sections.
class ChannelDetailScreen extends ConsumerStatefulWidget {
  final String channelId;
  final WebResult? preview;

  const ChannelDetailScreen({super.key, required this.channelId, this.preview});

  @override
  ConsumerState<ChannelDetailScreen> createState() =>
      _ChannelDetailScreenState();
}

class _ChannelDetailScreenState extends ConsumerState<ChannelDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);
  bool _following = false;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(youtubeChannelProvider(widget.channelId));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          async.value?.title ?? widget.preview?.title ?? 'Channel',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Open on YouTube',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => launchUrl(
              Uri.parse('https://www.youtube.com/channel/${widget.channelId}'),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'HOME'),
            Tab(text: 'VIDEOS'),
            Tab(text: 'PLAYLISTS'),
            Tab(text: 'MORE'),
          ],
        ),
      ),
      body: async.when(
        loading: () => Column(
          children: [
            _ChannelIdentity(
              title: widget.preview?.title ?? '',
              avatar: widget.preview?.thumbnailUrl,
              subscribers: null,
              following: _following,
              onFollow: _toggleFollow,
            ),
            const Expanded(child: Center(child: CircularProgressIndicator())),
          ],
        ),
        error: (error, _) => UIHelper.emptyState(
          context: context,
          icon: Icons.cloud_off,
          message: error is WebSearchNotConfigured
              ? error.message
              : 'Could not load this channel. Please try again.',
        ),
        data: (channel) => Column(
          children: [
            _ChannelIdentity(
              title: channel.title,
              avatar: channel.avatarUrl,
              subscribers: channel.subscriberCount,
              following: _following,
              onFollow: _toggleFollow,
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _videoList(
                    channel.latestVideos,
                    heading: "What's New | ${channel.title}",
                  ),
                  _videoList(channel.latestVideos),
                  _emptyTab(
                    Icons.video_library_outlined,
                    'No playlists are available for this channel.',
                  ),
                  _moreTab(channel),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleFollow() => setState(() => _following = !_following);

  Widget _videoList(List<WebResult> videos, {String? heading}) {
    if (videos.isEmpty) {
      return _emptyTab(Icons.play_circle_outline, 'No videos found.');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (heading != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              heading,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        for (final video in videos)
          _ChannelVideoTile(
            video: video,
            channelId: widget.channelId,
            recommendations: videos,
          ),
      ],
    );
  }

  Widget _moreTab(YouTubeChannelDetails channel) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      if (channel.description?.isNotEmpty == true) Text(channel.description!),
      const SizedBox(height: 20),
      _statLine('Subscribers', channel.subscriberCount),
      _statLine('Videos', channel.videoCount),
      _statLine('Views', channel.viewCount),
    ],
  );

  Widget _statLine(String label, int? value) => ListTile(
    title: Text(label),
    trailing: Text(value == null ? '—' : _compact(value)),
  );

  Widget _emptyTab(IconData icon, String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    ),
  );

  String _compact(int n) => n >= 1000000
      ? '${(n / 1000000).toStringAsFixed(2)}M'
      : n >= 1000
      ? '${(n / 1000).toStringAsFixed(1)}K'
      : '$n';
}

class _ChannelIdentity extends StatelessWidget {
  const _ChannelIdentity({
    required this.title,
    required this.avatar,
    required this.subscribers,
    required this.following,
    required this.onFollow,
  });
  final String title;
  final String? avatar;
  final int? subscribers;
  final bool following;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundImage: avatar == null ? null : NetworkImage(avatar!),
            child: avatar == null ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subscribers == null
                      ? 'YouTube channel'
                      : '${_compactNumber(subscribers!)} subscribers',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onFollow,
            child: Text(
              following ? 'FOLLOWING' : '+ FOLLOW',
              style: TextStyle(
                color: following
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _compactNumber(int n) => n >= 1000000
      ? '${(n / 1000000).toStringAsFixed(2)}M'
      : n >= 1000
      ? '${(n / 1000).toStringAsFixed(1)}K'
      : '$n';
}

class _ChannelVideoTile extends StatelessWidget {
  const _ChannelVideoTile({
    required this.video,
    required this.channelId,
    required this.recommendations,
  });
  final WebResult video;
  final String channelId;
  final List<WebResult> recommendations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => context.push(
              AppRouter.videoPlayer,
              extra: {
                'uri': video.url,
                'title': video.title,
                'webResult': video,
                'recommendations': recommendations,
              },
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                width: 132,
                height: 84,
                child: video.thumbnailUrl == null
                    ? ColoredBox(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.play_circle_outline),
                      )
                    : Image.network(
                        video.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => ColoredBox(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.play_circle_outline),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () => context.push(
                AppRouter.videoPlayer,
                extra: {
                  'uri': video.url,
                  'title': video.title,
                  'webResult': video,
                  'recommendations': recommendations,
                },
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    video.subtitle ?? 'YouTube',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    video.publishedAt == null ? '' : _age(video.publishedAt!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Consumer(
            builder: (context, ref, _) => IconButton(
              tooltip: 'Download video',
              onPressed: () => showDownloadOptionsSheet(context, video),
              icon: const Icon(Icons.download_outlined),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'channel') {
                context.push(AppRouter.channelPath(channelId));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'channel', child: Text('Channel details')),
            ],
          ),
        ],
      ),
    );
  }

  String _age(DateTime date) {
    final delta = DateTime.now().difference(date);
    if (delta.inDays >= 365) return '${delta.inDays ~/ 365}y ago';
    if (delta.inDays >= 30) return '${delta.inDays ~/ 30}mo ago';
    if (delta.inDays >= 1) return '${delta.inDays}d ago';
    if (delta.inHours >= 1) return '${delta.inHours}h ago';
    return '${delta.inMinutes.clamp(1, 59)}m ago';
  }
}
