# Post-install: הורדת מודלי דיקטה.
# רץ אוטומטית אחרי ההתקנה אם המשתמש סימן את הטסק "downloadmodels".
#
# אסטרטגיה: מורידים את הקבצים ישירות מ-HuggingFace דרך HTTPS,
# בלי להזדקק ל-Python. כך מתקין שאין לו אינטרנט עדיין יוכל פשוט
# להריץ אוצריא ולהשתמש בכלים שלא דורשים מודל מקומי.
#
# קבצי המודל יורדים ל-%LOCALAPPDATA%\otzaria_ai\models\

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ModelsRoot = Join-Path $env:LOCALAPPDATA "otzaria_ai\models"
New-Item -ItemType Directory -Force -Path $ModelsRoot | Out-Null

# רשימת המודלים להורדה - profile standard
$Models = @(
    @{
        Repo = "dicta-il/dictabert-tiny";
        Files = @("config.json", "tokenizer.json", "tokenizer_config.json", "vocab.txt", "model.safetensors", "special_tokens_map.json");
    },
    @{
        Repo = "dicta-il/dictabert-tiny-joint";
        # joint דורש גם קבצי .py בגלל trust_remote_code
        Files = @("config.json", "tokenizer.json", "tokenizer_config.json", "vocab.txt", "model.safetensors", "special_tokens_map.json", "BertForJointParsing.py", "BertForSyntaxParsing.py", "BertForMorphTagging.py", "BertForPrefixMarking.py", "BertForJointParsing.py");
    }
)

function Download-File {
    param([string]$Url, [string]$OutPath)
    Write-Host "  ↓ $Url" -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $Url -OutFile $OutPath -UseBasicParsing -TimeoutSec 600
    } catch {
        Write-Host "    ⚠ failed: $_" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  הורדת מודלי דיקטה לכלי ה-AI של אוצריא" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "יעד: $ModelsRoot"
Write-Host ""

foreach ($model in $Models) {
    $repo = $model.Repo
    $repoSafe = $repo -replace '/', '--'
    $localDir = Join-Path $ModelsRoot $repoSafe
    New-Item -ItemType Directory -Force -Path $localDir | Out-Null

    Write-Host "→ $repo" -ForegroundColor White

    foreach ($f in $model.Files) {
        $url = "https://huggingface.co/$repo/resolve/main/$f"
        $out = Join-Path $localDir $f
        if (Test-Path $out) {
            Write-Host "  ✓ $f (כבר קיים)" -ForegroundColor DarkGray
            continue
        }
        Download-File -Url $url -OutPath $out
    }
    Write-Host ""
}

Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  סיים. הפעל את אוצריא ולחץ על 'כלי AI'." -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green

Start-Sleep -Seconds 3
