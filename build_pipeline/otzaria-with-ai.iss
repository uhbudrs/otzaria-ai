; ════════════════════════════════════════════════════════════════════
;  Inno Setup - אוצריא עם כלי AI של דיקטה
;  installer יחיד שמתקין את הכל בלחיצה אחת.
;  אין צורך ב-Python, אין צורך בידע טכני.
; ════════════════════════════════════════════════════════════════════
;
; לקומפילציה:
;   ISCC.exe otzaria-with-ai.iss
;
; דורש לפני הקומפילציה:
;   1. אוצריא קומפילד ב-..\..\otzaria\build\windows\x64\runner\Release\
;   2. ה-sidecar קומפילד ב-..\dist\otzaria-ai\
;   3. (אופציונלי) מודלים מועתקים ל-..\dist\models\

#define MyAppName "אוצריא"
#define MyAppVersion "0.9.90-ai"
#define MyAppPublisher "Otzaria + Dicta AI"
#define MyAppURL "https://github.com/Otzaria/otzaria"
#define MyAppExeName "otzaria.exe"
#define AiServiceExeName "otzaria-ai.exe"

[Setup]
AppId={{B8E2C5A1-7F4D-4E2A-9C1B-AAD8F5E3B7C2}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName=C:\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=admin
OutputDir=..\dist
OutputBaseFilename=otzaria-{#MyAppVersion}-windows-with-ai
SetupIconFile=..\..\otzaria\installer\white_sketch128x128.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
DisableDirPage=auto
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
LZMAUseSeparateProcess=yes
LZMANumBlockThreads=4
DiskSpanning=no
ShowLanguageDialog=no

[Languages]
Name: "hebrew"; MessagesFile: "compiler:Languages\Hebrew.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
; המודלים מוטמעים ב-installer, ההורדה היא רק fallback למקרה שזה נמחק
Name: "downloadmodels"; Description: "הורד מודלים שוב מ-HuggingFace (לא נחוץ ברוב המקרים)"; GroupDescription: "כלי AI:"; Flags: unchecked

[InstallDelete]
Type: filesandordirs; Name: "{app}\default.isar"
Type: filesandordirs; Name: "{app}\ai\__pycache__"

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Files]
; ── אוצריא הראשית ────────────────────────────────────────────
Source: "..\..\otzaria\build\windows\x64\runner\Release\*"; \
    Excludes: "*.msix,*.msixbundle,*.appx,*.appxbundle,*.appinstaller"; \
    DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; ── ה-sidecar של AI (PyInstaller onedir) ────────────────────────
Source: "..\dist\otzaria-ai\*"; DestDir: "{app}\ai"; \
    Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist

; ── מודלים מודבקים (yרידו בעת ה-build) - ~360MB ─────────────────
Source: "..\dist\bundled_models\*"; DestDir: "{app}\bundled_models"; \
    Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist

; ── סקריפט הורדת מודלים (fallback אם המודלים המוטמעים נמחקו) ────
Source: "download_models_post_install.ps1"; DestDir: "{app}\ai"; Flags: ignoreversion

; ── סקריפט להעתקת המודלים המוטמעים ל-LOCALAPPDATA של המשתמש ─────
Source: "install_bundled_models.ps1"; DestDir: "{app}"; Flags: ignoreversion

; ── סקריפט הסרת התקנה - הוסר ב-V2 (לא קיים יותר) ─────────────────
; Source: "..\..\otzaria\installer\uninstall_msix.ps1"; DestDir: "{app}"; Flags: ignoreversion

[Run]
; העתקת המודלים המוטמעים ל-LOCALAPPDATA של המשתמש המתקין.
; runasoriginaluser מבטיח ש-$env:LOCALAPPDATA יתפרש כתיקיית המשתמש,
; לא של ה-admin שמריץ את ההתקנה.
Filename: "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"; \
    WorkingDir: "{app}"; \
    Parameters: "-NoProfile -ExecutionPolicy Bypass -File install_bundled_models.ps1"; \
    StatusMsg: "מתקין מודלי דיקטה (~360MB)..."; \
    Flags: runhidden runasoriginaluser

; הורדת מודלים מהאינטרנט - רק אם המשתמש סימן (fallback אם המוטמעים נכשלו)
Filename: "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"; \
    WorkingDir: "{app}\ai"; \
    Parameters: "-NoProfile -ExecutionPolicy Bypass -File download_models_post_install.ps1"; \
    Description: "הורד מודלים מ-HuggingFace (אם החריגה ב-NetFree)"; \
    StatusMsg: "מוריד מודלים מ-HuggingFace..."; \
    Tasks: downloadmodels; \
    Flags: postinstall runasoriginaluser

; הפעלת אוצריא בסוף
Filename: "{app}\{#MyAppExeName}"; \
    Description: "{cm:LaunchProgram,{#MyAppName}}"; \
    Flags: nowait postinstall skipifsilent

[UninstallRun]
; עצירת sidecar אם רץ
Filename: "{cmd}"; Parameters: "/C taskkill /IM {#AiServiceExeName} /F"; Flags: runhidden

[UninstallDelete]
Type: filesandordirs; Name: "{app}\ai"

[Code]
function GetModelsSize(Param: String): String;
begin
  Result := '~400';
end;

function InitializeSetup(): Boolean;
begin
  // ניתן להוסיף בדיקות תאימות (מקום בדיסק, RAM, וכו')
  Result := True;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  EnvFile: string;
  EnvContent: string;
begin
  if CurStep = ssPostInstall then
  begin
    // יוצרים קובץ env שאוצריא קוראת בעלייה - מציין שה-sidecar מותקן
    EnvFile := ExpandConstant('{app}\ai\.installed');
    EnvContent := 'profile=standard' + #13#10 +
                  'version={#MyAppVersion}' + #13#10;
    SaveStringToFile(EnvFile, EnvContent, False);
  end;
end;
