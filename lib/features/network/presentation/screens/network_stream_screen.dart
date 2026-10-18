import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/ui_helper.dart';
import '../../../../core/router/app_router.dart';

/// Network stream player supporting HTTP, HTTPS, HLS, DASH, RTSP, RTMP.
class NetworkStreamScreen extends StatefulWidget {
  const NetworkStreamScreen({super.key});

  @override
  State<NetworkStreamScreen> createState() => _NetworkStreamScreenState();
}

class _NetworkStreamScreenState extends State<NetworkStreamScreen> {
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();
  String _detectedProtocol = '';

  static const _protocolHints = {
    'http': 'HTTP stream',
    'https': 'HTTPS stream',
    'm3u8': 'HLS stream',
    'mpd': 'DASH stream',
    'rtsp': 'RTSP (IP cameras, CCTV)',
    'rtmp': 'RTMP (live streaming)',
    'smb': 'SMB shared folder',
    'ftp': 'FTP server',
    'sftp': 'SFTP (secure FTP)',
    'nfs': 'NFS mount',
    'upnp': 'UPnP / DLNA',
    'dlna': 'DLNA media server',
  };

  static const _exampleUrls = [
    _ExampleItem(label: 'HLS Test', url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8'),
    _ExampleItem(label: 'Big Buck Bunny', url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4'),
    _ExampleItem(label: 'Sintel', url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4'),
  ];

  void _detectProtocol(String url) {
    final lower = url.toLowerCase();
    String detected = 'http';
    for (final key in _protocolHints.keys) {
      if (lower.contains('.$key') || lower.startsWith('$key://')) {
        detected = key;
        break;
      }
    }
    setState(() => _detectedProtocol = detected);
  }

  void _playUrl() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    final isVideo = url.toLowerCase().contains('.m3u8') ||
        url.toLowerCase().contains('.mpd') ||
        url.toLowerCase().endsWith('.mp4') ||
        url.toLowerCase().endsWith('.mkv') ||
        url.toLowerCase().endsWith('.webm');

    final title = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : url.split('/').last;

    if (isVideo) {
      context.push(AppRouter.videoPlayer, extra: {
        'uri': url,
        'title': title,
      });
    } else {
      context.push(AppRouter.audioPlayer, extra: {
        'uri': url,
        'title': title,
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Open Network Stream')),
      body: SingleChildScrollView(
        padding: UIHelper.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // URL input
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Stream URL',
                hintText: 'https://example.com/video.m3u8',
                prefixIcon: const Icon(Icons.link),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste),
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null) {
                      _urlController.text = data!.text!;
                      _detectProtocol(data.text!);
                    }
                  },
                ),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              onChanged: _detectProtocol,
            ),
            UIHelper.vSM,

            // Protocol detection
            if (_detectedProtocol.isNotEmpty)
              Chip(
                avatar: Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.primary,
                  size: 16,
                ),
                label: Text(_protocolHints[_detectedProtocol] ?? _detectedProtocol),
                backgroundColor: theme.colorScheme.primaryContainer,
              ),

            UIHelper.vMD,

            // Optional name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name (optional)',
                hintText: 'My Stream',
                prefixIcon: Icon(Icons.label_outline),
                border: OutlineInputBorder(),
              ),
            ),
            UIHelper.vLG,

            // Play button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _playUrl,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play Stream'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            UIHelper.vLG,

            // Supported protocols
            Text('Supported Protocols', style: theme.textTheme.titleMedium),
            UIHelper.vSM,
            Wrap(
              spacing: UIHelper.spaceSM,
              runSpacing: UIHelper.spaceSM,
              children: ['HTTP', 'HTTPS', 'HLS', 'DASH', 'RTSP', 'RTMP', 'SMB', 'FTP', 'SFTP', 'NFS']
                  .map((p) => Chip(label: Text(p, style: const TextStyle(fontSize: 12))))
                  .toList(),
            ),
            UIHelper.vLG,

            // Example URLs
            Text('Test Streams', style: theme.textTheme.titleMedium),
            UIHelper.vSM,
            ..._exampleUrls.map((example) => Card(
                  child: ListTile(
                    title: Text(example.label),
                    subtitle: Text(
                      example.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    trailing: const Icon(Icons.play_circle_outline),
                    onTap: () {
                      _urlController.text = example.url;
                      _detectProtocol(example.url);
                    },
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _ExampleItem {
  final String label;
  final String url;
  const _ExampleItem({required this.label, required this.url});
}
