import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/ui_helper.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/download_manager.dart';
import '../../../../domain/entities/media_item.dart';
import '../../../../shared/media_navigation.dart';
import '../../../../shared/widgets/media_list_tile.dart';
import '../../../web_search/domain/web_search_models.dart';
import '../../../web_search/presentation/controllers/web_search_providers.dart';
import '../../../web_search/presentation/widgets/web_result_widgets.dart';
import '../controllers/search_controller.dart';

/// "Search or enter URL": URLs go straight to the downloader, text runs a
/// live on-device search and, on submit, an online search split into tabs.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();
  String? _submitted;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onSubmitted(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return;
    final url = _asUrl(text);
    if (url != null) {
      context.push(AppRouter.videoDownloader, extra: url);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _submitted = text);
  }

  String? _asUrl(String s) {
    if (s.contains(' ')) return null;
    final explicit = RegExp(r'^https?://', caseSensitive: false).hasMatch(s);
    final bare =
        s.toLowerCase().startsWith('www.') ||
        RegExp(r'^[\w-]+(\.[\w-]+)+/\S*$').hasMatch(s);
    if (!explicit && !bare) return null;
    final uri = Uri.tryParse(explicit ? s : 'https://$s');
    if (uri == null || !uri.host.contains('.')) return null;
    return uri.toString();
  }

  Future<void> _openFilters() async {
    final current = ref.read(webSearchFiltersProvider);
    final picked = await showWebSearchFilters(context, current);
    if (picked != null) {
      ref.read(webSearchFiltersProvider.notifier).set(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = ref.watch(searchControllerProvider);
    final filters = ref.watch(webSearchFiltersProvider);
    final activeDownloads = ref.watch(
      downloadManagerProvider.select((s) => s.activeCount),
    );
    final submitted = _submitted;

    return DefaultTabController(
      length: WebSearchTab.values.length,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: TextField(
            controller: _ctrl,
            autofocus: true,
            textInputAction: TextInputAction.search,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              hintText: 'Search or enter URL',
              border: InputBorder.none,
            ),
            onChanged: (v) {
              setState(() {});
              ref.read(searchControllerProvider.notifier).search(v);
            },
            onSubmitted: _onSubmitted,
          ),
          actions: [
            if (_ctrl.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear),
                tooltip: 'Clear',
                onPressed: () {
                  _ctrl.clear();
                  ref.read(searchControllerProvider.notifier).search('');
                  setState(() => _submitted = null);
                },
              ),
            IconButton(
              tooltip: 'Filters',
              onPressed: _openFilters,
              icon: Badge(
                isLabelVisible: !filters.isDefault,
                smallSize: 8,
                child: const Icon(Icons.tune_rounded),
              ),
            ),
            IconButton(
              tooltip: 'Downloads',
              onPressed: () => context.go(AppRouter.downloads),
              icon: Badge(
                isLabelVisible: activeDownloads > 0,
                label: Text('$activeDownloads'),
                child: const Icon(Icons.download_rounded),
              ),
            ),
          ],
          bottom: submitted == null
              ? null
              : TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    for (final t in WebSearchTab.values) Tab(text: t.label),
                  ],
                ),
        ),
        body: submitted == null
            ? _LocalResults(
                state: local,
                typed: _ctrl.text.trim(),
                onSearchOnline: () => _onSubmitted(_ctrl.text),
              )
            : TabBarView(
                children: [
                  for (final t in WebSearchTab.values)
                    _WebResultsTab(
                      request: WebSearchRequest(
                        query: submitted,
                        tab: t,
                        filters: filters,
                      ),
                      deviceResults: t == WebSearchTab.all
                          ? local.results
                          : const [],
                    ),
                ],
              ),
      ),
    );
  }
}

class _LocalResults extends StatelessWidget {
  final SearchState state;
  final String typed;
  final VoidCallback onSearchOnline;

  const _LocalResults({
    required this.state,
    required this.typed,
    required this.onSearchOnline,
  });

  @override
  Widget build(BuildContext context) {
    if (typed.isEmpty) {
      return UIHelper.emptyState(
        context: context,
        icon: Icons.travel_explore,
        message:
            'Search your library and the web,\nor paste a link to download it.',
      );
    }
    return ListView(
      padding: UIHelper.listPadding,
      children: [
        ListTile(
          leading: const Icon(Icons.travel_explore),
          title: Text('Search online for "$typed"'),
          trailing: const Icon(Icons.arrow_forward),
          onTap: onSearchOnline,
        ),
        const Divider(),
        if (state.loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (state.results.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text('No results on this device.')),
          )
        else
          for (final item in state.results)
            MediaListTile(item: item, onTap: () => openMedia(context, item)),
      ],
    );
  }
}

class _WebResultsTab extends ConsumerStatefulWidget {
  final WebSearchRequest request;
  final List<MediaItem> deviceResults;

  const _WebResultsTab({required this.request, required this.deviceResults});

  @override
  ConsumerState<_WebResultsTab> createState() => _WebResultsTabState();
}

class _WebResultsTabState extends ConsumerState<_WebResultsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = webSearchResultsProvider(widget.request);
    final async = ref.watch(provider);
    final theme = Theme.of(context);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          _ErrorState(error: e, onRetry: () => ref.invalidate(provider)),
      data: (results) {
        if (widget.request.tab == WebSearchTab.pictures) {
          return results.isEmpty
              ? _empty(context)
              : PictureGrid(pictures: results);
        }
        final channels = results
            .where((r) => r.kind == WebResultKind.channel)
            .toList();
        final others = results
            .where((r) => r.kind != WebResultKind.channel)
            .toList();
        final device = widget.deviceResults;
        if (results.isEmpty && device.isEmpty) return _empty(context);

        return RefreshIndicator(
          onRefresh: () => ref.refresh(provider.future),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              if (device.isNotEmpty) ...[
                _heading(theme, 'On this device'),
                for (final item in device.take(3))
                  MediaListTile(
                    item: item,
                    onTap: () => openMedia(context, item),
                  ),
              ],
              if (channels.isNotEmpty) ...[
                _heading(theme, 'YouTube channels'),
                SizedBox(
                  height: 116,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: channels.length,
                    separatorBuilder: (_, _) => UIHelper.hSM,
                    itemBuilder: (_, i) => ChannelTile(channel: channels[i]),
                  ),
                ),
              ],
              if (others.isNotEmpty &&
                  (channels.isNotEmpty || device.isNotEmpty))
                _heading(theme, 'Results'),
              for (final r in others)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: WebResultCard(
                    result: r,
                    recommendations: others,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _heading(ThemeData theme, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    ),
  );

  Widget _empty(BuildContext context) => UIHelper.emptyState(
    context: context,
    icon: Icons.search_off,
    message:
        'No ${widget.request.tab.label} results for '
        '"${widget.request.query}".',
  );
}

class _ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notConfigured = error is WebSearchNotConfigured;
    final message = switch (error) {
      WebSearchNotConfigured(:final message) => message,
      DioException() => 'Could not load results. Check your connection.',
      _ => 'Something went wrong while searching.',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              notConfigured ? Icons.key_off_outlined : Icons.cloud_off,
              size: 56,
              color: theme.colorScheme.outline,
            ),
            UIHelper.vMD,
            Text(message, textAlign: TextAlign.center),
            if (notConfigured) ...[
              UIHelper.vSM,
              Text(
                'Online search is not set up in this build yet.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ] else ...[
              UIHelper.vMD,
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
