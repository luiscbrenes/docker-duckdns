# docker-duckdns

A Docker image to automatically update your DuckDNS records using either:

- Internal (LAN) IPv4 and/or IPv6 addresses
- External (public) IPv4 and/or IPv6 addresses

This project is based on the excellent work from LinuxServer.io, but has been significantly modified to support updating private network addresses, making it ideal for homelab environments.

## Features

- Update internal IPv4 addresses (e.g. `192.168.x.x`, `10.x.x.x`)
- Update internal IPv6 addresses
- Update external IPv4 and IPv6 addresses
- Support for updating:
  - IPv4 only
  - IPv6 only
  - Both IPv4 and IPv6
- Optional logging to `/config/duck.log`
- Multi-subdomain support
- Compatible with Docker Compose, Dokploy, and Docker Swarm
- Based on Alpine Linux with s6-overlay

## Why use internal IP updates?

Normally, DuckDNS containers update your public IP address. In many homelab environments, however, DNS is used only inside the local network and should point to a server's private IP address.

Examples:

- `192.168.1.10`
- `192.168.100.120`
- `10.0.0.50`

This image adds support for:

```text
USE_INTERNAL_IP=true
```

When enabled, the container detects the host's LAN address and updates DuckDNS using that value.

## Supported Architectures

- amd64 (x86_64)
- arm64 (aarch64)

## Application Setup

1. Create an account at https://www.duckdns.org/
2. Create one or more subdomains.
3. Obtain your DuckDNS token.
4. Deploy this container with the required environment variables.

## Usage

> Unless marked as optional, all variables are required.

### Docker Compose

```yaml
services:
  duckdns:
    image: ghcr.io/luiscbrenes/docker-duckdns:latest
    container_name: duckdns
    network_mode: host
    environment:
      - PUID=1000                # optional
      - PGID=1000                # optional
      - TZ=America/Costa_Rica    # optional
      - SUBDOMAINS=mydomain
      - TOKEN=your-duckdns-token
      - UPDATE_IP=ipv4           # optional: ipv4, ipv6, both
      - USE_INTERNAL_IP=true     # optional
      - LOG_FILE=true            # optional
    volumes:
      - ./config:/config
    restart: unless-stopped
```

### Dokploy

Use the following image:

```text
ghcr.io/luiscbrenes/docker-duckdns:latest
```

Set the environment variables in the Dokploy interface and enable `network_mode: host`.

### Docker CLI

```bash
docker run -d \
  --name duckdns \
  --net=host \
  -e SUBDOMAINS=mydomain \
  -e TOKEN=your-duckdns-token \
  -e UPDATE_IP=ipv4 \
  -e USE_INTERNAL_IP=true \
  -e LOG_FILE=true \
  -v $(pwd)/config:/config \
  --restart unless-stopped \
  ghcr.io/luiscbrenes/docker-duckdns:latest
```

## Environment Variables

| Variable | Required | Description |
|--------|--------|--------|
| `SUBDOMAINS` | Yes | One or more DuckDNS subdomains separated by commas |
| `TOKEN` | Yes | Your DuckDNS token |
| `UPDATE_IP` | No | `ipv4`, `ipv6`, or `both` |
| `USE_INTERNAL_IP` | No | Set to `true` to use LAN IP addresses |
| `LOG_FILE` | No | Set to `true` to log to `/config/duck.log` |
| `PUID` | No | User ID for mounted volumes |
| `PGID` | No | Group ID for mounted volumes |
| `TZ` | No | Timezone |

## Behavior Matrix

| `USE_INTERNAL_IP` | `UPDATE_IP` | Result |
|------------------|------------|--------|
| `false` or unset | unset | DuckDNS auto-detects public IPv4 |
| `false` or unset | `ipv4` | Detect public IPv4 via Cloudflare |
| `false` or unset | `ipv6` | Detect public IPv6 via Cloudflare |
| `false` or unset | `both` | Detect both public IPv4 and IPv6 |
| `true` | `ipv4` | Detect internal IPv4 |
| `true` | `ipv6` | Detect internal IPv6 |
| `true` | `both` | Detect both internal IPv4 and IPv6 |

> Note: `USE_INTERNAL_IP=true` is intended to be used together with `UPDATE_IP`. If `UPDATE_IP` is omitted, DuckDNS will auto-detect the public IPv4 address.

## Logging

When `LOG_FILE=true`, logs are written to:

```text
/config/duck.log
```

The log file includes:

- Detected IP addresses
- Successful updates
- No-change notifications
- Error responses from DuckDNS

## Examples

### Update internal IPv4

```yaml
environment:
  - SUBDOMAINS=homelab
  - TOKEN=your-token
  - UPDATE_IP=ipv4
  - USE_INTERNAL_IP=true
```

### Update internal IPv4 and IPv6

```yaml
environment:
  - SUBDOMAINS=homelab
  - TOKEN=your-token
  - UPDATE_IP=both
  - USE_INTERNAL_IP=true
```

### Update public IPv4 (default behavior)

```yaml
environment:
  - SUBDOMAINS=homelab
  - TOKEN=your-token
```

## Networking

Host networking is recommended, especially when:

- Detecting IPv6 addresses
- Running in homelab environments
- Using internal IP detection

```yaml
network_mode: host
```

## Local Build

```bash
git clone https://github.com/luiscbrenes/docker-duckdns.git
cd docker-duckdns

docker build \
  --no-cache \
  --pull \
  -t ghcr.io/luiscbrenes/docker-duckdns:latest .
```

## Publishing to GitHub Container Registry

```bash
docker push ghcr.io/luiscbrenes/docker-duckdns:latest
```

## Updating

```bash
docker compose pull
docker compose up -d
```

## Useful Commands

### View logs

```bash
docker logs -f duckdns
```

### Open a shell inside the container

```bash
docker exec -it duckdns /bin/bash
```

### Show image version

```bash
docker inspect -f '{{ index .Config.Labels "build_version" }}' duckdns
```

## Use Cases

This image is particularly useful for:

- Homelabs
- Internal DNS resolution
- Reverse proxies such as Traefik and Nginx Proxy Manager
- Local-only services
- Split-horizon DNS environments

## Credits

This project is based on the original https://github.com/linuxserver/docker-duckdns image created by LinuxServer.io.

The code has been significantly modified to support internal IP detection and custom update workflows.

## License

This project inherits the license of the original project unless otherwise specified.
```
