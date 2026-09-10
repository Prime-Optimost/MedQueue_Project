@echo off
REM MedQueue GH - Quick Start Script for Windows
REM This script helps set up and run the Flutter app

echo.
echo ╔══════════════════════════════════════════════════════════════╗
echo ║           MedQueue GH - Flutter Frontend Prototype          ║
echo ║          Healthcare Appointment & Queue Management          ║
echo ╚══════════════════════════════════════════════════════════════╝
echo.

REM Get current directory
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo [1/4] Checking Flutter installation...
flutter --version >nul 2>&1
if errorlevel 1 (
    echo ✗ Flutter not found! Please install Flutter SDK.
    echo   Download from: https://flutter.dev/docs/get-started/install
    exit /b 1
)
echo ✓ Flutter installed

echo.
echo [2/4] Getting dependencies...
call flutter pub get
if errorlevel 1 (
    echo ✗ Failed to get dependencies
    exit /b 1
)
echo ✓ Dependencies installed

echo.
echo [3/4] Checking available devices...
flutter devices >nul 2>&1
if errorlevel 1 (
    echo ✗ No devices found! Start an Android emulator or connect a device.
    echo   To start Android emulator: Android Studio ^> Device Manager
    exit /b 1
)
echo ✓ Devices found

echo.
echo [4/4] Running MedQueue GH...
echo.
echo ════════════════════════════════════════════════════════════════
echo App is launching. This may take 30-60 seconds on first run...
echo ════════════════════════════════════════════════════════════════
echo.

call flutter run

if errorlevel 1 (
    echo.
    echo ✗ Failed to launch app
    exit /b 1
)

echo.
echo ✓ App launched successfully!
echo.
echo For demo instructions, see: TESTING_GUIDE.md
echo For detailed docs, see: README_MEDQUEUE.md
echo.

endlocal
