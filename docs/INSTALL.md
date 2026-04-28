# מדריך התקנה

## מה אתה מתקין

1. **תלות חד-פעמיות** - Python 3.10+ ו-pip
2. **חבילת ה-sidecar** - תיקיית `dicta_service/`
3. **המודלים של דיקטה** - יורדים אוטומטית בריצה ראשונה (או ידנית עם `download_models.py`)
4. **קוד ה-Dart** - מועתק לתיקיית `lib/ai/` של אוצריא

---

## חלק א' - הפעלת השרת מקור (מצב פיתוח)

### Windows

```powershell
# 1. ודא שיש Python 3.10 / 3.11 / 3.12.
#    אסור 3.13 / 3.14 - PyTorch עדיין לא משחרר wheels אליהן.
#    אם יש לך 3.14, התקן 3.12 בנוסף מ-https://www.python.org/downloads/
python --version

# 2. עבור לתיקיית הפרויקט
cd C:\Users\<שם>\Downloads\OTZ\otzaria-ai

# 3. צור סביבה וירטואלית עם 3.12 ספציפית
py -3.12 -m venv venv
.\venv\Scripts\Activate.ps1

# 4. התקן torch CPU (חוסך 2GB של CUDA שלא צריך)
pip install torch==2.4.1 --index-url https://download.pytorch.org/whl/cpu

# 5. התקן את שאר התלויות
pip install -r dicta_service\requirements.txt

# 6. הורדת מודלים (פעם אחת, ~400MB לפרופיל standard)
$env:OTZARIA_AI_PROFILE="standard"
python scripts\download_models.py --profile standard

# 7. הפעלת השרת
python -m dicta_service.main
```

תקבל:
```
INFO  main: starting otzaria-ai v0.1.0, profile=standard
INFO  main: ✓ ready on http://127.0.0.1:7821
```

### Linux / macOS

זהה אבל עם `python3` במקום `python`, וב-PowerShell `export OTZARIA_AI_PROFILE=standard` במקום `$env:`.

### בדיקה ידנית של השרת

```bash
curl http://127.0.0.1:7821/health
```

או טוב יותר - דפדפן:
- `http://127.0.0.1:7821/docs` - Swagger UI אינטראקטיבי, אפשר לבחון כל endpoint

---

## חלק ב' - אריזת השרת לקובץ אחד

לחלוקה למשתמשים בלי Python מותקן:

```bash
pip install pyinstaller
python scripts/build_sidecar.py
```

תוצאה: `dist/otzaria-ai.exe` (Windows) או `dist/otzaria-ai` (Linux/macOS).

הקובץ הזה הוא standalone. שים אותו בתיקייה `<otzaria_install>/ai/`.

---

## חלק ג' - שילוב ב-Otzaria

### 1. העתקת קוד ה-Dart

```bash
# מתיקיית otzaria-ai
cp -r dart_client/lib/ai/ ../otzaria/lib/
```

### 2. בדיקה שיש את התלויות הנדרשות ב-pubspec.yaml

`http: ^1.4.0` - **כבר קיים** באוצריא (ראיתי ב-pubspec.yaml).
`path: ^1.9.0` - **כבר קיים**.

אין צורך להוסיף תלויות חדשות.

### 3. הפעלת השירות ב-main.dart

הוסף בסביבה של `main()`:

```dart
import 'package:otzaria/ai/ai_process_manager.dart';
import 'package:otzaria/ai/ai_service.dart';

late final AiProcessManager aiProcessManager;
late final AiService aiService;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ... קוד קיים של אוצריא ...

  aiProcessManager = AiProcessManager(
    config: const AiProcessConfig(profile: 'standard'),
  );
  // לא חוסם את ההפעלה - נכשל בשקט אם אין sidecar
  unawaited(aiProcessManager.ensureRunning().catchError((e) {
    debugPrint('AI sidecar not available: $e');
  }));

  aiService = AiService(baseUrl: aiProcessManager.baseUrl);

  runApp(const MyApp());
}
```

### 4. הוספת פריט תפריט "כלי AI"

ב-`lib/navigation/` תוסיף Route חדש:

```dart
import 'package:otzaria/ai/views/ai_debug_screen.dart';

// בתוך ה-Drawer / Settings:
ListTile(
  leading: const Icon(Icons.auto_awesome),
  title: const Text('כלי AI'),
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => AiDebugScreen(ai: aiService)),
  ),
),
```

### 5. שילוב הרחבת שאילתה בחיפוש הקיים

ערוך את `lib/search/search_repository.dart` (ראה `dart_client/INTEGRATION.md` לקוד מדויק).

---

## פתרון בעיות

### "הסקריפט download_models.py נתקע ב-95%"
זה לרוב timeout ל-HuggingFace. הרץ שוב - הוא ממשיך מהמקום שעצר.

### "Windows Defender חוסם את otzaria-ai.exe"
תופעה ידועה של PyInstaller `--onefile`. החלף ל-`--onedir` ב-`build_sidecar.py`.

### "השרת עולה אבל הקריאה הראשונה איטית מאוד (10s)"
תקין. זמן ה-startup של ה-runtime + הטעינה הראשונה של המודל. הקריאות הבאות יהיו 10-50× מהירות יותר.

### "RAM נגמר על i3"
- וודא `profile=low`
- צמצם `max_loaded_models=1` ב-config.py
- צמצם `idle_timeout_s=120` כדי שמודלים יתפנו מהר יותר

### "השירות עובד מקור אבל אחרי build_sidecar.py - לא"
שכיחות הסיבות:
1. חוסר `--collect-all transformers` (כבר ב-build_sidecar.py)
2. trust_remote_code לא נתפס - אז המודלים של דיקטה מוסיפים `*.py` ל-cache. בדוק שהקבצים הללו הועתקו ל-build.
3. אנטי-וירוס - ראה למעלה.
