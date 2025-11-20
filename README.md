# 🌐 Cloudflare DNS Load Balancer

Failover automatizado de DNS usando a API da Cloudflare.

## ✨ Funcionalidades

- Failover automático entre dois links de internet
- Verificação por ICMP (ping)
- Criação e remoção automática de registros A
- Suporte a múltiplos subdomínios
- Proxy da Cloudflare ativado automaticamente
- Integração com systemd.timer
- Sem dependência de containers

## 🔧 Instalação

1. Clone o repositório:
```bash
git clone https://github.com/marcianordrgs/cloudflare-dns-loadbalancer.git
cd cloudflare-dns-loadbalancer
```

2. Copie os arquivos de configuração:
```bash
sudo mkdir -p /opt/cloudflare-failover
sudo cp config/config.example.env /opt/cloudflare-failover/config.env
sudo cp scripts/domains.example.txt /opt/cloudflare-failover/domains.txt
sudo cp scripts/cloudflare_failover.sh /opt/cloudflare-failover/
```

3. Edite o arquivo de configuração:
```bash
nano /opt/cloudflare-failover/config.env
```

4. Ative o Timer do systemd:
```bash
sudo cp systemd/cloudflare-failover.service* /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now cloudflare-failover.timer
```

5. Verifique se o timer está ativo:
```bash
systemctl list-timers | grep cloudflare
```

6. Teste manualmente:
```bash
sudo bash /opt/cloudflare-failover/cloudflare_failover.sh
```

## 📜 Licença

MIT License