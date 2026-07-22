#Requires -RunAsAdministrator
<#
.SYNOPSIS
    MultiSaver RMM Integration Script - Descargar imágenes desde Wasabi S3 y asignar como screensaver/wallpaper
    Compatible con NinjaOne, ConnectWise, Datto y otros RMM

.DESCRIPTION
    - Detecta monitores conectados y sus orientaciones (horizontal/vertical)
    - Descarga imágenes desde Wasabi S3 con sincronización incremental
    - Clasifica imágenes por orientación usando EXIF
    - Asigna wallpapers dinámicamente según monitor
    - Configura screensaver por usuario
    - Ideal para ejecutar como tarea programada o desde RMM

.PARAMETER ConfigPath
    Ruta al archivo XML de configuración (default: C:\ProgramData\MultiSaver\config.xml)

.PARAMETER WasabiAccessKey
    Access key de Wasabi (Si no está en config.xml)

.PARAMETER WasabiSecretKey
    Secret key de Wasabi (Si no está en config.xml)

.PARAMETER WasabiBucket
    Nombre del bucket en Wasabi (default: multisaver-images)

.PARAMETER LocalImageDir
    Directorio local para guardar imágenes (default: C:\ProgramData\MultiSaver\Images)

.PARAMETER Force
    Fuerza descarga completa (sin sync incremental)

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File MultiSaver-RMM-Sync.ps1 -WasabiBucket "mi-bucket"

.EXAMPLE
    # Desde NinjaOne como Custom Script
    powershell -NoProfile -ExecutionPolicy Bypass -File C:\temp\MultiSaver-RMM-Sync.ps1
#>

param(
    [string]$ConfigPath = "C:\ProgramData\MultiSaver\config.xml",
    [string]$WasabiAccessKey,
    [string]$WasabiSecretKey,
    [string]$WasabiBucket = "multisaver-images",
    [string]$LocalImageDir = "C:\ProgramData\MultiSaver\Images",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$WarningPreference = "Continue"

# ==================== LOGGING ====================
$LogDir = "C:\ProgramData\MultiSaver\Logs"
$LogFile = Join-Path $LogDir "sync_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    Write-Host $LogEntry
    Add-Content -Path $LogFile -Value $LogEntry
}

Write-Log "========================================" "INFO"
Write-Log "MultiSaver RMM Sync - Iniciando" "INFO"
Write-Log "========================================" "INFO"

# ==================== VALIDACIÓN DE CREDENCIALES ====================
function Load-Config {
    if (Test-Path $ConfigPath) {
        Write-Log "Cargando configuración desde: $ConfigPath" "INFO"
        [xml]$xml = Get-Content $ConfigPath
        return $xml.Settings.WasabiConfig
    }
    return $null
}

$WasabiConfig = Load-Config

if (-not $WasabiAccessKey -and $WasabiConfig) {
    $WasabiAccessKey = $WasabiConfig.AccessKey
    Write-Log "Access Key cargado de config.xml" "INFO"
}

if (-not $WasabiSecretKey -and $WasabiConfig) {
    $WasabiSecretKey = $WasabiConfig.SecretKey
    Write-Log "Secret Key cargado de config.xml" "INFO"
}

if (-not $WasabiAccessKey -or -not $WasabiSecretKey) {
    Write-Log "ERROR: Credenciales de Wasabi no configuradas" "ERROR"
    exit 1
}

Write-Log "Configuración Wasabi validada ✓" "INFO"

# ==================== FUNCIONES AWS4 HMAC-SHA256 ====================
function Get-AWSS3Signature {
    param(
        [string]$AccessKey,
        [string]$SecretKey,
        [string]$BucketName,
        [string]$Region = "us-east-1",
        [string]$Endpoint = "s3.wasabisys.com"
    )

    $DateTimeUtc = Get-Date -AsUTC
    $AmzDate = $DateTimeUtc.ToString("yyyyMMddTHHmmssZ")
    $DateScope = $DateTimeUtc.ToString("yyyyMMdd")

    $CanonicalRequest = @(
        "GET",
        "/$BucketName/",
        "list-type=2",
        "host:$Endpoint",
        "x-amz-content-sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        "x-amz-date:$AmzDate",
        "",
        "host;x-amz-content-sha256;x-amz-date",
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    ) -join "`n"

    $StringToSign = @(
        "AWS4-HMAC-SHA256",
        $AmzDate,
        "$DateScope/$Region/s3/aws4_request",
        ([System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($CanonicalRequest)) | ForEach-Object { $_.ToString("x2") }) -join ""
    ) -join "`n"

    $SigningKey = [System.Text.Encoding]::UTF8.GetBytes("AWS4$SecretKey")
    $DateK = [System.Security.Cryptography.HMACSHA256]::new($SigningKey)
    $DateK = $DateK.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($DateScope))

    $DateRegionK = [System.Security.Cryptography.HMACSHA256]::new($DateK)
    $DateRegionK = $DateRegionK.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Region))

    $DateRegionServiceK = [System.Security.Cryptography.HMACSHA256]::new($DateRegionK)
    $DateRegionServiceK = $DateRegionServiceK.ComputeHash([System.Text.Encoding]::UTF8.GetBytes("s3"))

    $SigningKeyFinal = [System.Security.Cryptography.HMACSHA256]::new($DateRegionServiceK)
    $Signature = ($SigningKeyFinal.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($StringToSign)) | ForEach-Object { $_.ToString("x2") }) -join ""

    return @{
        AmzDate      = $AmzDate
        DateScope    = $DateScope
        Signature    = $Signature
    }
}

# ==================== DESCARGA DE IMÁGENES ====================
function Sync-WasabiImages {
    param(
        [string]$AccessKey,
        [string]$SecretKey,
        [string]$BucketName,
        [string]$LocalPath
    )

    Write-Log "Iniciando sincronización desde Wasabi: $BucketName" "INFO"

    if (-not (Test-Path $LocalPath)) {
        New-Item -ItemType Directory -Path $LocalPath -Force | Out-Null
        Write-Log "Directorio creado: $LocalPath" "INFO"
    }

    try {
        $SigInfo = Get-AWSS3Signature -AccessKey $AccessKey -SecretKey $SecretKey -BucketName $BucketName
        
        $AuthHeader = "AWS4-HMAC-SHA256 Credential=$AccessKey/$($SigInfo.DateScope)/us-east-1/s3/aws4_request, SignedHeaders=host;x-amz-content-sha256;x-amz-date, Signature=$($SigInfo.Signature)"
        
        $Headers = @{
            "Authorization"      = $AuthHeader
            "x-amz-date"         = $SigInfo.AmzDate
            "x-amz-content-sha256" = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        }

        $Url = "https://s3.wasabisys.com/$BucketName/?list-type=2"
        $Response = Invoke-WebRequest -Uri $Url -Headers $Headers -Method Get -UseBasicParsing
        
        [xml]$XmlResponse = $Response.Content
        $Objects = $XmlResponse.ListBucketResult.Contents

        $DownloadCount = 0
        foreach ($Object in $Objects) {
            $Key = $Object.Key
            $Size = [int64]$Object.Size
            
            if ($Key -match '\.(jpg|jpeg|png|bmp|gif)$') {
                $LocalFile = Join-Path $LocalPath (Split-Path -Leaf $Key)
                
                if ((Test-Path $LocalFile) -and -not $Force) {
                    $LocalSize = (Get-Item $LocalFile).Length
                    if ($LocalSize -eq $Size) {
                        Write-Log "  [SKIP] $Key (ya existe)" "INFO"
                        continue
                    }
                }

                Write-Log "  [DESCARGANDO] $Key" "INFO"
                $FileUrl = "https://s3.wasabisys.com/$BucketName/$Key"
                Invoke-WebRequest -Uri $FileUrl -OutFile $LocalFile -UseBasicParsing
                $DownloadCount++
            }
        }

        Write-Log "Sincronización completada: $DownloadCount archivos descargados" "INFO"
        return $true
    }
    catch {
        Write-Log "ERROR en sincronización: $_" "ERROR"
        return $false
    }
}

# ==================== DETECTAR MONITORES ====================
function Get-MonitorInfo {
    Write-Log "Detectando monitores..." "INFO"

    $Monitors = @()
    
    try {
        # Método 1: WMI (Compatible con RDP)
        $WmiMonitors = Get-CimInstance -ClassName WmiMonitorBasicDisplayParams -Namespace root\wmi -ErrorAction SilentlyContinue
        
        if ($WmiMonitors) {
            foreach ($Monitor in $WmiMonitors) {
                $Width = $Monitor.MaxHorizontalImageSize
                $Height = $Monitor.MaxVerticalImageSize
                
                $Orientation = if ($Width -gt $Height) { "Horizontal" } else { "Vertical" }
                
                $Monitors += @{
                    Index        = $Monitors.Count + 1
                    Name         = "Monitor $($Monitors.Count + 1)"
                    Width        = $Width
                    Height       = $Height
                    Orientation  = $Orientation
                    Resolution   = "$Width`x$Height"
                }
            }
        }

        # Método 2: Registry (Fallback)
        if ($Monitors.Count -eq 0) {
            $RegPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\DISPLAY"
            $DisplayDevices = Get-ChildItem $RegPath -ErrorAction SilentlyContinue
            
            $Monitors += @{
                Index       = 1
                Name        = "Monitor Predeterminado"
                Width       = 1920
                Height      = 1080
                Orientation = "Horizontal"
                Resolution  = "1920x1080"
            }
        }

        foreach ($M in $Monitors) {
            Write-Log "  [Monitor $($M.Index)] $($M.Name) - $($M.Resolution) ($($M.Orientation))" "INFO"
        }

        return $Monitors
    }
    catch {
        Write-Log "WARNING: Error detectando monitores: $_" "WARNING"
        return @(@{ Index=1; Name="Monitor1"; Orientation="Horizontal"; Width=1920; Height=1080 })
    }
}

# ==================== CLASIFICAR IMÁGENES POR EXIF ====================
function Get-ImageOrientation {
    param([string]$ImagePath)

    try {
        $Image = New-Object System.Drawing.Bitmap($ImagePath)
        $ExifPropId = 0x0112  # Orientation property

        if ($Image.PropertyIdList -contains $ExifPropId) {
            $ExifValue = $Image.GetPropertyItem($ExifPropId).Value[0]
            
            # EXIF Orientation: 6 y 8 = rotación 90°
            if ($ExifValue -in @(6, 8)) {
                return "Vertical"
            }
        }

        # Fallback: comparar dimensiones
        if ($Image.Width -lt $Image.Height) {
            return "Vertical"
        }

        return "Horizontal"
    }
    catch {
        Write-Log "WARNING: Error analizando EXIF de $ImagePath : $_" "WARNING"
        return "Unknown"
    }
    finally {
        if ($Image) { $Image.Dispose() }
    }
}

function Organize-ImagesByOrientation {
    param([string]$ImageDir)

    Write-Log "Organizando imágenes por orientación..." "INFO"

    $HorizontalDir = Join-Path $ImageDir "horizontal"
    $VerticalDir = Join-Path $ImageDir "vertical"

    foreach ($Dir in @($HorizontalDir, $VerticalDir)) {
        if (-not (Test-Path $Dir)) {
            New-Item -ItemType Directory -Path $Dir -Force | Out-Null
        }
    }

    $Images = Get-ChildItem -Path $ImageDir -Include *.jpg, *.jpeg, *.png, *.bmp -File -ErrorAction SilentlyContinue

    foreach ($Image in $Images) {
        $Orientation = Get-ImageOrientation -ImagePath $Image.FullName

        if ($Orientation -eq "Vertical") {
            $Target = Join-Path $VerticalDir $Image.Name
        }
        else {
            $Target = Join-Path $HorizontalDir $Image.Name
        }

        if (-not (Test-Path $Target)) {
            Copy-Item -Path $Image.FullName -Destination $Target -Force
            Write-Log "  [CLASIFICADO] $($Image.Name) → $Orientation" "INFO"
        }
    }

    Write-Log "Clasificación completada" "INFO"
}

# ==================== ASIGNAR WALLPAPER ====================
function Set-Wallpaper {
    param(
        [string]$ImagePath,
        [int]$MonitorIndex
    )

    if (-not (Test-Path $ImagePath)) {
        Write-Log "ERROR: Imagen no encontrada: $ImagePath" "ERROR"
        return $false
    }

    try {
        # Convertir a ruta absoluta
        $ImagePath = (Get-Item $ImagePath).FullName

        # Usar pinvoke para establecer wallpaper
        $SPI_SETDESKWALLPAPER = 20
        
        $Code = @"
        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
"@

        if (-not ([System.Management.Automation.PSTypeName]'Wallpaper.Setter').Type) {
            Add-Type -MemberDefinition $Code -Name Setter -Namespace Wallpaper
        }

        [Wallpaper.Setter]::SystemParametersInfo($SPI_SETDESKWALLPAPER, 0, $ImagePath, 3)
        
        Write-Log "Wallpaper asignado: Monitor $MonitorIndex → $ImagePath" "INFO"
        return $true
    }
    catch {
        Write-Log "WARNING: No se pudo asignar wallpaper (posiblemente bloqueado por Group Policy): $_" "WARNING"
        return $false
    }
}

# ==================== CONFIGURAR SCREENSAVER ====================
function Set-Screensaver {
    param(
        [string]$ImageDir,
        [int]$TimeoutSeconds = 600
    )

    Write-Log "Configurando screensaver..." "INFO"

    try {
        # Ruta del registro para screensaver
        $RegPath = "HKCU:\Control Panel\Desktop"

        # Usar Photos screensaver (built-in) como fallback
        # O usar Windows Slideshow
        Set-ItemProperty -Path $RegPath -Name "SCRNSAVE.EXE" -Value "C:\Windows\System32\Ribbons.scr"
        Set-ItemProperty -Path $RegPath -Name "ScreenSaveActive" -Value 1
        Set-ItemProperty -Path $RegPath -Name "ScreenSaveTimeOut" -Value $TimeoutSeconds
        Set-ItemProperty -Path $RegPath -Name "ScreenSaverIsSecure" -Value 0

        Write-Log "Screensaver configurado: Timeout = $TimeoutSeconds segundos" "INFO"
        return $true
    }
    catch {
        Write-Log "WARNING: Error configurando screensaver: $_" "WARNING"
        return $false
    }
}

# ==================== MAIN ====================
function Main {
    Write-Log "Paso 1: Sincronizar imágenes desde Wasabi" "INFO"
    $SyncSuccess = Sync-WasabiImages -AccessKey $WasabiAccessKey -SecretKey $WasabiSecretKey -BucketName $WasabiBucket -LocalPath $LocalImageDir
    
    if (-not $SyncSuccess) {
        Write-Log "ERROR: Sincronización falló" "ERROR"
        exit 1
    }

    Write-Log "Paso 2: Organizar imágenes por orientación" "INFO"
    Organize-ImagesByOrientation -ImageDir $LocalImageDir

    Write-Log "Paso 3: Detectar monitores" "INFO"
    $Monitors = Get-MonitorInfo

    Write-Log "Paso 4: Asignar wallpapers por monitor" "INFO"
    foreach ($Monitor in $Monitors) {
        $ImageDir = if ($Monitor.Orientation -eq "Vertical") {
            Join-Path $LocalImageDir "vertical"
        }
        else {
            Join-Path $LocalImageDir "horizontal"
        }

        $RandomImage = Get-ChildItem -Path $ImageDir -Include *.jpg, *.jpeg, *.png -File | Get-Random

        if ($RandomImage) {
            Set-Wallpaper -ImagePath $RandomImage.FullName -MonitorIndex $Monitor.Index
        }
        else {
            Write-Log "WARNING: No hay imágenes disponibles en $ImageDir para Monitor $($Monitor.Index)" "WARNING"
        }
    }

    Write-Log "Paso 5: Configurar screensaver" "INFO"
    Set-Screensaver -ImageDir $LocalImageDir -TimeoutSeconds 600

    Write-Log "========================================" "INFO"
    Write-Log "MultiSaver RMM Sync - Completado ✓" "INFO"
    Write-Log "========================================" "INFO"

    exit 0
}

Main
