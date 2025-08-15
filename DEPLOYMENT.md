# Home Assistant Container Deployment Guide

## Přehled

Tento projekt poskytuje optimalizovaný a zabezpečený kontejner pro Home Assistant s následujícími vylepšeními:

### 🚀 Hlavní funkce
- **Multi-stage build** pro optimalizaci velikosti image
- **Non-root uživatel** pro zvýšenou bezpečnost
- **SELinux konfigurace** pro dodatečnou ochranu
- **Health checks** pro monitoring
- **Automatické zálohování** s rotací
- **Fail2ban** pro ochranu proti útokům
- **BuildKit cache** pro rychlejší buildy

## 📋 Požadavky

- Docker 20.10+
- Docker Compose 2.0+
- Git
- Bash shell

## 🚀 Rychlý start

### 1. Klonování repozitáře
```bash
git clone <repository-url>
cd image-mode-hass
```

### 2. Konfigurace
```bash
# Kopírování konfiguračního souboru
cp env.example .env

# Úprava konfigurace podle potřeby
nano .env
```

### 3. Nasazení
```bash
# Automatické nastavení a spuštění
./deploy.sh setup

# Nebo manuální postup
./deploy.sh build
./deploy.sh start
```

## ⚙️ Konfigurace

### Environment proměnné

| Proměnná | Výchozí hodnota | Popis |
|----------|----------------|-------|
| `TIMEZONE` | `Europe/Prague` | Časové pásmo |
| `HASS_USER` | `hass` | Uživatel pro Home Assistant |
| `HASS_UID` | `1000` | UID uživatele |
| `HASS_GID` | `1000` | GID skupiny |
| `HASS_CONFIG_DIR` | `./config` | Adresář konfigurace |
| `HASS_BACKUP_DIR` | `./backups` | Adresář záloh |
| `HASS_SECRETS_DIR` | `./secrets` | Adresář tajemství |

### Struktura adresářů
```
image-mode-hass/
├── config/          # Home Assistant konfigurace
├── backups/         # Zálohy
├── secrets/         # Tajemství (read-only)
├── logs/           # Logy
├── ssl/            # SSL certifikáty
└── ssh/            # SSH klíče
```

## 🛠️ Správa

### Základní příkazy

```bash
# Stav kontejneru
./deploy.sh status

# Logy
./deploy.sh logs

# Přístup do kontejneru
./deploy.sh shell

# Restart
./deploy.sh restart

# Zastavení
./deploy.sh stop
```

### Zálohování a obnova

```bash
# Vytvoření zálohy
./deploy.sh backup

# Obnova ze zálohy
./deploy.sh restore backups/hass_backup_20231201_143022.tar.gz
```

### Monitoring

```bash
# Health check
./deploy.sh health

# Aktualizace
./deploy.sh update

# Vyčištění
./deploy.sh clean
```

## 🔒 Bezpečnost

### Implementované bezpečnostní opatření

1. **Non-root uživatel**
   - Home Assistant běží pod uživatelem `hass`
   - Omezená oprávnění pro zvýšenou bezpečnost

2. **SELinux**
   - Povolené porty: 22 (SSH), 8123 (Home Assistant)
   - Nastavené boolean hodnoty pro SSH

3. **SSH hardening**
   - Zakázané root přihlášení
   - Pouze SSH klíče (zakázané hesla)
   - Omezené pokusy o přihlášení

4. **Fail2ban**
   - Ochrana proti brute force útokům
   - Automatické blokování IP adres

5. **Firewall**
   - Povolené pouze potřebné porty
   - Veřejná zóna jako výchozí

### Doporučené bezpečnostní postupy

1. **SSH klíče**
   ```bash
   # Generování SSH klíče
   ssh-keygen -t ed25519 -C "hass@example.com"
   
   # Kopírování do kontejneru
   cp ~/.ssh/id_ed25519.pub ./ssh/authorized_keys
   ```

2. **SSL certifikáty**
   ```bash
   # Vlastní certifikáty
   cp your-cert.pem ./ssl/
   cp your-key.pem ./ssl/
   ```

3. **Tajemství**
   ```bash
   # Konfigurace tajemství
   nano ./secrets/secrets.yaml
   ```

## 📊 Monitoring a logy

### Health check
Kontejner obsahuje automatický health check, který kontroluje:
- Dostupnost Home Assistant API
- Stav SSH služby
- Využití disku a paměti

### Logy
```bash
# Zobrazení logů
./deploy.sh logs

# Logy Home Assistant
docker-compose exec home-assistant tail -f /var/log/home-assistant/home-assistant.log

# Logy systému
docker-compose exec home-assistant journalctl -f
```

### Metriky
- **Disk usage**: Automatické sledování
- **Memory usage**: Kontrola využití paměti
- **Service status**: Stav všech služeb

## 🔧 Troubleshooting

### Časté problémy

1. **Kontejner se nespustí**
   ```bash
   # Kontrola logů
   ./deploy.sh logs
   
   # Kontrola stavu
   ./deploy.sh status
   ```

2. **Problémy s oprávněními**
   ```bash
   # Oprava oprávnění
   sudo chown -R 1000:1000 config/ backups/ logs/
   ```

3. **Problémy s porty**
   ```bash
   # Kontrola obsazených portů
   netstat -tulpn | grep :8123
   netstat -tulpn | grep :22
   ```

4. **Problémy s SELinux**
   ```bash
   # Kontrola SELinux
   docker-compose exec home-assistant getenforce
   
   # Dočasné vypnutí (jen pro testování)
   docker-compose exec home-assistant setenforce 0
   ```

### Debugging

```bash
# Debug mode
docker-compose exec home-assistant bash

# Kontrola služeb
systemctl status sshd
systemctl status chronyd
systemctl status fail2ban

# Kontrola sítí
ip addr show
ss -tulpn
```

## 📈 Výkonnostní optimalizace

### Build optimalizace
- **Multi-stage build**: Snížení velikosti finálního image
- **BuildKit cache**: Rychlejší opakované buildy
- **Layer caching**: Optimalizace Docker vrstev

### Runtime optimalizace
- **Non-root uživatel**: Bezpečnostní optimalizace
- **SELinux**: Dodatečná ochrana
- **Health checks**: Automatický monitoring

### Monitoring
```bash
# Využití prostředků
docker stats home-assistant

# Disk usage
docker-compose exec home-assistant df -h

# Memory usage
docker-compose exec home-assistant free -h
```

## 🔄 Aktualizace

### Automatická aktualizace
```bash
./deploy.sh update
```

### Manuální aktualizace
```bash
# Pull změn
git pull origin main

# Rebuild image
./deploy.sh -f build

# Restart
./deploy.sh restart
```

## 📝 Logování

### Konfigurace logů
```yaml
# configuration.yaml
logger:
  default: info
  logs:
    homeassistant: info
    homeassistant.core: info
    homeassistant.components: info
```

### Rotace logů
- Automatická rotace každý den
- Komprese starých logů
- Retence 7 dní

## 🤝 Přispívání

1. Fork repozitáře
2. Vytvoření feature branch
3. Commit změn
4. Push do branch
5. Vytvoření Pull Request

## 📄 Licence

Tento projekt je licencován pod MIT licencí.

## 🆘 Podpora

Pro podporu a otázky:
- Vytvořte Issue na GitHub
- Kontaktujte autora
- Konzultujte dokumentaci

---

**Poznámka**: Tento kontejner je optimalizován pro produkční nasazení s důrazem na bezpečnost a výkonnost.
