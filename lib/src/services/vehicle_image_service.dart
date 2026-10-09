import 'dart:convert';
import 'package:http/http.dart' as http;

class VehicleReferencePhoto {
  const VehicleReferencePhoto({
    required this.url,
    required this.source,
    required this.credit,
    required this.title,
    required this.exactYear,
  });
  final String url, source, credit, title;
  final bool exactYear;
}

class VehicleImageService {
  VehicleImageService({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  static final shared = VehicleImageService();
  final _cache = <String, Future<VehicleReferencePhoto?>>{};

  static String modelQuery(String text) {
    final words = text
        .toLowerCase()
        .replaceAll(RegExp(r'\b(?:19|20)\d{2}\b'), '')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    if (words.length < 2) return '';
    return words.take(6).join(' ');
  }

  Future<VehicleReferencePhoto?> lookup(String model) {
    final key = model.trim().toLowerCase();
    if (modelQuery(key).isEmpty) return Future.value(null);
    if (_cache.length > 100) _cache.clear();
    return _cache.putIfAbsent(key, () => _lookup(key));
  }

  Future<VehicleReferencePhoto?> _lookup(String model) async {
    final query = modelQuery(model);
    final year = RegExp(r'\b(?:19|20)\d{2}\b').firstMatch(model)?.group(0);
    try {
      final uri = Uri.https('commons.wikimedia.org', '/w/api.php', {
        'action': 'query',
        'generator': 'search',
        'gsrsearch': '"$query" filetype:bitmap',
        'gsrnamespace': '6',
        'gsrlimit': '6',
        'prop': 'imageinfo',
        'iiprop': 'url|mime|extmetadata',
        'iiextmetadatafilter': 'Artist|LicenseShortName',
        'iiurlwidth': '640',
        'format': 'json',
        'formatversion': '2',
        'origin': '*',
      });
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final pages =
          (body['query']?['pages'] as List? ?? []).whereType<Map>().toList()
            ..sort((a, b) {
              final ay =
                  year != null && (a['title'] as String? ?? '').contains(year);
              final by =
                  year != null && (b['title'] as String? ?? '').contains(year);
              return ay == by
                  ? ((a['index'] as num?) ?? 99).compareTo(
                      (b['index'] as num?) ?? 99,
                    )
                  : ay
                  ? -1
                  : 1;
            });
      for (final page in pages) {
        final title = page['title'] as String? ?? '';
        final normalized = title.toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9]+'),
          ' ',
        );
        if (!query
            .split(' ')
            .every((word) => normalized.split(' ').contains(word)))
          continue;
        if (RegExp(
          r'\b(interior|engine|logo|badge|dashboard|toy|wreck|room)\b',
        ).hasMatch(normalized))
          continue;
        final info = (page['imageinfo'] as List?)?.firstOrNull as Map?;
        if (info == null ||
            !['image/jpeg', 'image/png', 'image/webp'].contains(info['mime']))
          continue;
        final metadata = info['extmetadata'] as Map? ?? {};
        final license = plain(
          metadata['LicenseShortName']?['value'] as String? ?? '',
        );
        if (!(license.startsWith('CC BY') ||
            license == 'CC0' ||
            license == 'Public domain'))
          continue;
        final url = info['thumburl'] as String? ?? '';
        final source = info['descriptionurl'] as String? ?? '';
        if (!safeImageUrl(url) ||
            Uri.tryParse(source)?.host != 'commons.wikimedia.org')
          continue;
        return VehicleReferencePhoto(
          url: url,
          source: source,
          credit:
              '${plain(metadata['Artist']?['value'] as String? ?? 'See source for author')} / $license',
          title: title,
          exactYear: year != null && title.contains(year),
        );
      }
    } catch (_) {
      /* Offline, unsupported model or invalid response: use upload fallback. */
    }
    return null;
  }

  static bool safeImageUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri?.scheme == 'https' &&
        ['upload.wikimedia.org', 'thumb.wikimedia.org'].contains(uri?.host);
  }

  static String plain(String value) => value
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ')
      .trim();
}
