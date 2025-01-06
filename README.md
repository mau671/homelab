# Homelab Setup

This repository provides configurations for setting up a homelab environment using Docker Compose. It includes services such as Emby, Jellyfin, and Traefik, each configured for seamless integration and optimized performance.

## Services

### Emby
- **Description**: Media server for streaming personal content like movies, TV shows, and music.
- **Features**:
  - Hardware acceleration for transcoding.
  - Integration with Traefik for secure HTTPS access.
- **Configuration**:
  See [emby/README.md](emby/README.md).

### Jellyfin
- **Description**: Open-source media server for managing and streaming your media collection.
- **Features**:
  - Hardware acceleration for transcoding.
  - Integration with Traefik for secure HTTPS access.
- **Configuration**:
  See [jellyfin/README.md](jellyfin/README.md).

### Traefik
- **Description**: Reverse proxy and load balancer for managing traffic to your homelab services.
- **Features**:
  - Automatic HTTPS with Let's Encrypt.
  - Basic authentication for secure dashboard access.
  - Dynamic service discovery.
- **Configuration**:
  See [traefik/README.md](traefik/README.md).

## Prerequisites

- Docker and Docker Compose installed on your system.
- A domain name configured to point to your server.
- Basic knowledge of Docker and networking.

## Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/mau671/homelab.git
   cd homelab
   ```

2. Set up the `web` Docker network if it doesn't already exist:
   ```bash
   docker network create web
   ```

3. Follow the individual service setup guides:
   - [Emby](emby/README.md)
   - [Jellyfin](jellyfin/README.md)
   - [Traefik](traefik/README.md)

## Example Workflow

### Deploy Traefik
1. Navigate to the `traefik/` directory:
   ```bash
   cd traefik
   ```
2. Customize the configuration files as per your setup.
3. Deploy Traefik:
   ```bash
   docker compose up -d
   ```

### Deploy Media Servers (Emby/Jellyfin)
1. Navigate to the respective directory (e.g., `emby/`):
   ```bash
   cd emby
   ```
2. Customize `compose.yaml` for your media library paths, user IDs, and domain configuration.
3. Deploy the service:
   ```bash
   docker compose up -d
   ```

## Troubleshooting

- Check container logs for errors:
  ```bash
  docker compose logs <service>
  ```
  Replace `<service>` with `traefik`, `emby`, or `jellyfin`.

- Verify network connectivity:
  ```bash
  docker network inspect web
  ```

- Ensure proper permissions for volume paths (e.g., `config` directories, media libraries).

## References

- [Docker Documentation](https://docs.docker.com/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Emby Documentation](https://emby.media/documentation.html)
- [Jellyfin Documentation](https://jellyfin.org/docs/)

