@echo off
:: Ensure the script is running with Administrative privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script must be run as an Administrator.
    pause
    exit /b 1
)

:: "Run as administrator" starts in C:\Windows\System32 - work from the script's folder
pushd "%~dp0"

:: --- CONFIGURATION VARIABLES ---
set "SPLUNK_MSI=splunkforwarder-10.2.8-981c2d735e4d-windows-x64.msi"
set "SPLUNK_SERVER=10.x.x.x"
set "SPLUNK_DIR=C:\Program Files\SplunkUniversalForwarder"
set "SPLUNK_BIN=%SPLUNK_DIR%\bin\splunk.exe"

:: Refuse to run with the placeholder Deployment Server
if "%SPLUNK_SERVER%"=="" goto :no_server
if /i "%SPLUNK_SERVER:x.x=%" neq "%SPLUNK_SERVER%" goto :no_server

:: Verify the installer file actually exists in the script directory
if not exist "%SPLUNK_MSI%" (
    echo ERROR: %SPLUNK_MSI% not found in %CD%!
    popd
    exit /b 1
)

echo Installing Splunk Universal Forwarder...
:: Running msiexec with cleared syntax and proper quotes
msiexec.exe /i "%SPLUNK_MSI%" USE_LOCAL_SYSTEM=1 AGREETOLICENSE=Yes DEPLOYMENT_SERVER="%SPLUNK_SERVER%:8089" INSTALLDIR="%SPLUNK_DIR%" /quiet /L*v install_log.txt
set "MSI_RC=%errorlevel%"

:: 3010 = success, reboot required
if "%MSI_RC%"=="3010" echo NOTE: Installation succeeded, a reboot is required to complete it.
if "%MSI_RC%"=="3010" set "MSI_RC=0"

if %MSI_RC% equ 0 (
    echo Installation success!

    echo Restarting Splunk Service to apply changes...
    "%SPLUNK_BIN%" restart --accept-license --answer-yes --no-prompt

    echo Updating Splunk Windows Service Configurations...
    :: Set service to Delayed Start
    sc config SplunkForwarder start=delayed-auto

    :: Set recovery actions (Restart service after 1 minute on 1st/2nd failures)
    sc failure SplunkForwarder actions=restart/60000/restart/60000/""/60000 reset=86400

    echo Configuration update complete.
) else (
    echo ERROR: File %SPLUNK_MSI% installation failed with exit code %MSI_RC%!
    echo Check %CD%\install_log.txt for details.
    popd
    exit /b %MSI_RC%
)

echo.
popd
exit /b 0

:no_server
echo ERROR: SPLUNK_SERVER is not set ("%SPLUNK_SERVER%"). Edit the configuration block first.
popd
exit /b 1
