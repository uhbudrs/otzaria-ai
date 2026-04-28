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
    _tabs = TabController(length: 7, vsync: this);
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
              Tab(text: 'דקדוק'),
              Tab(text: 'הרחבת חיפוש'),
              Tab(text: 'NER'),
              Tab(text: 'ציטוטים'),
              Tab(text: 'ניקוד'),
              Tab(text: 'תרגום'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          children: [
            _HealthTab(ai: widget.ai),
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
              run: (text) async => widget.ai.nakdan(text),
              hint: 'טקסט לא מנוקד',
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
