import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

class FactData {
  const FactData({required this.id, required this.text});

  final String id;
  final String text;
}

class FactService {
  FactService() : _client = HttpClient() {
    _client.connectionTimeout = const Duration(seconds: 12);
  }

  final HttpClient _client;
  final Random _random = Random();
  List<FactData> _facts = <FactData>[];
  String _loadedCategory = '';

  /// Loads facts from the local JSON asset for the given [category].
  /// The category maps to `assets/facts/{category}.json`.
  Future<void> loadFacts(String category) async {
    if (category == _loadedCategory && _facts.isNotEmpty) {
      return;
    }

    final jsonString =
        await rootBundle.loadString('assets/facts/$category.json');
    final List<dynamic> parsed = jsonDecode(jsonString) as List<dynamic>;

    _facts = parsed.map((entry) {
      final map = entry as Map<String, dynamic>;
      return FactData(
        id: '${category}_${map['id']}',
        text: map['fact'] as String,
      );
    }).toList();

    _facts.shuffle(_random);
    _loadedCategory = category;
  }

  /// Returns the next fact that hasn't been seen recently.
  /// When all facts have been seen, clears the seen set and cycles.
  FactData getNextFact({required Set<String> seenIds}) {
    // Try to find an unseen fact
    for (final fact in _facts) {
      if (!seenIds.contains(fact.id)) {
        return fact;
      }
    }

    // All facts seen — clear category-specific seen IDs and reshuffle.
    final prefix = '${_loadedCategory}_';
    seenIds.removeWhere((id) => id.startsWith(prefix));
    _facts.shuffle(_random);

    return _facts.first;
  }

  /// Translates English text to Hindi using Google Translate's public endpoint.
  /// Falls back to the original text on failure.
  Future<String> translateToHindi(String text) async {
    try {
      final uri = Uri.parse(
        'https://translate.googleapis.com/translate_a/single'
        '?client=gtx&sl=en&tl=hi&dt=t&q=${Uri.encodeComponent(text)}',
      );
      final request = await _client.getUrl(uri);
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        return text;
      }
      final decoded = jsonDecode(body);
      if (decoded is List && decoded.isNotEmpty && decoded[0] is List) {
        final chunks = decoded[0] as List<dynamic>;
        return chunks
            .map(
              (chunk) => chunk is List && chunk.isNotEmpty
                  ? chunk.first?.toString() ?? ''
                  : '',
            )
            .join();
      }
    } catch (_) {
      return text;
    }
    return text;
  }

  /// Returns the total number of loaded facts (useful for progress tracking).
  int get totalFacts => _facts.length;

  /// Returns true if facts have been loaded.
  bool get isLoaded => _facts.isNotEmpty;
}
