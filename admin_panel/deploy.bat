@echo off
echo ========================================================
echo 🚀 StudentHub Admin Panel - 1-Click Vercel Deployer
echo ========================================================
echo.

cd /d "c:\Users\Rohit\StudentHub\admin_panel"

echo 📦 1/2 Building Flutter Web Release...
call flutter build web --release
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

echo.
echo ========================================================
echo 🎉 DEPLOYMENT COMPLETE! Your update is live on Vercel.
echo ========================================================
echo.
pause
