// AiProvider - singleton מרכזי לכלי AI באוצריא.
//
// משתמשים בו דרך AiProvider.instance בכל מקום באפליקציה.
// הוא מחזיק:
//   • את ה-AiProcessManager (תהליך השרת)
//   • את ה-AiService (HTTP client)
//   • דגל isReady שאומר אם השרת באמת זמין
//
// אפשר לקרוא לפונקציות AI גם כשהשרת לא רץ - הן יזרקו שגיאה
// והקוד הקורא יוכל ל-fallback להתנהגות הרגילה (חיפוש בלי AI).

import 'dart:async';
import 'package:flutter/foundation.dart';

import 'ai_process_manager.dart';
import 'ai_service.dart';

class AiProvider extends ChangeNotifier {
  AiProvider._();
  static final AiProvider instance = AiProvider._();

  late final AiProcessManager _manager =
      AiProcessManager(config: const AiProcessConfig(profile: 'standard'));
  late final AiService service = AiService(baseUrl: _manager.baseUrl);

  bool _isReady = false;
  bool _isStarting = false;
  String? _lastError;

  bool get isReady => _isReady;
  bool get isStarting => _isStarting;
  String? get lastError => _lastError;

  /// קוראים פעם אחת ב-main.dart.
  /// מתחיל בהפעלת השרת ברקע ואחר כך בודק שהוא חי.
  /// לא חוסם את הפעלת האפליקציה - אם נכשל, הדגל isReady נשאר false
  /// והאפליקציה ממשיכה לעבוד בלי AI.
  Future<void> initialize() async {
    if (_isStarting || _isReady) return;
    _isStarting = true;
    notifyListeners();
    try {
      await _manager.ensureRunning(timeout: const Duration(seconds: 45));
      _isReady = true;
      _lastError = null;
      debugPrint('AI sidecar is ready at ${_manager.baseUrl}');
    } catch (e) {
      _isReady = false;
      _lastError = e.toString();
      debugPrint('AI sidecar failed to start: $e');
    } finally {
      _isStarting = false;
      notifyListeners();
    }
  }

  Future<void> shutdown() async {
    service.close();
    await _manager.stop();
    _isReady = false;
    notifyListeners();
  }
}
