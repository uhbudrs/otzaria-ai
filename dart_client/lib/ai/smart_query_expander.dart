// מעטפת לחיבור AI אל search_repository.dart הקיים של אוצריא.
//
// במקום להחליף את החיפוש - מרחיבים אותו: מקבלים שאילתה רגילה,
// קוראים ל-/morph/expand לכל מילה משמעותית, ובונים שאילתה מורחבת
// שעוברת ל-Tantivy. כך החיפוש המקומי המהיר נשמר, ופשוט מקבל
// יותר וריאציות.
//
// אינטגרציה ב-search_repository.dart:
//
//   final expander = SmartQueryExpander(ai);
//   final expanded = await expander.expand(originalQuery);
//   final results = await index.search(regexTerms: expanded.regexTerms, ...);

import 'dart:async';
import 'ai_service.dart';

class ExpandedQuery {
  final String original;
  final List<String> originalTokens;
  final List<List<String>> tokenVariants;
  final List<String> regexTerms;

  ExpandedQuery({
    required this.original,
    required this.originalTokens,
    required this.tokenVariants,
    required this.regexTerms,
  });
}

class SmartQueryExpander {
  SmartQueryExpander(this._ai, {this.maxVariantsPerToken = 24});

  final AiService _ai;
  final int maxVariantsPerToken;

  // מילים שלא נרחיב - תווי שאלה, ברכות, מילים קצרות
  static const _skipShorter = 2;
  static final _stopwords = <String>{
    'של', 'על', 'אל', 'את', 'אם', 'או', 'גם', 'כי', 'לא', 'הוא', 'היא', 'זה',
    'זו', 'מה', 'מי', 'איך', 'עם', 'כל', 'רק', 'יש', 'אין', 'הנה'
  };

  Future<ExpandedQuery> expand(String query) async {
    final tokens = _tokenize(query);
    final variantsByToken = <List<String>>[];

    final futures = <Future<List<String>>>[];
    for (final t in tokens) {
      if (t.length <= _skipShorter || _stopwords.contains(t)) {
        futures.add(Future.value([t]));
      } else {
        futures.add(_safeExpand(t));
      }
    }
    final results = await Future.wait(futures);
    for (final r in results) {
      variantsByToken.add(r.take(maxVariantsPerToken).toList());
    }

    final regexTerms = variantsByToken
        .map((variants) =>
            variants.length == 1 ? variants.first : '(${variants.join('|')})')
        .toList();

    return ExpandedQuery(
      original: query,
      originalTokens: tokens,
      tokenVariants: variantsByToken,
      regexTerms: regexTerms,
    );
  }

  Future<List<String>> _safeExpand(String token) async {
    try {
      return await _ai.expandQuery(token);
    } catch (_) {
      return [token];
    }
  }

  List<String> _tokenize(String s) {
    return s
        .split(RegExp(r'\s+'))
        .map((t) => t.replaceAll(RegExp(r'[^֐-׿a-zA-Z0-9]'), ''))
        .where((t) => t.isNotEmpty)
        .toList();
  }
}
