// מטמון embeddings מקומי. שמירת וקטורים פעם אחת לכל פסקה -
// כל החיפושים הסמנטיים הבאים רצים מקומית בלי קריאה לשרת.
//
// משתמשים ב-Isar שכבר משולב באוצריא. אנחנו לא מגדירים את הסכמה כאן
// כי build_runner של Isar צריך להיות בתוך אוצריא עצמה - זה רק
// snippet שמראה את הצורה. ראה DRAFT-isar-collection.md בתיעוד.

import 'dart:typed_data';
import 'dart:math' as math;

class CachedEmbedding {
  final String docId;
  final int paragraphIndex;
  final Float32List vector;

  const CachedEmbedding({
    required this.docId,
    required this.paragraphIndex,
    required this.vector,
  });
}

/// כלי טהור לחיפוש top-k cosine מעל מערך embeddings.
/// משמש את הצד הלקוח כדי להימנע ממשלוח כל הקורפוס לשרת.
class CosineSearcher {
  static double dot(Float32List a, Float32List b) {
    assert(a.length == b.length);
    double s = 0;
    for (var i = 0; i < a.length; i++) {
      s += a[i] * b[i];
    }
    return s;
  }

  /// מניח שהוקטורים כבר מנורמלים L2 (השרת מנרמל לפני שמחזיר).
  static List<MapEntry<int, double>> topK(
    Float32List query,
    List<Float32List> corpus,
    int k,
  ) {
    final scored = <MapEntry<int, double>>[];
    for (var i = 0; i < corpus.length; i++) {
      scored.add(MapEntry(i, dot(query, corpus[i])));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(math.min(k, scored.length)).toList();
  }
}

/// המרה הלוך-חזור בין List<double> (תשובת ה-API) ל-Float32List (חסכוני בזיכרון).
Float32List vecFromJson(List<num> json) {
  final out = Float32List(json.length);
  for (var i = 0; i < json.length; i++) {
    out[i] = json[i].toDouble();
  }
  return out;
}

List<double> vecToJson(Float32List vec) =>
    List<double>.generate(vec.length, (i) => vec[i]);
