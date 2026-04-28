// שירות תקשורת עם sidecar של דיקטה.
// משתמשים בקלאס היחיד הזה מכל מקום באפליקציה. הוא לא טוען מודלים -
// רק שולח HTTP requests. ה-sidecar מנהל את המודלים בעצמו.
//
// התקנה: הוסיפו את `http: ^1.4.0` ל-pubspec.yaml (כבר נמצא באוצריא).

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class AiServiceException implements Exception {
  final String message;
  final int? statusCode;
  AiServiceException(this.message, {this.statusCode});
  @override
  String toString() => 'AiServiceException($statusCode): $message';
}

class AiHealth {
  final String status;
  final String version;
  final String profile;
  final bool cloudEnabled;
  final List<Map<String, dynamic>> loadedModels;

  AiHealth({
    required this.status,
    required this.version,
    required this.profile,
    required this.cloudEnabled,
    required this.loadedModels,
  });

  factory AiHealth.fromJson(Map<String, dynamic> j) => AiHealth(
        status: j['status'] as String,
        version: j['version'] as String,
        profile: j['profile'] as String,
        cloudEnabled: j['cloud_enabled'] as bool,
        loadedModels:
            (j['loaded_models'] as List).cast<Map<String, dynamic>>(),
      );
}

class NerEntity {
  final String text;
  final String label;
  final int? start;
  final int? end;
  NerEntity(this.text, this.label, this.start, this.end);
  factory NerEntity.fromJson(Map<String, dynamic> j) => NerEntity(
        j['text'] as String? ?? '',
        j['label'] as String? ?? '',
        j['start'] as int?,
        j['end'] as int?,
      );
}

class CitationHit {
  final String ref;
  final String text;
  final double score;
  CitationHit(this.ref, this.text, this.score);
  factory CitationHit.fromJson(Map<String, dynamic> j) => CitationHit(
        j['ref'] as String,
        j['text'] as String,
        (j['score'] as num).toDouble(),
      );
}

class QaResult {
  final String answer;
  final double score;
  QaResult(this.answer, this.score);
  factory QaResult.fromJson(Map<String, dynamic> j) => QaResult(
        j['answer'] as String? ?? '',
        (j['score'] as num? ?? 0).toDouble(),
      );
}

class AiService {
  AiService({
    Uri? baseUrl,
    http.Client? client,
    Duration timeout = const Duration(seconds: 60),
  })  : _base = baseUrl ?? Uri.parse('http://127.0.0.1:7821'),
        _client = client ?? http.Client(),
        _timeout = timeout;

  final Uri _base;
  final http.Client _client;
  final Duration _timeout;

  void close() => _client.close();

  Uri _u(String path) => _base.replace(path: path);

  Future<dynamic> _post(String path, Object body) async {
    final resp = await _client
        .post(
          _u(path),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    if (resp.statusCode >= 300) {
      throw AiServiceException(
        'POST $path failed: ${resp.body}',
        statusCode: resp.statusCode,
      );
    }
    return jsonDecode(utf8.decode(resp.bodyBytes));
  }

  Future<AiHealth> health() async {
    final resp = await _client.get(_u('/health')).timeout(_timeout);
    if (resp.statusCode != 200) {
      throw AiServiceException('health failed', statusCode: resp.statusCode);
    }
    return AiHealth.fromJson(jsonDecode(utf8.decode(resp.bodyBytes)));
  }

  /// מחזיר embeddings (מטריצה N×D) עבור רשימת טקסטים.
  Future<List<List<double>>> embed(List<String> texts) async {
    final j = await _post('/embed', {'texts': texts}) as Map<String, dynamic>;
    final raw = (j['vectors'] as List).cast<List>();
    return raw
        .map((row) => row.map((v) => (v as num).toDouble()).toList())
        .toList();
  }

  /// חיפוש סמנטי - שאילתה מול קורפוס. שימושי לבדיקה,
  /// בייצור עדיף לשמור embeddings ב-Isar ולחפש מקומית.
  Future<List<Map<String, dynamic>>> semanticSearch(
    String query,
    List<String> corpus, {
    int topK = 10,
  }) async {
    final j = await _post('/semantic_search', {
      'query': query,
      'corpus': corpus,
      'top_k': topK,
    }) as Map<String, dynamic>;
    return (j['hits'] as List).cast<Map<String, dynamic>>();
  }

  /// ניתוח מורפולוגי מלא - שורש, חלק דיבר, נטייה, NER, syntax.
  Future<List<Map<String, dynamic>>> morphAnalyze(List<String> texts) async {
    final j = await _post('/morph/analyze', {'texts': texts})
        as Map<String, dynamic>;
    return (j['results'] as List).cast<Map<String, dynamic>>();
  }

  /// רק רשימת השורשים/lemmas של משפט.
  Future<List<String>> lemmas(String text) async {
    final j =
        await _post('/morph/lemmas', {'text': text}) as Map<String, dynamic>;
    return (j['lemmas'] as List).cast<String>();
  }

  /// הרחבת שאילתה - כל הוריאציות של מילה לחיפוש regex.
  /// המקום שבו אנחנו מחברים את AI לחיפוש Tantivy הקיים של אוצריא.
  Future<List<String>> expandQuery(String word) async {
    final j =
        await _post('/morph/expand', {'word': word}) as Map<String, dynamic>;
    return (j['variants'] as List).cast<String>();
  }

  /// זיהוי שמות (NER).
  Future<List<List<NerEntity>>> ner(List<String> texts) async {
    final j = await _post('/ner', {'texts': texts}) as Map<String, dynamic>;
    final results = (j['results'] as List).cast<List>();
    return results
        .map((row) => row
            .cast<Map<String, dynamic>>()
            .map(NerEntity.fromJson)
            .toList())
        .toList();
  }

  /// שאלה+הקשר → תשובה. דורש פרופיל high (אחרת מחזיר שגיאה 501).
  Future<QaResult> qa(String question, String context) async {
    final j = await _post('/qa', {'question': question, 'context': context})
        as Map<String, dynamic>;
    return QaResult.fromJson(j);
  }

  /// חיפוש ציטוטים מקראיים בטקסט נתון.
  Future<List<CitationHit>> findCitations(String text, {int topK = 5}) async {
    final j = await _post('/citations/find', {'text': text, 'top_k': topK})
        as Map<String, dynamic>;
    return (j['hits'] as List)
        .cast<Map<String, dynamic>>()
        .map(CitationHit.fromJson)
        .toList();
  }

  /// ניקוד אוטומטי. genre: 'modern' או 'rabbinic'.
  Future<String> nakdan(String text, {String genre = 'modern'}) async {
    final j = await _post('/nakdan', {'text': text, 'genre': genre})
        as Map<String, dynamic>;
    return j['vocalized'] as String? ?? text;
  }

  Future<String> translate(String text,
      {String source = 'he', String target = 'en'}) async {
    final j = await _post(
      '/translate',
      {'text': text, 'source': source, 'target': target},
    ) as Map<String, dynamic>;
    return j['translation'] as String? ?? '';
  }
}
