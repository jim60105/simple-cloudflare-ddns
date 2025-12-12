# simple-cloudflare-ddns

A simple Cloudflare Dynamic DNS updater that runs in a container. It updates your Cloudflare DNS A/AAAA records with your current public IP address.

## Features

- Updates IPv4 (A record) and/or IPv6 (AAAA record) DNS records
- Configurable via environment variables
- Supports custom IP detection services
- Minimal container image based on curl

## Quick Start

```bash
podman run --rm \
  -e API_TOKEN=your_cloudflare_api_token \
  -e ZONE_ID=your_zone_id \
  -e A_RECORD_ID=your_a_record_id \
  -e A_RECORD_NAME=subdomain.example.com \
  ghcr.io/jim60105/simple-cloudflare-ddns
```

## Environment Variables

### Required

| Variable | Description |
|----------|-------------|
| `API_TOKEN` | Cloudflare API Token with `Zone:DNS:Edit` permission |
| `ZONE_ID` | Cloudflare Zone ID (found in domain overview page) |

### Optional (at least one record must be configured)

| Variable | Description | Default |
|----------|-------------|---------|
| `A_RECORD_ID` | DNS record ID for IPv4 A record (enables IPv4 updates) | - |
| `A_RECORD_NAME` | Domain name for A record | - |
| `AAAA_RECORD_ID` | DNS record ID for IPv6 AAAA record (enables IPv6 updates) | - |
| `AAAA_RECORD_NAME` | Domain name for AAAA record | - |
| `IPV4_API_URL` | URL to get public IPv4 address | `https://api.ipify.org` |
| `IPV6_API_URL` | URL to get public IPv6 address | `https://api6.ipify.org` |

## Setup Guide

### 1. Create Cloudflare API Token

1. Go to [Cloudflare API Tokens](https://dash.cloudflare.com/profile/api-tokens)
2. Click **Create Token**
3. Use **Custom token** template
4. Set Token name: `DNS Update Script`
5. Set Permissions: `Zone` → `DNS` → `Edit`
6. Set Zone Resources: `Include` → `All zones` (or specific zones)
7. Click **Continue to summary** then **Create Token**
8. Copy the token for use as `API_TOKEN`

### 2. Get Zone ID

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Select your domain
3. On the **Overview** page, find **Zone ID** in the right sidebar
4. Copy it for use as `ZONE_ID`

### 3. Get DNS Record IDs

Run this command to list all DNS records in your zone:

```bash
curl -X GET "https://api.cloudflare.com/client/v4/zones/YOUR_ZONE_ID/dns_records/" \
     -H "Authorization: Bearer YOUR_API_TOKEN" | jq '.result[] | {id, name, type}'
```

Find the record(s) you want to update and copy their `id` values.

## Usage Examples

### IPv4 Only

```bash
podman run --rm \
  -e API_TOKEN=your_token \
  -e ZONE_ID=your_zone_id \
  -e A_RECORD_ID=your_a_record_id \
  -e A_RECORD_NAME=home.example.com \
  ghcr.io/jim60105/simple-cloudflare-ddns
```

### IPv6 Only

```bash
podman run --rm \
  -e API_TOKEN=your_token \
  -e ZONE_ID=your_zone_id \
  -e AAAA_RECORD_ID=your_aaaa_record_id \
  -e AAAA_RECORD_NAME=home.example.com \
  ghcr.io/jim60105/simple-cloudflare-ddns
```

### Both IPv4 and IPv6

```bash
podman run --rm \
  -e API_TOKEN=your_token \
  -e ZONE_ID=your_zone_id \
  -e A_RECORD_ID=your_a_record_id \
  -e A_RECORD_NAME=home.example.com \
  -e AAAA_RECORD_ID=your_aaaa_record_id \
  -e AAAA_RECORD_NAME=home.example.com \
  ghcr.io/jim60105/simple-cloudflare-ddns
```

### With Custom IP Detection Service

```bash
podman run --rm \
  -e API_TOKEN=your_token \
  -e ZONE_ID=your_zone_id \
  -e A_RECORD_ID=your_a_record_id \
  -e IPV4_API_URL=https://ifconfig.me/ip \
  ghcr.io/jim60105/simple-cloudflare-ddns
```

### Using with Cron (Scheduled Updates)

To run the updater periodically, you can use a cron job on the host:

```bash
# Edit crontab
crontab -e

# Add this line to run every 5 minutes
*/5 * * * * podman run --rm -e API_TOKEN=... -e ZONE_ID=... -e A_RECORD_ID=... ghcr.io/jim60105/simple-cloudflare-ddns
```

Or use a container orchestration tool like Kubernetes CronJob.

## Alternative IP Detection Services

You can use any service that returns your public IP as plain text:

- IPv4: `https://api.ipify.org`, `https://ifconfig.me`, `https://icanhazip.com`
- IPv6: `https://api6.ipify.org`, `https://ifconfig.co`

## License

This project is licensed under the AGPL-3.0-or-later License - see the [LICENSE](LICENSE) file for details.
