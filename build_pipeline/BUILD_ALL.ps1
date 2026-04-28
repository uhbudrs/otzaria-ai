# ════════════════════════════════════════════════════════════════════
#   BUILD_ALL.ps1 - מ-Source ל-Installer יחיד
# ════════════════════════════════════════════════════════════════════
#
# סקריפט אחד שמייצר את ה-installer הסופי של אוצריא+AI.
#
# הרצה:
#   .\BUILD_ALL.ps1
#
# מה הוא עושה (לפי הסדר):
#   1. בודק dependencies (Python 3.12, Flutter, Inno Setup)
#   2. בונה את ה-AI sidecar עם PyInstaller
#   3. בונה את אוצריא לפלטפורמת Windows release
#   4. מריץ Inno Setup כדי לייצר otzaria-X.X-windows-with-ai.exe
#
# זמן בנייה משוער: 10-25 דקות בריצה ראשונה (תלוי בהורדת תלויות).
# בריצות חוזרות: 3-7 דקות.

[CmdletBinding()]
param(
    [switch]$SkipSidecar,
    [switch]$SkipFlutter,
    [switch]$SkipInstaller,
    [string]$PythonExe = "py -3.12",
    [string]$Profile = "standard"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$OtzariaRoot = Join-Path (Split-Path -Parent $Root) "otzaria"
$DistDir = Join-Path $Root "dist"

function Section($title) {
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host "  $title" -ForegroundColor Magenta
    Write-Host "════════════════════════════════════════════════════" -ForegroundColor Magenta
}

function Require-Tool($cmd, $hint) {
    $found = Get-Command $cmd -ErrorAction SilentlyContinue
    if (-not $found) {
        Write-Host "❌ $cmd לא נמצא." -ForegroundColor Red
        Write-Host "   $hint" -ForegroundColor Yellow
        exit 1
    }
}

# ── שלב 0: בדיקת תלויות ─────────────────────────────────────────
Section "שלב 0: בדיקת dependencies"
Require-Tool "py" "התקן Python 3.12 מ-https://www.python.org/downloads/"
Require-Tool "flutter" "התקן Flutter SDK מ-https://flutter.dev/"
$Iscc = Get-Command "iscc" -ErrorAction SilentlyContinue
if (-not $Iscc) {
    # winget מתקין ל-LOCALAPPDATA למשתמש שאינו מנהל, או ל-Program Files
    $InnoCandidates = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
        "${env:LOCALAPPDATA}\Programs\Inno Setup 6\ISCC.exe"
    )
    $InnoFound = $InnoCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($InnoFound) {
        $env:PATH = "$env:PATH;$([System.IO.Path]::GetDirectoryName($InnoFound))"
        Write-Host "✓ Inno Setup נמצא ב: $InnoFound"
    } else {
        Write-Host "⚠ Inno Setup לא נמצא. התקנה: winget install JRSoftware.InnoSetup" -ForegroundColor Yellow
        if (-not $SkipInstaller) { exit 1 }
    }
}
Write-Host "✓ כל ה-dependencies מותקנים" -ForegroundColor Green

# ── שלב 1: בניית ה-AI sidecar ───────────────────────────────────
if (-not $SkipSidecar) {
    Section "שלב 1: בניית AI sidecar עם PyInstaller"

    Push-Location $Root
    try {
        $venvDir = Join-Path $Root ".venv-build"
        if (-not (Test-Path $venvDir)) {
            Write-Host "→ יוצר venv עם Python 3.12..."
            Invoke-Expression "$PythonExe -m venv `"$venvDir`""
        }

        $venvPython = Join-Path $venvDir "Scripts\python.exe"
        $venvPip    = Join-Path $venvDir "Scripts\pip.exe"

        Write-Host "→ מתקין torch CPU..."
        & $venvPip install --quiet torch==2.4.1 --index-url https://download.pytorch.org/whl/cpu

        Write-Host "→ מתקין שאר התלויות..."
        & $venvPip install --quiet -r "$Root\dicta_service\requirements.txt"

        Write-Host "→ מתקין pyinstaller..."
        & $venvPip install --quiet pyinstaller==6.10.0

        Write-Host "→ מריץ PyInstaller..."
        & $venvPython -m PyInstaller "$Root\build_pipeline\otzaria-ai.spec" `
            --noconfirm --clean `
            --distpath "$DistDir" `
            --workpath "$Root\build"

        $exePath = Join-Path $DistDir "otzaria-ai\otzaria-ai.exe"
        if (Test-Path $exePath) {
            Write-Host "✓ sidecar נבנה: $exePath" -ForegroundColor Green
        } else {
            Write-Host "❌ sidecar לא נבנה כצפוי" -ForegroundColor Red
            exit 1
        }
    } finally {
        Pop-Location
    }
}

# ── שלב 2: בניית Flutter Windows release ────────────────────────
if (-not $SkipFlutter) {
    Section "שלב 2: בניית אוצריא (Flutter Windows release)"

    if (-not (Test-Path $OtzariaRoot)) {
        Write-Host "❌ תיקיית otzaria לא נמצאה ב: $OtzariaRoot" -ForegroundColor Red
        exit 1
    }

    Push-Location $OtzariaRoot
    try {
        Write-Host "→ flutter pub get..."
        & flutter pub get

        Write-Host "→ flutter build windows --release..."
        & flutter build windows --release

        $flutterOut = Join-Path $OtzariaRoot "build\windows\x64\runner\Release\otzaria.exe"
        if (Test-Path $flutterOut) {
            Write-Host "✓ אוצריא נבנתה: $flutterOut" -ForegroundColor Green
        } else {
            Write-Host "❌ אוצריא לא נבנתה כצפוי" -ForegroundColor Red
            exit 1
        }
    } finally {
        Pop-Location
    }
}

# ── שלב 3: יצירת ה-installer המאוחד ─────────────────────────────
if (-not $SkipInstaller) {
    Section "שלב 3: יצירת installer מאוחד עם Inno Setup"

    Push-Location (Join-Path $Root "build_pipeline")
    try {
        & iscc "otzaria-with-ai.iss"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Inno Setup נכשל" -ForegroundColor Red
            exit 1
        }
    } finally {
        Pop-Location
    }

    $installer = Get-ChildItem -Path $DistDir -Filter "otzaria-*-windows-with-ai.exe" |
                 Sort-Object LastWriteTime -Descending |
                 Select-Object -First 1
    if ($installer) {
        $sizeMB = [math]::Round($installer.Length / 1MB, 1)
        Write-Host ""
        Write-Host "════════════════════════════════════════════════════" -ForegroundColor Green
        Write-Host "  ✓ ה-installer מוכן!" -ForegroundColor Green
        Write-Host "════════════════════════════════════════════════════" -ForegroundColor Green
        Write-Host ""
        Write-Host "  קובץ: $($installer.FullName)"
        Write-Host "  גודל: $sizeMB MB"
        Write-Host ""
        Write-Host "  לחיצה כפולה תתקין את אוצריא + כלי AI." -ForegroundColor Cyan
        Write-Host ""
    }
}
