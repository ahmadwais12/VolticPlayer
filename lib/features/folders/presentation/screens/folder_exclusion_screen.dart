import 'package:flutter/material.dart';

import '../../../../core/constants/ui_helper.dart';

/// Default excluded folder patterns matching requirements doc §37.
const _defaultExclusions = [
  'WhatsApp',
  'Telegram',
  'Cache',
  '.thumbnails',
  'Android/data',
  'Temporary',
  'Hidden',
  '.Trashes',
  'Recycle',
];

/// Folder exclusion settings screen.
/// Users can exclude specific folders from the media scanner.
class FolderExclusionScreen extends StatefulWidget {
  const FolderExclusionScreen({super.key});

  @override
  State<FolderExclusionScreen> createState() => _FolderExclusionScreenState();
}

class _FolderExclusionScreenState extends State<FolderExclusionScreen> {
  late List<String> _excludedFolders;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _excludedFolders = List.from(_defaultExclusions);
  }

  void _addFolder() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    if (_excludedFolders.contains(name)) return;
    setState(() {
      _excludedFolders.add(name);
      _controller.clear();
    });
  }

  void _removeFolder(String folder) {
    setState(() => _excludedFolders.remove(folder));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Folder Exclusions')),
      body: Column(
        children: [
          // Add folder input
          Padding(
            padding: UIHelper.screenPadding,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Folder name to exclude',
                      prefixIcon: Icon(Icons.folder_off_outlined),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addFolder(),
                  ),
                ),
                UIHelper.hSM,
                FilledButton(
                  onPressed: _addFolder,
                  child: const Text('Add'),
                ),
              ],
            ),
          ),

          // Explanation
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: UIHelper.spaceLG),
            child: Text(
              'Media in these folders will be excluded from the library scanner. '
              'Changes apply on next scan.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          UIHelper.vMD,

          // Excluded folders list
          Expanded(
            child: _excludedFolders.isEmpty
                ? UIHelper.emptyState(
                    context: context,
                    icon: Icons.folder_open,
                    message: 'No folders excluded.\nAll folders will be scanned.',
                  )
                : ListView.builder(
                    padding: UIHelper.screenPadding,
                    itemCount: _excludedFolders.length,
                    itemBuilder: (context, index) {
                      final folder = _excludedFolders[index];
                      final isDefault = _defaultExclusions.contains(folder);
                      return Card(
                        margin: const EdgeInsets.only(bottom: UIHelper.spaceXS),
                        child: ListTile(
                          leading: Icon(
                            Icons.folder_off,
                            color: theme.colorScheme.error,
                          ),
                          title: Text(folder),
                          subtitle: isDefault ? const Text('Default exclusion') : null,
                          trailing: IconButton(
                            icon: Icon(
                              isDefault ? Icons.lock : Icons.close,
                              size: 18,
                              color: isDefault ? theme.colorScheme.outline : null,
                            ),
                            onPressed: isDefault ? null : () => _removeFolder(folder),
                            tooltip: isDefault ? 'Default exclusion' : 'Remove',
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
