import 'dart:convert';
import 'dart:io';

class FactData {
  const FactData({required this.id, required this.text});

  final String id;
  final String text;
}

class FactService {
  FactService({HttpClient? client}) : _client = client ?? HttpClient() {
    _client.connectionTimeout = const Duration(seconds: 12);
  }

  final HttpClient _client;
  static const String _apiUrl =
      'https://uselessfacts.jsph.pl/api/v2/facts/random?language=en';

  Future<FactData> fetchFact({required Set<String> seenIds}) async {
    var attempts = 0;
    while (attempts < 10) {
      attempts += 1;
      try {
        final request = await _client.getUrl(
          Uri.parse('$_apiUrl&_=${DateTime.now().millisecondsSinceEpoch}'),
        );
        final response = await request.close().timeout(
          const Duration(seconds: 12),
        );
        final body = await response.transform(utf8.decoder).join();
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException('HTTP ${response.statusCode}');
        }

        final json = jsonDecode(body);
        if (json is! Map<String, dynamic>) {
          throw const FormatException('Unexpected fact payload');
        }

        final id = json['id']?.toString();
        final text = json['text']?.toString();
        if (id == null || text == null || id.isEmpty || text.isEmpty) {
          throw const FormatException('Missing fact fields');
        }

        if (seenIds.contains(id)) {
          continue;
        }

        if (seenIds.length >= 1000) {
          seenIds.remove(seenIds.first);
        }

        seenIds.add(id);
        return FactData(id: id, text: text);
      } catch (_) {
        if (attempts >= 10) {
          rethrow;
        }
        await Future<void>.delayed(Duration(milliseconds: 600 * attempts));
      }
    }

    throw const HttpException('Failed after retries');
  }

  Future<String> translateToHindi(String text) async {
    try {
      final uri = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=hi&dt=t&q=${Uri.encodeComponent(text)}',
      );
      final request = await _client.getUrl(uri);
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}');
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
}
