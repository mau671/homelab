# Jellyfin Setup

This guide provides instructions to set up a Jellyfin server with hardware acceleration, integrated with Traefik as a reverse proxy for HTTPS and domain-based routing.

## Files Included

- `compose.yaml`: Docker Compose configuration for Jellyfin.
- Example Traefik configuration integrated with Jellyfin.

## Prerequisites

- Docker and Docker Compose installed.
- A Traefik setup as per the [Traefik setup](../traefik/).
- A domain name for Jellyfin.
- Knowledge of your system's GPU for hardware acceleration.

---

## compose.yaml

```yaml
services:
  jellyfin:
    image: lscr.io/linuxserver/jellyfin:latest
    container_name: jellyfin
    restart: unless-stopped
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Your_Timezone
      - DOCKER_MODS=ghcr.io/intro-skipper/intro-skipper-docker-mod
      # - JELLYFIN_PublishedServerUrl=https://your-jellyfin-domain.com # Optional
    volumes:
      - /path/to/jellyfin/config:/config
      - /path/to/media/movies:/data/movies
      - /path/to/media/series:/data/series
    devices:
      - /dev/dri:/dev/dri # For hardware acceleration
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.jellyfin.entrypoints=websecure"
      - "traefik.http.routers.jellyfin.rule=Host(`your-jellyfin-domain.com`)">
      - "traefik.http.routers.jellyfin.service=jellyfin"
      - "traefik.http.routers.jellyfin.tls.certresolver=lets-encrypt"
      - "traefik.http.services.jellyfin.loadbalancer.server.port=8096"
    networks:
      - web

networks:
  web:
    external: true
```

---

## Instructions

### 1. Customize `compose.yaml`

1. **Volumes**:
   - Replace `/path/to/jellyfin/config` with the path for Jellyfin's configuration.
   - Replace `/path/to/media/movies` and `/path/to/media/series` with paths to your media directories.

2. **Environment Variables**:
   - Set `PUID` and `PGID` to match the user and group IDs managing the files.
   - Update `TZ` with your timezone (e.g., `America/Costa_Rica`).
   - Optionally, set `JELLYFIN_PublishedServerUrl` if you want Jellyfin to announce a specific URL.

3. **Domain Configuration**:
   - Replace `your-jellyfin-domain.com` in the labels with your Jellyfin domain.

4. **Hardware Acceleration**:
   - Ensure `/dev/dri` is present on your host for Intel/AMD GPUs.
   - Add NVIDIA support using the `nvidia-container-toolkit` if required.

---

## Deploy Jellyfin

1. **Start the Container**:
   ```bash
   docker compose up -d
   ```

2. **Verify**:
   ```bash
   docker compose ps
   ```

---

## Hardware Acceleration Setup

1. **Host Configuration**:
   - Ensure GPU drivers are installed on the host.
   - For Intel/AMD GPUs, ensure `/dev/dri` exists.

2. **Enable Hardware Acceleration in Jellyfin**:
   - Go to **Dashboard > Playback > Transcoding** in Jellyfin.
   - Enable hardware acceleration.
   - Select the appropriate decoder/encoder for your GPU (e.g., VA-API).

---

## Traefik Integration

### Traefik Dynamic Configuration (`traefik_dynamic.toml`)

Ensure your Traefik setup includes the following configuration:

```toml
[http.routers.jellyfin]
  rule = "Host(`your-jellyfin-domain.com`)"
  entrypoints = ["websecure"]
  service = "jellyfin"
  [http.routers.jellyfin.tls]
    certResolver = "lets-encrypt"
```

---

## Troubleshooting

1. **Logs**:
   - Check Jellyfin logs:
     ```bash
     docker compose logs jellyfin
     ```
   - Check Traefik logs:
     ```bash
     docker compose logs traefik
     ```

2. **Hardware Issues**:
   - Verify that `/dev/dri` is correctly mapped.
   - Ensure GPU drivers are properly installed.

---

## References

- [Jellyfin Documentation](https://jellyfin.org/docs/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)

