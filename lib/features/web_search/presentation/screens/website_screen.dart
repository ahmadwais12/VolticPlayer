import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../../../core/services/web_session_service.dart';
import '../../domain/web_search_models.dart';
import '../widgets/download_options_sheet.dart';

class WebsiteScreen extends ConsumerStatefulWidget {
  const WebsiteScreen({super.key, required this.url});

  final String url;

  @override
  ConsumerState<WebsiteScreen> createState() => _WebsiteScreenState();
}

class _WebsiteScreenState extends ConsumerState<WebsiteScreen>
    with WidgetsBindingObserver {
  late final WebViewController _controller;
  late final TextEditingController _urlController;
  final FocusNode _urlFocus = FocusNode();
  String _title = 'Website';
  int _progress = 0;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String? _loadError;
  String _lastUrl = '';
  bool _startedLoad = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastUrl = widget.url;
    _title = _hostLabel(widget.url);
    _urlController = TextEditingController(text: widget.url);

    // Create the controller immediately so WebViewWidget can mount on first
    // frame. Loading before the platform view exists often shows
    // "Webpage not available" on Android.
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(WebSessionService.userAgentFor(widget.url))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onPageStarted: (url) {
            _lastUrl = url;
            _syncUrlBar(url);
            if (mounted) {
              setState(() {
                _loadError = null;
                _progress = 0;
              });
            }
            _updateNavigationState();
          },
          onPageFinished: (url) async {
            _lastUrl = url;
            _syncUrlBar(url);
            final pageTitle = await _controller.getTitle();
            if (!mounted) return;
            setState(() {
              _title = pageTitle?.trim().isNotEmpty == true
                  ? pageTitle!.trim()
                  : _hostLabel(url);
              _progress = 100;
            });
            _updateNavigationState();
            await WebSessionService.persistCookies(url);
          },
          onUrlChange: (change) {
            final url = change.url;
            if (url == null || url.isEmpty) return;
            _lastUrl = url;
            _syncUrlBar(url);
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;

            final scheme = uri.scheme.toLowerCase();
            // Keep http(s) inside the WebView. App deep links (intent://,
            // fb://, instagram://, market://) cause Android's
            // "Webpage not available" page if WebView tries to open them.
            if (scheme == 'http' || scheme == 'https') {
              return NavigationDecision.navigate;
            }
            if (scheme == 'about' || scheme == 'blob' || scheme == 'data') {
              return NavigationDecision.navigate;
            }

            _tryLaunchExternal(request.url);
            return NavigationDecision.prevent;
          },
          onWebResourceError: (error) {
            // Ignore subframe / cancelled loads; only surface real main-frame
            // failures. Unknown schemes are already blocked in onNavigationRequest.
            if (error.isForMainFrame != true || !mounted) return;
            final desc = error.description.toLowerCase();
            if (desc.contains('err_unknown_url_scheme') ||
                desc.contains('unknown url scheme') ||
                desc.contains('err_aborted')) {
              return;
            }
            setState(() => _loadError = error.description);
          },
        ),
      );

    _configureAndroid();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startLoad());
  }

  void _syncUrlBar(String url) {
    if (_urlFocus.hasFocus) return;
    if (_urlController.text == url) return;
    _urlController.value = TextEditingValue(
      text: url,
      selection: TextSelection.collapsed(offset: url.length),
    );
  }

  Future<void> _configureAndroid() async {
    try {
      if (_controller.platform is AndroidWebViewController) {
        final android = _controller.platform as AndroidWebViewController;
        await android.setMediaPlaybackRequiresUserGesture(false);
        await WebSessionService.configurePersistentCookies(_controller);
      }
    } catch (_) {
      // WebView configuration is optional on platforms without Android APIs.
    }
  }

  Future<void> _startLoad() async {
    if (_startedLoad || !mounted) return;
    _startedLoad = true;
    try {
      await WebSessionService.restoreCookies(widget.url);
      await WebSessionService.configurePersistentCookies(_controller);
      if (!mounted) return;
      await _controller.loadRequest(Uri.parse(widget.url));
    } catch (e) {
      if (mounted) {
        setState(() => _loadError = e.toString());
      }
    }
  }

  Future<void> _submitUrl(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;

    var candidate = trimmed;
    if (!candidate.contains('://')) {
      if (candidate.contains('.') && !candidate.contains(' ')) {
        candidate = 'https://$candidate';
      } else {
        candidate =
            'https://www.google.com/search?q=${Uri.encodeQueryComponent(candidate)}';
      }
    }

    final uri = Uri.tryParse(candidate);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return;
    }

    _urlFocus.unfocus();
    setState(() {
      _loadError = null;
      _lastUrl = uri.toString();
    });
    _syncUrlBar(uri.toString());
    await _controller.loadRequest(uri);
  }

  Future<void> _updateNavigationState() async {
    final canGoBack = await _controller.canGoBack();
    final canGoForward = await _controller.canGoForward();
    if (!mounted) return;
    setState(() {
      _canGoBack = canGoBack;
      _canGoForward = canGoForward;
    });
  }

  Future<void> _tryLaunchExternal(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // The external handler may be unavailable for this URL.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      final url = _lastUrl.isNotEmpty ? _lastUrl : widget.url;
      WebSessionService.persistCookies(url);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final url = _lastUrl.isNotEmpty ? _lastUrl : widget.url;
    WebSessionService.persistCookies(url);
    _urlController.dispose();
    _urlFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: SizedBox(
            height: 40,
            child: TextField(
              controller: _urlController,
              focusNode: _urlFocus,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              autocorrect: false,
              enableSuggestions: false,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Enter URL',
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.65,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                suffixIcon: IconButton(
                  tooltip: 'Go',
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  onPressed: () => _submitUrl(_urlController.text),
                ),
              ),
              onSubmitted: _submitUrl,
              onTap: () {
                _urlController.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _urlController.text.length,
                );
              },
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Open in browser',
            icon: const Icon(Icons.open_in_browser_rounded),
            onPressed: () => _controller.currentUrl().then((url) {
              if (url != null) launchUrlExternally(url);
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_progress < 100) LinearProgressIndicator(value: _progress / 100),
          if (_loadError != null)
            MaterialBanner(
              content: Text('Could not load this page: $_loadError'),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() => _loadError = null);
                    _controller.reload();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Material(
          elevation: 4,
          child: SizedBox(
            height: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: _canGoBack
                      ? () {
                          _controller.goBack();
                          _updateNavigationState();
                        }
                      : null,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                IconButton(
                  tooltip: 'Forward',
                  onPressed: _canGoForward
                      ? () {
                          _controller.goForward();
                          _updateNavigationState();
                        }
                      : null,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: () => _controller.reload(),
                  icon: const Icon(Icons.refresh_rounded),
                ),
                FilledButton.icon(
                  onPressed: _downloadCurrentPage,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Download'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _hostLabel(String url) => Uri.tryParse(url)?.host ?? 'Website';

  Future<void> _downloadCurrentPage() async {
    final url = await _controller.currentUrl();
    if (!mounted || url == null) return;
    final result = WebResult(
      id: url,
      kind: WebResultKind.web,
      title: _title,
      url: url,
      source: Uri.tryParse(url)?.host ?? 'Website',
    );
    await showDownloadOptionsSheet(context, result);
  }

  Future<void> launchUrlExternally(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
