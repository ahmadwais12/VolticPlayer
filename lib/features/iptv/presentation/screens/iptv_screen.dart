import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/ui_helper.dart';
import '../../../../core/router/app_router.dart';

/// IPTV channel model.
class IPTVChannel {
  final String name;
  final String url;
  final String? logo;
  final String group;
  final String? tvgId;

  const IPTVChannel({
    required this.name,
    required this.url,
    this.logo,
    this.group = 'Uncategorized',
    this.tvgId,
  });
}

/// IPTV playlist provider.
class IPTVPlaylistNotifier extends Notifier<List<IPTVChannel>> {
  @override
  List<IPTVChannel> build() => [];

  /// Parse an M3U/M3U8 playlist from text content.
  void parseM3U(String content) {
    final channels = <IPTVChannel>[];
    final lines = content.split('\n');
    
    String? pendingName;
    String? pendingLogo;
    String? pendingGroup;
    String? pendingTvgId;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('#EXTINF:')) {
        // Parse EXTINF line: #EXTINF:-1 tvg-id="..." tvg-logo="..." group-title="...",Channel Name
        pendingName = null;
        pendingLogo = null;
        pendingGroup = 'Uncategorized';
        pendingTvgId = null;

        // Extract tvg-logo
        final logoMatch = RegExp(r'tvg-logo="([^"]*)"').firstMatch(trimmed);
        if (logoMatch != null) pendingLogo = logoMatch.group(1);

        // Extract group-title
        final groupMatch = RegExp(r'group-title="([^"]*)"').firstMatch(trimmed);
        if (groupMatch != null) pendingGroup = groupMatch.group(1);

        // Extract tvg-id
        final tvgMatch = RegExp(r'tvg-id="([^"]*)"').firstMatch(trimmed);
        if (tvgMatch != null) pendingTvgId = tvgMatch.group(1);

        // Extract name (after last comma)
        final lastComma = trimmed.lastIndexOf(',');
        if (lastComma >= 0 && lastComma < trimmed.length - 1) {
          pendingName = trimmed.substring(lastComma + 1).trim();
        }
      } else if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
        // This is a URL line
        final url = trimmed;
        if (url.startsWith('http') || url.startsWith('rtsp') || url.startsWith('rtmp')) {
          channels.add(IPTVChannel(
            name: pendingName ?? url.split('/').last,
            url: url,
            logo: pendingLogo,
            group: pendingGroup ?? 'Uncategorized',
            tvgId: pendingTvgId,
          ));
        }
        pendingName = null;
        pendingLogo = null;
        pendingGroup = null;
        pendingTvgId = null;
      }
    }

    state = channels;
  }

  void clear() => state = [];
}

final iptvProvider =
    NotifierProvider<IPTVPlaylistNotifier, List<IPTVChannel>>(
  () => IPTVPlaylistNotifier(),
);

class IPTVScreen extends ConsumerStatefulWidget {
  const IPTVScreen({super.key});

  @override
  ConsumerState<IPTVScreen> createState() => _IPTVScreenState();
}

class _IPTVScreenState extends ConsumerState<IPTVScreen> {
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _loadFromUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fetching playlist...')),
    );

    try {
      final dio = Dio();
      final response = await dio.get(url);
      if (response.statusCode == 200 && response.data is String) {
        ref.read(iptvProvider.notifier).parseM3U(response.data as String);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Loaded ${ref.read(iptvProvider).length} channels')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to fetch playlist')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _loadFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['m3u', 'm3u8'],
      );
      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.first.path!);
      final content = await file.readAsString();
      ref.read(iptvProvider.notifier).parseM3U(content);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Loaded ${ref.read(iptvProvider).length} channels from ${result.files.first.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading file: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final channels = ref.watch(iptvProvider);
    final groups = _groupByGroup(channels);

    return Scaffold(
      appBar: AppBar(
        title: const Text('IPTV'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_open),
            onPressed: _loadFromFile,
            tooltip: 'Open M3U file',
          ),
        ],
      ),
      body: Column(
        children: [
          // URL input
          Padding(
            padding: UIHelper.screenPadding,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      hintText: 'Paste M3U/M3U8 URL',
                      prefixIcon: Icon(Icons.link),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                ),
                UIHelper.hSM,
                FilledButton(
                  onPressed: _loadFromUrl,
                  child: const Text('Load'),
                ),
              ],
            ),
          ),

          if (channels.isEmpty)
            Expanded(
              child: UIHelper.emptyState(
                context: context,
                icon: Icons.live_tv_outlined,
                message: 'No channels loaded.\nImport an M3U/M3U8 playlist to start.',
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: groups.length,
                itemBuilder: (context, groupIndex) {
                  final group = groups.keys.elementAt(groupIndex);
                  final groupChannels = groups[group]!;
                  return ExpansionTile(
                    title: Text('$group (${groupChannels.length})'),
                    initiallyExpanded: groupIndex == 0,
                    children: groupChannels.map((channel) {
                      return ListTile(
                        leading: channel.logo != null
                            ? CircleAvatar(
                                backgroundImage: NetworkImage(channel.logo!),
                                onBackgroundImageError: (_, __) {},
                              )
                            : const CircleAvatar(child: Icon(Icons.tv)),
                        title: Text(
                          channel.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.play_circle_outline),
                        onTap: () {
                          context.push(AppRouter.videoPlayer, extra: {
                            'uri': channel.url,
                            'title': channel.name,
                          });
                        },
                      );
                    }).toList(),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Map<String, List<IPTVChannel>> _groupByGroup(List<IPTVChannel> channels) {
    final groups = <String, List<IPTVChannel>>{};
    for (final ch in channels) {
      groups.putIfAbsent(ch.group, () => []).add(ch);
    }
    return groups;
  }
}
