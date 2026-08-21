@echo off
echo ========================================================
echo 🚀 StudentHub In-App OTA Release Publisher
echo ========================================================
echo.

cd /d "%~dp0"

if "%PUSH_SECRET%"=="" (
    set PUSH_SECRET=studenthub-dev-push-secret
    echo ℹ️ PUSH_SECRET set to default: studenthub-dev-push-secret
)

echo.
echo Running automated build and Supabase release publisher...
echo.

call dart run tool/release.dart %*

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ Release publishing failed with exit code %ERRORLEVEL%.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo ========================================================
echo 🎉 RELEASE PUBLISHED & BROADCAST TO ALL USERS!
echo ========================================================
echo.
pause
