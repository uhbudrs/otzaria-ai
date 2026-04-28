# שילוב הקוד באוצריא

מסמך זה מראה את ה-diff המדויק ל-`lib/search/search_repository.dart`
ו-`lib/find_ref/find_ref_repository.dart` כדי שהחיפוש הקיים יקבל את
היכולות של דיקטה.

## 1. הרחבת שאילתה אוטומטית (smart query expansion)

זה השינוי בעל יחס תועלת/מאמץ הגבוה ביותר. אין שינוי UI - פשוט החיפוש
הקיים מתחיל למצוא הרבה יותר בזכות הוספת ניתוח לפי שורש.

### לפני

```dart
// lib/search/search_repository.dart - הקוד הקיים
final params = SearchQueryBuilder.prepareQueryParams(
    query, fuzzy, distance, customSpacing, alternativeWords, searchOptions);
final List<String> regexTerms = params['regexTerms'] as List<String>;
```

### אחרי

```dart
import 'package:otzaria/ai/ai_service.dart';
import 'package:otzaria/ai/smart_query_expander.dart';

class SearchRepository {
  SearchRepository({AiService? ai, bool useAi = true})
      : _expander = (ai != null && useAi) ? SmartQueryExpander(ai) : null;

  final SmartQueryExpander? _expander;

  Future<List<SearchResult>> searchTexts(...) async {
    // ... הקוד הקיים עד לבניית regexTerms ...

    final params = SearchQueryBuilder.prepareQueryParams(
        query, fuzzy, distance, customSpacing, alternativeWords, searchOptions);
    List<String> regexTerms = params['regexTerms'] as List<String>;

    // ⬇⬇⬇ התוספת ⬇⬇⬇
    if (_expander != null && !fuzzy) {
      try {
        final expanded = await _expander!.expand(query);
        // משלב את הוריאציות עם ה-regexTerms הקיימים
        regexTerms = expanded.regexTerms;
      } catch (_) {
        // אם השרת לא זמין - חיפוש רגיל
      }
    }

    final results = await index.search(
      regexTerms: regexTerms,
      facets: facets,
      // ... שאר הפרמטרים ...
    );
    return results;
  }
}
```

**אפקט:** חיפוש "הלך" יתחיל למצוא גם הולך, ילך, מהלך, הליכה, וכו' - אוטומטית.

---

## 2. הצגת ניתוח דקדוקי במילה לחוצה

ב-`lib/text_book/` יש widget שמציג טקסט. הוסף onLongPress לכל מילה:

```dart
import 'package:otzaria/ai/ai_service.dart';

InkWell(
  onLongPress: () async {
    final analysis = await aiService.morphAnalyze([sentence]);
    if (analysis.isEmpty) return;
    final tokens = analysis.first['tokens'] as List;
    final tokenObj = tokens.firstWhere(
      (t) => t['token'] == word,
      orElse: () => null,
    );
    if (tokenObj == null) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => _MorphCard(token: tokenObj),
    );
  },
  child: Text(word),
)
```

ה-`_MorphCard` מציג:
- שורש: `tokenObj['lex']`
- חלק דיבור: `tokenObj['morph']['pos']`
- מין/מספר: `tokenObj['morph']['feats']`

---

## 3. סימון שמות אוטומטית בטקסט (NER)

```dart
class HighlightedText extends StatefulWidget {
  final String text;
  final AiService ai;
  // ...
}

class _HighlightedTextState extends State<HighlightedText> {
  List<NerEntity> _entities = [];

  @override
  void initState() {
    super.initState();
    _loadEntities();
  }

  Future<void> _loadEntities() async {
    try {
      final r = await widget.ai.ner([widget.text]);
      if (mounted) setState(() => _entities = r.first);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final spans = _buildSpans();
    return RichText(text: TextSpan(children: spans));
  }

  List<InlineSpan> _buildSpans() {
    if (_entities.isEmpty) return [TextSpan(text: widget.text)];
    final out = <InlineSpan>[];
    var cursor = 0;
    final sorted = [..._entities]..sort(
        (a, b) => (a.start ?? 0).compareTo(b.start ?? 0));
    for (final e in sorted) {
      if (e.start == null || e.end == null) continue;
      if (e.start! > cursor) {
        out.add(TextSpan(text: widget.text.substring(cursor, e.start!)));
      }
      out.add(TextSpan(
        text: widget.text.substring(e.start!, e.end!),
        style: TextStyle(
          color: _colorForLabel(e.label),
          fontWeight: FontWeight.bold,
        ),
        // אפשר להוסיף recognizer ללחיצה - חיפוש האדם הזה
      ));
      cursor = e.end!;
    }
    if (cursor < widget.text.length) {
      out.add(TextSpan(text: widget.text.substring(cursor)));
    }
    return out;
  }

  Color _colorForLabel(String label) {
    switch (label) {
      case 'PER': return Colors.blue;        // אדם
      case 'LOC': return Colors.green;       // מקום
      case 'ORG': return Colors.purple;      // ארגון
      case 'DATE':
      case 'TIMEX': return Colors.orange;    // תאריך
      default: return Colors.grey;
    }
  }
}
```

---

## 4. כפתור "מצא ציטוטים" בתפריט קונטקסט

ב-`lib/text_book/` בתפריט הקליק הימני:

```dart
PopupMenuItem(
  child: const Text('מצא ציטוטים בקטע זה'),
  onTap: () async {
    final selection = controller.selectedText;
    if (selection.isEmpty) return;
    final hits = await aiService.findCitations(selection);
    showDialog(
      context: context,
      builder: (_) => CitationsDialog(hits: hits),
    );
  },
),
```

---

## 5. find_ref_repository - אינטגרציה עם זיהוי שמות חכם

ה-find_ref הקיים משתמש ב-regex לזיהוי שמות ספרים. בעיות:
- "ב"מ" → לפעמים בבא מציעא, לפעמים ראשי תיבות אחרים
- "רמב"ם" עם הקשר

NER יכול לעזור: אם הוא מזהה PER (אדם), זה כנראה שם של ראשון/אחרון, לא שם ספר.

```dart
// lib/find_ref/find_ref_repository.dart
class FindRefRepository {
  // הקוד הקיים של regex matching
  // ...

  Future<List<RefMatch>> findInText(String text) async {
    final regexMatches = _findByRegex(text);  // הקיים

    // העשרה: סנן אפשרויות שגויות לפי NER
    if (_aiService != null) {
      try {
        final entities = await _aiService.ner([text]);
        final perRanges = entities.first
            .where((e) => e.label == 'PER')
            .map((e) => Range(e.start!, e.end!))
            .toList();
        // אם match נמצא בתוך טווח של PER, סבירות שזה שם אדם ולא ספר
        return regexMatches.where((m) => !_overlapsAny(m.range, perRanges)).toList();
      } catch (_) {
        return regexMatches;
      }
    }
    return regexMatches;
  }
}
```

---

## 6. מדיניות שגיאות

המדיניות המומלצת בכל מקום שאוצריא קוראת לשירות:

1. **תמיד try/catch.** השרת עלול ליפול, להיתקע על מודל, או פשוט לא להיות מותקן.
2. **תמיד fallback.** החיפוש המילולי הרגיל חייב לעבוד גם בלי שירות AI.
3. **לא להראות שגיאות AI למשתמש בקריאות שקטות.** הוסף indicator קטן (איקון אפור) שמראה שיכולת AI לא זמינה.
4. **למסכים ייעודיים** (מסך AI, ניקוד) - אז כן להציג שגיאה ברורה.
