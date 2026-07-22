@echo off
REM MultiSaver RMM Sync - Batch Launcher
REM Ejecutable desde NinjaOne, ConnectWise, Datto
REM
REM Uso:
REM   MultiSaver-RMM-Sync.bat
REM   MultiSaver-RMM-Sync.bat "C:\ruta\config.xml"
REM
REM Para NinjaOne: 
REM   Settings > Automation > Custom Scripts > Add Script
REM   Script Type: Batch
REM   Content: (este archivo)
REM   Schedule: Daily, Weekly, o bajo demanda

setlocal enabledelayedexpansion

REM ========== CONFIGURACIÓN ==========
set SCRIPT_DIR=%~dp0
set PS_SCRIPT=%SCRIPT_DIR%MultiSaver-RMM-Sync.ps1
set LOG_DIR=C:\ProgramData\MultiSaver\Logs
set LOG_FILE=%LOG_DIR%\batch_sync.log

REM Crear directorio de logs
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

echo. >> "%LOG_FILE%"
echo ========================================= >> "%LOG_FILE%"
echo [%date% %time%] MultiSaver RMM Sync iniciando >> "%LOG_FILE%"
echo ========================================= >> "%LOG_FILE%"

REM ========== VALIDAR PowerShell ==========
powershell -NoProfile -ExecutionPolicy Bypass -Command "exit $PSHOME" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] PowerShell no disponible >> "%LOG_FILE%"
    exit /b 1
)

REM ========== EJECUTAR SCRIPT PowerShell ==========
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" >> "%LOG_FILE%" 2>&1
set SCRIPT_EXIT_CODE=%errorlevel%

REM ========== REGISTRAR RESULTADO ==========
if %SCRIPT_EXIT_CODE% equ 0 (
    echo [%date% %time%] Sincronización completada exitosamente >> "%LOG_FILE%"
    echo [%date% %time%] Exit Code: %SCRIPT_EXIT_CODE% >> "%LOG_FILE%"
) else (
    echo [%date% %time%] ERROR - Sincronización falló >> "%LOG_FILE%"
    echo [%date% %time%] Exit Code: %SCRIPT_EXIT_CODE% >> "%LOG_FILE%"
)

echo ========================================= >> "%LOG_FILE%"

REM ========== RETORNAR CÓDIGO DE SALIDA ==========
exit /b %SCRIPT_EXIT_CODE%
