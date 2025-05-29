# Homelab Scripts Collection

Colección de scripts profesionales para la gestión y automatización de un homelab basado en Proxmox VE.

## 📂 Estructura Organizacional

```
scripts/
├── intel-gpu/              # Gestión automática de Intel GPU
├── wait-mounts/             # Sistema de espera de puntos de montaje  
├── container-management/    # Administración de contenedores LXC
├── utilities/               # Herramientas y utilidades varias
└── README.md               # Esta documentación
```

## 🎯 Sistemas Principales

### 🖥️ Intel GPU Management
Soluciona el problema de detección variable de Intel iGPU después de reinicios:
- **Detección automática** del dispositivo correcto (`/dev/dri/cardX`)
- **Actualización automática** de configuraciones LXC
- **Servicio systemd** para funcionamiento transparente
- **Soporte multi-contenedor** con respaldos automáticos

### ⏱️ Wait-Mounts System  
Asegura que los contenedores esperen a que los puntos de montaje estén disponibles:
- **Monitoreo inteligente** de NFS, CIFS y otros montajes
- **Inicio automático** de contenedores cuando todo esté listo
- **Configuración flexible** de timeouts e intervalos
- **Modo daemon** para monitoreo continuo

### 📦 Container Management
Herramientas para administración avanzada de contenedores LXC:
- **Redimensionamiento seguro** de discos con validación
- **Interfaz interactiva** con verificaciones automáticas
- **Sistema de respaldos** integrado

### 🛠️ Utilities
Colección de herramientas de instalación y configuración:
- **Instaladores automatizados** (btop, WireGuard, GPU drivers, etc.)
- **Detección automática** de hardware y sistema operativo
- **Soporte multi-distribución** (Ubuntu/Debian)
- **Configuraciones optimizadas** para homelab
- **Verificación de integridad** y dependencias

## 🚀 Instalación Rápida

### 🎯 Instalador Maestro (Recomendado)
```bash
sudo chmod +x install-homelab-scripts.sh
sudo ./install-homelab-scripts.sh
```
**El instalador maestro ofrece un menú interactivo para instalar todos los sistemas.**

### Instalación Individual

#### Intel GPU Auto-Fix
```bash
cd intel-gpu/
sudo chmod +x install-intel-gpu-autofix.sh
sudo ./install-intel-gpu-autofix.sh
```

#### Wait-Mounts System
```bash
cd wait-mounts/
sudo chmod +x install-wait-mounts.sh  
sudo ./install-wait-mounts.sh
```

#### Scripts Individuales
```bash
# Redimensionar contenedor LXC
cd container-management/
sudo ./resize-lxc.sh

# Instalar herramientas
cd utilities/
sudo ./install-btop.sh
sudo ./install-wireguard-lxc.sh
sudo ./install-gpu-drivers.sh
```

## ✨ Características Comunes

Todos los scripts siguen patrones profesionales consistentes:

### 🎨 Interfaz Visual
- **Colores consistentes** para diferentes tipos de mensajes
- **Iconos descriptivos** para mejor experiencia de usuario
- **Formato estructurado** con separadores y secciones claras

### 🛡️ Seguridad y Confiabilidad
- **Verificación de prerrequisitos** antes de ejecución
- **Validación de entrada** para prevenir errores
- **Sistema de respaldos** automático antes de cambios
- **Manejo completo de errores** con mensajes informativos

### 📝 Logging y Monitoreo
- **Logging detallado** en archivos dedicados
- **Integración con systemd** para servicios automáticos
- **Códigos de salida** apropiados para automatización

### 🔧 Flexibilidad
- **Modos interactivo y automatizado** según necesidades
- **Configuración por archivos** para personalización
- **Parámetros CLI** para scripting avanzado

## 📋 Casos de Uso del Homelab

### Media Server Stack
```bash
# 1. Configurar Intel GPU para transcoding
cd intel-gpu/ && sudo ./install-intel-gpu-autofix.sh

# 2. Configurar espera de montajes NAS
cd wait-mounts/ && sudo ./install-wait-mounts.sh

# 3. Redimensionar contenedores según necesidad
cd container-management/ && sudo ./resize-lxc.sh
```

### Infrastructure Setup
```bash
# 1. Instalar herramientas de monitoreo
cd utilities/ && sudo ./install-btop.sh

# 2. Configurar VPN en contenedores
cd utilities/ && sudo ./install-wireguard-lxc.sh

# 3. Automatizar gestión de GPU
cd intel-gpu/ && sudo systemctl enable intel-gpu-autofix.service
```

## 🔄 Mantenimiento y Updates

### Verificar Estado de Servicios
```bash
# Intel GPU service
sudo systemctl status intel-gpu-autofix.service
sudo journalctl -u intel-gpu-autofix.service

# Wait-mounts service  
sudo systemctl status wait-mounts.service
sudo journalctl -u wait-mounts.service
```

### Logs y Troubleshooting
```bash
# Ver logs de Intel GPU
tail -f /var/log/intel-gpu-autofix.log

# Ver logs de Wait-mounts
tail -f /var/log/wait-mounts.log

# Ver logs de resize operations
tail -f /var/log/resize-lxc.log
```

## 🆘 Soporte y Troubleshooting

### Problemas Comunes

**Intel GPU no detectado:**
```bash
# Verificar detección manual
cd intel-gpu/
sudo ./fix-intel-gpu-containers.sh --check-only
```

**Montajes no detectados:**
```bash  
# Verificar montajes manualmente
cd wait-mounts/
sudo ./wait-mounts.sh --mounts "/mnt/nas" --debug
```

**Contenedores no redimensionan:**
```bash
# Verificar espacio y permisos
cd container-management/
sudo ./resize-lxc.sh # Modo interactivo con diagnósticos
```

### Contacto y Contribuciones

Para mejoras, reportes de bugs o nuevas funcionalidades, considera:
- Revisar logs detallados antes de reportar issues
- Incluir información de sistema (Proxmox version, etc.)
- Proponer mejoras siguiendo los patrones establecidos

---

**⚡ Tip:** Todos los scripts pueden ejecutarse con `--help` o `-h` para obtener información detallada de uso.
