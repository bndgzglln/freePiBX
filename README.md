# PiBX - FreePBX & Asterisk in Docker

A turnkey VoIP PBX system running **FreePBX 17** and **Asterisk 21** inside a single Docker container, with **Caddy** as an integrated reverse proxy. Designed for ARM64 (Raspberry Pi, Apple Silicon) and optimized for low-resource hosts.

> **Vibecoded with [OpenCode](https://opencode.ai) and Qwen 3.7 Max.**

---

## What This Does

Docker containerizes the entire PBX stack so you can deploy a production-grade phone system on any machine with Docker installed. Instead of installing Asterisk, FreePBX, Apache, MariaDB, and Caddy directly on your host, everything runs isolated inside a container with persistent volumes for data.

**Why Docker?**
- **Isolation** - the PBX stack doesn't pollute your host OS
- **Portability** - same image runs on a Pi, a NAS, or a cloud VM
- **Reproducibility** - one `docker compose up` and you have a working PBX
- **Easy updates** - pull a new image, restart, done

---

## Architecture

```
                    Host Network (network_mode: host)
                    ┌──────────────────────────────────┐
                    │         Docker Container         │
                    │                                  │
  HTTP/HTTPS ──────►│  Caddy (:80, :443)               │
                    │    └─ reverse_proxy              │
                    │       ├─ Apache (:8099)          │
                    │       └─ Apache (:8443)          │
                    │                                  │
  SIP ─────────────►│  Asterisk (:5060/udp, :5160/udp) │
  IAX ─────────────►│  Asterisk (:4569)                │
  RTP ─────────────►│  Asterisk (:10000-11000/udp)     │
                    │                                  │
                    │  MariaDB (embedded, :3306)       │
                    │  Fail2Ban                        │
                    │  s6-overlay (process supervisor) │
                    └──────────────────────────────────┘
```

### Caddy as Reverse Proxy

Caddy runs **inside the same container** as Apache, managed by s6-overlay. This eliminates the need for a separate proxy container while keeping the host's ports 80/443 free for other services if Apache is configured on non-standard ports.

- **Caddy** listens on `:80` and `:443` on the host
- **Apache** listens internally on `:8099` (HTTP) and `:8443` (HTTPS)
- Caddy proxies all traffic to Apache, handling HTTP/2, HTTP/3, and optional TLS termination

The Caddyfile is mounted from `./data/var/www/Caddyfile` and can be edited to customize routing, add TLS, or configure additional domains. After editing, reload Caddy:

```bash
docker exec freepbx-app caddy reload --config /etc/caddy/Caddyfile
```

### Host Network Mode

The container uses `network_mode: host` to avoid the overhead of mapping 1001 individual UDP ports (10000-11000) for RTP media streams. This is critical for VoIP:

- **No iptables rules per port** - saves kernel resources on low-power hosts
- **No NAT overhead** - RTP packets flow directly, reducing latency and jitter
- **SIP/RTP reachability** - Asterisk sees real client IPs without port translation issues

---

## Prerequisites

- Docker and Docker Compose V2 installed
- ARM64 or x86_64 host (image built for `linux/arm64`)
- Ports 80, 443, 5060/udp, 5160/udp, 10000-11000/udp available on the host
- If ports 80/443 are taken by another service, change `HTTP_PORT`/`HTTPS_PORT` in `docker-compose.yaml` and update `freepbx-17/install/etc/caddy/Caddyfile` accordingly

---

## Quick Start

### 1. Generate SSL Certificates (Optional)

If you want HTTPS with a proper CA-signed certificate:

```bash
chmod +x scripts/generate-secrets.sh
./scripts/generate-secrets.sh your.domain.com
```

This creates a self-signed CA and server certificate in `data/certs/`. Skip this step if you don't need SSL or plan to use Let's Encrypt externally.

### 2. Start the Container

```bash
docker compose up -d
```

The first boot takes **5-30 minutes** depending on your internet connection. FreePBX modules are downloaded and the database is initialized.

### 3. Access the Web UI

Open `http://<host-ip>/admin` in your browser. Create an admin account on first login.

---

## Configuration

### Environment Variables

| Variable | Description | Default |
|:--------:|:-----------:|:-------:|
| `HTTP_PORT` | Apache HTTP port (Caddy proxies to this) | `8099` |
| `HTTPS_PORT` | Apache HTTPS port (Caddy proxies to this) | `8443` |
| `RTP_START` | First RTP media port | `10000` |
| `RTP_FINISH` | Last RTP media port | `11000` |
| `DB_EMBEDDED` | Use embedded MariaDB (`TRUE`/`FALSE`) | `TRUE` |
| `DB_HOST` | External DB host (if `DB_EMBEDDED=FALSE`) | - |
| `DB_PORT` | External DB port | `3306` |
| `DB_NAME` | Database name | - |
| `DB_USER` | Database user | - |
| `DB_PASS` | Database password | - |
| `ENABLE_SSL` | Enable Apache SSL VirtualHost | `FALSE` |
| `ENABLE_FOP` | Enable Flash Operator Panel 2 | `FALSE` |
| `ENABLE_FAIL2BAN` | Enable Fail2Ban | `TRUE` |
| `UCP_FIRST` | Show User Control Panel as homepage | `TRUE` |

### Data Volumes

| Host Path | Container Path | Description |
|:---------:|:--------------:|:-----------:|
| `./data/certs` | `/certs` | SSL certificates |
| `./data/data` | `/data` | Asterisk/FreePBX persistent data |
| `./data/logs` | `/var/log` | Apache, Asterisk, system logs |
| `./data/www` | `/var/www/html` | Web root (custom files) |
| `./data/db` | `/var/lib/mysql` | MariaDB database files |
| `./data/var/www/Caddyfile` | `/etc/caddy/Caddyfile` | Caddy reverse proxy config (editable) |

### Networking Ports

| Port | Protocol | Service |
|:----:|:--------:|:-------:|
| 80 | TCP | Caddy (HTTP) |
| 443 | TCP | Caddy (HTTPS) |
| 4445 | TCP | FOP2 |
| 4569 | UDP | IAX2 |
| 5060 | UDP | PJSIP |
| 5160 | UDP | SIP (Chan) |
| 10000-11000 | UDP | RTP media |

---

## Running & Maintenance

### Shell Access

```bash
docker exec -it freepbx-app bash
```

### View Logs

```bash
docker logs -f freepbx-app
```

### Restart

```bash
docker compose restart
```

### Update Image

```bash
docker compose pull
docker compose up -d
```

### Upgrade FreePBX Core Modules

If the FreePBX framework or core module update fails, enter the container and run:

```bash
docker exec -it freepbx-app upgrade-core
```

### Upgrade CDR Module

```bash
docker exec -it freepbx-app upgrade-cdr
```

### Fail2Ban

Fail2Ban is enabled by default. For rules to trigger, enable the `security` log level in FreePBX under **Settings > Log File Settings > Log files**.

---

## Building the Image

```bash
docker build -t bndgzglln23/pibpx:latest .
```

For cross-platform builds (e.g., building on x86 for ARM64):

```bash
docker buildx create --name pibx-builder --use
docker buildx build --platform linux/arm64 -t bndgzglln23/pibpx:latest --push .
```

---

## Known Issues

- **CDR Module Update** - may fail with embedded DB. Run `upgrade-cdr` inside the container.
- **Feature Codes** - `helptext` column too short. Fix: `ALTER TABLE featurecodes MODIFY COLUMN helptext varchar(500);`
- **WebRTC** - requires a valid (non-self-signed) SSL certificate.

---

## Credits

Based on [tiredofit/docker-freepbx](https://github.com/tiredofit/docker-freepbx) by Dave Conroy and [epandi/tiredofit-freepbx-arm](https://github.com/epandi/tiredofit-freepbx-arm).
