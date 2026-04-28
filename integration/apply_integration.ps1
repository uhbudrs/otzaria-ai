# החלת אינטגרציית AI על מקור אוצריא (migrationDB_V2 / 0.9.90+).
#
# שינויים בענף החדש:
#   - more_screen.dart הוחלף ב-tools/tools_screen.dart עם ToolDescriptor registry
#   - main.dart: initialize() → _runAppBootstrap()
#   - search_repository.dart דומה אבל עם 2 instances של regexTerms

[CmdletBinding()]
param(
    [string]$OtzariaPath = (Resolve-Path "$PSScriptRoot\..\..\otzaria").Path
)

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot

if (-not (Test-Path "$OtzariaPath\lib\main.dart")) {
    Write-Error "$OtzariaPath לא נראה כמו תיקיית otzaria"
    exit 1
}

Write-Host "החלת אינטגרציית AI על: $OtzariaPath" -ForegroundColor Cyan

# ────────────────────────────────────────────────────────────────────
# שלב 1: העתקת lib/ai/
# ────────────────────────────────────────────────────────────────────
$source = "$Root\lib\ai"
$target = "$OtzariaPath\lib\ai"
if (Test-Path $target) { Remove-Item -Recurse -Force $target }
Copy-Item -Recurse $source $target
$count = (Get-ChildItem $target -Recurse -File).Count
Write-Host "→ הועתקו $count קבצי AI ל-lib/ai/" -ForegroundColor Green

# ────────────────────────────────────────────────────────────────────
# שלב 2: main.dart - import + הפעלה ב-bootstrap
# ────────────────────────────────────────────────────────────────────
$mainDart = "$OtzariaPath\lib\main.dart"
$mainContent = Get-Content $mainDart -Raw -Encoding UTF8

if ($mainContent -notlike "*ai/ai_provider.dart*") {
    # מוסיפים import אחרי import של find_ref_repository (קיים ב-V2)
    $importAnchor = "import 'package:otzaria/find_ref/find_ref_repository.dart';"
    if ($mainContent.Contains($importAnchor)) {
        $mainContent = $mainContent.Replace(
            $importAnchor,
            "$importAnchor`r`nimport 'package:otzaria/ai/ai_provider.dart';"
        )
    } else {
        Write-Host "  ⚠ לא נמצא anchor להוספת import ב-main.dart" -ForegroundColor Yellow
    }

    # מוסיפים את ה-AI initialize אחרי _runAppBootstrap בתוך main()
    $bootAnchor = "  await _runAppBootstrap();"
    if ($mainContent.Contains($bootAnchor)) {
        $mainContent = $mainContent.Replace(
            $bootAnchor,
            "$bootAnchor`r`n`r`n  // הפעלת AI sidecar ברקע - לא חוסם את עליית האפליקציה`r`n  unawaited(AiProvider.instance.initialize());"
        )
    } else {
        Write-Host "  ⚠ לא נמצא '_runAppBootstrap' ב-main.dart" -ForegroundColor Yellow
    }

    [System.IO.File]::WriteAllText($mainDart, $mainContent, [System.Text.UTF8Encoding]::new($false))
    Write-Host "→ main.dart עודכן" -ForegroundColor Green
} else {
    Write-Host "→ main.dart כבר עם AI" -ForegroundColor DarkGray
}

# ────────────────────────────────────────────────────────────────────
# שלב 3: tools_screen.dart - הוספת BuiltInToolDescriptor חדש
# ────────────────────────────────────────────────────────────────────
$toolsDart = "$OtzariaPath\lib\tools\tools_screen.dart"
if (-not (Test-Path $toolsDart)) {
    Write-Error "tools_screen.dart לא נמצא - אולי ענף שגוי?"
    exit 1
}

$toolsContent = Get-Content $toolsDart -Raw -Encoding UTF8

if ($toolsContent -notlike "*builtin.ai_tools*") {
    # הוספת import של AiMainScreen
    $toolsImportAnchor = "import 'package:otzaria/tools/calendar/calendar_screen.dart';"
    if ($toolsContent.Contains($toolsImportAnchor)) {
        $toolsContent = $toolsContent.Replace(
            $toolsImportAnchor,
            "$toolsImportAnchor`r`nimport 'package:otzaria/ai/views/ai_main_screen.dart';"
        )
    }

    # הוספת BuiltInToolDescriptor אחרי acronyms_dictionary (האחרון, order 70)
    # הסגירה היא ' );\r\n    ];' - מצרפים ערך נוסף לפניה
    $listEndPattern = @'
        toolId: 'builtin.acronyms_dictionary',
        label: 'ראשי תיבות',
        icon: FluentIcons.text_quote_24_regular,
        iconFilled: FluentIcons.text_quote_24_filled,
        order: 70,
        pageBuilder: () => const AcronymsDictionaryScreen(),
      ),
    ];
'@
    $listEndReplace = @'
        toolId: 'builtin.acronyms_dictionary',
        label: 'ראשי תיבות',
        icon: FluentIcons.text_quote_24_regular,
        iconFilled: FluentIcons.text_quote_24_filled,
        order: 70,
        pageBuilder: () => const AcronymsDictionaryScreen(),
      ),
      BuiltInToolDescriptor(
        toolId: 'builtin.ai_tools',
        label: 'כלי AI',
        icon: FluentIcons.bot_24_regular,
        iconFilled: FluentIcons.bot_24_filled,
        order: 80,
        pageBuilder: () => const AiMainScreen(),
      ),
    ];
'@

    if ($toolsContent.Contains($listEndPattern)) {
        $toolsContent = $toolsContent.Replace($listEndPattern, $listEndReplace)
        [System.IO.File]::WriteAllText($toolsDart, $toolsContent, [System.Text.UTF8Encoding]::new($false))
        Write-Host "→ tools_screen.dart - נוסף descriptor של AI" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ לא נמצא end-of-list pattern ב-tools_screen.dart" -ForegroundColor Yellow
    }
} else {
    Write-Host "→ tools_screen.dart כבר עם AI" -ForegroundColor DarkGray
}

# ────────────────────────────────────────────────────────────────────
# שלב 4: search_repository.dart - הרחבת שאילתה
# יש 2 instances של regexTerms ב-V2 - מטפלים רק בראשון (regular search)
# ────────────────────────────────────────────────────────────────────
$searchDart = "$OtzariaPath\lib\search\search_repository.dart"
$searchContent = Get-Content $searchDart -Raw -Encoding UTF8

if ($searchContent -notlike "*AI-expanded regexTerms*") {
    # 4a. imports
    $searchImportAnchor = "import 'package:flutter/foundation.dart';"
    if ($searchContent.Contains($searchImportAnchor)) {
        $searchContent = $searchContent.Replace(
            $searchImportAnchor,
            "$searchImportAnchor`r`nimport 'package:otzaria/ai/ai_provider.dart';`r`nimport 'package:otzaria/ai/smart_query_expander.dart';"
        )
    }

    # 4b. הסרת final + הוספת בלוק AI.
    # שני ה-heredocs single-quoted (@'...'@) - PS לא יבצע interpolation על $regexTerms וכו.
    # ב-Dart מותר לכתוב strings עם ' או " - שני הסגנונות מקובלים.
    $regularSearchBlock = @'
    final List<String> regexTerms = params["regexTerms"] as List<String>;
    final int effectiveSlop = params["effectiveSlop"] as int;
    final int maxExpansions = params["maxExpansions"] as int;
'@
    $regularSearchReplace = @'
    List<String> regexTerms = params["regexTerms"] as List<String>;
    final int effectiveSlop = params["effectiveSlop"] as int;
    final int maxExpansions = params["maxExpansions"] as int;

    // Smart query expansion via AI sidecar (DictaBERT lemma).
    // Searching halach will also find holech, yelech, halicha etc.
    if (AiProvider.instance.isReady && !fuzzy && !hasAlternativeWords) {
      try {
        final expander = SmartQueryExpander(AiProvider.instance.service);
        final expanded = await expander.expand(query);
        if (expanded.regexTerms.isNotEmpty) {
          regexTerms = expanded.regexTerms;
          debugPrint("AI-expanded regexTerms: $regexTerms");
        }
      } catch (e) {
        debugPrint("AI expansion failed (using basic search): $e");
      }
    }
'@
    # אבל ה-block המקורי בקובץ דווקא יש לו ' (singlequote)! נחליף ב-block אם נמצא:
    # מנסה גם אם הקובץ באמת עם '
    $regularSearchBlockSingleQ = "    final List<String> regexTerms = params['regexTerms'] as List<String>;`r`n    final int effectiveSlop = params['effectiveSlop'] as int;`r`n    final int maxExpansions = params['maxExpansions'] as int;"

    # החלפה ראשונה בלבד! יש 2 מתודות חיפוש בקובץ V2, רק אחת מהן (הראשונה)
    # מגדירה hasAlternativeWords. נשתמש ב-IndexOf + Substring.
    $matchedBlock = $null
    if ($searchContent.Contains($regularSearchBlockSingleQ)) {
        $matchedBlock = $regularSearchBlockSingleQ
        Write-Host "→ search_repository.dart - matched single-quote block" -ForegroundColor Cyan
    } elseif ($searchContent.Contains($regularSearchBlock)) {
        $matchedBlock = $regularSearchBlock
        Write-Host "→ search_repository.dart - matched double-quote block" -ForegroundColor Cyan
    } else {
        Write-Host "  ⚠ לא נמצא ה-block של regexTerms" -ForegroundColor Yellow
    }

    if ($matchedBlock) {
        # החלף רק את המופע הראשון
        $idx = $searchContent.IndexOf($matchedBlock)
        if ($idx -ge 0) {
            $before = $searchContent.Substring(0, $idx)
            $after  = $searchContent.Substring($idx + $matchedBlock.Length)
            $searchContent = $before + $regularSearchReplace + $after
            Write-Host "→ search_repository.dart עם הרחבת AI (פעם אחת בלבד)" -ForegroundColor Green
        }
    }

    [System.IO.File]::WriteAllText($searchDart, $searchContent, [System.Text.UTF8Encoding]::new($false))
} else {
    Write-Host "→ search_repository.dart כבר עם AI" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  אינטגרציה הושלמה (migrationDB_V2)" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════" -ForegroundColor Green
