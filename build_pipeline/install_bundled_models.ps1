# מעתיק את המודלים המוטמעים מ-{app}\bundled_models אל
# %LOCALAPPDATA%\otzaria_ai\models. רץ ע"י ה-installer בסוף ההתקנה
# עם דגל runasoriginaluser כדי ש-$env:LOCALAPPDATA יתפרש כמשתמש.

$ErrorActionPreference = "Continue"

$src = Join-Path $PSScriptRoot "bundled_models"
$dst = Join-Path $env:LOCALAPPDATA "otzaria_ai\models"

if (-not (Test-Path $src)) {
    Write-Host "אין bundled_models - מדלג"
    exit 0
}

# יצירת היעד אם לא קיים
New-Item -ItemType Directory -Force -Path $dst | Out-Null

# העתקה (לא דורסים אם כבר יש - המשתמש אולי הוריד גרסה אחרת)
foreach ($modelDir in (Get-ChildItem $src -Directory)) {
    $target = Join-Path $dst $modelDir.Name
    if (Test-Path $target) {
        Write-Host "$($modelDir.Name) - כבר קיים, מדלג"
        continue
    }
    Copy-Item -Recurse $modelDir.FullName $target -Force
    Write-Host "✓ $($modelDir.Name)"
}

Write-Host ""
Write-Host "מודלים מותקנים ב: $dst"
