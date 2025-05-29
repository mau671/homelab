# Utility Scripts

Este directorio contiene scripts de utilidades y herramientas de instalación para el homelab.

## 📁 Contenido

### Scripts de Instalación
- **`install-btop.sh`** - Instalador de btop (monitor de sistema mejorado)
- **`install-wireguard-lxc.sh`** - Instalador de WireGuard en contenedores LXC

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

## 📋 Uso

```bash
# Instalar btop
sudo ./install-btop.sh

# Instalar WireGuard en LXC
sudo ./install-wireguard-lxc.sh
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
