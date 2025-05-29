# Intel GPU Management Scripts

Este directorio contiene scripts para la gestión automática de dispositivos Intel GPU en contenedores LXC de Proxmox VE.

## 📁 Contenido

### Scripts Principales
- **`fix-intel-gpu-containers.sh`** - Script principal para detectar y configurar Intel GPU
- **`intel-gpu-autofix.sh`** - Script de servicio para ejecución automática
- **`install-intel-gpu-autofix.sh`** - Instalador del sistema completo

### Configuración
- **`intel-gpu-containers.conf.example`** - Archivo de configuración de ejemplo
- **`intel-gpu-autofix.service`** - Archivo de servicio systemd

## 🚀 Instalación Rápida

```bash
sudo chmod +x install-intel-gpu-autofix.sh
sudo ./install-intel-gpu-autofix.sh
```

## 🎯 Problema que Resuelve

El Intel iGPU puede aparecer como diferentes números de tarjeta (`card0` o `card1`) después de reinicios del sistema. Este sistema:

- ✅ Detecta automáticamente el dispositivo Intel GPU correcto
- ✅ Actualiza las configuraciones de contenedores LXC automáticamente  
- ✅ Funciona como servicio systemd para arranque automático
- ✅ Crea respaldos antes de modificar configuraciones
- ✅ Maneja múltiples contenedores simultáneamente

## 📋 Uso Manual

```bash
# Verificar detección de GPU
sudo ./fix-intel-gpu-containers.sh --check-only

# Configurar contenedores específicos
sudo ./fix-intel-gpu-containers.sh --containers "101,102" --auto

# Modo interactivo
sudo ./fix-intel-gpu-containers.sh
```

## 🔧 Gestión del Servicio

```bash
# Habilitar servicio
sudo systemctl enable intel-gpu-autofix.service

# Iniciar servicio
sudo systemctl start intel-gpu-autofix.service

# Ver estado
sudo systemctl status intel-gpu-autofix.service

# Ver logs
sudo journalctl -u intel-gpu-autofix.service
```

## ⚙️ Configuración

Edita `/etc/intel-gpu-containers.conf` para especificar los IDs de contenedores:

```bash
# IDs de contenedores que usan Intel GPU
CONTAINERS="101,102,104"
```
