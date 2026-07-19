import 'package:flutter/material.dart';

import '../tally/widgets/tally_glyph.dart';
import 'search_index.dart';

/// The search page (the frontpage's top link): a text box over the full
/// [buildSearchIndex] list — every page and every page's dropdown content
/// (e.g. each tally system). All entries show up front; typing filters them
/// live, and tapping one navigates straight to that page/selection.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _entries = buildSearchIndex();
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open(SearchEntry entry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: RouteSettings(name: entry.route),
        builder: entry.builder,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = _entries.where((e) => e.matches(_query)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Search pages and tally systems…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() {
                              _controller.clear();
                              _query = '';
                            }),
                          ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              Expanded(
                child: results.isEmpty
                    ? const _EmptyState()
                    : ListView.separated(
                        itemCount: results.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final entry = results[i];
                          return ListTile(
                            leading: _leading(entry),
                            title: Text(entry.title),
                            subtitle: Text(entry.subtitle),
                            trailing: const Icon(Icons.north_east),
                            onTap: () => _open(entry),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _leading(SearchEntry entry) => entry.glyphSlug != null
      ? TallyGlyph(entry.glyphSlug!, size: 32)
      : Icon(entry.icon ?? Icons.article_outlined);
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        'No matches.',
        style: theme.textTheme.bodyLarge
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
