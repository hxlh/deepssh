@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "APP_NAME=deepssh"
set "DIST_DIR=dist"

if "%~1"=="" goto usage_error

set "COMMAND=%~1"

if "%COMMAND%"=="fmt" goto fmt
if "%COMMAND%"=="build" goto build
if "%COMMAND%"=="package" goto package
if "%COMMAND%"=="-h" goto usage_ok
if "%COMMAND%"=="--help" goto usage_ok

echo Unknown command: %COMMAND% 1>&2
goto usage_error

:fmt
if not "%~2"=="" (
  echo fmt does not accept options. 1>&2
  goto usage_error
)
cargo fmt --manifest-path rust/Cargo.toml || exit /b 1
dart format lib test || exit /b 1
flutter_rust_bridge_codegen generate || exit /b 1
flutter analyze || exit /b 1
exit /b 0

:build
call :parse_mode debug %2 %3 %4 %5 %6 %7 %8 %9 || exit /b 1
call :run_build %MODE% || exit /b 1
exit /b 0

:package
call :parse_mode release %2 %3 %4 %5 %6 %7 %8 %9 || exit /b 1
call :run_build %MODE% || exit /b 1
call :package_build %MODE% || exit /b 1
exit /b 0

:parse_mode
set "MODE=%~1"
shift /1
:parse_mode_loop
if "%~1"=="" exit /b 0
if "%~1"=="--debug" (
  set "MODE=debug"
  shift /1
  goto parse_mode_loop
)
if "%~1"=="--profile" (
  set "MODE=profile"
  shift /1
  goto parse_mode_loop
)
if "%~1"=="--release" (
  set "MODE=release"
  shift /1
  goto parse_mode_loop
)
if "%~1"=="-h" goto usage_ok
if "%~1"=="--help" goto usage_ok
echo Unknown option: %~1 1>&2
call :usage 1>&2
exit /b 1

:run_build
flutter build windows --%~1
exit /b %ERRORLEVEL%

:package_build
set "MODE=%~1"
set "MODE_DIR=Debug"
if "%MODE%"=="profile" set "MODE_DIR=Profile"
if "%MODE%"=="release" set "MODE_DIR=Release"

set "ARCH=x64"
if /I "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "ARCH=arm64"

set "SOURCE=build\windows\%ARCH%\runner\%MODE_DIR%"
set "TARGET=%DIST_DIR%\%APP_NAME%-windows-%ARCH%-%MODE%"

if not exist "%SOURCE%\" (
  echo Build output not found: %SOURCE% 1>&2
  exit /b 1
)

if exist "%TARGET%\" rmdir /s /q "%TARGET%" || exit /b 1
mkdir "%TARGET%" || exit /b 1
xcopy "%SOURCE%\*" "%TARGET%\" /E /I /Y >nul || exit /b 1
echo Packaged: %TARGET%
exit /b 0

:usage_ok
call :usage
exit /b 0

:usage_error
call :usage 1>&2
exit /b 1

:usage
echo Usage:
echo   build.bat fmt
echo   build.bat build [--debug^|--profile^|--release]
echo   build.bat package [--debug^|--profile^|--release]
echo.
echo Defaults:
echo   build   -^> --debug
echo   package -^> --release
exit /b 0
