# 🌐 Cloudflare DNS Load Balancer

Automated DNS-based failover and simple load balancing between two internet links using the Cloudflare API.

## ✨ Features

- Automatic failover between two internet links
- Basic load balancing by managing DNS A records across two upstream IPs
- Health checks via ICMP (ping)
- Automatic creation and removal of A records
- Support for multiple hostnames/subdomains
- Cloudflare proxy (CDN) enabled for managed records
- Integration with systemd.timer for periodic checks
- No container required

## 🔧 Installation

1. Install required packages (Debian/Ubuntu example):
```bash
sudo apt update
sudo apt install -y curl jq
```
For CentOS/RHEL/Fedora use yum/dnf:
```bash
sudo dnf install -y curl jq
```

2. Clone the repository:
```bash
git clone https://github.com/marcianordrgs/cloudflare-dns-loadbalancer.git
cd cloudflare-dns-loadbalancer
```

3. Copy configuration and script files:
```bash
sudo mkdir -p /opt/cloudflare-failover
sudo cp config/config.example.env /opt/cloudflare-failover/config.env
sudo cp scripts/domains.example.txt /opt/cloudflare-failover/domains.txt
sudo cp scripts/cloudflare_failover.sh /opt/cloudflare-failover/
```

4. Edit the domains file
```bash
sudo nano /opt/cloudflare-failover/domains.txt
```
- Add one hostname per line, for example:
```
example.com
sub.example.com
```
- Save and exit. These are the hostnames the script will manage.

5. Edit the Cloudflare config:
```bash
sudo nano /opt/cloudflare-failover/config.env
```
- Fill in CF_API_TOKEN, CF_ZONE_ID, IP_LINK1, IP_LINK2.

6. Install and enable the systemd timer:
```bash
sudo cp systemd/cloudflare-failover.* /etc/systemd/system/
sudo cp systemd/cloudflare-failover.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now cloudflare-failover.timer
```

7. Verify the timer is active:
```bash
systemctl status cloudflare-failover.timer
```

8. Test the script manually:
```bash
sudo bash /opt/cloudflare-failover/cloudflare_failover.sh
```

## 📜 License

MIT License