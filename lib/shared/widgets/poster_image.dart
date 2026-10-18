import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/constants/ui_helper.dart';
import '../../domain/entities/media_item.dart';

/// Small reusable poster widget that handles network, file and placeholder
/// sources uniformly so every screen shows media art identically.
class PosterImage extends StatelessWidget {
  final String? path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final IconData placeholder;

  const PosterImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder = Icons.video_file_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final child = _buildImage(theme);

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(UIHelper.radiusSM),
        child: child,
      ),
    );
  }

  Widget _buildImage(ThemeData theme) {
    if (path == null || path!.isEmpty) return _placeholder(theme);
    if (path!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: path!,
        fit: fit,
        placeholder: (_, __) => _placeholder(theme),
        errorWidget: (_, __, ___) => _placeholder(theme),
      );
    }
    if (path!.startsWith('file://')) {
      return Image.file(
        File(path!.replaceFirst('file://', '')),
        fit: fit,
        errorBuilder: (_, __, ___) => _placeholder(theme),
      );
    }
    return Image.file(
      File(path!),
      fit: fit,
      errorBuilder: (_, __, ___) => _placeholder(theme),
    );
  }

  Widget _placeholder(ThemeData theme) => Container(
    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
    child: Center(
      child: Icon(
        placeholder,
        size: UIHelper.iconLG,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

/// Artwork tile used across library cards. It prefers extracted media art and
/// builds a distinct album-style cover when a song has no embedded artwork.
class MediaArtwork extends StatelessWidget {
  const MediaArtwork({
    super.key,
    required this.item,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final MediaItem item;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (item.thumbnailPath?.isNotEmpty == true || !item.isAudio) {
      return PosterImage(
        path: item.thumbnailPath,
        width: width,
        height: height,
        fit: fit,
        placeholder: item.isAudio
            ? Icons.music_note_rounded
            : Icons.movie_rounded,
      );
    }

    final seed = item.displayName.hashCode & 0x7fffffff;
    final hue = (seed % 360).toDouble();
    final first = HSLColor.fromAHSL(1, hue, .62, .32).toColor();
    final second = HSLColor.fromAHSL(1, (hue + 48) % 360, .68, .52).toColor();
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(UIHelper.radiusSM),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [first, second],
            ),
          ),
          child: Stack(
            children: [
              const Center(
                child: Icon(
                  Icons.album_rounded,
                  size: 56,
                  color: Colors.white70,
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Text(
                  item.album?.isNotEmpty == true
                      ? item.album!
                      : item.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
