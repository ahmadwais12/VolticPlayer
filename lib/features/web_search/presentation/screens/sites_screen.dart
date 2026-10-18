import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/router/app_router.dart';

class SitesScreen extends StatefulWidget {
  const SitesScreen({super.key});

  @override
  State<SitesScreen> createState() => _SitesScreenState();
}

class _SitesScreenState extends State<SitesScreen> {
  static const _storageKey = 'web_search_custom_sites';
  static const _builtInSites = <_SiteLink>[
    _SiteLink(
      name: 'YouTube',
      url: 'https://www.youtube.com',
      asset: 'assets/icons/youtube.svg',
      color: Color(0xFFE62117),
    ),
    _SiteLink(
      name: 'WhatsApp',
      url: 'https://www.whatsapp.com',
      asset: 'assets/icons/whatsapp.svg',
      color: Color(0xFF25D366),
    ),
    _SiteLink(
      name: 'Facebook',
      url: 'https://www.facebook.com',
      asset: 'assets/icons/facebook.svg',
      color: Color(0xFF1877F2),
    ),
    _SiteLink(
      name: 'Instagram',
      url: 'https://www.instagram.com',
      asset: 'assets/icons/instagram.svg',
      color: Color(0xFFC13584),
    ),
    _SiteLink(
      name: 'Google',
      url: 'https://www.google.com',
      asset: 'assets/icons/google.svg',
      color: Color(0xFF4285F4),
    ),
  ];

  List<_SiteLink> _customSites = [];

  @override
  void initState() {
    super.initState();
    _loadCustomSites();
  }

  Future<void> _loadCustomSites() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_storageKey);
    if (!mounted || stored == null) return;
    try {
      final decoded = jsonDecode(stored) as List<dynamic>;
      setState(() {
        _customSites = decoded
            .whereType<Map<String, dynamic>>()
            .map(
              (entry) => _SiteLink(
                name: entry['name'] as String? ?? '',
                url: entry['url'] as String? ?? '',
              ),
            )
            .where((site) => site.name.isNotEmpty && _validUrl(site.url))
            .toList();
      });
    } on FormatException {
      await preferences.remove(_storageKey);
    }
  }

  Future<void> _saveCustomSites() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(_customSites.map((site) => site.toJson()).toList()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sites = [..._builtInSites, ..._customSites];
    return Scaffold(
      appBar: AppBar(title: const Text('Sites')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSite,
        icon: const Icon(Icons.add_link_rounded),
        label: const Text('Add site'),
      ),
      body: sites.isEmpty
          ? const Center(child: Text('Add a website to get started.'))
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: .88,
              ),
              itemCount: sites.length,
              itemBuilder: (context, index) {
                final site = sites[index];
                final isCustom = index >= _builtInSites.length;
                return Material(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: .58,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _openSite(site.url),
                    onLongPress: isCustom ? () => _removeSite(site) : null,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SiteIcon(site: site),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            site.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _addSite() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final site = await showDialog<_SiteLink>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add website'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'My website',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a name'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: urlController,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Website link',
                  hintText: 'https://example.com',
                ),
                validator: (value) => value == null || !_validUrl(value.trim())
                    ? 'Enter a valid http or https link'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(
                dialogContext,
                _SiteLink(
                  name: nameController.text.trim(),
                  url: urlController.text.trim(),
                ),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    nameController.dispose();
    urlController.dispose();
    if (site == null || !mounted) return;
    setState(() => _customSites.add(site));
    await _saveCustomSites();
  }

  Future<void> _removeSite(_SiteLink site) async {
    setState(() => _customSites.remove(site));
    await _saveCustomSites();
  }

  void _openSite(String value) {
    context.push(AppRouter.website, extra: value);
  }

  static bool _validUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.contains('.');
  }
}

class _SiteLink {
  const _SiteLink({
    required this.name,
    required this.url,
    this.asset,
    this.color = const Color(0xFF607D8B),
  });

  final String name;
  final String url;
  final String? asset;
  final Color color;

  Map<String, String> toJson() => {'name': name, 'url': url};
}

class _SiteIcon extends StatelessWidget {
  const _SiteIcon({required this.site});

  final _SiteLink site;

  @override
  Widget build(BuildContext context) {
    final icon = site.asset == null
        ? _customFavicon(site.url)
        : SvgPicture.asset(
            site.asset!,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          );
    return Container(
      width: 58,
      height: 58,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: site.color,
        borderRadius: BorderRadius.circular(17),
      ),
      child: icon,
    );
  }

  Widget _customFavicon(String url) {
    final faviconUri = Uri.https('www.google.com', '/s2/favicons', {
      'domain_url': url,
      'sz': '128',
    });
    return Image.network(
      faviconUri.toString(),
      errorBuilder: (_, _, _) =>
          const Icon(Icons.language_rounded, color: Colors.white, size: 30),
    );
  }
}
