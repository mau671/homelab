# Traefik Setup

This repository contains a Docker Compose configuration and Traefik configuration files to set up a reverse proxy with Traefik. This setup is designed for a homelab environment and supports secure HTTPS with Let's Encrypt certificates, basic authentication for the dashboard, and dynamic service configuration.

## Files Included

- `compose.yaml`: Docker Compose file to set up the Traefik container.
- `traefik.toml`: Main Traefik configuration file.
- `traefik_dynamic.toml`: Dynamic Traefik configuration for routers, middleware, and services.

## Prerequisites

- Docker and Docker Compose installed.
- A domain name for your services.
- Access to modify DNS settings for your domain.
- A valid email address for Let's Encrypt SSL certificates.

## Setup Instructions

### 1. Customize the Configuration Files

#### `compose.yaml`
1. Replace the volume paths in the `volumes` section with the actual paths on your system:
   ```yaml
   - /home/docker/traefik/config/traefik.toml:/traefik.toml
   - /home/docker/traefik/config/traefik_dynamic.toml:/traefik_dynamic.toml
   - /home/docker/traefik/config/acme.json:/acme.json
   ```
2. Ensure the `web` network exists and is external. You can create it if it does not exist:
   ```bash
   docker network create web
   ```

#### `traefik.toml`
1. Replace the email address for Let's Encrypt with your own:
   ```toml
   email = "your-email@example.com"
   ```
2. Verify that the `network` matches the one in `compose.yaml`:
   ```toml
   network = "web"
   ```

#### `traefik_dynamic.toml`
1. Replace the basic authentication user and password hash if needed. You can generate a new password hash using tools like `htpasswd`:
   ```bash
   htpasswd -nb admin yourpassword
   ```
2. Replace the `Host` rule in the `http.routers.api` section with your domain:
   ```toml
   rule = "Host(`your-domain.com`)"
   ```

### 2. Prepare the `acme.json` File
The `acme.json` file is used by Traefik to store SSL certificates. Create this file and set the appropriate permissions:
```bash
sudo touch /home/docker/traefik/config/acme.json
sudo chmod 600 /home/docker/traefik/config/acme.json
```

### 3. Deploy Traefik
Start the Traefik container using Docker Compose:
```bash
docker-compose -f compose.yaml up -d
```

### 4. Test the Setup
- Access the Traefik dashboard at `https://your-domain.com` (replace with your configured domain).
- Log in using the username and password configured in `traefik_dynamic.toml`.

## Example of Service Integration
To route traffic to a service, add the following labels to the service's configuration:
```yaml
labels:
  - traefik.enable=true
  - traefik.http.routers.myservice.entrypoints=websecure
  - traefik.http.routers.myservice.rule=Host(`your-service-domain.com`)
  - traefik.http.routers.myservice.service=myservice
  - traefik.http.routers.myservice.tls.certresolver=lets-encrypt
  - traefik.http.services.myservice.loadbalancer.server.port=YOUR_SERVICE_PORT
networks:
  - web
```
Replace:
- `your-service-domain.com` with your service's domain.
- `YOUR_SERVICE_PORT` with the port exposed by your service.

## Troubleshooting

### Common Issues
1. **Network Not Found**:
   If you encounter an error about the `web` network not being found, ensure it exists by running:
   ```bash
   docker network create web
   ```

2. **Permission Issues with `acme.json`**:
   Ensure the file exists and has the correct permissions:
   ```bash
   sudo chmod 600 /path/to/acme.json
   ```

3. **Let's Encrypt Rate Limits**:
   If you exceed rate limits, refer to [Let's Encrypt Rate Limits](https://letsencrypt.org/docs/rate-limits/).

### Logs
Check Traefik logs for more information:
```bash
docker logs traefik
```

## References
- [Traefik Documentation](https://doc.traefik.io/traefik/)

