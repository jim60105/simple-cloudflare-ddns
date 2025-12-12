# Simple Cloudflare DDNS Updater

A simple Cloudflare Dynamic DNS updater running in a container that keeps your DNS records up to date.

## ✨ Features

- 🌍 Updates IPv4 (A record) and/or IPv6 (AAAA record) DNS records
- ⚙️ Configurable via environment variables
- 🔎 Supports custom IP detection services
- 🪶 Minimal container image based on curl

## 🚀 Quick Start

```bash
podman run --rm \
  -e API_TOKEN=your_cloudflare_api_token \
  -e ZONE_ID=your_zone_id \
  -e A_RECORD_ID=your_a_record_id \
  -e A_RECORD_NAME=subdomain.example.com \
  ghcr.io/jim60105/simple-cloudflare-ddns
```

## ⚙️ Environment Variables

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

## 🛠️ Setup Guide

### 🔐 1. Create Cloudflare API Token

1. Go to [Cloudflare API Tokens](https://dash.cloudflare.com/profile/api-tokens)
2. Click **Create Token**
3. Use **Custom token** template
4. Set Token name: `DNS Update Script`
5. Set Permissions: `Zone` → `DNS` → `Edit`
6. Set Zone Resources: `Include` → `All zones` (or specific zones)
7. Click **Continue to summary** then **Create Token**
8. Copy the token for use as `API_TOKEN`

### 🆔 2. Get Zone ID

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Select your domain
3. On the **Overview** page, find **Zone ID** in the right sidebar
4. Copy it for use as `ZONE_ID`

### 🧾 3. Get DNS Record IDs

Run this command to list all DNS records in your zone:

```bash
curl -X GET "https://api.cloudflare.com/client/v4/zones/YOUR_ZONE_ID/dns_records/" \
     -H "Authorization: Bearer YOUR_API_TOKEN" | jq '.result[] | {id, name, type}'
```

Find the record(s) you want to update and copy their `id` values.

## 📌 Usage Examples

### 🟦 IPv4 Only

```bash
podman run --rm \
  -e API_TOKEN=your_token \
  -e ZONE_ID=your_zone_id \
  -e A_RECORD_ID=your_a_record_id \
  -e A_RECORD_NAME=home.example.com \
  ghcr.io/jim60105/simple-cloudflare-ddns
```

### 🟪 IPv6 Only

```bash
podman run --rm \
  -e API_TOKEN=your_token \
  -e ZONE_ID=your_zone_id \
  -e AAAA_RECORD_ID=your_aaaa_record_id \
  -e AAAA_RECORD_NAME=home.example.com \
  ghcr.io/jim60105/simple-cloudflare-ddns
```

### 🔁 Both IPv4 and IPv6

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

### 🧭 With Custom IP Detection Service

```bash
podman run --rm \
  -e API_TOKEN=your_token \
  -e ZONE_ID=your_zone_id \
  -e A_RECORD_ID=your_a_record_id \
  -e A_RECORD_NAME=home.example.com \
  -e IPV4_API_URL=https://ifconfig.me/ip \
  ghcr.io/jim60105/simple-cloudflare-ddns
```

### ⏱️ Using with Cron (Scheduled Updates)

To run the updater periodically, you can use a cron job on the host:

```bash
# Edit crontab
crontab -e

# Add this line to run every 5 minutes
*/5 * * * * podman run --rm -e API_TOKEN=... -e ZONE_ID=... -e A_RECORD_ID=... ghcr.io/jim60105/simple-cloudflare-ddns
```

### ☸️ Kubernetes CronJob

The recommended way is to store credentials/IDs in a Kubernetes Secret and reference it from a CronJob.

1. Create a Secret (replace values):

   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: cloudflare-ddns
   type: Opaque
   stringData:
     API_TOKEN: "your_cloudflare_api_token"
     ZONE_ID: "your_zone_id"
     A_RECORD_ID: "your_a_record_id"
     A_RECORD_NAME: "home.example.com"
     # Optional (IPv6)
     # AAAA_RECORD_ID: "your_aaaa_record_id"
     # AAAA_RECORD_NAME: "home.example.com"
   ```

   Apply it:

   ```bash
   kubectl apply -f secret.yaml
   ```

2. Create a CronJob:

   ```yaml
   apiVersion: batch/v1
   kind: CronJob
   metadata:
     name: simple-cloudflare-ddns
   spec:
     schedule: "*/5 * * * *"
     concurrencyPolicy: Forbid
     successfulJobsHistoryLimit: 1
     failedJobsHistoryLimit: 3
     jobTemplate:
       spec:
         template:
           spec:
             restartPolicy: Never
             containers:
               - name: ddns
                 image: ghcr.io/jim60105/simple-cloudflare-ddns:latest
                 imagePullPolicy: IfNotPresent
                 envFrom:
                   - secretRef:
                       name: cloudflare-ddns
   ```

   Apply it:

   ```bash
   kubectl apply -f cronjob.yaml
   ```

## 🌐 Alternative IP Detection Services

### 🔒 Recommended: Deploy Your Own Service

For maximum reliability and to avoid dependency on third-party services, I recommend deploying your own IP detection service using [Your IP - Cloudflare Worker](https://github.com/jim60105/worker-your-ip).

**Why deploy your own?**

- 🛡️ **Reliability**: Not vulnerable to third-party service outages or rate limits
- 🔐 **Security**: Full control over your infrastructure
- ⚡ **Performance**: Cloudflare's global edge network ensures fast response times
- 💰 **Cost**: Free tier covers most personal use cases

**Quick Deploy:**

[![Deploy to Cloudflare Workers](https://deploy.workers.cloudflare.com/button)](https://deploy.workers.cloudflare.com/?url=https://github.com/jim60105/worker-your-ip)

Once deployed, use your worker URL in environment variables:

```bash
-e IPV4_API_URL=https://your-worker.workers.dev/ipv4 \
-e IPV6_API_URL=https://your-worker.workers.dev/ipv6
```

> [!Note]
> I made this 😉

### 🌍 Public Third-Party Services

If you prefer using existing services, any service that returns your public IP as plain text works:

- IPv4: `https://api.ipify.org`, `https://ifconfig.me`, `https://icanhazip.com`
- IPv6: `https://api6.ipify.org`, `https://ifconfig.co`

## 📄 License

<img src="https://github.com/user-attachments/assets/7be89814-775c-4306-b323-bff9376a857e" alt="agplv3" width="300" />

[GNU AFFERO GENERAL PUBLIC LICENSE Version 3](./LICENSE)

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.
