// מסך לבדיקה ידנית של כל ה-endpoints. שימושי במהלך הפיתוח.
// אחרי שכל endpoint עובד מכאן, אפשר להעביר כל פיצ'ר למסכים ייעודיים
// (full_text_search_screen, find_ref_dialog וכו').

import 'package:flutter/material.dart';

import '../ai_service.dart';

class AiDebugScreen extends StatefulWidget {
  const AiDebugScreen({super.key, required this.ai});
  final AiService ai;

  @override
  State<AiDebugScreen> createState() => _AiDebugScreenState();
}

class _AiDebugScreenState extends State<AiDebugScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 9, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('כלי AI - בדיקה'),
          bottom: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabs: const [
              Tab(text: 'בריאות'),
              Tab(text: 'חיפוש סמנטי'),
              Tab(text: 'שאלות ותשובות'),
              Tab(text: 'מציאת מקבילות'),
              Tab(text: 'דקדוק'),
              Tab(text: 'הרחבת חיפוש'),
              Tab(text: 'NER'),
              Tab(text: 'ציטוטים'),
              Tab(text: 'תרגום'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          children: [
            _HealthTab(ai: widget.ai),
            _SemanticSearchTab(ai: widget.ai),
            _QaTab(ai: widget.ai),
            _ParallelsTab(ai: widget.ai),
            _SimpleTextTab(
              ai: widget.ai,
              run: (text) async {
                final r = await widget.ai.morphAnalyze([text]);
                return r.isEmpty ? '(ריק)' : _pretty(r.first);
              },
              hint: 'הכנס משפט לניתוח דקדוקי',
            ),
            _SimpleTextTab(
              ai: widget.ai,
              run: (text) async {
                final r = await widget.ai.expandQuery(text.trim());
                return r.join('  •  ');
              },
              hint: 'הכנס מילה אחת ונקבל את כל הוריאציות',
            ),
            _SimpleTextTab(
              ai: widget.ai,
              run: (text) async {
                final r = await widget.ai.ner([text]);
                if (r.isEmpty || r.first.isEmpty) return 'לא נמצאו שמות';
                return r.first
                    .map((e) => '${e.text} → ${e.label}')
                    .join('\n');
              },
              hint: 'הכנס פסקה לזיהוי שמות',
            ),
            _SimpleTextTab(
              ai: widget.ai,
              run: (text) async {
                final r = await widget.ai.findCitations(text);
                if (r.isEmpty) return 'לא נמצאו ציטוטים';
                return r
                    .map((c) =>
                        '${c.ref} (${c.score.toStringAsFixed(2)})\n${c.text}')
                    .join('\n\n');
              },
              hint: 'פסקה רבנית - נחפש ציטוטים מקראיים',
            ),
            _SimpleTextTab(
              ai: widget.ai,
              run: (text) async => widget.ai.translate(text),
              hint: 'טקסט עברי לתרגום לאנגלית',
            ),
          ],
        ),
      ),
    );
  }

  static String _pretty(Map<String, dynamic> obj) {
    final tokens = obj['tokens'] as List? ?? [];
    return tokens
        .map((t) {
          final m = t as Map<String, dynamic>;
          final tok = m['token'] ?? '';
          final lex = m['lex'] ?? m['lemma'] ?? '';
          final morph = m['morph'] ?? '';
          return '$tok  →  שורש: $lex  ($morph)';
        })
        .join('\n');
  }
}

class _HealthTab extends StatefulWidget {
  const _HealthTab({required this.ai});
  final AiService ai;

  @override
  State<_HealthTab> createState() => _HealthTabState();
}

class _HealthTabState extends State<_HealthTab> {
  String _output = 'לחץ על "בדוק" כדי להתחבר לשרת';
  bool _loading = false;

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _output = 'מתחבר...';
    });
    try {
      final h = await widget.ai.health();
      setState(() {
        _output = '''
סטטוס: ${h.status}
גרסה: ${h.version}
פרופיל: ${h.profile}
ענן זמין: ${h.cloudEnabled ? 'כן' : 'לא'}

מודלים טעונים:
${h.loadedModels.map((m) => '  • ${m['name']} (${m['size_mb']} MB, idle ${m['idle_seconds']}s)').join('\n')}
''';
      });
    } catch (e) {
      setState(() => _output = 'שגיאה: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: _loading ? null : _run,
            icon: const Icon(Icons.health_and_safety),
            label: const Text('בדוק חיבור לשרת'),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                _output,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleTextTab extends StatefulWidget {
  const _SimpleTextTab({
    required this.ai,
    required this.run,
    required this.hint,
  });

  final AiService ai;
  final Future<String> Function(String) run;
  final String hint;

  @override
  State<_SimpleTextTab> createState() => _SimpleTextTabState();
}

class _SimpleTextTabState extends State<_SimpleTextTab> {
  final _controller = TextEditingController();
  String _output = '';
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _loading = true;
      _output = 'מעבד...';
    });
    try {
      final out = await widget.run(text);
      setState(() => _output = out);
    } catch (e) {
      setState(() => _output = 'שגיאה: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: widget.hint,
              border: const OutlineInputBorder(),
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loading ? null : _go,
            child: const Text('הרץ'),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                _output,
                textDirection: TextDirection.rtl,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//   חיפוש סמנטי
//   המשתמש מדביק קורפוס (כל שורה = פסקה) + שאילתה,
//   מקבל top-k הפסקאות הדומות ביותר במשמעות.
// ═══════════════════════════════════════════════════════════════════════════
class _SemanticSearchTab extends StatefulWidget {
  const _SemanticSearchTab({required this.ai});
  final AiService ai;
  @override
  State<_SemanticSearchTab> createState() => _SemanticSearchTabState();
}

class _SemanticSearchTabState extends State<_SemanticSearchTab> {
  final _query = TextEditingController(text: 'אדם שעבר עבירה בשגגה');
  final _corpus = TextEditingController(text:
      'הזיד וחילל שבת חייב מיתה בידי אדם\n'
      'שכח ועשה מלאכה בשבת חייב חטאת\n'
      'מי שכפר בעיקר אינו בכלל ישראל\n'
      'תועה בדרכי המצוות לא נחשב מזיד\n'
      'הטועה בהוראת בית דין פטור');
  String _output = 'הכנס שאילתה ורשימת פסקאות (כל שורה = פסקה).';
  bool _loading = false;

  @override
  void dispose() {
    _query.dispose();
    _corpus.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final q = _query.text.trim();
    final lines = _corpus.text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (q.isEmpty || lines.isEmpty) return;
    setState(() {
      _loading = true;
      _output = 'מחפש...';
    });
    try {
      final hits = await widget.ai.semanticSearch(q, lines, topK: 5);
      if (hits.isEmpty) {
        setState(() => _output = 'לא נמצאו תוצאות.');
        return;
      }
      final buf = StringBuffer('דמיון סמנטי לשאילתה: "$q"\n\n');
      for (final h in hits) {
        final score = (h['score'] as num).toDouble();
        final text = h['text'] as String;
        buf.writeln('${(score * 100).toStringAsFixed(0)}%  →  $text');
      }
      setState(() => _output = buf.toString());
    } catch (e) {
      setState(() => _output = 'שגיאה: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _query,
            decoration: const InputDecoration(
              labelText: 'שאילתה',
              border: OutlineInputBorder(),
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _corpus,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'קורפוס - כל שורה = פסקה',
              border: OutlineInputBorder(),
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loading ? null : _go,
            child: const Text('חפש לפי משמעות'),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                _output,
                textDirection: TextDirection.rtl,
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//   שאלות ותשובות
//   המשתמש מדביק הקשר + שאלה, ה-AI מוצא את התשובה בתוך ההקשר.
// ═══════════════════════════════════════════════════════════════════════════
class _QaTab extends StatefulWidget {
  const _QaTab({required this.ai});
  final AiService ai;
  @override
  State<_QaTab> createState() => _QaTabState();
}

class _QaTabState extends State<_QaTab> {
  final _context = TextEditingController(text:
      'בית המקדש הראשון נבנה על ידי שלמה המלך בירושלים. '
      'הבית הראשון עמד על תילו 410 שנה. '
      'הוא חרב בתשעה באב בשנת 3338 לבריאת העולם, '
      'בידי נבוכדנצר מלך בבל, ובני ישראל הוגלו לבבל.');
  final _question = TextEditingController(text: 'מתי חרב הבית הראשון?');
  String _output = 'הכנס טקסט הקשר + שאלה.';
  bool _loading = false;

  @override
  void dispose() {
    _context.dispose();
    _question.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final c = _context.text.trim();
    final q = _question.text.trim();
    if (c.isEmpty || q.isEmpty) return;
    setState(() {
      _loading = true;
      _output = 'מחפש תשובה...';
    });
    try {
      final r = await widget.ai.qa(q, c);
      setState(() {
        _output = 'תשובה: ${r.answer}\n\n'
            'ביטחון: ${(r.score * 100).toStringAsFixed(0)}%';
      });
    } catch (e) {
      setState(() => _output =
          'שגיאה: $e\n\n(QA דורש פרופיל high או שירות ענן של דיקטה.)');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _context,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'הקשר (פסקה מהספר)',
              border: OutlineInputBorder(),
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _question,
            decoration: const InputDecoration(
              labelText: 'שאלה',
              border: OutlineInputBorder(),
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loading ? null : _go,
            child: const Text('שאל'),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                _output,
                textDirection: TextDirection.rtl,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//   מציאת מקבילות (Cross-book parallels)
//   הגרסה הפשוטה: המשתמש מדביק פסקה + ספרים לחיפוש,
//   מקבל פסקאות דומות במשמעות.
//   גרסה מלאה (אינדוקס סמנטי של כל הספרייה) - מתוכננת לעתיד.
// ═══════════════════════════════════════════════════════════════════════════
class _ParallelsTab extends StatefulWidget {
  const _ParallelsTab({required this.ai});
  final AiService ai;
  @override
  State<_ParallelsTab> createState() => _ParallelsTabState();
}

class _ParallelsTabState extends State<_ParallelsTab> {
  final _passage = TextEditingController(text:
      'אסור לעשות מלאכה ביום השבת, ואפילו מלאכה קלה. '
      'והמחלל שבת בפרהסיא דינו כעובד עבודה זרה.');
  final _candidates = TextEditingController(text:
      'שמור את יום השבת לקדשו ששת ימים תעבוד\n'
      'כל מלאכה לא יעשה בהם אך אשר יאכל לכל נפש\n'
      'מחלל שבת בפרהסיא ככופר בכל התורה כולה\n'
      'הזיד וחילל שבת חייב מיתה בידי אדם\n'
      'אם רעב הוא אכל ונפשו תרעב לא תאמר עליו דבר\n'
      'יום השביעי שבת לה אלקיך לא תעשה כל מלאכה');
  String _output = 'הדבק פסקה ראשית + רשימת פסקאות מועמדות (כל שורה).';
  bool _loading = false;

  @override
  void dispose() {
    _passage.dispose();
    _candidates.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final p = _passage.text.trim();
    final lines = _candidates.text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (p.isEmpty || lines.isEmpty) return;
    setState(() {
      _loading = true;
      _output = 'מחפש מקבילות...';
    });
    try {
      // אותו endpoint כמו semantic search - רק עם הקשר אחר.
      final hits = await widget.ai.semanticSearch(p, lines, topK: 5);
      if (hits.isEmpty) {
        setState(() => _output = 'לא נמצאו מקבילות.');
        return;
      }
      final buf = StringBuffer('מקבילות תוכניות לפסקה:\n\n');
      for (final h in hits) {
        final score = (h['score'] as num).toDouble();
        final text = h['text'] as String;
        if (score < 0.5) continue; // סינון פסקאות לא רלוונטיות
        final emoji = score > 0.85
            ? '🟢'
            : score > 0.7
                ? '🟡'
                : '⚪';
        buf.writeln('$emoji  ${(score * 100).toStringAsFixed(0)}%  $text\n');
      }
      setState(() => _output = buf.toString());
    } catch (e) {
      setState(() => _output = 'שגיאה: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _passage,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'פסקה ראשית (מהספר שאתה קורא)',
              border: OutlineInputBorder(),
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _candidates,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'פסקאות מועמדות (כל שורה = פסקה)',
              border: OutlineInputBorder(),
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 4),
          const Text(
            'הערה: גרסה מלאה תאנדקס את כל הספרייה אוטומטית. כעת - manual.',
            style: TextStyle(fontSize: 11, color: Colors.grey),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loading ? null : _go,
            child: const Text('מצא מקבילות'),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                _output,
                textDirection: TextDirection.rtl,
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
