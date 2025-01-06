# Emby Setup

This guide provides instructions to set up an Emby server with hardware acceleration, integrated with Traefik as a reverse proxy for HTTPS and domain-based routing.

## Files Included

- `compose.yaml`: Docker Compose configuration for Emby.
- Example Traefik configuration integrated with Emby.

## Prerequisites

- Docker and Docker Compose installed.
- A Traefik setup as per the [Traefik setup](../traefik/).
- A domain name for Emby.
- Knowledge of your system's GPU for hardware acceleration.

---

## compose.yaml

```yaml
services:
  emby:
    image: lscr.io/linuxserver/emby:latest
    container_name: emby
    restart: unless-stopped
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Your_Timezone
    volumes:
      - /path/to/emby/config:/config
      - /path/to/media/movies:/data/movies
      - /path/to/media/series:/data/series
    devices:
      - /dev/dri:/dev/dri # For hardware acceleration
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.emby.entrypoints=websecure"
      - "traefik.http.routers.emby.rule=Host(`your-emby-domain.com`)">
      - "traefik.http.routers.emby.service=emby"
      - "traefik.http.routers.emby.tls.certresolver=lets-encrypt"
      - "traefik.http.services.emby.loadbalancer.server.port=8096"
    networks:
      - web

networks:
  web:
    external: true
```

---

## Instructions

### 1. Customize `compose.yaml`

1. **Volumes:**
   - Replace `/path/to/emby/config` with the path where Emby should store its configuration.
   - Replace `/path/to/media/movies` and `/path/to/media/series` with paths to your media directories.

2. **Environment Variables:**
   - Set `PUID` and `PGID` to match the user and group IDs that will manage the files.
   - Update the timezone `TZ` to match your local time (e.g., `America/Costa_Rica`).

3. **Domain Configuration:**
   - Replace `your-emby-domain.com` with your actual domain name for Emby.

4. **Hardware Acceleration:**
   - Ensure `/dev/dri` exists on your host machine.
   - This is typically available on systems with Intel or AMD GPUs.

### 2. Enable Hardware Acceleration in Emby

Once Emby is running:

1. Log in to the Emby admin dashboard.
2. Go to **Dashboard > Transcoding**.
3. Under **Transcoding**, enable hardware acceleration.
4. Select the appropriate decoder/encoder based on your GPU (e.g., VA-API for Intel).


### 3. Deploy Emby

Start the container:
```bash
docker compose up -d
```

Verify the container is running:
```bash
docker compose ps
```

### 4. Access Emby

- Open a browser and navigate to `https://your-emby-domain.com`.
- Log in and start configuring your media libraries.

---

## Example Traefik Integration

Ensure your Traefik configuration includes the `web` network and matches the labels defined in `compose.yaml`. For example:

### Traefik Dynamic Configuration (`traefik_dynamic.toml`)

```toml
[http.routers.emby]
  rule = "Host(`your-emby-domain.com`)"
  entrypoints = ["websecure"]
  service = "emby"
  [http.routers.emby.tls]
    certResolver = "lets-encrypt"
```

---

## Troubleshooting

### Hardware Acceleration Issues
- Verify that `/dev/dri` is correctly passed to the container.
- Check Emby logs for errors related to transcoding.
- Ensure your GPU drivers are installed and up-to-date.

### Traefik Issues
- Verify the Traefik dashboard to ensure the router and service are detected.
- Check Traefik logs for errors related to the `emby` service.

### Logs
To inspect logs:

```bash
docker compose logs emby
```

For Traefik:
```bash
docker compose logs traefik
```

---

## References

- [Emby Documentation](https://emby.media/documentation.html)
- [Traefik Documentation](https://doc.traefik.io/traefik/)

