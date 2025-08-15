# Home Assistant Podman Deployment Guide

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
- **Systemd integrace** pro automatické spouštění

## 📋 Požadavky

- Podman 4.0+
- Systemd
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
./podman-deploy.sh setup

# Nebo manuální postup
./podman-deploy.sh build
./podman-deploy.sh start
```

## ⚙️ Konfigurace

### Environment proměnné

| Proměnná | Výchozí hodnota | Popis |
|----------|----------------|-------|
| `TIMEZONE` | `Europe/Prague` | Časové pásmo |
| `HASS_USER` | `hass` | Uživatel pro Home Assistant |
| `HASS_UID` | `1000` | UID uživatele |
| `HASS_GID` | `1000` | GID skupiny |
| `BACKUP_RETENTION_DAYS` | `7` | Dny retence záloh |

### Struktura adresářů
```
/var/home-assistant/
├── config/          # Home Assistant konfigurace
├── backups/         # Zálohy
└── secrets/         # Tajemství (read-only)

/var/log/home-assistant/  # Logy
```

## 🛠️ Správa

### Základní příkazy

```bash
# Stav kontejneru a služby
./podman-deploy.sh status

# Logy
./podman-deploy.sh logs

# Přístup do kontejneru
./podman-deploy.sh shell

# Restart
./podman-deploy.sh restart

# Zastavení
./podman-deploy.sh stop

# Povolení automatického spouštění
./podman-deploy.sh enable

# Zakázání automatického spouštění
./podman-deploy.sh disable
```

### Zálohování a obnova

```bash
# Vytvoření zálohy
./podman-deploy.sh backup

# Obnova ze zálohy
./podman-deploy.sh restore /var/home-assistant/backups/hass_backup_20231201_143022.tar.gz
```

### Monitoring

```bash
# Health check
./podman-deploy.sh health

# Aktualizace
./podman-deploy.sh update

# Vyčištění
./podman-deploy.sh clean
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
   sudo cp ~/.ssh/id_ed25519.pub /var/home-assistant/secrets/authorized_keys
   ```

2. **SSL certifikáty**
   ```bash
   # Vlastní certifikáty
   sudo cp your-cert.pem /var/home-assistant/secrets/
   sudo cp your-key.pem /var/home-assistant/secrets/
   ```

3. **Tajemství**
   ```bash
   # Konfigurace tajemství
   sudo nano /var/home-assistant/secrets/secrets.yaml
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
./podman-deploy.sh logs

# Logy Home Assistant
journalctl -u home-assistant -f

# Logy systému
podman exec home-assistant journalctl -f
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
   ./podman-deploy.sh logs
   
   # Kontrola stavu
   ./podman-deploy.sh status
   ```

2. **Problémy s oprávněními**
   ```bash
   # Oprava oprávnění
   sudo chown -R 1000:1000 /var/home-assistant
   sudo chown -R 1000:1000 /var/log/home-assistant
   ```

3. **Problémy s porty**
   ```bash
   # Kontrola obsazených portů
   sudo ss -tulpn | grep :8123
   sudo ss -tulpn | grep :22
   ```

4. **Problémy s SELinux**
   ```bash
   # Kontrola SELinux
   podman exec home-assistant getenforce
   
   # Dočasné vypnutí (jen pro testování)
   podman exec home-assistant setenforce 0
   ```

### Debugging

```bash
# Debug mode
./podman-deploy.sh shell

# Kontrola služeb
systemctl status home-assistant
systemctl status sshd
systemctl status chronyd
systemctl status fail2ban

# Kontrola sítí
podman exec home-assistant ip addr show
podman exec home-assistant ss -tulpn
```

## 📈 Výkonnostní optimalizace

### Build optimalizace
- **Multi-stage build**: Snížení velikosti finálního image
- **BuildKit cache**: Rychlejší opakované buildy
- **Layer caching**: Optimalizace Podman vrstev

### Runtime optimalizace
- **Non-root uživatel**: Bezpečnostní optimalizace
- **SELinux**: Dodatečná ochrana
- **Health checks**: Automatický monitoring
- **Systemd integrace**: Automatické spouštění

### Monitoring
```bash
# Využití prostředků
podman stats home-assistant

# Disk usage
podman exec home-assistant df -h

# Memory usage
podman exec home-assistant free -h
```

## 🔄 Aktualizace

### Automatická aktualizace
```bash
./podman-deploy.sh update
```

### Manuální aktualizace
```bash
# Pull změn
git pull origin main

# Rebuild image
./podman-deploy.sh -f build

# Restart
./podman-deploy.sh restart
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

## 🔧 Systemd integrace

### Automatické spouštění
```bash
# Povolení automatického spouštění
./podman-deploy.sh enable

# Kontrola stavu
systemctl is-enabled home-assistant
```

### Timer služby
Projekt obsahuje automatické timer služby:
- `hass-backup.timer` - automatické zálohování
- `hass-auto-update.timer` - automatické aktualizace

### Správa služeb
```bash
# Povolení timer služeb
sudo systemctl enable hass-backup.timer
sudo systemctl enable hass-auto-update.timer

# Spuštění timer služeb
sudo systemctl start hass-backup.timer
sudo systemctl start hass-auto-update.timer
```

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

**Poznámka**: Tento kontejner je optimalizován pro produkční nasazení s důrazem na bezpečnost a výkonnost. Používá Podman s systemd integrací pro maximální kompatibilitu s moderními Linux systémy.
