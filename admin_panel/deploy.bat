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
call vercel --prod --yes

echo.
echo ========================================================
echo 🎉 DEPLOYMENT COMPLETE! Your update is live on Vercel.
echo ========================================================
echo.
pause
