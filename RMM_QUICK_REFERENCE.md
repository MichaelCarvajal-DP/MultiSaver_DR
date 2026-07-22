# MultiSaver RMM - Quick Reference

## 🚀 En 5 minutos

### 1. Deploy (1 comando)
```powershell
# Ejecutar como Admin
powershell -ExecutionPolicy Bypass -File Deploy-MultiSaver-RMM.ps1 -CreateScheduledTask
```

### 2. Configurar Wasabi
```powershell
# Editar:
notepad C:\ProgramData\MultiSaver\config.xml

# Buscar y actualizar:
<AccessKey>TU_ACCESSKEY</AccessKey>
<SecretKey>TU_SECRETKEY</SecretKey>
<Bucket>mi-bucket-nombre</Bucket>
```

### 3. Probar
```powershell
# Ejecutar manualmente:
powershell -NoProfile -ExecutionPolicy Bypass -File C:\ProgramData\MultiSaver\MultiSaver-RMM-Sync.ps1

# Ver logs:
Get-Content C:\ProgramData\MultiSaver\Logs\sync_*.log -Tail 30
```

### 4. Integrar en NinjaOne
```
1. Administration → Automation → Custom Scripts
2. Name: "MultiSaver - Sync"
3. Type: Batch
4. Content: C:\ProgramData\MultiSaver\MultiSaver-RMM-Sync.bat
5. ✅ Run as Administrator
6. Save → Assign to Device Group → Schedule Daily
```

---

## 📊 ¿Qué hace?

| Paso | Función | Resultado |
|------|---------|-----------|
| 1️⃣ | Descargar desde Wasabi S3 | ✓ `C:\ProgramData\MultiSaver\Images\` |
| 2️⃣ | Analizar EXIF de imágenes | ✓ Detecta si es horizontal/vertical |
| 3️⃣ | Organizar en carpetas | ✓ `horizontal/` y `vertical/` |
| 4️⃣ | Detectar monitores | ✓ Obtiene resolución de cada monitor |
| 5️⃣ | Asignar wallpaper | ✓ 1 imagen random por monitor |
| 6️⃣ | Configurar screensaver | ✓ 10 min inactividad |

---

## 📁 Estructura después de Deploy

```
C:\ProgramData\MultiSaver\
├── config.xml                    ← Editar credenciales aquí
├── MultiSaver-RMM-Sync.ps1      ← Script principal
├── MultiSaver-RMM-Sync.bat      ← Wrapper para NinjaOne
├── Images/                       ← Descargadas automáticamente
│   ├── horizontal/               (imágenes apaisadas)
│   └── vertical/                 (imágenes verticales)
└── Logs/                         ← Auditoría
    └── sync_2026-07-22_HH-MM-SS.log
```

---

## ⚙️ Parámetros PowerShell

```powershell
# Básico (usa config.xml)
powershell -File MultiSaver-RMM-Sync.ps1

# Con parámetros explícitos
powershell -File MultiSaver-RMM-Sync.ps1 `
  -WasabiBucket "mi-bucket" `
  -WasabiAccessKey "XXX" `
  -WasabiSecretKey "YYY"

# Forzar descarga completa
powershell -File MultiSaver-RMM-Sync.ps1 -Force

# Desde config personalizado
powershell -File MultiSaver-RMM-Sync.ps1 -ConfigPath "D:\custom\config.xml"
```

---

## 🔐 Credenciales Wasabi

### Dónde obtener

1. Login → [console.wasabisys.com](https://console.wasabisys.com)
2. Account Settings → Access Keys
3. Create Access Key
4. Copiar **Access Key ID** y **Secret Access Key**

### Dónde guardar
- Archivo: `C:\ProgramData\MultiSaver\config.xml`
- Solo Administrador puede leer
- Nunca compartir en logs públicos

---

## 🐛 Troubleshooting

| Problema | Solución |
|----------|----------|
| "ERROR: Credenciales no configuradas" | Editar `config.xml` con Access Key |
| "Access Denied en Wasabi" | Verificar credenciales; IAM user tiene permisos `s3:ListBucket`, `s3:GetObject` |
| "Monitores no detectados" | Fallback automático a 1920x1080; revisar logs |
| "Wallpaper no cambia" | Group Policy bloqueando; o sin imágenes en carpeta |
| "No hay imágenes descargadas" | Verificar bucket exists; permisos IAM; conexión internet |

---

## 📍 Ubicación de Logs

```
C:\ProgramData\MultiSaver\Logs\
```

**En NinjaOne**: Machine → Automation → History → Click script → View Output

---

## 🎯 Ejemplos RMM

### NinjaOne - Ejecutar diariamente
```
Device Group: Workstations
Script: MultiSaver - Sync
Schedule: Daily 09:00 AM
```

### ConnectWise - Ejecutar cada 2 horas
```
Script: MultiSaver-RMM-Sync.bat
Frequency: Every 2 hours
Target Devices: All
```

### Datto RMM - Bajo demanda
```
Scripts → MultiSaver-RMM-Sync.bat
Right-click device → Execute Script → Now
```

---

## 📞 Support

**Repositorio**: [MichaelCarvajal-DP/MultiSaver_DR](https://github.com/MichaelCarvajal-DP/MultiSaver_DR)

**Más info**: Ver `RMM_NINJAONE_GUIDE.md`

---

**v1.0** | 2026-07-22
