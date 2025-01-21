### WireGuard VPN for Plex Setup Guide

This guide provides step-by-step instructions for setting up **WireGuard VPN** for Plex using separate server and client configurations.

---

## Server Setup

### Prerequisites
1. Ensure **Docker** and **Docker Compose** are installed on the server.
2. Obtain the server's **public IP address or domain name**.

### Instructions
1. **Prepare the `server.yaml` File**  
   Save the content from `./server.yaml` to a file named `server.yaml`.

2. **Edit the `/config/wg_confs/wg0.conf` File**  
   On the server, add the following rules to enable Plex traffic redirection:

   ```bash
   PostUp = iptables -t nat -A POSTROUTING -o wg+ -j MASQUERADE; \
            iptables -t nat -A PREROUTING -p tcp --dport 32400 -j DNAT --to-destination 10.13.13.2:32400
   PreDown = iptables -t nat -D POSTROUTING -o wg+ -j MASQUERADE; \
             iptables -t nat -D PREROUTING -p tcp --dport 32400 -j DNAT --to-destination 10.13.13.2:32400
   ```

   Replace `10.13.13.2` with the internal IP assigned to Plex.

3. **Start the Server**  
   Run the following command to start the WireGuard server:

   ```bash
   docker compose -f server.yaml up -d
   ```

4. **Generate Client Configuration Files**  
   After starting the server, find the generated client configurations in `/path/to/wireguard/config/peerX/`.

---

## Client Setup

### Prerequisites
1. Ensure **Docker** and **Docker Compose** are installed on the client machine.
2. Obtain the client configuration file (`wg0.conf`) generated on the server.

### Instructions
1. **Create the `plex` Network**  
   Create a shared external Docker network named `plex`:

   ```bash
   docker network create --driver=bridge --subnet=172.20.0.0/16 plex
   ```

2. **Prepare the `client.yaml` File**  
   Save the content from `./client.yaml` to a file named `client.yaml`.

3. **Add the Client Configuration**  
   Copy the `wg0.conf` file generated on the server to `/home/docker/wireguard/config` on the client machine.

4. **Start the Client**  
   Run the following command to start the WireGuard client and Plex:

   ```bash
   docker compose -f client.yaml up -d
   ```

## Verifications
1. **Verify WireGuard Connection**  
   On the client machine, check the connection status:

   ```bash
   docker logs wireguard
   ```

2. **Access Plex**  
   Open your browser and navigate to `http://172.20.0.3:32400/web`.

3. **Troubleshooting**  
   - Ensure the server and client configurations match.
   - Verify the correct IP forwarding rules are applied on the server.

