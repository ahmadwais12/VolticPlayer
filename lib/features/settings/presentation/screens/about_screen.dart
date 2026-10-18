import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/ui_helper.dart';
import '../../../../shared/widgets/app_logo.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: UIHelper.screenPadding,
        children: [
          // ── App icon ─────────────────────────────────────────────
          const Center(child: AppLogo(size: 84)),
          UIHelper.vMD,
          Center(
            child: Text(
              AppConstants.appName,
              style: theme.textTheme.titleLarge,
            ),
          ),
          Center(
            child: Text(
              'Version ${AppConstants.appVersion} (${AppConstants.appBuild})',
              style: theme.textTheme.bodySmall,
            ),
          ),
          UIHelper.vLG,

          // ── Info rows ────────────────────────────────────────────
          _TappableInfoRow(
            label: 'App Name',
            value: AppConstants.appName,
            icon: Icons.play_circle_outline,
          ),
          _TappableInfoRow(
            label: 'Version',
            value: '${AppConstants.appVersion} (${AppConstants.appBuild})',
            icon: Icons.tag,
          ),
          _TappableInfoRow(
            label: 'Privacy Policy',
            value: 'View',
            icon: Icons.description_outlined,
            onTap: () =>
                _launchUrl(context, 'https://volticplayer.app/privacy'),
          ),
          _TappableInfoRow(
            label: 'Terms of Service',
            value: 'View',
            icon: Icons.gavel_outlined,
            onTap: () => _launchUrl(context, 'https://volticplayer.app/terms'),
          ),
          _TappableInfoRow(
            label: 'Open Source Licenses',
            value: 'View',
            icon: Icons.code_outlined,
            onTap: () => showLicensePage(
              context: context,
              applicationName: AppConstants.appName,
              applicationVersion: AppConstants.appVersion,
            ),
          ),
          _TappableInfoRow(
            label: 'Language',
            value: 'English',
            icon: Icons.language_outlined,
            showDivider: false,
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open $url')));
    }
  }
}

class _TappableInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool showDivider;
  final VoidCallback? onTap;

  const _TappableInfoRow({
    required this.label,
    required this.value,
    required this.icon,
    this.showDivider = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label),
      subtitle: Text(value),
      trailing: onTap != null ? const Icon(Icons.open_in_new, size: 18) : null,
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}
