import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/ui_helper.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/review_service.dart';
import '../../data/google_profile_service.dart';
import '../../data/profile_accounts_database.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _google = GoogleProfileService.instance;
  final _accountsDatabase = ProfileAccountsDatabase.instance;
  SignedInProfile? _profile;
  List<SavedProfileAccount> _savedAccounts = const [];
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restoreAccount();
  }

  Future<void> _restoreAccount() async {
    await _reloadSavedAccounts();
    if (!mounted) return;
    try {
      final profile = await _google.currentProfile();
      if (mounted) setState(() => _profile = profile);
      if (profile != null) await _rememberProfile(profile);
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _google.signIn();
      final profile = await _google.currentProfile();
      if (mounted) setState(() => _profile = profile);
      if (profile != null) await _rememberProfile(profile);
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _google.signOut();
      if (mounted) setState(() => _profile = null);
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rememberProfile(SignedInProfile profile) async {
    try {
      await _accountsDatabase.save(
        id: profile.id,
        email: profile.email,
        displayName: profile.displayName,
        photoUrl: profile.photoUrl,
      );
      await _reloadSavedAccounts();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save this profile on the device.');
      }
    }
  }

  Future<void> _reloadSavedAccounts() async {
    try {
      final accounts = await _accountsDatabase.getAll();
      if (mounted) setState(() => _savedAccounts = accounts);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not load saved profiles from this device.',
        );
      }
    }
  }

  Future<void> _removeSavedAccount(SavedProfileAccount account) async {
    try {
      await _accountsDatabase.remove(account.id);
      await _reloadSavedAccounts();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not remove the saved profile.');
      }
    }
  }

  String _friendlyError(Object error) {
    if (error is StateError) {
      return 'Google sign-in needs an OAuth client ID configured for this app.';
    }
    return 'Google sign-in failed. Check the app OAuth setup and try again.';
  }

  // ── Shortcut / support actions ─────────────────────────────────────────

  /// YouTube subscriptions live on the web, so open them in the in-app browser.
  void _openSubscriptions() {
    context.push(
      AppRouter.website,
      extra: 'https://www.youtube.com/feed/subscriptions',
    );
  }

  Future<void> _shareApp() async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              '${AppConstants.appName} — ${AppConstants.appTagline}\n'
              '${AppConstants.googlePlayUrl}',
        ),
      );
    } catch (_) {
      _showMessage('Sharing is not available on this device.');
    }
  }

  Future<void> _likeUs() async {
    try {
      await ReviewService.openStoreListing();
    } catch (_) {
      _showMessage('Could not open the store listing.');
    }
  }

  Future<void> _checkForUpdate() => _openExternal(AppConstants.googlePlayUrl);

  Future<void> _sendFeedback() async {
    final info = await PackageInfo.fromPlatform();
    final uri = Uri(
      scheme: 'mailto',
      path: AppConstants.supportEmail,
      queryParameters: {
        'subject': '${AppConstants.appName} feedback',
        'body':
            'Tell us what to improve:\n\n'
            'App Version: ${info.version}\n'
            'Build: ${info.buildNumber}\n',
      },
    );
    if (!await canLaunchUrl(uri)) {
      _showMessage('No email app found on this device.');
      return;
    }
    await launchUrl(uri);
  }

  Future<void> _openHelp() => _openExternal('${AppConstants.websiteUrl}/help');

  Future<void> _openExternal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    _showMessage('Could not open $url');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: UIHelper.screenPadding,
        children: [
          const SizedBox(height: UIHelper.spaceLG),
          CircleAvatar(
            radius: 48,
            backgroundColor: theme.colorScheme.primaryContainer,
            backgroundImage: _profile?.photoUrl == null
                ? null
                : NetworkImage(_profile!.photoUrl!),
            child: _profile?.photoUrl != null
                ? null
                : Icon(
                    Icons.person_outline_rounded,
                    size: 48,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
          ),
          const SizedBox(height: UIHelper.spaceMD),
          Text(
            _profile?.displayName ?? _profile?.email ?? 'Your profile',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          if (_profile != null) ...[
            const SizedBox(height: UIHelper.spaceXS),
            Text(
              _profile!.email,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: UIHelper.spaceXL),
          if (_busy)
            const Center(child: CircularProgressIndicator())
          else if (_profile == null)
            FilledButton.icon(
              onPressed: _google.isConfigured ? _signIn : null,
              icon: const Icon(Icons.login_rounded),
              label: const Text('Continue with Google'),
            )
          else
            OutlinedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out'),
            ),

          // ── Personal shortcuts ──────────────────────────────────────
          const SizedBox(height: UIHelper.spaceXL),
          _ProfileShortcuts(
            items: [
              _ProfileShortcut(
                icon: Icons.folder_open_rounded,
                label: 'My Files',
                onTap: () => context.push(AppRouter.downloadDetails),
              ),
              _ProfileShortcut(
                icon: Icons.history_rounded,
                label: 'History',
                onTap: () => context.push(AppRouter.history),
              ),
              _ProfileShortcut(
                icon: Icons.subscriptions_outlined,
                label: 'Subscription',
                onTap: _openSubscriptions,
              ),
              _ProfileShortcut(
                icon: Icons.queue_music_rounded,
                label: 'Playlist',
                onTap: () => context.push(AppRouter.playlists),
              ),
            ],
          ),

          // ── App actions ─────────────────────────────────────────────
          const SizedBox(height: UIHelper.spaceMD),
          _ProfileActionBox(
            items: [
              _ProfileAction(
                icon: Icons.share_outlined,
                label: 'Share',
                onTap: _shareApp,
              ),
              _ProfileAction(
                icon: Icons.favorite_outline_rounded,
                label: 'Like us',
                onTap: _likeUs,
              ),
              _ProfileAction(
                icon: Icons.system_update_alt_rounded,
                label: 'Update',
                onTap: _checkForUpdate,
              ),
              _ProfileAction(
                icon: Icons.rate_review_outlined,
                label: 'Feedback',
                onTap: _sendFeedback,
              ),
              _ProfileAction(
                icon: Icons.help_outline_rounded,
                label: 'Help',
                onTap: _openHelp,
              ),
              _ProfileAction(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () => context.push(AppRouter.settings),
              ),
            ],
          ),

          if (!_google.isConfigured) ...[
            const SizedBox(height: UIHelper.spaceMD),
            const Text(
              'Google sign-in needs an OAuth web client ID. Configure '
              'GOOGLE_SERVER_CLIENT_ID when building the app to enable it.',
              textAlign: TextAlign.center,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: UIHelper.spaceMD),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          if (_savedAccounts.isNotEmpty) ...[
            const SizedBox(height: UIHelper.spaceXL),
            Text(
              'Accounts saved on this device',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: UIHelper.spaceSM),
            for (final account in _savedAccounts)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: account.photoUrl == null
                        ? null
                        : NetworkImage(account.photoUrl!),
                    child: account.photoUrl == null
                        ? const Icon(Icons.person_outline_rounded)
                        : null,
                  ),
                  title: Text(account.displayName ?? account.email),
                  subtitle: account.displayName == null
                      ? null
                      : Text(account.email),
                  trailing: IconButton(
                    tooltip: 'Remove saved profile',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _removeSavedAccount(account),
                  ),
                ),
              ),
          ],
          const SizedBox(height: UIHelper.spaceLG),
          Text(
            'Google handles sign-in securely. This app never asks for or '
            'stores your Google password.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A personal-content shortcut on the Profile page.
class _ProfileShortcut {
  const _ProfileShortcut({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// Two-column grid of shortcuts shown under the profile header
/// (My Files, History, Subscription, Playlist).
class _ProfileShortcuts extends StatelessWidget {
  const _ProfileShortcuts({required this.items});

  final List<_ProfileShortcut> items;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var index = 0; index < items.length; index += 2) {
      if (index > 0) rows.add(UIHelper.vSM);
      final hasSecond = index + 1 < items.length;
      rows.add(
        Row(
          children: [
            Expanded(child: _ShortcutCard(item: items[index])),
            UIHelper.hSM,
            Expanded(
              child: hasSecond
                  ? _ShortcutCard(item: items[index + 1])
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
    }
    return Column(children: rows);
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({required this.item});

  final _ProfileShortcut item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(UIHelper.radiusMD),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(UIHelper.radiusMD),
        child: Padding(
          padding: const EdgeInsets.all(UIHelper.spaceSM + 4),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(UIHelper.radiusSM),
                ),
                child: Icon(item.icon, size: 20, color: colors.primary),
              ),
              UIHelper.hSM,
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
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

/// An app-level action inside the grouped actions box.
class _ProfileAction {
  const _ProfileAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// One grouped card holding the app actions
/// (Share, Like us, Update, Feedback, Help, Settings).
class _ProfileActionBox extends StatelessWidget {
  const _ProfileActionBox({required this.items});

  final List<_ProfileAction> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(UIHelper.radiusMD),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: UIHelper.spaceSM + 4,
                vertical: 2,
              ),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(UIHelper.radiusSM),
                ),
                child: Icon(items[index].icon, color: colors.primary, size: 21),
              ),
              title: Text(
                items[index].label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: colors.outline,
              ),
              onTap: items[index].onTap,
            ),
            if (index != items.length - 1)
              Divider(
                height: 1,
                indent: 68,
                endIndent: 12,
                color: colors.outlineVariant.withValues(alpha: 0.55),
              ),
          ],
        ],
      ),
    );
  }
}
