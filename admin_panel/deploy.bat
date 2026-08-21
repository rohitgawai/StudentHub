@echo off
echo ========================================================
echo 🚀 StudentHub Admin Panel - 1-Click Vercel Deployer
echo ========================================================
echo.

cd /d "c:\Users\Rohit\StudentHub\admin_panel"

echo 📦 1/2 Building Flutter Web Release...
if "%PUSH_SECRET%"=="" (
    echo ⚠️ PUSH_SECRET environment variable is not set!
    echo    The admin panel will build WITHOUT the shared secret and
    echo    admin login/actions will fail at runtime.
    echo.
    echo    Set it with:   set PUSH_SECRET=your-secret-value
    pause
)
call flutter build web --release --no-tree-shake-icons --dart-define=PUSH_SECRET=%PUSH_SECRET%
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Build failed! Aborting deployment.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo 🌐 2/2 Uploading Live Update to Vercel...
cd build\web
echo Re-linking project (safe after every clean build)...
call vercel link --yes --project web --scope akai11
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Vercel link failed! Aborting deployment.
    pause
    exit /b %ERRORLEVEL%
)
call vercel --prod --yes --scope akai11
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Production deploy FAILED with error code %ERRORLEVEL%.
    echo    The update was NOT published. No alias change was made.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo 🔗 Applying custom domain alias...
call vercel alias set web-pearl-one-86.vercel.app studenthub-admin-panel.vercel.app --scope akai11
if %ERRORLEVEL% NEQ 0 (
    echo [WARNING] Custom domain alias could not be applied.
)

echo ========================================================
echo DEPLOYMENT COMPLETE!
echo.
echo   Custom domain: https://studenthub-admin-panel.vercel.app
echo   Fallback URL:  https://web-pearl-one-86.vercel.app
echo ========================================================
echo.
pause



