@echo off
set "UPDATER_VERSION=1.12"
set "NSIS=D:\NSIS\_Unicode\makensis.exe"

mkdir "%~dp0\bin" 2> NUL
mkdir "%~dp0\out" 2> NUL

set "ISO_DATE="
for /F "tokens=1,2 delims=:" %%a in ('"%~dp0\etc\date.exe" +ISODATE:%%Y-%%m-%%d') do (
	if "%%a"=="ISODATE" set "ISO_DATE=%%b"
)

if exist "%~dp0\out\Chromium-Updater.%ISO_DATE%.zip" (
	echo. && echo ERROR: File "%~dp0\out\Chromium-Updater.%ISO_DATE%.zip" already exists !!! && echo.
	pause && goto:eof
)

"%NSIS%" "/DUPDATER_VERSION=%UPDATER_VERSION%" "%~dp0\src\Chromium-Updater.nsi"
if not "%ERRORLEVEL%"=="0" (
	echo. && echo ERROR: Something went wrong !!! && echo.
	pause && goto:eof
)

copy /Y /V "%~dp0\*.txt" "%~dp0\bin"

echo Chromium Updater v%UPDATER_VERSION% (%ISO_DATE%) >                               "%~dp0\bin\VERSION"
echo Copyright (C) 2008-2015 LoRd_MuldeR ^<MuldeR2@GMX.de^>. Some Rights Reserved. >> "%~dp0\bin\VERSION"
echo. >>                                                                              "%~dp0\bin\VERSION"
echo Please visit http://muldersoft.com/ for news and updates! >>                     "%~dp0\bin\VERSION"
echo. >>                                                                              "%~dp0\bin\VERSION"

pushd "%~dp0\bin"
"%~dp0\etc\zip.exe" -r -9 -z "%~dp0\out\Chromium-Updater.%ISO_DATE%.zip" "*.*" < "%~dp0\bin\VERSION"
popd

attrib +R "%~dp0\out\Chromium-Updater.%ISO_DATE%.zip"

echo. && echo Compleed.
echo. && pause
