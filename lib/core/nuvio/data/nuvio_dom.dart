import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// Cheerio-compatible DOM backing for Nuvio scrapers.
///
/// Real Nuvio plugins are bundled with `cheerio-without-node-native`. Beyond
/// `load / $(sel) / find / attr / text` they routinely walk the tree
/// (`parent`, `closest`, `children`, `next`, `siblings`) and narrow selections
/// (`filter('a')`, `not('.x')`), so all of that is served here — package:html
/// does the work and JS only ever holds stable node ids, which keeps one
/// selector to one bridge call.
class NuvioDom {
  final Map<String, _Doc> _docs = {};
  int _seq = 0;

  String load(String html) {
    final id = 'd${++_seq}';
    _docs[id] = _Doc(html_parser.parse(html));
    return id;
  }

  void free(String docId) => _docs.remove(docId);

  void clear() => _docs.clear();

  /// Query within the document, or within [contextId] when provided.
  List<String> query(String docId, String? contextId, String selector) {
    final doc = _docs[docId];
    if (doc == null) return const [];

    final root = contextId == null || contextId.isEmpty
        ? null
        : doc.nodes[contextId];
    if (contextId != null && contextId.isNotEmpty && root == null) {
      return const [];
    }

    final Iterable<dom.Element> found;
    try {
      found = root == null
          ? doc.document.querySelectorAll(selector)
          : root.querySelectorAll(selector);
    } catch (_) {
      // Cheerio tolerates selectors package:html rejects.
      return const [];
    }
    return [for (final element in found) doc.register(element)];
  }

  /// package:html has no `Element.matches`, so "does this node match?" is
  /// answered by matching the selector once per document and testing identity.
  Set<dom.Element> _matching(_Doc doc, String selector) {
    final cached = doc.matchCache[selector];
    if (cached != null) return cached;
    Set<dom.Element> matched;
    try {
      matched = Set<dom.Element>.identity()
        ..addAll(doc.document.querySelectorAll(selector));
    } catch (_) {
      matched = Set<dom.Element>.identity();
    }
    doc.matchCache[selector] = matched;
    return matched;
  }

  /// `selection.filter('sel')` / `.not('sel')` / `.is('sel')`.
  List<String> filter(String docId, List<String> nodeIds, String selector) {
    final doc = _docs[docId];
    if (doc == null) return const [];
    final matched = _matching(doc, selector);
    final out = <String>[];
    for (final id in nodeIds) {
      final element = doc.nodes[id];
      if (element != null && matched.contains(element)) out.add(id);
    }
    return out;
  }

  /// Tree walking: `parent`, `parents`, `closest`, `children`, `next`,
  /// `nextAll`, `prev`, `prevAll`, `siblings`, plus `index`.
  List<String> relation(
    String docId,
    List<String> nodeIds,
    String kind,
    String? selector,
  ) {
    final doc = _docs[docId];
    if (doc == null) return const [];

    final matchSet = (selector == null || selector.isEmpty)
        ? null
        : _matching(doc, selector);
    bool matches(dom.Element element) =>
        matchSet == null || matchSet.contains(element);

    final out = <String>[];
    final seen = <String>{};
    void add(dom.Element? element) {
      if (element == null || !matches(element)) return;
      final id = doc.register(element);
      if (seen.add(id)) out.add(id);
    }

    for (final id in nodeIds) {
      final element = doc.nodes[id];
      if (element == null) continue;
      switch (kind) {
        case 'parent':
          add(element.parent);
        case 'parents':
          var current = element.parent;
          while (current != null) {
            add(current);
            current = current.parent;
          }
        case 'closest':
          dom.Element? current = element;
          while (current != null) {
            if (matches(current)) {
              add(current);
              break;
            }
            current = current.parent;
          }
        case 'children':
          for (final child in element.children) {
            add(child);
          }
        case 'next':
          add(_sibling(element, forward: true));
        case 'nextAll':
          var next = _sibling(element, forward: true);
          while (next != null) {
            add(next);
            next = _sibling(next, forward: true);
          }
        case 'prev':
          add(_sibling(element, forward: false));
        case 'prevAll':
          var prev = _sibling(element, forward: false);
          while (prev != null) {
            add(prev);
            prev = _sibling(prev, forward: false);
          }
        case 'siblings':
          final parent = element.parent;
          if (parent != null) {
            for (final child in parent.children) {
              if (!identical(child, element)) add(child);
            }
          }
        case 'index':
          final parent = element.parent;
          out.add(
            parent == null ? '-1' : '${parent.children.indexOf(element)}',
          );
      }
    }
    return out;
  }

  static dom.Element? _sibling(dom.Element element, {required bool forward}) {
    final parent = element.parent;
    if (parent == null) return null;
    final siblings = parent.children;
    final index = siblings.indexOf(element);
    if (index < 0) return null;
    final target = forward ? index + 1 : index - 1;
    if (target < 0 || target >= siblings.length) return null;
    return siblings[target];
  }

  String? attr(String docId, String nodeId, String name) =>
      _docs[docId]?.nodes[nodeId]?.attributes[name];

  String text(String docId, String nodeId) =>
      _docs[docId]?.nodes[nodeId]?.text ?? '';

  /// cheerio concatenates the text of every node in the selection.
  String textOf(String docId, List<String> nodeIds) {
    final doc = _docs[docId];
    if (doc == null) return '';
    if (nodeIds.isEmpty)
      return doc.document.body?.text ?? doc.document.text ?? '';
    final buffer = StringBuffer();
    for (final id in nodeIds) {
      buffer.write(doc.nodes[id]?.text ?? '');
    }
    return buffer.toString();
  }

  /// Empty [nodeId] means "the whole document", matching `$.html()`.
  String html(String docId, String nodeId) {
    final doc = _docs[docId];
    if (doc == null) return '';
    if (nodeId.isEmpty) return doc.document.outerHtml;
    return doc.nodes[nodeId]?.innerHtml ?? '';
  }

  /// Everything the JS side needs about a batch of nodes in one call: cuts the
  /// bridge chatter that would otherwise dominate a big page.
  String describeBatch(String docId, List<String> nodeIds) {
    final doc = _docs[docId];
    if (doc == null) return '[]';
    return jsonEncode([
      for (final id in nodeIds)
        if (doc.nodes[id] case final element?)
          {
            'id': id,
            'tag': element.localName ?? '',
            'text': element.text,
            'attrs': element.attributes.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          },
    ]);
  }

  int get documentCount => _docs.length;
}

class _Doc {
  _Doc(this.document);

  final dom.Document document;
  final Map<String, dom.Element> nodes = {};
  final Map<String, Set<dom.Element>> matchCache = {};
  final Map<dom.Element, String> _ids = {};
  int _seq = 0;

  String register(dom.Element element) {
    final existing = _ids[element];
    if (existing != null) return existing;
    final id = 'n${++_seq}';
    nodes[id] = element;
    _ids[element] = id;
    return id;
  }
}
