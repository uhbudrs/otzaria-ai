@echo off
setlocal enabledelayedexpansion
rem בנייה ידנית של אוצריא דרך vcvars64.bat
rem עוקף את Flutter doctor שמתבלבל בין Insiders ל-BuildTools

rem מנסה קודם BuildTools, ואז Insiders
set "VCVARS=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
if not exist "!VCVARS!" set "VCVARS=C:\Program Files\Microsoft Visual Studio\18\Insiders\VC\Auxiliary\Build\vcvars64.bat"
if not exist "!VCVARS!" (
    echo ERROR: vcvars64.bat not found in BuildTools or Insiders
    exit /b 1
)
echo Using vcvars: !VCVARS!
call "!VCVARS!" || exit /b %ERRORLEVEL%

echo.
echo === Compiler available ===
where cl.exe
echo.

echo === Flutter version ===
"C:\flutter\bin\flutter.bat" --version
echo.

cd /d "C:\Users\וינוגרד-0583275480\Downloads\OTZ\otzaria"
echo === pub get ===
"C:\flutter\bin\flutter.bat" pub get || exit /b %ERRORLEVEL%

echo === flutter build windows ===
"C:\flutter\bin\flutter.bat" build windows --release || exit /b %ERRORLEVEL%

echo.
echo === Output ===
dir "C:\Users\וינוגרד-0583275480\Downloads\OTZ\otzaria\build\windows\x64\runner\Release\otzaria.exe"
