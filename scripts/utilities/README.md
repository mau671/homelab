# Utility Scripts

Este directorio contiene scripts de utilidades y herramientas de instalación para el homelab.

## 📁 Contenido

### Scripts de Instalación
- **`install-btop.sh`** - Instalador de btop (monitor de sistema mejorado)
- **`install-wireguard-lxc.sh`** - Instalador de WireGuard en contenedores LXC
- **`install-gpu-drivers.sh`** - Instalador automático de drivers GPU (NVIDIA/Intel)

## 🎯 Funcionalidades

### install-btop.sh
Instalador automatizado de btop con:
- ✅ Detección automática de arquitectura del sistema
- ✅ Descarga e instalación automática
- ✅ Verificación de integridad
- ✅ Configuración optimizada

### install-wireguard-lxc.sh
Instalador de WireGuard para contenedores LXC con:
- ✅ Configuración automática de kernel modules
- ✅ Preparación del contenedor para VPN
- ✅ Instalación de dependencias
- ✅ Configuración de red optimizada

### install-gpu-drivers.sh
Instalador automático de drivers GPU con:
- ✅ Detección automática de GPUs NVIDIA e Intel
- ✅ Instalación optimizada para Ubuntu y Debian
- ✅ Herramientas de monitoreo (nvidia-smi, intel_gpu_top)
- ✅ Configuración de VA-API y OpenCL
- ✅ Script de estado de GPU integrado

## 📋 Uso

```bash
# Instalar btop
sudo ./install-btop.sh

# Instalar WireGuard en LXC
sudo ./install-wireguard-lxc.sh

# Instalar drivers GPU automáticamente
sudo ./install-gpu-drivers.sh

# Instalar drivers específicos (forzar)
sudo ./install-gpu-drivers.sh --force-nvidia
sudo ./install-gpu-drivers.sh --force-intel

# Verificar que se instalaría sin cambios
sudo ./install-gpu-drivers.sh --dry-run
```

## 🔧 Características Comunes

Todos los scripts de utilidades incluyen:
- ✅ Verificación de prerrequisitos
- ✅ Salida con colores y formato profesional
- ✅ Manejo completo de errores
- ✅ Logging de operaciones
- ✅ Validación de sistema

## ⚡ Próximas Utilidades

Scripts planificados para agregar:
- Instalador de Docker optimizado
- Script de configuración de SSH hardening
- Herramienta de backup automático
- Monitor de recursos del homelab
