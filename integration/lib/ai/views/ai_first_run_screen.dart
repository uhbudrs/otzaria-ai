// מסך שמוצג כששירות ה-AI לא זמין.
// סיבות אפשריות:
//   • ה-installer לא הותקן עם תוסף ה-AI
//   • Antivirus חוסם את otzaria-ai.exe
//   • אין מספיק זיכרון
//
// המסך מציג הסבר ידידותי וכפתור "נסה שוב".

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ai_provider.dart';

class AiFirstRunScreen extends StatelessWidget {
  const AiFirstRunScreen({super.key, this.error});
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('כלי AI')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.smart_toy_outlined,
                    size: 80,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'שירות ה-AI לא רץ כרגע',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'יש כמה אפשרויות מדוע:',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  const _BulletText(
                    '🔵 התוסף לא הותקן - הורד את הגרסה המלאה מהאתר',
                  ),
                  const _BulletText(
                    '🔵 אנטי-וירוס חוסם את otzaria-ai.exe - הוסף חריגה',
                  ),
                  const _BulletText(
                    '🔵 חסר זיכרון פנוי - סגור תוכנות אחרות',
                  ),
                  const _BulletText(
                    '🔵 ההורדה הראשונה של המודלים עוד פעילה - חכה כמה דקות',
                  ),
                  const SizedBox(height: 24),
                  if (error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        'פרטי שגיאה: $error',
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            AiProvider.instance.initialize();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('נסה שוב'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => launchUrl(
                            Uri.parse('https://github.com/Otzaria/otzaria/releases'),
                          ),
                          icon: const Icon(Icons.download),
                          label: const Text('הורד גרסה מלאה'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BulletText extends StatelessWidget {
  const _BulletText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(text, style: const TextStyle(fontSize: 14)),
    );
  }
}
