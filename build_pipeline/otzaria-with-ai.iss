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
#define MyAppVersion "0.9.71-ai"
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
Name: "downloadmodels"; Description: "הורד את מודלי דיקטה כעת (כ-400MB, דורש אינטרנט)"; GroupDescription: "כלי AI:"; Flags: checkedonce

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

; ── סקריפט הורדת מודלים (לטסק האופציונלית) ───────────────────────
Source: "download_models_post_install.ps1"; DestDir: "{app}\ai"; Flags: ignoreversion

; ── סקריפט הסרת התקנה ───────────────────────────────────────────
Source: "..\..\otzaria\installer\uninstall_msix.ps1"; DestDir: "{app}"; Flags: ignoreversion

[Run]
; הסר MSIX קודם של אוצריא אם קיים
Filename: "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"; \
    WorkingDir: "{app}"; \
    Parameters: " -sta -WindowStyle Hidden -noprofile -executionpolicy bypass -file uninstall_msix.ps1"; \
    Flags: runhidden

; הורדת מודלים אם המשתמש בחר
Filename: "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"; \
    WorkingDir: "{app}\ai"; \
    Parameters: "-NoProfile -ExecutionPolicy Bypass -File download_models_post_install.ps1"; \
    Description: "הורדת מודלי דיקטה"; \
    StatusMsg: "מוריד את מודלי ה-AI מ-HuggingFace ({code:GetModelsSize}MB)..."; \
    Tasks: downloadmodels; \
    Flags: postinstall

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
