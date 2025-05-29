# Wait-Mounts System Scripts

Este directorio contiene scripts para esperar a que los puntos de montaje estén disponibles antes de iniciar contenedores LXC en Proxmox VE.

## 📁 Contenido

### Scripts Principales
- **`wait-mounts.sh`** - Script principal para monitorear puntos de montaje
- **`install-wait-mounts.sh`** - Instalador del sistema completo

### Configuración
- **`wait-mounts.conf.example`** - Archivo de configuración de ejemplo
- **`wait-mounts.service`** - Archivo de servicio systemd

## 🚀 Instalación Rápida

```bash
sudo chmod +x install-wait-mounts.sh
sudo ./install-wait-mounts.sh
```

## 🎯 Problema que Resuelve

Los contenedores LXC pueden iniciarse antes de que los puntos de montaje (NFS, CIFS, etc.) estén disponibles. Este sistema:

- ✅ Espera a que los puntos de montaje estén disponibles
- ✅ Inicia contenedores automáticamente cuando están listos
- ✅ Funciona como servicio systemd para arranque automático
- ✅ Monitoreo continuo y reintentos automáticos
- ✅ Configuración flexible de timeouts y intervalos

## 📋 Uso Manual

```bash
# Modo interactivo
sudo ./wait-mounts.sh

# Con archivo de configuración
sudo ./wait-mounts.sh --config /etc/wait-mounts.conf

# Especificar puntos de montaje directamente
sudo ./wait-mounts.sh --mounts "/mnt/data /mnt/backup"

# Con contenedores específicos
sudo ./wait-mounts.sh --containers "101,102"

# Modo daemon (continuo)
sudo ./wait-mounts.sh --daemon
```

## 🔧 Gestión del Servicio

```bash
# Habilitar servicio
sudo systemctl enable wait-mounts.service

# Iniciar servicio
sudo systemctl start wait-mounts.service

# Ver estado
sudo systemctl status wait-mounts.service

# Ver logs
sudo journalctl -u wait-mounts.service
```

## ⚙️ Configuración

Edita `/etc/wait-mounts.conf` para especificar puntos de montaje y contenedores:

```bash
# Puntos de montaje a monitorear
MOUNT_POINTS=("/mnt/nas" "/mnt/backup" "/mnt/media")

# IDs de contenedores a iniciar
CONTAINERS="101,102,104"

# Timeout en segundos
TIMEOUT=300

# Intervalo de verificación en segundos
CHECK_INTERVAL=5
```

## 📝 Casos de Uso Comunes

- **NAS/Storage:** Esperar montajes NFS antes de iniciar contenedores de media
- **Backups:** Asegurar que unidades de backup estén montadas
- **Shared Storage:** Contenedores que dependen de almacenamiento compartido
- **Network Drives:** Montajes CIFS/SMB que pueden tardar en conectar
