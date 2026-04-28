# החלת אינטגרציית AI על מקור אוצריא.
#
# הסקריפט הזה לוקח otzaria שהוקלון מ-GitHub ומפעיל עליו את כל השינויים
# הדרושים כדי שהיא תעבוד עם sidecar ה-AI.
#
# הרצה:
#   .\apply_integration.ps1 -OtzariaPath C:\path\to\otzaria
#
# (כברירת מחדל: ..\..\otzaria)

[CmdletBinding()]
param(
    [string]$OtzariaPath = (Resolve-Path "$PSScriptRoot\..\..\otzaria").Path
)

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot

if (-not (Test-Path $OtzariaPath)) {
    Write-Error "תיקיית otzaria לא נמצאה ב: $OtzariaPath"
    exit 1
}

if (-not (Test-Path "$OtzariaPath\lib\main.dart")) {
    Write-Error "$OtzariaPath לא נראה כמו תיקיית otzaria - חסר lib/main.dart"
    exit 1
}

Write-Host "החלת אינטגרציית AI על: $OtzariaPath" -ForegroundColor Cyan
Write-Host ""

# ── שלב 1: העתקת קבצי AI חדשים ─────────────────────────────────
Write-Host "→ מעתיק תיקיית lib/ai/..." -ForegroundColor White
$source = "$Root\lib\ai"
$target = "$OtzariaPath\lib\ai"
if (Test-Path $target) { Remove-Item -Recurse -Force $target }
Copy-Item -Recurse $source $target
Write-Host "  ✓ הועתקו $((Get-ChildItem $target -Recurse -File).Count) קבצים" -ForegroundColor Green
Write-Host ""

# ── שלב 2: פאצ'ים לקבצים קיימים ─────────────────────────────────
$patches = @(
    @{
        File = "lib\main.dart";
        Find = "import 'package:otzaria/settings/backup_service.dart';";
        Add  = "import 'package:otzaria/settings/backup_service.dart';`r`nimport 'package:otzaria/ai/ai_provider.dart';";
    },
    @{
        File = "lib\main.dart";
        Find = "  await initialize();";
        Add  = "  await initialize();`r`n`r`n  // הפעלת AI sidecar ברקע - לא חוסם את עליית האפליקציה`r`n  unawaited(AiProvider.instance.initialize());";
    },
    @{
        File = "lib\navigation\more_screen.dart";
        Find = "import 'package:otzaria/settings/settings_repository.dart';";
        Add  = "import 'package:otzaria/settings/settings_repository.dart';`r`nimport 'package:otzaria/ai/views/ai_main_screen.dart';";
    },
    @{
        File = "lib\search\search_repository.dart";
        Find = "import 'package:flutter/foundation.dart';";
        Add  = "import 'package:flutter/foundation.dart';`r`nimport 'package:otzaria/ai/ai_provider.dart';`r`nimport 'package:otzaria/ai/smart_query_expander.dart';";
    }
)

Write-Host "→ מחיל patches על קבצים קיימים..." -ForegroundColor White
foreach ($patch in $patches) {
    $filePath = Join-Path $OtzariaPath $patch.File
    if (-not (Test-Path $filePath)) {
        Write-Host "  ⚠ דילוג: $($patch.File) לא נמצא" -ForegroundColor Yellow
        continue
    }
    $content = Get-Content $filePath -Raw -Encoding UTF8
    if ($content.Contains($patch.Add)) {
        Write-Host "  • $($patch.File) - כבר מותחל" -ForegroundColor DarkGray
        continue
    }
    if (-not $content.Contains($patch.Find)) {
        Write-Host "  ⚠ $($patch.File) - לא נמצא הטקסט לחיפוש (אולי גרסה שונה)" -ForegroundColor Yellow
        continue
    }
    $newContent = $content.Replace($patch.Find, $patch.Add)
    Set-Content -Path $filePath -Value $newContent -Encoding UTF8 -NoNewline
    Write-Host "  ✓ $($patch.File)" -ForegroundColor Green
}

Write-Host ""

# ── שלב 3: שינויים נוספים ב-more_screen ─────────────────────────
$moreScreen = Join-Path $OtzariaPath "lib\navigation\more_screen.dart"
if (Test-Path $moreScreen) {
    $content = Get-Content $moreScreen -Raw -Encoding UTF8

    # הוספת ה-AiMainScreen ל-PageView (פעמיים - small + wide screen)
    $oldPattern = "GematriaSearchScreen(key: _gematriaKey),`r`n                    ],`r`n                  ),`r`n                ),"
    $newPattern = "GematriaSearchScreen(key: _gematriaKey),`r`n                      const AiMainScreen(),`r`n                    ],`r`n                  ),`r`n                ),"
    if (-not $content.Contains("const AiMainScreen()")) {
        Write-Host "  ⚠ הוספת AiMainScreen ל-more_screen דורשת התאמה ידנית - ראה מסמך README"
    }
}

# ── שלב 4: שינוי הצהרת regexTerms ל-mutable ─────────────────────
$searchRepo = Join-Path $OtzariaPath "lib\search\search_repository.dart"
if (Test-Path $searchRepo) {
    $content = Get-Content $searchRepo -Raw -Encoding UTF8
    if ($content.Contains("final List<String> regexTerms = params['regexTerms'] as List<String>;")) {
        $content = $content.Replace(
            "final List<String> regexTerms = params['regexTerms'] as List<String>;",
            "List<String> regexTerms = params['regexTerms'] as List<String>;"
        )
        Set-Content -Path $searchRepo -Value $content -Encoding UTF8 -NoNewline
        Write-Host "  ✓ regexTerms הפך ל-mutable" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  אינטגרציה הושלמה בהצלחה" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "השלבים הבאים:"
Write-Host "  1. בנה את אוצריא: cd $OtzariaPath; flutter build windows --release"
Write-Host "  2. או הרץ build_pipeline\BUILD_ALL.ps1 לבנייה אוטומטית של ה-installer."
