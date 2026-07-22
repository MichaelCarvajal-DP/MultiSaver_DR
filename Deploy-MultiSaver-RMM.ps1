#!/usr/bin/env powershell
<#
.SYNOPSIS
    Deployment script para MultiSaver en RMM
    Configura todos los directorios, archivos y permisos necesarios

.DESCRIPTION
    Este script prepara una máquina para ejecutar MultiSaver desde NinjaOne u otro RMM
    - Crea estructura de directorios
    - Genera template de config.xml
    - Configura permisos
    - Registra tarea programada (opcional)

.PARAMETER WasabiAccessKey
    Access Key de Wasabi (opcional si solo es deploy)

.PARAMETER WasabiSecretKey
    Secret Key de Wasabi (opcional si solo es deploy)

.PARAMETER CreateScheduledTask
    Crear tarea programada para sincronización automática

.EXAMPLE
    .\Deploy-MultiSaver-RMM.ps1 -CreateScheduledTask

.EXAMPLE
    .\Deploy-MultiSaver-RMM.ps1 -WasabiAccessKey "XXX" -WasabiSecretKey "YYY" -CreateScheduledTask
#>

#Requires -RunAsAdministrator

param(
    [string]$WasabiAccessKey,
    [string]$WasabiSecretKey,
    [switch]$CreateScheduledTask
)

$ErrorActionPreference = "Stop"

# ==================== CONFIGURACIÓN ====================
$BaseDir = "C:\ProgramData\MultiSaver"
$ImageDir = Join-Path $BaseDir "Images"
$LogDir = Join-Path $BaseDir "Logs"
$ConfigFile = Join-Path $BaseDir "config.xml"

Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║ MultiSaver RMM Deployment Script       ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ==================== CREAR DIRECTORIOS ====================
Write-Host "📁 Creando estructura de directorios..." -ForegroundColor Yellow

@($BaseDir, $ImageDir, $LogDir, (Join-Path $ImageDir "horizontal"), (Join-Path $ImageDir "vertical")) | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
        Write-Host "  ✓ $_" -ForegroundColor Green
    }
    else {
        Write-Host "  ↻ $_ (ya existe)" -ForegroundColor Gray
    }
}

# ==================== COPIAR SCRIPTS ====================
Write-Host ""
Write-Host "📄 Instalando scripts de sincronización..." -ForegroundColor Yellow

$ScriptDir = Split-Path -Parent $PSCommandPath
$SyncScript = Join-Path $ScriptDir "MultiSaver-RMM-Sync.ps1"
$SyncBatch = Join-Path $ScriptDir "MultiSaver-RMM-Sync.bat"

foreach ($Script in @($SyncScript, $SyncBatch)) {
    if (Test-Path $Script) {
        $Destination = Join-Path $BaseDir (Split-Path -Leaf $Script)
        Copy-Item -Path $Script -Destination $Destination -Force
        Write-Host "  ✓ $(Split-Path -Leaf $Script)" -ForegroundColor Green
    }
}

# ==================== CREAR CONFIG.XML ====================
Write-Host ""
Write-Host "⚙️  Configurando archivos..." -ForegroundColor Yellow

if (-not (Test-Path $ConfigFile)) {
    $ConfigTemplate = @"
<?xml version="1.0" encoding="utf-8"?>
<Settings>
  <WasabiConfig>
    <AccessKey>$(if ($WasabiAccessKey) { $WasabiAccessKey } else { 'COLOCAR_AQUI_ACCESS_KEY' })</AccessKey>
    <SecretKey>$(if ($WasabiSecretKey) { $WasabiSecretKey } else { 'COLOCAR_AQUI_SECRET_KEY' })</SecretKey>
    <Bucket>multisaver-images</Bucket>
    <LocalImageDir>$ImageDir</LocalImageDir>
  </WasabiConfig>
  <Monitors>
    <Monitor>
      <Name>Monitor 1</Name>
      <Orientation>Horizontal</Orientation>
    </Monitor>
    <Monitor>
      <Name>Monitor 2</Name>
      <Orientation>Vertical</Orientation>
    </Monitor>
  </Monitors>
</Settings>
"@

    $ConfigTemplate | Out-File -FilePath $ConfigFile -Encoding UTF8
    Write-Host "  ✓ config.xml creado" -ForegroundColor Green

    if (-not $WasabiAccessKey -or -not $WasabiSecretKey) {
        Write-Host "  ⚠️  IMPORTANTE: Actualizar credenciales en $ConfigFile" -ForegroundColor Yellow
    }
}
else {
    Write-Host "  ↻ config.xml (ya existe)" -ForegroundColor Gray
}

# ==================== CONFIGURAR PERMISOS ====================
Write-Host ""
Write-Host "🔐 Configurando permisos..." -ForegroundColor Yellow

try {
    # Dar control total al grupo de administradores
    $Admin = "BUILTIN\Administrators"
    icacls $BaseDir /grant:r "$Admin`:F" /T /C | Out-Null
    Write-Host "  ✓ Permisos configurados para Administradores" -ForegroundColor Green

    # Hacer config.xml más restringido (solo admin)
    icacls $ConfigFile /inheritance:r | Out-Null
    icacls $ConfigFile /grant:r "$Admin`:F" /C | Out-Null
    Write-Host "  ✓ config.xml protegido (solo Administrador)" -ForegroundColor Green
}
catch {
    Write-Host "  ⚠️  Error configurando permisos: $_" -ForegroundColor Yellow
}

# ==================== CREAR TAREA PROGRAMADA ====================
Write-Host ""

if ($CreateScheduledTask) {
    Write-Host "📅 Creando tarea programada..." -ForegroundColor Yellow

    $TaskName = "MultiSaver-RMM-Sync"
    $TaskPath = "\MultiSaver\"
    $ScriptPath = Join-Path $BaseDir "MultiSaver-RMM-Sync.bat"

    # Descripción de la tarea
    $TaskDescription = "Sincroniza imágenes desde Wasabi S3 y asigna wallpapers por monitor"

    # Eliminar si existe
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "  ↻ Tarea anterior removida" -ForegroundColor Gray
    }

    # Crear trigger para ejecutar diariamente a las 9 AM
    $Trigger = New-ScheduledTaskTrigger -Daily -At 09:00

    # Crear acción
    $Action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c `"$ScriptPath`""

    # Crear configuración de la tarea
    $Settings = New-ScheduledTaskSettingsSet `
        -MultipleInstances IgnoreNew `
        -ExecutionTimeLimit (New-TimeSpan -Hours 1) `
        -RunOnlyIfNetworkAvailable `
        -StartWhenAvailable

    # Registrar tarea
    Register-ScheduledTask `
        -TaskName $TaskName `
        -TaskPath $TaskPath `
        -Trigger $Trigger `
        -Action $Action `
        -Settings $Settings `
        -Description $TaskDescription `
        -RunLevel Highest | Out-Null

    Write-Host "  ✓ Tarea programada creada" -ForegroundColor Green
    Write-Host "  📍 Nombre: $TaskName" -ForegroundColor Cyan
    Write-Host "  📍 Horario: Diariamente a las 09:00 AM" -ForegroundColor Cyan
    Write-Host "  📍 Ruta: $TaskPath" -ForegroundColor Cyan
}
else {
    Write-Host "📅 Tarea programada: Omitida (usar -CreateScheduledTask para incluir)" -ForegroundColor Gray
}

# ==================== RESUMEN ====================
Write-Host ""
Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║ ✅ Instalación Completada              ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "📍 Ubicación de instalación:" -ForegroundColor Cyan
Write-Host "   $BaseDir"
Write-Host ""
Write-Host "📁 Estructura:" -ForegroundColor Cyan
Write-Host "   ├─ config.xml (⚙️  Actualizar credenciales Wasabi)"
Write-Host "   ├─ MultiSaver-RMM-Sync.ps1"
Write-Host "   ├─ MultiSaver-RMM-Sync.bat"
Write-Host "   ├─ Images/"
Write-Host "   │  ├─ horizontal/"
Write-Host "   │  └─ vertical/"
Write-Host "   └─ Logs/"
Write-Host ""
Write-Host "🔧 Próximos pasos:" -ForegroundColor Cyan
Write-Host "   1. Editar $ConfigFile"
Write-Host "   2. Agregar credenciales de Wasabi (AccessKey, SecretKey)"
Write-Host "   3. Verificar nombre del bucket"
Write-Host "   4. Ejecutar manualmente para probar:"
Write-Host "      powershell -NoProfile -ExecutionPolicy Bypass -File `"$BaseDir\MultiSaver-RMM-Sync.ps1`""
Write-Host ""
Write-Host "📋 Para integrar en NinjaOne:" -ForegroundColor Cyan
Write-Host "   1. Administration > Automation > Custom Scripts"
Write-Host "   2. New Script (Batch type)"
Write-Host "   3. Copy: $BaseDir\MultiSaver-RMM-Sync.bat"
Write-Host "   4. Run as Administrator"
Write-Host "   5. Save y asignar a Device Group"
Write-Host ""
Write-Host "📖 Ver guía completa:" -ForegroundColor Cyan
Write-Host "   - RMM_NINJAONE_GUIDE.md en el repositorio"
Write-Host ""

# ==================== VALIDAR CONFIG ====================
Write-Host "🔍 Validación rápida:" -ForegroundColor Yellow
if (Test-Path $ConfigFile) {
    [xml]$Config = Get-Content $ConfigFile
    $AccessKey = $Config.Settings.WasabiConfig.AccessKey
    $Bucket = $Config.Settings.WasabiConfig.Bucket

    if ($AccessKey -match "COLOCAR_AQUI" -or [string]::IsNullOrWhiteSpace($AccessKey)) {
        Write-Host "   ⚠️  Access Key: NO CONFIGURADO" -ForegroundColor Yellow
    }
    else {
        Write-Host "   ✓ Access Key: Configurado" -ForegroundColor Green
    }

    if ($Bucket -and $Bucket -ne "multisaver-images") {
        Write-Host "   ✓ Bucket: $Bucket" -ForegroundColor Green
    }
    else {
        Write-Host "   ⚠️  Bucket: Usar default o actualizar" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "✨ Instalación lista. Actualiza config.xml y ejecuta desde NinjaOne." -ForegroundColor Green
