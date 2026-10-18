import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/ui_helper.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/download_manager.dart';
import '../../../../shared/widgets/library_page_header.dart';
import '../../../../shared/widgets/banner_ad_widget.dart';
import '../../domain/web_search_models.dart';
import '../controllers/web_search_providers.dart';
import '../widgets/download_options_sheet.dart';
import '../widgets/web_result_widgets.dart';

/// Online search and URL entry for the Download destination.
class WebSearchScreen extends ConsumerStatefulWidget {
  const WebSearchScreen({super.key});

  @override
  ConsumerState<WebSearchScreen> createState() => _WebSearchScreenState();
}

class _WebSearchScreenState extends ConsumerState<WebSearchScreen> {
  final _controller = TextEditingController();
  final _searchFocusNode = FocusNode();
  static const _searchHistoryKey = 'downloads_search_history_v1';
  static const _hotSearches = [
    '\u0622\u0647\u0646\u06af \u0647\u0627\u06cc \u062c\u062f\u06cc\u062f',
    '\u0622\u0647\u0646\u06af \u062c\u062f\u06cc\u062f 2025',
    '\u0622\u0647\u0646\u06af \u062c\u062f\u06cc\u062f',
    '\u0622\u0647\u0646\u06af \u0645\u0627\u062f\u0631',
    '\u0622\u0647\u0646\u06af \u0647\u0627\u06cc \u0627\u0641\u063a\u0627\u0646\u06cc',
    '\u0646\u0648\u062d\u0647',
  ];
  List<String> _searchHistory = [];
  bool _showSearchLanding = false;
  WebSearchTab _tab = WebSearchTab.all;
  String _query = '';
  String? _submittedUrl;
  String _homeTopic = 'All';

  @override
  void dispose() {
    _controller.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _searchHistory = prefs.getStringList(_searchHistoryKey) ?? [];
    });
  }

  Future<void> _rememberSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final next = [
      query,
      ..._searchHistory.where(
        (item) => item.toLowerCase() != query.toLowerCase(),
      ),
    ];
    await prefs.setStringList(_searchHistoryKey, next);
    if (mounted) setState(() => _searchHistory = next);
  }

  Future<void> _clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_searchHistoryKey);
    if (mounted) setState(() => _searchHistory = []);
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    await _rememberSearch(query);
    if (!mounted) return;
    final uri = Uri.tryParse(query);
    final isUrl =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.contains('.');
    setState(() {
      _query = isUrl ? '' : query;
      _submittedUrl = isUrl ? uri.toString() : null;
      _tab = WebSearchTab.all;
      _showSearchLanding = false;
    });
    _searchFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_showSearchLanding) return _buildSearchLanding(theme);
    final filters = ref.watch(webSearchFiltersProvider);
    final isLanding = _query.isEmpty && _submittedUrl == null;
    final request = WebSearchRequest(
      query: isLanding ? 'trending videos' : _query,
      tab: isLanding ? WebSearchTab.all : _tab,
      filters: filters,
    );
    final results = ref.watch(webSearchResultsProvider(request));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
              child: Row(
                children: [
                  if (!isLanding)
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => setState(() {
                        _query = '';
                        _submittedUrl = null;
                      }),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    ),
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _searchFocusNode,
                        textInputAction: TextInputAction.search,
                        onTap: _openSearchLanding,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _search(),
                        decoration: InputDecoration(
                          hintText: 'Search or enter URL',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_controller.text.isNotEmpty)
                                IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    _controller.clear();
                                    setState(() {
                                      _query = '';
                                      _submittedUrl = null;
                                    });
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                              IconButton(
                                tooltip: 'Search',
                                onPressed: _search,
                                icon: const Icon(Icons.arrow_forward_rounded),
                              ),
                            ],
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(width: 1, height: 30, color: theme.dividerColor),
                  _MyFilesIconButton(
                    onPressed: () => context.push(
                      AppRouter.downloadDetails,
                      extra: 'downloading',
                    ),
                  ),
                  if (!isLanding)
                    IconButton(
                      tooltip: 'Search filters',
                      onPressed: () => _showFilters(filters),
                      icon: Icon(
                        Icons.tune,
                        color: filters.isDefault
                            ? null
                            : theme.colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ),
            if (isLanding) ...[
              LibraryPageHeader(
                title: 'Downloads',
                subtitle: 'Search online, open a URL, or save for offline',
                icon: Icons.cloud_download_rounded,
                actions: [
                  LibraryHeaderAction(
                    icon: Icons.download_for_offline_outlined,
                    tooltip: 'My downloads',
                    onPressed: () => context.push(
                      AppRouter.downloadDetails,
                      extra: 'downloading',
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 3,
                  ),
                  children: [
                    _TopicChip(
                      label: 'Shorts',
                      icon: Icons.smart_display_rounded,
                      selected: _homeTopic == 'Shorts',
                      onTap: () => _searchTopic('Shorts'),
                    ),
                    _TopicChip(
                      label: 'All',
                      selected: _homeTopic == 'All',
                      onTap: () => _searchTopic('trending videos'),
                    ),
                    _TopicChip(
                      label: 'Music',
                      selected: _homeTopic == 'Music',
                      onTap: () => _searchTopic('popular music'),
                    ),
                    _TopicChip(
                      label: 'Movies',
                      selected: _homeTopic == 'Movies',
                      onTap: () => _searchTopic('movies'),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 104,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  children: [
                    _SiteShortcut(
                      label: 'YouTube',
                      asset: 'assets/icons/youtube.svg',
                      color: const Color(0xFFE62117),
                      onTap: () => _openSite('https://www.youtube.com/'),
                    ),
                    _SiteShortcut(
                      label: 'WhatsApp',
                      asset: 'assets/icons/whatsapp.svg',
                      color: const Color(0xFF25D366),
                      onTap: () => _openSite('https://web.whatsapp.com/'),
                    ),
                    _SiteShortcut(
                      label: 'Facebook',
                      asset: 'assets/icons/facebook.svg',
                      color: const Color(0xFF1877F2),
                      onTap: () => _openSite('https://www.facebook.com/'),
                    ),
                    _SiteShortcut(
                      label: 'Instagram',
                      asset: 'assets/icons/instagram.svg',
                      color: const Color(0xFFC13584),
                      onTap: () => _openSite('https://www.instagram.com/'),
                    ),
                    _SiteShortcut(
                      label: 'Sites',
                      asset: 'assets/icons/sites.svg',
                      color: theme.colorScheme.primary,
                      onTap: () => context.push(AppRouter.sites),
                    ),
                  ],
                ),
              ),
            ],
            if (_query.isNotEmpty || _submittedUrl != null)
              Column(
                children: [
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        for (final tab in WebSearchTab.values)
                          WebSearchTopTab(
                            label: tab.label,
                            selected: _tab == tab,
                            onTap: () => setState(() => _tab = tab),
                          ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: theme.dividerColor),
                  SizedBox(
                    height: 54,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      children: [
                        WebSearchFilterChip(
                          label: 'Type',
                          value: _tab == WebSearchTab.all ? null : _tab.label,
                          onTap: () => _chooseTab(),
                        ),
                        WebSearchFilterChip(
                          label: 'Duration',
                          value: filters.duration == WebDuration.any
                              ? null
                              : filters.duration.label,
                          onTap: () => _showFilters(filters),
                        ),
                        WebSearchFilterChip(
                          label: 'Upload date',
                          value: filters.uploadDate == WebUploadDate.any
                              ? null
                              : filters.uploadDate.label,
                          onTap: () => _showFilters(filters),
                        ),
                        WebSearchFilterChip(
                          label: 'Features',
                          value: filters.order == WebSortOrder.relevance
                              ? null
                              : filters.order.label,
                          onTap: () => _showFilters(filters),
                        ),
                        if (!filters.isDefault)
                          TextButton(
                            onPressed: () => ref
                                .read(webSearchFiltersProvider.notifier)
                                .set(const WebSearchFilters()),
                            child: const Text('Reset'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            Expanded(child: _buildResults(results, theme)),
          ],
        ),
      ),
    );
  }

  void _openSearchLanding() {
    if (_showSearchLanding) return;
    setState(() => _showSearchLanding = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  Widget _buildSearchLanding(ThemeData theme) {
    final colors = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () {
                      _searchFocusNode.unfocus();
                      setState(() => _showSearchLanding = false);
                    },
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest.withValues(
                          alpha: 0.65,
                        ),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _searchFocusNode,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _search(),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search or enter URL',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _controller.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    _controller.clear();
                                    setState(() {});
                                    _searchFocusNode.requestFocus();
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  TextButton(onPressed: _search, child: const Text('SEARCH')),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Search History',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (_searchHistory.isNotEmpty)
                        IconButton(
                          tooltip: 'Clear search history',
                          onPressed: _clearSearchHistory,
                          icon: Icon(
                            Icons.delete_outline,
                            color: colors.outline,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_searchHistory.isEmpty)
                    Text(
                      'Your recent searches will appear here.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final query in _searchHistory)
                          _searchChip(query, theme),
                      ],
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'Hot Searches',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < _hotSearches.length; i++)
                        _searchChip(_hotSearches[i], theme, showFlame: i < 2),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              height: 72,
              margin: const EdgeInsets.fromLTRB(0, 4, 0, 8),
              padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Advertisement',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.outline,
                    ),
                  ),
                  const Expanded(child: Center(child: SmartBannerAd())),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchChip(String query, ThemeData theme, {bool showFlame = false}) {
    return ActionChip(
      avatar: showFlame
          ? const Icon(
              Icons.local_fire_department_rounded,
              color: Colors.deepOrange,
              size: 18,
            )
          : null,
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Text(query, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.45,
      ),
      side: BorderSide.none,
      onPressed: () {
        _controller.text = query;
        _controller.selection = TextSelection.collapsed(offset: query.length);
        _search();
      },
    );
  }

  Future<void> _showFilters(WebSearchFilters filters) async {
    final chosen = await showWebSearchFilters(context, filters);
    if (chosen != null) ref.read(webSearchFiltersProvider.notifier).set(chosen);
  }

  void _searchTopic(String query) {
    setState(() {
      _homeTopic = switch (query) {
        'Shorts' => 'Shorts',
        'popular music' => 'Music',
        'movies' => 'Movies',

        _ => 'All',
      };
      _controller.text = query == 'trending videos' ? '' : query;
      _query = query;
      _submittedUrl = null;
    });
  }

  void _searchSite(WebSearchTab tab) {
    setState(() {
      _tab = tab;
      _controller.text = 'popular';
      _query = 'popular';
      _submittedUrl = null;
    });
  }

  void _openSite(String url) {
    context.push(AppRouter.website, extra: url);
  }

  Future<void> _chooseTab() async {
    final chosen = await showModalBottomSheet<WebSearchTab>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final tab in WebSearchTab.values)
              ListTile(
                title: Text(tab.label),
                trailing: _tab == tab ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, tab),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen != null) setState(() => _tab = chosen);
  }

  Widget _buildResults(AsyncValue<List<WebResult>>? results, ThemeData theme) {
    if (_submittedUrl case final url?) {
      final uri = Uri.parse(url);
      final image = RegExp(
        r'\.(jpg|jpeg|png|gif|webp)(\?.*)?$',
        caseSensitive: false,
      ).hasMatch(uri.path);
      final result = WebResult(
        id: url,
        kind: image ? WebResultKind.image : WebResultKind.video,
        title: uri.pathSegments.isEmpty ? uri.host : uri.pathSegments.last,
        subtitle: 'Ready to download from ${uri.host}',
        url: url,
        source: uri.host,
      );
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [WebResultCard(result: result)],
      );
    }
    if (results == null) {
      return Center(
        child: UIHelper.emptyState(
          context: context,
          icon: Icons.travel_explore,
          message:
              'Find videos, playlists, channels, pictures and pages to download.',
        ),
      );
    }
    return results.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 40,
                color: theme.colorScheme.outline,
              ),
              UIHelper.vMD,
              Text(
                error is WebSearchNotConfigured
                    ? error.message
                    : error.toString().replaceFirst('Bad state: ', ''),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              UIHelper.vMD,
              FilledButton.icon(
                onPressed: () {
                  final filters = ref.read(webSearchFiltersProvider);
                  final request = WebSearchRequest(
                    query: _query.isEmpty ? 'trending videos' : _query,
                    tab: _tab,
                    filters: filters,
                  );
                  ref.invalidate(webSearchResultsProvider(request));
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('No results found.'));
        }
        // All tab: group by every top filter. Other tabs stay a flat list.
        if (_tab == WebSearchTab.all && _submittedUrl == null) {
          return _buildAllGroupedResults(items, theme);
        }
        if (_tab == WebSearchTab.pictures) {
          return PictureGrid(pictures: items);
        }
        final channels = items
            .where((r) => r.kind == WebResultKind.channel)
            .toList();
        final other = items
            .where((r) => r.kind != WebResultKind.channel)
            .toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (channels.isNotEmpty) ...[
              Text(
                'YouTube channels',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              UIHelper.vSM,
              SizedBox(
                height: 122,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: channels.length,
                  separatorBuilder: (_, _) => UIHelper.hSM,
                  itemBuilder: (_, i) => ChannelTile(channel: channels[i]),
                ),
              ),
              UIHelper.vSM,
            ],
            for (final result in other)
              WebResultCard(result: result, recommendations: other),
          ],
        );
      },
    );
  }

  /// Renders All with every top-filter part visible, in the same order as the
  /// chips: YouTube (songs/movies), Playlist, Instagram, Facebook, Pictures,
  /// Google.
  Widget _buildAllGroupedResults(List<WebResult> items, ThemeData theme) {
    final videos = items.where((r) => r.kind == WebResultKind.video).toList();
    final playlists = items
        .where((r) => r.kind == WebResultKind.playlist)
        .toList();
    final channels = items
        .where((r) => r.kind == WebResultKind.channel)
        .toList();
    final instagram = items.where((r) => r.source == 'Instagram').toList();
    final facebook = items.where((r) => r.source == 'Facebook').toList();
    final pictures = items.where((r) => r.kind == WebResultKind.image).toList();
    final google = items
        .where(
          (r) =>
              r.source == 'Google' &&
              r.kind == WebResultKind.web &&
              !r.isYouTube,
        )
        .toList();

    Widget sectionTitle(String label) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Text(
        label,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    Widget emptyHint(String label) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        'No $label results',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
    );

    List<Widget> cardSection(String title, List<WebResult> rows) => [
      sectionTitle(title),
      if (rows.isEmpty)
        emptyHint(title)
      else
        for (final r in rows) WebResultCard(result: r, recommendations: videos),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // YouTube songs / movies first (matches downloader purpose).
        sectionTitle('YouTube'),
        if (channels.isNotEmpty) ...[
          SizedBox(
            height: 122,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: channels.length,
              separatorBuilder: (_, _) => UIHelper.hSM,
              itemBuilder: (_, i) => ChannelTile(channel: channels[i]),
            ),
          ),
          UIHelper.vSM,
        ],
        if (videos.isEmpty)
          emptyHint('YouTube')
        else
          for (final r in videos)
            WebResultCard(result: r, recommendations: videos),
        ...cardSection('Playlist', playlists),
        ...cardSection('Instagram', instagram),
        ...cardSection('Facebook', facebook),
        sectionTitle('Pictures'),
        if (pictures.isEmpty)
          emptyHint('Pictures')
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
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
                      child: r.thumbnailUrl == null
                          ? ColoredBox(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.image_outlined),
                            )
                          : Image.network(
                              r.thumbnailUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => ColoredBox(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                              ),
                            ),
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
          ),
        ...cardSection('Google', google),
      ],
    );
  }
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 9),
      child: ChoiceChip(
        avatar: icon == null
            ? null
            : Icon(
                icon,
                color: selected ? theme.colorScheme.onPrimary : Colors.red,
                size: 19,
              ),
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.58,
        ),
        selectedColor: theme.colorScheme.onSurface,
        labelStyle: TextStyle(
          color: selected
              ? theme.colorScheme.surface
              : theme.colorScheme.onSurface,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
        side: BorderSide.none,
        shape: const StadiumBorder(),
      ),
    );
  }
}

class _SiteShortcut extends StatelessWidget {
  const _SiteShortcut({
    required this.label,
    required this.asset,
    required this.color,
    required this.onTap,
  });
  final String label;
  final String asset;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 83,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(13),
              child: SvgPicture.asset(
                asset,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Download icon next to the search bar with an in-progress count badge.
class _MyFilesIconButton extends ConsumerWidget {
  const _MyFilesIconButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadManagerProvider);
    final active = downloads.items
        .where(
          (item) =>
              item.isActive ||
              item.isPaused ||
              item.status == DownloadStatus.failed,
        )
        .length;

    return IconButton(
      tooltip: active > 0 ? 'My Files ($active downloading)' : 'My Files',
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: active > 0,
        label: Text('$active'),
        child: const Icon(Icons.download_for_offline_outlined, size: 28),
      ),
    );
  }
}
