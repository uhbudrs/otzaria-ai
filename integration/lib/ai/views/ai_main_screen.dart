// המסך הראשי של "כלי AI" - מה שהמשתמש רואה כשלוחץ על "כלי AI" בתפריט.
//
// אם השרת עדיין מוריד מודלים - מציג מסך first-run עם פרוגרס בר.
// אחרת - מציג את כל הכלים בלשוניות.

import 'package:flutter/material.dart';

import '../ai_provider.dart';
import 'ai_debug_screen.dart';
import 'ai_first_run_screen.dart';

class AiMainScreen extends StatefulWidget {
  const AiMainScreen({super.key});

  @override
  State<AiMainScreen> createState() => _AiMainScreenState();
}

class _AiMainScreenState extends State<AiMainScreen> {
  @override
  void initState() {
    super.initState();
    AiProvider.instance.addListener(_onChange);
    if (!AiProvider.instance.isReady && !AiProvider.instance.isStarting) {
      AiProvider.instance.initialize();
    }
  }

  @override
  void dispose() {
    AiProvider.instance.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = AiProvider.instance;

    if (p.isStarting) {
      return const _StartingScreen();
    }

    if (!p.isReady) {
      return AiFirstRunScreen(error: p.lastError);
    }

    return AiDebugScreen(ai: p.service);
  }
}

class _StartingScreen extends StatelessWidget {
  const _StartingScreen();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('כלי AI')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'מאתחל את שירות ה-AI...',
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 8),
              Text(
                'בפעם הראשונה זה יכול לקחת עד דקה',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
