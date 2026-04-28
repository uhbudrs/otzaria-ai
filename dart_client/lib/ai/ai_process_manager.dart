// מנהל את תהליך ה-sidecar של דיקטה.
//
// כשהאפליקציה עולה: מאתר את הקובץ ההפעלה (otzaria-ai.exe ב-Windows,
// otzaria-ai ב-Linux/macOS) שאריזנו עם PyInstaller, מפעיל אותו ברקע,
// ומחכה ש-/health יחזיר 200.
//
// כשהאפליקציה נסגרת: SIGTERM נקי + המתנה קצרה + kill אם צריך.

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class AiProcessConfig {
  final String executableName;
  final int port;
  final String profile;
  final bool allowCloud;

  const AiProcessConfig({
    this.executableName = 'otzaria-ai',
    this.port = 7821,
    this.profile = 'standard',
    this.allowCloud = true,
  });
}

class AiProcessManager {
  AiProcessManager({this.config = const AiProcessConfig()});

  final AiProcessConfig config;
  Process? _proc;
  bool _externallyManaged = false;

  Uri get baseUrl => Uri.parse('http://127.0.0.1:${config.port}');

  /// מאתר את ה-sidecar binary שאוצריא תוקנה איתו.
  /// סדר חיפוש:
  ///   1. ליד ה-exe של אוצריא (`<dir>/ai/otzaria-ai[.exe]`)
  ///   2. ב-PATH של המערכת
  ///   3. בתיקיית פיתוח (`../otzaria-ai/dist/`)
  File? _resolveBinary() {
    final exeName = Platform.isWindows
        ? '${config.executableName}.exe'
        : config.executableName;

    final candidates = <String>[
      p.join(p.dirname(Platform.resolvedExecutable), 'ai', exeName),
      p.join(p.dirname(Platform.resolvedExecutable), exeName),
    ];

    for (final path in candidates) {
      final f = File(path);
      if (f.existsSync()) return f;
    }
    return null;
  }

  /// מנסה להתחבר לשרת קיים. אם לא קיים - מפעיל אחד חדש.
  Future<void> ensureRunning({Duration timeout = const Duration(seconds: 30)}) async {
    if (await _isAlive()) {
      _externallyManaged = true;
      return;
    }

    final bin = _resolveBinary();
    if (bin == null) {
      throw StateError(
        'otzaria-ai sidecar binary not found. '
        'Install it via the bundled installer or run from source.',
      );
    }

    _proc = await Process.start(
      bin.path,
      const [],
      environment: {
        'OTZARIA_AI_PORT': '${config.port}',
        'OTZARIA_AI_PROFILE': config.profile,
        'OTZARIA_AI_CLOUD': config.allowCloud ? '1' : '0',
      },
      mode: ProcessStartMode.detachedWithStdio,
    );

    // המתנה ל-readiness
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await _isAlive()) return;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    await stop();
    throw TimeoutException('otzaria-ai did not become healthy in $timeout');
  }

  Future<bool> _isAlive() async {
    try {
      final r = await http
          .get(baseUrl.replace(path: '/health'))
          .timeout(const Duration(seconds: 2));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    if (_externallyManaged) return;
    final p = _proc;
    if (p == null) return;
    p.kill(ProcessSignal.sigterm);

    final exit = await p.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        p.kill(ProcessSignal.sigkill);
        return -1;
      },
    );
    _proc = null;
    return;
  }
}
