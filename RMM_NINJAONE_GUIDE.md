# MultiSaver - Integración RMM (NinjaOne, ConnectWise, Datto)

## 📋 Resumen

Script PowerShell que automatiza:
✅ Descarga incremental de imágenes desde Wasabi S3  
✅ Detección automática de monitores y orientaciones  
✅ Clasificación EXIF de imágenes (horizontal/vertical)  
✅ Asignación de wallpapers dinámicos por monitor  
✅ Configuración de screensaver  
✅ Logging detallado para auditoría  

**Ideal para**: NinjaOne, ConnectWise Manage, Datto RMM, Syncro, etc.

---

## 🚀 Instalación Rápida en NinjaOne

### 1️⃣ Preparar el Script

**Opción A: Descarga desde repositorio**
```bash
cd C:\temp
git clone https://github.com/MichaelCarvajal-DP/MultiSaver_DR.git
# O descargar ZIP manualmente
```

**Opción B: Crear archivo manualmente**
- Copiar el contenido de `MultiSaver-RMM-Sync.ps1` a `C:\ProgramData\MultiSaver\MultiSaver-RMM-Sync.ps1`

### 2️⃣ Configurar Credenciales Wasabi

**Archivo de configuración**: `C:\ProgramData\MultiSaver\config.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<Settings>
  <WasabiConfig>
    <AccessKey>TUACCESSKEY</AccessKey>
    <SecretKey>TUSECRETKEY</SecretKey>
    <Bucket>mi-bucket-multisaver</Bucket>
    <LocalImageDir>C:\ProgramData\MultiSaver\Images</LocalImageDir>
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
```

**Dónde obtener credenciales**:
1. Login en [wasabisys.com](https://console.wasabisys.com)
2. Account Settings → Access Keys
3. Copiar Access Key ID y Secret Access Key

### 3️⃣ Crear Script en NinjaOne

**Pasos en NinjaOne Dashboard**:

1. **Ir a**: Administration → Automation → Custom Scripts
2. **Click**: "+ New Script"
3. **Configurar**:
   - **Name**: "MultiSaver - Sync Images"
   - **Description**: "Sincroniza imágenes desde Wasabi S3 y asigna wallpapers por monitor"
   - **Script Type**: "Batch"
   - **Content**: Copiar contenido de `MultiSaver-RMM-Sync.bat`

4. **Opciones**:
   - ✅ Run as Administrator
   - ✅ Run on Windows
   - Timeout: 300 segundos (5 minutos)

5. **Click**: "Save"

### 4️⃣ Programar Ejecución

**Opción A: Una sola máquina**
- Click en máquina → "Automation" → "+ Run Automation"
- Seleccionar "MultiSaver - Sync Images"
- Frecuencia: Daily, Weekly, o Manual

**Opción B: Grupo de máquinas**
1. Crear un "Device Group" (ej: "Workstations - Marketing")
2. Administration → Automation → Policies
3. "+ New Policy"
4. Asignar script "MultiSaver - Sync Images"
5. Horario: ej: 8:00 AM diariamente
6. Asignar al grupo

**Opción C: Bajo demanda**
- Right-click en máquina → Execute Script → Seleccionar "MultiSaver - Sync Images" → Run

---

## 📖 Uso Manual

### Ejecutar desde PowerShell

```powershell
# Con credenciales en config.xml
powershell -ExecutionPolicy Bypass -File C:\ProgramData\MultiSaver\MultiSaver-RMM-Sync.ps1

# Con parámetros explícitos
powershell -ExecutionPolicy Bypass -File C:\ProgramData\MultiSaver\MultiSaver-RMM-Sync.ps1 `
  -WasabiBucket "mi-bucket" `
  -WasabiAccessKey "XXXXX" `
  -WasabiSecretKey "YYYYY"

# Forzar descarga completa (sin sync incremental)
powershell -ExecutionPolicy Bypass -File C:\ProgramData\MultiSaver\MultiSaver-RMM-Sync.ps1 -Force

# Ver logs
Get-Content C:\ProgramData\MultiSaver\Logs\*.log -Tail 50
```

### Ejecutar desde Batch

```batch
C:\ProgramData\MultiSaver\MultiSaver-RMM-Sync.bat
```

---

## 🔍 Monitoreo y Logs

### Ubicación de logs

```
C:\ProgramData\MultiSaver\Logs\
├── sync_2026-07-22_15-10-50.log    (PowerShell)
└── batch_sync.log                   (Batch wrapper)
```

### Ver log más reciente

```powershell
Get-ChildItem C:\ProgramData\MultiSaver\Logs\sync_*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content -Tail 100
```

### En NinjaOne: Ver resultados

1. Ir a máquina → Automation → History
2. Buscar "MultiSaver - Sync Images"
3. Click en ejecución → "View Details"
4. Ver output en campo "Output"

---

## ⚙️ Parámetros PowerShell

| Parámetro | Tipo | Default | Descripción |
|-----------|------|---------|-------------|
| `ConfigPath` | string | `C:\ProgramData\MultiSaver\config.xml` | Ruta al archivo de configuración XML |
| `WasabiAccessKey` | string | (desde config) | Access Key de Wasabi (Si no está en config) |
| `WasabiSecretKey` | string | (desde config) | Secret Key de Wasabi (Si no está en config) |
| `WasabiBucket` | string | `multisaver-images` | Nombre del bucket en Wasabi |
| `LocalImageDir` | string | `C:\ProgramData\MultiSaver\Images` | Directorio local para descargas |
| `Force` | switch | (false) | Fuerza descarga completa (sin delta sync) |

---

## 🎯 Funcionalidades Principales

### 1. Descarga desde Wasabi S3

- **Autenticación**: AWS4-HMAC-SHA256 (nativa de Wasabi)
- **Sincronización incremental**: Solo descarga archivos nuevos/modificados
- **Delta sync**: Compara tamaño de archivo antes de descargar
- **Soporta**: JPG, PNG, BMP, GIF
- **Logs**: Detalla cada archivo descargado

### 2. Detección de Monitores

- **Método 1**: WMI (Windows Management Instrumentation)
  - Soporta múltiples monitores
  - Compatible con RDP/Terminal Services
  - Extrae tamaño físico en cm

- **Método 2**: Fallback a Registry
  - Si WMI falla, usa valores del sistema
  - Asume 1 monitor 1920x1080

### 3. Orientación Automática

```
Imagen con EXIF Orientation = 6 u 8  → Clasificada como "Vertical"
Ancho > Alto                         → Clasificada como "Horizontal"
Alto >= Ancho                        → Clasificada como "Vertical"
```

Ficheros organizados en:
- `C:\ProgramData\MultiSaver\Images\horizontal\`
- `C:\ProgramData\MultiSaver\Images\vertical\`

### 4. Asignación de Wallpaper

- 1 imagen aleatoria por monitor
- Usar PinVoke de Windows API
- Compatible con Group Policy
- Silencioso si bloqueado (no causa error)

### 5. Screensaver

- Tipo: Ribbons.scr (built-in)
- Timeout: 600 segundos (10 minutos)
- Configurable por registry

---

## 🔐 Seguridad

### ✅ Recomendaciones

1. **Almacenar credenciales en config.xml con permisos restringidos**
   ```powershell
   # Solo administrador puede leer
   icacls C:\ProgramData\MultiSaver\config.xml /grant:r "%USERNAME%":F /remove "Users"
   ```

2. **Usar Wasabi IAM User (no root credentials)**
   - Console.wasabisys.com → Users → Create User
   - Policy: S3 ListBucket + GetObject en bucket específico

3. **Ejecutar script con contexto de usuario local**
   - NinjaOne: ✅ "Run as Administrator" (SISTEMA)
   - Mejor: Crear task scheduler con usuario específico

4. **Auditar cambios en wallpaper**
   - Logs en `C:\ProgramData\MultiSaver\Logs\`
   - Centralizar con Event Viewer o SIEM

---

## 🐛 Troubleshooting

### Error: "Credenciales no configuradas"

**Solución**:
```powershell
# Verificar config.xml existe
Test-Path C:\ProgramData\MultiSaver\config.xml

# Ver contenido
Get-Content C:\ProgramData\MultiSaver\config.xml
```

### Error: "Access Denied" en Wasabi

**Solución**:
1. Verificar Access Key / Secret Key en config.xml
2. En Wasabi console: Verificar que IAM user tiene permiso `s3:ListBucket` y `s3:GetObject`
3. Verificar nombre del bucket exacto (case-sensitive)

### No se detectan monitores

**Solución**:
```powershell
# Ejecutar manualmente
Get-CimInstance -ClassName WmiMonitorBasicDisplayParams -Namespace root\wmi

# Si no retorna nada, usar fallback (automático)
```

### Wallpaper no cambia

**Posibles causas**:
- ✅ Bloqueado por Group Policy
  ```powershell
  gpedit.msc → User Config → Admin Templates → Desktop → Desktop
  Buscar "Prevent changes to wallpaper"
  ```
- ✅ Usuario no tiene permisos
  - Ejecutar como Administrador
- ✅ Archivos de imagen no encontrados
  - Verificar `C:\ProgramData\MultiSaver\Images\`

---

## 📊 Ejemplos de Caso de Uso

### Caso 1: Oficina con 2 monitores (1H + 1V)

**Configuración NinjaOne**:
```
Ejecutar diariamente a las 9:00 AM
```

**Resultado**:
- Monitor 1 (Horizontal): Imagen aleatoria de `horizontal/`
- Monitor 2 (Vertical): Imagen aleatoria de `vertical/`
- Cada día se asigna una imagen diferente

### Caso 2: Fleet de laptops (Home Office)

**Configuración NinjaOne**:
```
Device Group: "Home Office Laptops"
Ejecutar: Lunes, Miércoles, Viernes a las 2:00 PM
```

**Resultado**:
- Script ejecuta en paralelo en todas las máquinas
- Cada laptop descarga solo archivos nuevos (delta sync)
- Logs centralizados en NinjaOne Dashboard

### Caso 3: Digital Signage en Retail

**Configuración NinjaOne**:
```
Ejecutar cada 2 horas (para imagenes dinámicas)
```

**Customización**:
```powershell
# En script, agregar loop cada 2 horas:
while($true) {
    & C:\ProgramData\MultiSaver\MultiSaver-RMM-Sync.ps1
    Start-Sleep -Seconds 7200  # 2 horas
}
```

---

## 📦 Integración Adicional

### Con el MultiSaver.exe (Si está compilado)

El script puede ejecutar también el .exe como screensaver fullscreen:

```powershell
# Agregar a fin del script
Start-Process -Path "C:\Program Files\MultiSaver\MultiSaver.exe" -ArgumentList "/s" -WindowStyle Hidden
```

### Notificación por Email (NinjaOne)

En NinjaOne Dashboard, crear Policy con:
```
Alert Conditions: 
- If script output contains "ERROR"
- Then send email to IT@company.com
```

---

## 📝 Changelog

### v1.0 (2026-07-22)
- ✅ Descarga desde Wasabi S3 con AWS4-HMAC-SHA256
- ✅ Detección automática de monitores
- ✅ Análisis EXIF para orientación
- ✅ Sincronización incremental (delta sync)
- ✅ Asignación de wallpaper por monitor
- ✅ Logging completo
- ✅ Compatible con NinjaOne, ConnectWise, Datto

---

## 💬 Soporte y Contribuciones

Para reportar problemas o sugerir mejoras:
- GitHub: [MichaelCarvajal-DP/MultiSaver_DR](https://github.com/MichaelCarvajal-DP/MultiSaver_DR)
- Email: michael@example.com

---

**Última actualización**: 2026-07-22  
**Versión**: 1.0  
**Licencia**: MIT
