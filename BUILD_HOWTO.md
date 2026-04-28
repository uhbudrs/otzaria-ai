# איך לבנות את ה-installer הסופי

מסמך זה מציג בדיוק איך מקבלים את הקובץ הסופי - `otzaria-X.X-windows-with-ai.exe` - שמשתמש קצה (אברך בכולל) יוריד וילחץ עליו.

## מה הוא מקבל

**קובץ אחד** (כ-1.2GB), לחיצה כפולה → אשף בעברית → התקנת אוצריא + כלי AI + הורדת מודלי דיקטה. בלי Python. בלי git. בלי שום ידע טכני.

## מה צריך כדי לבנות אותו

### במחשב המפתח (לא במחשב המשתמש)
1. **Windows 10/11** 64-bit
2. **Python 3.12** (הותקן אוטומטית בתהליך הזה)
3. **Flutter SDK** (כבר ב-`C:\flutter\`)
4. **Visual Studio 2022** עם workload "Desktop development with C++":
   - MSVC v143 - VS 2022 C++ x64/x86 build tools
   - Windows 10/11 SDK
   - C++ CMake tools
5. **Inno Setup 6** - מ-https://jrsoftware.org/isdl.php
6. **לפחות 5GB דיסק פנוי**

## שלב 1: הכנה חד-פעמית

```powershell
# 1. ודא Python 3.12
py -3.12 --version

# 2. ודא Flutter
flutter doctor

# 3. אם flutter doctor מציין שחסר Visual Studio C++ workload, הפעל את Visual Studio Installer והוסף "Desktop development with C++"

# 4. התקן Inno Setup אם אין
# הרץ: ..\otzaria\installer\install_inno_setup.ps1
```

## שלב 2: בניית ה-installer

```powershell
cd C:\Users\<שם>\Downloads\OTZ\otzaria-ai\build_pipeline
.\BUILD_ALL.ps1
```

זה הכל. אחרי 10-25 דקות תקבל:

```
otzaria-ai\dist\otzaria-0.9.71-ai-windows-with-ai.exe   (~1.2GB)
```

## מה עושה BUILD_ALL.ps1

| שלב | פעולה | זמן |
|-----|--------|-----|
| 0 | בודק dependencies | 2 שניות |
| 1 | יוצר venv .venv-build/ ומתקין torch CPU + transformers | 3-8 דקות (ראשונה בלבד) |
| 2 | מריץ PyInstaller → `dist/otzaria-ai/otzaria-ai.exe` (~250MB) | 2-4 דקות |
| 3 | `flutter build windows --release` | 1-3 דקות |
| 4 | מריץ Inno Setup → `dist/otzaria-X.X-windows-with-ai.exe` | 1-2 דקות |

## אופציונלי - דילוג על שלבים

```powershell
# בנה רק את ה-installer (אם sidecar+flutter כבר מוכנים):
.\BUILD_ALL.ps1 -SkipSidecar -SkipFlutter

# בנה רק sidecar:
.\BUILD_ALL.ps1 -SkipFlutter -SkipInstaller

# פרופיל אחר ל-AI (low / standard / high):
.\BUILD_ALL.ps1 -Profile low
```

## בנייה אוטומטית ב-GitHub Actions

הקובץ [`.github/workflows/build-installer.yml`](.github/workflows/build-installer.yml) מריץ את כל התהליך אוטומטית כשעולה tag חדש (`v*`) או מהממשק. התוצר נשמר כ-artifact + Release.

לפעלה ידנית: GitHub → Actions → Build Otzaria + AI Installer → Run workflow.

## מה עושה ה-installer במחשב המשתמש

1. **שואל היכן להתקין** (ברירת מחדל: `C:\אוצריא`)
2. **שואל אם להוריד מודלי AI עכשיו** (כ-400MB) - מסומן כברירת מחדל
3. **מחלץ קבצים:**
   - `C:\אוצריא\otzaria.exe` - האפליקציה
   - `C:\אוצריא\ai\otzaria-ai.exe` - שרת ה-AI
   - שאר ספריות + DLLs
4. **מוריד מודלים** (אם נבחר) ל-`%LOCALAPPDATA%\otzaria_ai\models\`
5. **מציע להפעיל את אוצריא**
6. אוצריא בעלייה הראשונה: מפעילה את `ai/otzaria-ai.exe` ברקע אוטומטית. תוך 30 שניות "כלי AI" בתפריט עובד.

## בדיקת תקינות במחשב הבדיקה

לאחר התקנה:
1. פתח אוצריא
2. עבור ל"כלי AI" בתפריט (אייקון `auto_awesome`)
3. לחץ "בדוק חיבור לשרת"
4. אמור להופיע:
   ```
   סטטוס: ok
   גרסה: 0.1.0
   פרופיל: standard
   ענן זמין: כן
   ```
5. נסה את הלשונית "הרחבת חיפוש" עם המילה "הלך" - אמור לקבל הולך, ילך, מהלך, וכו'.
6. החיפוש הרגיל (Tantivy) עכשיו אוטומטית משתמש ב-AI אם הוא זמין.

## פתרון בעיות נפוצות

| בעיה | פתרון |
|------|--------|
| `flutter build windows` נכשל "Visual Studio toolchain" | התקן C++ workload כפי שמתואר למעלה |
| `Inno Setup not found` | הרץ `install_inno_setup.ps1` או הוסף ל-PATH ידני |
| ה-PyInstaller .exe גדול מדי (>500MB) | ראה `--excludes` ב-`otzaria-ai.spec` |
| Windows Defender מסמן את ה-installer | חתום ב-cert (יש קובץ sivan22.pfx באוצריא), או הגש ל-Microsoft submit |
| משתמש קצה: AI לא מתחיל | פתח Task Manager → תהליכים → ראה אם `otzaria-ai.exe` רץ. אם לא - ANTIVIRUS חוסם. |

## חתימה דיגיטלית (אופציונלי, מומלץ)

ה-installer לא חתום כברירת מחדל. כדי לחתום:

```powershell
# בתוך BUILD_ALL.ps1, אחרי Inno Setup, הוסף:
& signtool sign /f sivan22.pfx /p sivan22 /t http://timestamp.digicert.com $installer.FullName
```

ללא חתימה, Windows SmartScreen יציג אזהרה למשתמש בפעם הראשונה. עם חתימה תקינה - לא.
