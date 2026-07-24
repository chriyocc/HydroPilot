# HydroPilot Ubuntu Backend Deployment

## Recommended Network Shape

Use your Ubuntu server as the public HydroPilot backend host:

```text
Flutter app -> https://api.your-domain.com -> Ubuntu backend -> MQTT broker <- ESP32
```

Recommended split:

- Use Tailscale for SSH and private server administration.
- Use your Cloudflare domain for the mobile app backend URL.
- Use a managed MQTT broker, or expose a separate TLS MQTT broker on `8883` if you self-host MQTT.

Tailscale alone is good for private testing, but it is not the best production address for the app unless every phone that uses HydroPilot will always be connected to your tailnet.

## Option A: Cloudflare Tunnel

This is the preferred setup for a small home/server deployment because your backend can be public through your domain without opening inbound ports on the Ubuntu server.

High-level flow:

```text
Cloudflare DNS -> Cloudflare Tunnel -> localhost:3000 on Ubuntu
```

### 1. Prepare Ubuntu

```bash
sudo apt update
sudo apt install -y git curl
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
node --version
npm --version
```

### 2. Deploy the Backend Code

Choose a stable deployment path:

```bash
sudo mkdir -p /opt/hydropilot
sudo chown "$USER":"$USER" /opt/hydropilot
cd /opt/hydropilot
git clone https://github.com/chriyocc/HydroPilot.git .
cd backend
npm ci
```

If the repo is already on the server, pull it instead:

```bash
cd /opt/hydropilot
git pull
cd backend
npm ci
```

### 3. Configure Environment

The backend will not start until the MQTT and device environment variables are set. Create the production `.env` file on the Ubuntu server:

```bash
cd /opt/hydropilot/backend
nano .env
```

Paste this template and replace the placeholder values:

```env
NODE_ENV=production
PORT=3000

MQTT_BROKER_URL=mqtts://your-broker-host:8883
MQTT_USERNAME=your-mqtt-username
MQTT_PASSWORD=your-mqtt-password

HYDRO_DEVICE_ID=device-1
HYDRO_TOPIC_PREFIX=hydro

COMMAND_TIMEOUT_MS=5000
TELEMETRY_STALE_MS=30000
STATE_STALE_MS=15000
```

The `HYDRO_DEVICE_ID` and `HYDRO_TOPIC_PREFIX` values must match the ESP32 firmware configuration.

Lock down the file so only your SSH user can read the MQTT password:

```bash
chmod 600 /opt/hydropilot/backend/.env
```

Check that Node can load the environment:

```bash
cd /opt/hydropilot/backend
npm start
```

Expected result:

```text
HydroPilot backend listening on port 3000
```

Leave that running in one SSH window and test from another SSH window:

```bash
curl http://127.0.0.1:3000/api/health
curl http://127.0.0.1:3000/api/device
curl http://127.0.0.1:3000/api/device/status
```

Stop the manual server with `Ctrl+C` after the local checks work.

Common problems at this step:

- `Missing required environment variables`: the `.env` file is missing a required key or the backend is not being started from `/opt/hydropilot/backend`.
- MQTT connection warnings: broker URL, username, password, or firewall egress is wrong.
- `EADDRINUSE`: another process is already using port `3000`.

### 4. Run Backend with systemd

`systemd` keeps the backend running after SSH disconnects and restarts it after a reboot.

Create `/etc/systemd/system/hydropilot-backend.service`:

```bash
sudo nano /etc/systemd/system/hydropilot-backend.service
```

Paste:

```ini
[Unit]
Description=HydroPilot Backend
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/hydropilot/backend
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=5
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
```

If `which npm` returns something other than `/usr/bin/npm`, update `ExecStart` to match:

```bash
which npm
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable hydropilot-backend
sudo systemctl start hydropilot-backend
sudo systemctl status hydropilot-backend
```

Check logs:

```bash
journalctl -u hydropilot-backend -n 100 --no-pager
```

Follow live logs while testing:

```bash
journalctl -u hydropilot-backend -f
```

Check locally again:

```bash
curl http://127.0.0.1:3000/api/health
curl http://127.0.0.1:3000/api/device
```

Useful service commands:

```bash
sudo systemctl restart hydropilot-backend
sudo systemctl stop hydropilot-backend
sudo systemctl start hydropilot-backend
```

When you update backend code later:

```bash
cd /opt/hydropilot
git pull
cd backend
npm ci
sudo systemctl restart hydropilot-backend
journalctl -u hydropilot-backend -n 100 --no-pager
```

### 5. Publish with Cloudflare Tunnel

This exposes your backend as `https://api.your-domain.com` while the Node process stays bound to `localhost:3000`.

#### 5.1 Create the Tunnel in Cloudflare

In the Cloudflare dashboard:

1. Go to `Zero Trust`.
2. Go to `Networks` or `Networking`.
3. Open `Tunnels`.
4. Select `Create a tunnel`.
5. Choose `Cloudflared`.
6. Name it `hydropilot-backend`.
7. Choose Linux as the environment.
8. Copy the install command Cloudflare shows.

The command will look like this:

```bash
sudo cloudflared service install <CLOUDFLARE_TUNNEL_TOKEN>
```

Run that command over SSH on the Ubuntu server.

Check the service:

```bash
sudo systemctl status cloudflared
journalctl -u cloudflared -n 100 --no-pager
```

Cloudflare should show the tunnel as `Healthy`.

#### 5.2 Add the Public Hostname

Inside the same tunnel page, add a public hostname:

```text
api.your-domain.com -> http://localhost:3000
```

Suggested values:

```text
Subdomain: api
Domain: your-domain.com
Path: leave empty
Service type: HTTP
Service URL: localhost:3000
```

Cloudflare will create the needed DNS route for the tunnel. If Cloudflare says a DNS record already exists for `api.your-domain.com`, delete the old `A`, `AAAA`, or `CNAME` record for `api` first, then add the tunnel route again.

#### 5.3 Test the Public Backend

From your laptop or phone network, test:

```bash
curl https://api2.yoyojun.site/api/health
curl https://api2.yoyojun.site/api/device
curl https://api2.yoyojun.site/api/device/status
curl https://api2.yoyojun.site/api/device/ec-history
```

Set the app backend URL to:

```text
https://api2.yoyojun.site
```

For the SSE endpoint, use this check:

```bash
curl -N https://api2.yoyojun.site/api/device/events
```

Expected behavior:

- The command stays open.
- It prints an initial `snapshot` event.
- New telemetry/state events appear when MQTT messages arrive.

#### 5.4 Keep Tailscale for Admin

Use Tailscale SSH or normal SSH over Tailscale for server control:

```bash
ssh your-user@your-server-tailnet-name
```

The public app should use the Cloudflare domain. Your admin shell can keep using the private Tailscale address.

## Option B: Public IP + Nginx

Use this if you prefer a traditional reverse proxy and are comfortable opening ports `80` and `443` on the Ubuntu server.

Cloudflare DNS:

```text
Type: A
Name: api
Content: <your-server-public-ip>
Proxy: Proxied
```

Nginx reverse proxy:

```nginx
server {
    listen 80;
    server_name api.your-domain.com;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 3600s;
    }
}
```

`proxy_buffering off` matters because the backend uses Server-Sent Events at `/api/device/events`.

## Private Testing with Tailscale

If this is only for your own phone and laptop, you can skip the public domain at first and use Tailscale:

```bash
tailscale serve --bg --https=443 localhost:3000
```

Then use the generated Tailscale HTTPS name as the app backend URL.

This requires the phone to have Tailscale installed, connected, and allowed to access the server.

## MQTT Decision

The backend domain and MQTT broker are separate decisions.

Recommended easiest path:

- Keep using a managed MQTT broker such as HiveMQ Cloud, EMQX Cloud, or another TLS broker.
- Point both the ESP32 and backend to the same broker.
- Keep the backend public through `https://api.your-domain.com`.

Self-hosted MQTT path:

- Install Mosquitto on Ubuntu.
- Expose port `8883` with TLS.
- Use a DNS-only Cloudflare record such as `mqtt.your-domain.com`.
- Do not use the normal orange-cloud HTTP proxy for raw MQTT traffic.

## Production Checklist

- Backend runs under systemd and restarts after reboot.
- `.env` exists on the server and contains real MQTT credentials.
- `curl http://127.0.0.1:3000/api/health` works on the server.
- `curl https://api2.yoyojun.site/api/health` works from outside the server.
- Flutter app backend URL is set to `https://api2.yoyojun.site`.
- ESP32 and backend use the same `HYDRO_DEVICE_ID` and topic prefix.
- MQTT broker receives ESP32 telemetry and backend commands.
- SSE endpoint `/api/device/events` remains connected during app runtime.
