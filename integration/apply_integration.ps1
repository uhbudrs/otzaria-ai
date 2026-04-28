# החלת אינטגרציית AI על מקור אוצריא.
# הסקריפט עושה את כל השינויים הדרושים כדי שאוצריא תעבוד עם sidecar ה-AI.
#
# הרצה:
#   .\apply_integration.ps1 -OtzariaPath C:\path\to\otzaria
#
# ברירת מחדל: ..\..\otzaria

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
    Write-Error "$OtzariaPath לא נראה כמו תיקיית otzaria"
    exit 1
}

Write-Host "החלת אינטגרציית AI על: $OtzariaPath" -ForegroundColor Cyan
Write-Host ""

# ────────────────────────────────────────────────────────────────────
# שלב 1: העתקת lib/ai/ לתוך otzaria
# ────────────────────────────────────────────────────────────────────
Write-Host "→ מעתיק תיקיית lib/ai/..." -ForegroundColor White
$source = "$Root\lib\ai"
$target = "$OtzariaPath\lib\ai"
if (Test-Path $target) { Remove-Item -Recurse -Force $target }
Copy-Item -Recurse $source $target
$count = (Get-ChildItem $target -Recurse -File).Count
Write-Host "  ✓ הועתקו $count קבצים" -ForegroundColor Green

# ────────────────────────────────────────────────────────────────────
# פונקציה לעדכון קובץ עם בדיקה שהשינוי לא הוחל כפול
# ────────────────────────────────────────────────────────────────────
function Replace-Once {
    param([string]$FilePath, [string]$Find, [string]$Replace, [string]$Marker)
    if (-not (Test-Path $FilePath)) {
        Write-Host "  ⚠ לא קיים: $FilePath" -ForegroundColor Yellow
        return
    }
    $content = Get-Content $FilePath -Raw -Encoding UTF8
    if ($content -like "*$Marker*") {
        Write-Host "  • כבר מותחל: $((Split-Path $FilePath -Leaf))" -ForegroundColor DarkGray
        return
    }
    if (-not $content.Contains($Find)) {
        Write-Host "  ⚠ לא נמצא הטקסט במקור: $((Split-Path $FilePath -Leaf))" -ForegroundColor Yellow
        Write-Host "    מחפש: $($Find.Substring(0, [Math]::Min(80, $Find.Length)))..." -ForegroundColor DarkYellow
        return
    }
    $newContent = $content.Replace($Find, $Replace)
    [System.IO.File]::WriteAllText($FilePath, $newContent, [System.Text.UTF8Encoding]::new($false))
    Write-Host "  ✓ $((Split-Path $FilePath -Leaf))" -ForegroundColor Green
}

# ────────────────────────────────────────────────────────────────────
# שלב 2: פאצ' main.dart
# ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "→ מעדכן main.dart..." -ForegroundColor White
$mainDart = "$OtzariaPath\lib\main.dart"

Replace-Once -FilePath $mainDart `
    -Find "import 'package:otzaria/settings/backup_service.dart';" `
    -Replace "import 'package:otzaria/settings/backup_service.dart';`r`nimport 'package:otzaria/ai/ai_provider.dart';" `
    -Marker "ai/ai_provider.dart"

Replace-Once -FilePath $mainDart `
    -Find "  await initialize();" `
    -Replace "  await initialize();`r`n`r`n  // הפעלת AI sidecar ברקע - לא חוסם את עליית האפליקציה`r`n  unawaited(AiProvider.instance.initialize());" `
    -Marker "AiProvider.instance.initialize"

# ────────────────────────────────────────────────────────────────────
# שלב 3: פאצ' more_screen.dart - תפריט "כלי AI"
# ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "→ מעדכן more_screen.dart..." -ForegroundColor White
$moreDart = "$OtzariaPath\lib\navigation\more_screen.dart"

# 3a. import
Replace-Once -FilePath $moreDart `
    -Find "import 'package:otzaria/settings/settings_repository.dart';" `
    -Replace "import 'package:otzaria/settings/settings_repository.dart';`r`nimport 'package:otzaria/ai/views/ai_main_screen.dart';" `
    -Marker "ai/views/ai_main_screen.dart"

# 3b. הוספת AiMainScreen לשני ה-PageView (small + wide)
$content = Get-Content $moreDart -Raw -Encoding UTF8
if ($content -notmatch "const AiMainScreen\(\)") {
    # PageView ראשון (BottomNavigationBar - small screen)
    $smallPattern = "                      GematriaSearchScreen(key: _gematriaKey),`r`n                    ],"
    $smallReplace = "                      GematriaSearchScreen(key: _gematriaKey),`r`n                      const AiMainScreen(),`r`n                    ],"
    if ($content.Contains($smallPattern)) {
        $content = $content.Replace($smallPattern, $smallReplace)
    }
    # PageView שני (NavigationRail - wide screen)
    $widePattern = "                    GematriaSearchScreen(key: _gematriaKey),`r`n                  ],"
    $wideReplace = "                    GematriaSearchScreen(key: _gematriaKey),`r`n                    const AiMainScreen(),`r`n                  ],"
    if ($content.Contains($widePattern)) {
        $content = $content.Replace($widePattern, $wideReplace)
    }

    # הוספת destination ל-NavigationRail
    $railPattern = "                  NavigationRailDestination(`r`n                    icon: Icon(FluentIcons.calculator_24_regular),`r`n                    label: Text('גימטריות'),`r`n                  ),`r`n                ],"
    $railReplace = "                  NavigationRailDestination(`r`n                    icon: Icon(FluentIcons.calculator_24_regular),`r`n                    label: Text('גימטריות'),`r`n                  ),`r`n                  NavigationRailDestination(`r`n                    icon: Icon(Icons.auto_awesome),`r`n                    label: Text('כלי AI'),`r`n                  ),`r`n                ],"
    if ($content.Contains($railPattern)) {
        $content = $content.Replace($railPattern, $railReplace)
    }

    # הוספת BottomNavigationBarItem
    $bottomPattern = "                BottomNavigationBarItem(`r`n                  icon: Icon(FluentIcons.calculator_24_regular, size: 20),`r`n                  label: 'גימטריה',`r`n                ),`r`n              ],"
    $bottomReplace = "                BottomNavigationBarItem(`r`n                  icon: Icon(FluentIcons.calculator_24_regular, size: 20),`r`n                  label: 'גימטריה',`r`n                ),`r`n                BottomNavigationBarItem(`r`n                  icon: Icon(Icons.auto_awesome, size: 20),`r`n                  label: 'AI',`r`n                ),`r`n              ],"
    if ($content.Contains($bottomPattern)) {
        $content = $content.Replace($bottomPattern, $bottomReplace)
    }

    # _getTitle - הוספת case 5
    $titlePattern = "      case 4:`r`n        return 'גימטריה';`r`n      default:"
    $titleReplace = "      case 4:`r`n        return 'גימטריה';`r`n      case 5:`r`n        return 'כלי AI';`r`n      default:"
    if ($content.Contains($titlePattern)) {
        $content = $content.Replace($titlePattern, $titleReplace)
    }

    [System.IO.File]::WriteAllText($moreDart, $content, [System.Text.UTF8Encoding]::new($false))
    Write-Host "  ✓ הוספתי כל ה-AI hooks ל-more_screen.dart" -ForegroundColor Green
} else {
    Write-Host "  • more_screen.dart כבר עם AI" -ForegroundColor DarkGray
}

# ────────────────────────────────────────────────────────────────────
# שלב 4: פאצ' search_repository.dart - הרחבת שאילתה
# ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "→ מעדכן search_repository.dart..." -ForegroundColor White
$searchDart = "$OtzariaPath\lib\search\search_repository.dart"

# 4a. imports
Replace-Once -FilePath $searchDart `
    -Find "import 'package:flutter/foundation.dart';" `
    -Replace "import 'package:flutter/foundation.dart';`r`nimport 'package:otzaria/ai/ai_provider.dart';`r`nimport 'package:otzaria/ai/smart_query_expander.dart';" `
    -Marker "ai/ai_provider.dart"

# 4b + 4c: שני שינויים בו זמנית - mutable + בלוק AI
# מאחדים כדי לוודא שאין דילוג בגלל marker
$content = Get-Content $searchDart -Raw -Encoding UTF8
$expansionMarker = "AI-expanded regexTerms"
if ($content -notlike "*$expansionMarker*") {
    # שלב א': הסרת final
    $finalFind = "final List<String> regexTerms = params['regexTerms'] as List<String>;"
    $finalReplace = "List<String> regexTerms = params['regexTerms'] as List<String>;"
    if ($content.Contains($finalFind)) {
        $content = $content.Replace($finalFind, $finalReplace)
        Write-Host "  ✓ regexTerms הפך ל-mutable" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ לא נמצא 'final List<String> regexTerms'" -ForegroundColor Yellow
    }

    # שלב ב': הוספת בלוק הרחבה. השתמשנו ב-here-string single-quoted (@'...'@)
    # כדי ש-PowerShell לא יבצע interpolation על $regexTerms ו-$e בתוך הקוד Dart.
    $findBlock = "    final int maxExpansions = params['maxExpansions'] as int;"
    $replaceBlock = @'
    final int maxExpansions = params['maxExpansions'] as int;

    // הרחבת שאילתה אוטומטית לפי שורש (lemma) דרך AI sidecar.
    // חיפוש "הלך" ימצא גם "הולך", "ילך", "הליכה" וכו'.
    // בכישלון - חיפוש רגיל בלי AI.
    if (AiProvider.instance.isReady && !fuzzy && !hasAlternativeWords) {
      try {
        final expander = SmartQueryExpander(AiProvider.instance.service);
        final expanded = await expander.expand(query);
        if (expanded.regexTerms.isNotEmpty) {
          regexTerms = expanded.regexTerms;
          debugPrint('AI-expanded regexTerms: $regexTerms');
        }
      } catch (e) {
        debugPrint('AI expansion failed (using basic search): $e');
      }
    }
'@
    if ($content.Contains($findBlock)) {
        $content = $content.Replace($findBlock, $replaceBlock)
        Write-Host "  ✓ הוספתי בלוק הרחבת AI" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ לא נמצאה השורה לאחריה להוסיף את בלוק ה-AI" -ForegroundColor Yellow
    }

    [System.IO.File]::WriteAllText($searchDart, $content, [System.Text.UTF8Encoding]::new($false))
} else {
    Write-Host "  • search_repository.dart כבר עם AI" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  אינטגרציה הושלמה" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════" -ForegroundColor Green
