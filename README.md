# acme-bot

An SSL certificate auto-renewal and deployment bot running in a Docker container, based on [acme.sh](https://github.com/acmesh-official/acme.sh).

## Why acme-bot?

[acme.sh](https://github.com/acmesh-official/acme.sh) is an excellent ACME protocol client that supports various DNS APIs and web servers, and can automatically apply for and renew SSL certificates. However, while acme.sh provides an official Docker image, this image cannot automatically update and deploy certificates based on configuration provided through environment variables. You must manually run `acme.sh` commands to configure the running container.

**acme-bot is a wrapper around the official acme.sh Docker image.** It allows you to configure certificate issuance entirely through environment variables. On first startup, acme-bot automatically issues certificates for your domains, and then the built-in daemon handles automatic renewals forever.

Perfect for running as a standalone certificate management bot in Docker or Docker Swarm.

## Quick Start

```bash
docker run -d \
  --name acme-bot \
  -e EMAIL="admin@example.com" \
  -e AB_EXAMPLE_DOMAINS="dns_cf:example.com,*.example.com" \
  -e CF_Token="zfNp-Xm0VhSaCNun7dkLzwnw0UN7FNjaMurUZ8vf" \
  -e CF_Account_ID="763eac4f1bcebd8b5c95e9fc50d010b4" \
  -v ./acme_data:/acme.sh \
  ghcr.io/depuits/acme-bot:latest
```

Or use `docker-compose.yml`:

```yaml
services:
  acme-bot:
    image: ghcr.io/depuits/acme-bot:latest
    container_name: acme-bot
    restart: unless-stopped
    environment:
      - EMAIL=admin@example.com
      # Use AB_<GROUP>_DOMAINS format
      - AB_EXAMPLE_DOMAINS=dns_cf:example.com,*.example.com
      # DNS credentials
      - CF_Token=zfNp-Xm0VhSaCNun7dkLzwnw0UN7FNjaMurUZ8vf
      - CF_Account_ID=763eac4f1bcebd8b5c95e9fc50d010b4
    volumes:
      - ./acme_data:/acme.sh
```

### Multiple Certificate Groups Example
```yaml
services:
  acme-bot:
    image: ghcr.io/depuits/acme-bot:latest
    environment:
      - EMAIL=admin@example.com
      # Group 1: Main domain with Traefik
      - AB_TRAEFIK_DOMAINS=dns_freedns:example.com,*.example.com
      - AB_TRAEFIK_RELOADCMD=touch /certs/traefik.reload
      - AB_TRAEFIK_KEY_PATH=/certs/traefik.key
      - AB_TRAEFIK_FULLCHAIN_PATH=/certs/traefik.pem
      # Group 2: API domain with Nginx
      - AB_NGINX_DOMAINS=dns_cf:api.example.net
      - AB_NGINX_CERT_HOME=/nginx/certs
      - AB_NGINX_RELOADCMD=docker exec nginx nginx -s reload # for this to work you will need to have access to the docker socket
      # DNS credentials
      - FREEDNS_User=your_username
      - FREEDNS_Password=your_password
      - CF_Token=your_token
    volumes:
      - ./acme_data:/acme.sh
      - ./traefik_certs:/certs
      - ./nginx_certs:/nginx/certs
```

## How It Works

1. **First Startup** (`daemon` mode): acme-bot reads your environment variables and:
  - Registers an ACME account (using `EMAIL`)
  - Sets the default CA (if `CA` is specified)
  - Configures notifications (if `NOTIFY` is specified)
  - Issues certificates for all certificate groups (`AB_<GROUP>_DOMAINS`)
  - Starts the renewal daemon (cron job)
2. **Renewals**: The daemon runs on a randomized schedule and automatically renews certificates when they expire.
3. **Deployment**: If you set `AB_<GROUP>_RELOADCMD`, it will be executed after each successful issuance or renewal for that group.

See [acme.sh Docker documentation](https://github.com/acmesh-official/acme.sh/wiki/Run-acme.sh-in-docker) for usage without the `daemon` command.

## Environment Variables

### Required

| Variable | Description | Example |
|----------|-------------|---------|
| EMAIL | Your email address for ACME account registration | admin@example.com |

#### Certificate Groups

Define one or more certificate groups using the prefix `AB_<GROUP>_`. Each group requires at least `AB_<GROUP>_DOMAINS`. All other variables are optional.

> **Note:** The group name (e.g., `MAIN`, `TRAEFIK`, `NGINX`) must be uppercase and can only contain letters and numbers. It must start with a letter. Invalid examples: `1MAIN` (starts with number), `my-group` (lower case and contains hyphen), `NGINX_PROD` (contains underscore).

| Variable | Description | Example |
|----------|-------------|---------|
| `AB_<GROUP>_DOMAINS` | (Required) Domain configuration in `METHOD:DOMAIN1,DOMAIN2` format | `AB_MAIN_DOMAINS=dns_freedns:example.com,*.example.com` |
| `AB_<GROUP>_RELOADCMD` | Command to run after certificate installation | `AB_MAIN_RELOADCMD=touch /certs/reload` |
| `AB_<GROUP>_CERT_HOME` | Custom certificate storage directory | `AB_MAIN_CERT_HOME=/certs/example` |
| `AB_<GROUP>_KEY_PATH` | Path for the private key file | `AB_MAIN_KEY_PATH=/certs/example.key` |
| `AB_<GROUP>_FULLCHAIN_PATH` | Path for the fullchain certificate | `AB_MAIN_FULLCHAIN_PATH=/certs/example.pem` |
| `AB_<GROUP>_WEBROOT_PATH` | Webroot path for HTTP-01 challenge | `AB_MAIN_WEBROOT_PATH=/usr/share/nginx/html` |

**DOMAINS Format Details:**

```text
METHOD:DOMAIN1,DOMAIN2, ...
```

- `METHOD`: The challenge method. Can be:
  * `dns_*` — DNS challenge (e.g., dns_freedns, dns_cloudflare, dns_ali)
  * `http` — HTTP-01 challenge (requires WEBROOT_PATH)
  * `tls-alpn-01` — TLS-ALPN-01 challenge
- `DOMAIN1,DOMAIN2`: Comma-separated list of domains (can include wildcards like `*.example.com`)

**Tip:** 
- Use `AB_<GROUP>_CERT_HOME` to store all certificate files in a custom directory
- Use `AB_<GROUP>_KEY_PATH` and `AB_<GROUP>_FULLCHAIN_PATH` to specify exact file paths
- If both are set, `KEY_PATH` and `FULLCHAIN_PATH` take precedence over `CERT_HOME`

### Optional

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| CA | ACME CA server to use | `zerossl` | `letsencrypt` |
| NOTIFY | Notification hook(s) |(none) | `customscript` |
| NOTIFY_LEVEL | Notification level | `2` | `3` |
| NOTIFY_MODE | Notification mode | `0` | `1` |
| NOTIFY_SOURCE | Notification source | (none) | `myservername` |

#### DNS Provider Credentials

After specifying a DNS provider in `AB_<GROUP>_DOMAINS` (e.g., `dns_cf`), you must provide the corresponding credentials as environment variables. See the [acme.sh DNS API documentation](https://github.com/acmesh-official/acme.sh/wiki/dnsapi) for the complete list.

##### Common examples:

| Provider | Required Variables |
|----------|--------------------|
| Cloudflare | `CF_Key`, `CF_Email` or `CF_Token` |
| Route53 | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` |
| FreeDNS Afraid.org | `FREEDNS_User`, `FREEDNS_Password` |

#### Notification Variables

If you specify `NOTIFY`, you may need additional environment variables for your notification hook. See the [acme.sh notification documentation](https://github.com/acmesh-official/acme.sh/wiki/notify).

## Storage and Persistence

All certificates, account information, and configuration are stored in /acme.sh inside the container. Mount this directory to a volume to persist certificates across container restarts:

```yaml
volumes:
  - ./acme_data:/acme.sh
```

## Running Single Commands

Since acme-bot is a wrapper around acme.sh, you can run any acme.sh command directly:

```bash
# List all certificates
docker exec acme-bot acme.sh --list

# Show account information
docker exec acme-bot acme.sh --show-account

# Upgrade acme.sh to the latest version
docker exec acme-bot acme.sh --upgrade

# Issue a certificate manually (if needed)
docker exec acme-bot acme.sh --issue -d example.com --webroot /var/www/html

# Force renew a certificate
docker exec acme-bot acme.sh --renew -d example.com --force
```

## Tags

acme-bot has its own versioning, independent of acme.sh.

- `latest` — Latest stable acme-bot release
- `dev` — Development build (may be unstable)  
- `1.0.0`, `1.0.1`, etc. — Specific acme-bot versions

**Example:** acme-bot v1.0.0 might be built on acme.sh 3.1.4, while v1.1.0 could use acme.sh 3.1.5. Check the [GitHub Releases](https://github.com/depuits/acme-bot/releases) for the exact combination in each version.
