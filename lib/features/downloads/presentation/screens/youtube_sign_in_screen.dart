import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../shared/widgets/app_logo.dart';
import '../../../profile/data/google_profile_service.dart';

/// Sign-in prompt for YouTube-linked features (Private / sync).
class YoutubeSignInScreen extends StatefulWidget {
  const YoutubeSignInScreen({super.key});

  @override
  State<YoutubeSignInScreen> createState() => _YoutubeSignInScreenState();
}

class _YoutubeSignInScreenState extends State<YoutubeSignInScreen> {
  final _google = GoogleProfileService.instance;
  bool _busy = false;
  String? _error;
  GoogleSignInAccount? _account;

  static const _features = [
    (_FeatureIcon.youtube, 'Subscriptions'),
    (_FeatureIcon.watchLater, 'Watch Later'),
    (_FeatureIcon.history, 'History'),
    (_FeatureIcon.like, 'Like & Dislike videos'),
    (_FeatureIcon.person, 'Personalized recommendations'),
  ];

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    if (!_google.isConfigured) return;
    try {
      final account = await _google.restoreAccount();
      if (mounted) setState(() => _account = account);
    } catch (_) {}
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_google.isConfigured) {
        await prefs.setBool('downloads_youtube_signed_in_v1', true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Private folder unlocked')),
        );
        Navigator.of(context).pop(true);
        return;
      }
      final account = await _google.signIn();
      await prefs.setBool('downloads_youtube_signed_in_v1', true);
      if (!mounted) return;
      setState(() => _account = account);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signed in as ${account.email}')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is StateError
            ? 'Google sign-in needs an OAuth client ID configured for this app.'
            : 'Sign-in was cancelled or failed. Try again.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const youtubeRed = Color(0xFFE62117);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        title: const Text(
          'Sign in with YouTube',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 18),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: theme.colorScheme.outlineVariant),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppLogo(size: 56, radius: 12, showShadow: false),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Icon(
                    Icons.swap_horiz_rounded,
                    size: 28,
                    color: Colors.grey.shade400,
                  ),
                ),
                Container(
                  width: 56,
                  height: 56,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: youtubeRed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SvgPicture.asset(
                    'assets/icons/youtube.svg',
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'Sign in with YouTube',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'to unlock following featrues',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            for (final feature in _features)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                  children: [
                    _FeatureLeading(kind: feature.$1),
                    const SizedBox(width: 14),
                    Text(
                      feature.$2,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            if (_account != null) ...[
              const SizedBox(height: 8),
              Text(
                'Signed in as ${_account!.email}',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 36),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _busy ? null : _signIn,
                style: FilledButton.styleFrom(
                  backgroundColor: youtubeRed,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: youtubeRed.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Sign in',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _FeatureIcon { youtube, watchLater, history, like, person }

class _FeatureLeading extends StatelessWidget {
  const _FeatureLeading({required this.kind});
  final _FeatureIcon kind;

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case _FeatureIcon.youtube:
        return Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          child: SvgPicture.asset(
            'assets/icons/youtube.svg',
            width: 22,
            height: 22,
            colorFilter: const ColorFilter.mode(
              Color(0xFFE62117),
              BlendMode.srcIn,
            ),
          ),
        );
      case _FeatureIcon.watchLater:
        return const Icon(Icons.access_time_rounded, color: Color(0xFF2196F3));
      case _FeatureIcon.history:
        return const Icon(Icons.history_rounded, color: Color(0xFF26C6DA));
      case _FeatureIcon.like:
        return const Icon(Icons.thumb_up_rounded, color: Color(0xFFFBC02D));
      case _FeatureIcon.person:
        return const Icon(Icons.person_rounded, color: Color(0xFF43A047));
    }
  }
}
