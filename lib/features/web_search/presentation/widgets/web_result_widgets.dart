import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/ui_helper.dart';
import '../../../../core/router/app_router.dart';
import '../../domain/web_search_models.dart';
import 'download_options_sheet.dart';

Future<void> openWebResult(
  BuildContext context,
  WebResult r, {
  List<WebResult> recommendations = const [],
}) async {
  if (r.kind == WebResultKind.channel) {
    context.push(AppRouter.channelPath(r.id), extra: r);
    return;
  }
  if (r.kind == WebResultKind.video && r.source == 'YouTube') {
    context.push(
      AppRouter.videoPlayer,
      extra: {
        'uri': r.url,
        'title': r.title,
        'webResult': r,
        'recommendations': recommendations
            .where((v) => v.kind == WebResultKind.video)
            .toList(),
      },
    );
    return;
  }
  final uri = Uri.tryParse(r.url);
  if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Wide search result card with a prominent thumbnail and inline download.
class WebResultCard extends ConsumerWidget {
  final WebResult result;
  final List<WebResult> recommendations;

  const WebResultCard({
    super.key,
    required this.result,
    this.recommendations = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final r = result;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => openWebResult(
              context,
              r,
              recommendations: recommendations,
            ),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 218,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.16),
                    blurRadius: 0,
                    offset: const Offset(0, 5),
                  ),
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.10),
                    blurRadius: 0,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _Thumb(url: r.thumbnailUrl, kind: r.kind),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.65),
                          ],
                        ),
                      ),
                    ),
                    if (r.kind == WebResultKind.playlist)
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.playlist_play_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                r.itemCount != null
                                    ? '${r.itemCount} Videos'
                                    : 'Playlist',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (r.kind != WebResultKind.playlist)
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Text(
                          r.source,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => openWebResult(
                    context,
                    r,
                    recommendations: recommendations,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (r.subtitle != null && r.subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          r.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (r.isDownloadable)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.download_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 28,
                  ),
                  tooltip: 'Download',
                  onPressed: r.kind == WebResultKind.image
                      ? () => downloadImageResult(context, ref, r)
                      : () => showDownloadOptionsSheet(context, r),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class WebSearchTopTab extends StatelessWidget {
  const WebSearchTopTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected
                  ? theme.colorScheme.onSurface
                  : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class WebSearchFilterChip extends StatelessWidget {
  const WebSearchFilterChip({
    super.key,
    required this.label,
    required this.onTap,
    this.value,
  });
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        onPressed: onTap,
        avatar: null,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value ?? label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          ],
        ),
        backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.65,
        ),
        side: BorderSide.none,
        shape: const StadiumBorder(),
      ),
    );
  }
}

/// Round avatar tile for a YouTube channel; tapping opens its detail page.
class ChannelTile extends StatelessWidget {
  final WebResult channel;

  const ChannelTile({super.key, required this.channel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => openWebResult(context, channel),
      borderRadius: BorderRadius.circular(UIHelper.radiusMD),
      child: SizedBox(
        width: 96,
        child: Column(
          children: [
            ClipOval(
              child: SizedBox(
                width: 64,
                height: 64,
                child: _Thumb(url: channel.thumbnailUrl, kind: channel.kind),
              ),
            ),
            UIHelper.vXS,
            Text(
              channel.title,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PictureGrid extends ConsumerWidget {
  final List<WebResult> pictures;

  const PictureGrid({super.key, required this.pictures});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: pictures.length,
      itemBuilder: (context, i) {
        final r = pictures[i];
        return ClipRRect(
          borderRadius: BorderRadius.circular(UIHelper.radiusSM),
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                onTap: () => openWebResult(context, r),
                child: _Thumb(url: r.thumbnailUrl, kind: r.kind),
              ),
              Positioned(
                right: 4,
                bottom: 4,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.download_rounded),
                    color: Colors.white,
                    tooltip: 'Download picture',
                    onPressed: () => downloadImageResult(context, ref, r),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Thumb extends StatelessWidget {
  final String? url;
  final WebResultKind kind;

  const _Thumb({required this.url, required this.kind});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(switch (kind) {
        WebResultKind.channel => Icons.person,
        WebResultKind.image => Icons.image_outlined,
        WebResultKind.web => Icons.public,
        _ => Icons.play_circle_outline,
      }, color: scheme.outline),
    );
    if (url == null) return placeholder;
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => placeholder,
    );
  }
}

/// Bottom sheet for sort order, upload date and duration filters.
Future<WebSearchFilters?> showWebSearchFilters(
  BuildContext context,
  WebSearchFilters current,
) {
  return showModalBottomSheet<WebSearchFilters>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _FilterSheet(initial: current),
  );
}

class _FilterSheet extends StatefulWidget {
  final WebSearchFilters initial;

  const _FilterSheet({required this.initial});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late WebSearchFilters _f = widget.initial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget group<T>(
      String title,
      List<T> values,
      T selected,
      String Function(T) label,
      ValueChanged<T> onSelect,
    ) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          UIHelper.vSM,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in values)
                ChoiceChip(
                  label: Text(label(v)),
                  selected: v == selected,
                  onSelected: (_) => setState(() => onSelect(v)),
                ),
            ],
          ),
          UIHelper.vMD,
        ],
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filters',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            UIHelper.vMD,
            group(
              'Sort by',
              WebSortOrder.values,
              _f.order,
              (v) => v.label,
              (v) => _f = _f.copyWith(order: v),
            ),
            group(
              'Upload date',
              WebUploadDate.values,
              _f.uploadDate,
              (v) => v.label,
              (v) => _f = _f.copyWith(uploadDate: v),
            ),
            group(
              'Duration (videos)',
              WebDuration.values,
              _f.duration,
              (v) => v.label,
              (v) => _f = _f.copyWith(duration: v),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () =>
                      setState(() => _f = const WebSearchFilters()),
                  child: const Text('Reset'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(context, _f),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
