# Security Guide for Home Assistant bootc

This document contains recommendations and configuration for securing your Home Assistant server.

## 🔐 Basic Security Configuration

### SSH Configuration
Recommended configuration in `/etc/ssh/sshd_config`:

```bash
# Disable root login
PermitRootLogin no

# Use key-based authentication only
PasswordAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey

# Restrict users
AllowUsers hass-admin

# Change default port (optional)
Port 2222

# Other security settings
Protocol 2
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding no
PermitTunnel no
```

### Firewall Configuration
```bash
# Basic setup
sudo firewall-cmd --set-default-zone=public

# Allowed services
sudo firewall-cmd --add-service=ssh --permanent
sudo firewall-cmd --add-port=8123/tcp --permanent

# For changed SSH port
sudo firewall-cmd --add-port=2222/tcp --permanent
sudo firewall-cmd --remove-service=ssh --permanent

# Apply changes
sudo firewall-cmd --reload
```

## 🛡️ Fail2ban Configuration

### Main Configuration
File `/etc/fail2ban/jail.local`:

```ini
[DEFAULT]
# Ban IP for 1 hour after 5 failed attempts within 10 minutes
bantime = 3600
findtime = 600
maxretry = 5
backend = systemd

# Email notifications (optional)
destemail = admin@yourdomain.com
sendername = Fail2Ban
mta = sendmail

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
bantime = 3600
maxretry = 3

[home-assistant]
enabled = true
port = 8123
filter = home-assistant
logpath = /var/log/home-assistant/*.log
bantime = 1800
findtime = 600
maxretry = 10
```

### Home Assistant Filter
File `/etc/fail2ban/filter.d/home-assistant.conf`:

```ini
[Definition]
failregex = ^.*WARNING.*Login attempt or request with invalid authentication from <HOST>.*$
            ^.*WARNING.*Invalid authentication.*<HOST>.*$
            ^.*ERROR.*Invalid auth.*<HOST>.*$
            ^.*WARNING.*Suspicious activity.*<HOST>.*$

ignoreregex =
```

## 🔒 SSL/TLS Configuration

### Let's Encrypt with nginx
1. Install nginx:
```bash
sudo dnf install nginx certbot python3-certbot-nginx
```

2. Nginx configuration (`/etc/nginx/conf.d/homeassistant.conf`):
```nginx
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;

    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-Frame-Options DENY always;
    add_header X-XSS-Protection "1; mode=block" always;

    location / {
        proxy_pass http://127.0.0.1:8123;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

3. Obtain certificate:
```bash
sudo certbot --nginx -d your-domain.com
```

## 🌐 Network Security

### ZeroTier Recommendations
```bash
# Use specific network ID
sudo zerotier-cli join NETWORK_ID

# Check connected networks
sudo zerotier-cli listnetworks

# In ZeroTier Central:
# - Authorize only necessary devices
# - Use specific IP ranges
# - Activate flow rules to restrict access
```

### Port Security
```bash
# Scan open ports
sudo nmap -sT -O localhost

# Check listening ports
sudo ss -tulpn

# Disable unnecessary services
sudo systemctl disable bluetooth
sudo systemctl disable cups
```

## 👤 User Management

### Creating Administrative User
```bash
# Create user
sudo useradd -m -G wheel,systemd-journal hass-admin
sudo passwd hass-admin

# SSH key
sudo mkdir -p /home/hass-admin/.ssh
sudo cat > /home/hass-admin/.ssh/authorized_keys << 'EOF'
ssh-rsa AAAAB3NzaC1yc2EAAAADAQ... your-public-key
EOF
sudo chown -R hass-admin:hass-admin /home/hass-admin/.ssh
sudo chmod 700 /home/hass-admin/.ssh
sudo chmod 600 /home/hass-admin/.ssh/authorized_keys
```

### Sudo Configuration
File `/etc/sudoers.d/hass-admin`:
```bash
# Home Assistant admin user
hass-admin ALL=(ALL) NOPASSWD: /bin/systemctl restart home-assistant
hass-admin ALL=(ALL) NOPASSWD: /bin/systemctl status home-assistant
hass-admin ALL=(ALL) NOPASSWD: /bin/journalctl -u home-assistant
hass-admin ALL=(ALL) NOPASSWD: /opt/hass-scripts/backup-hass.sh
hass-admin ALL=(ALL) NOPASSWD: /opt/hass-scripts/health-check.sh
```

## 🏠 Home Assistant Security

### Configuration.yaml Recommendations
```yaml
# HTTP configuration
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 127.0.0.1
    - ::1
  ip_ban_enabled: true
  login_attempts_threshold: 5

# Logger for security events
logger:
  default: warning
  logs:
    homeassistant.components.http.auth: info
    homeassistant.components.auth: info

# Recorder - limit history for better performance
recorder:
  purge_keep_days: 30
  commit_interval: 1
  auto_purge: true
```

## 🔍 Monitoring and Audit

### Logging
```bash
# Centralized logging
sudo journalctl -f

# Specific services
sudo journalctl -u home-assistant -f
sudo journalctl -u fail2ban -f
sudo journalctl -u sshd -f

# Security events
sudo journalctl _COMM=sudo
sudo ausearch -m avc
```

### Health Check Script
Regular security check:
```bash
# Daily execution
echo "0 6 * * * /opt/hass-scripts/health-check.sh --verbose | mail -s 'Daily Health Check' admin@yourdomain.com" | sudo crontab
```

## 🔄 Backup Security

### Backup Encryption
```bash
# GPG encryption
gpg --symmetric --cipher-algo AES256 backup-file.tar.gz

# Decryption
gpg --decrypt backup-file.tar.gz.gpg > backup-file.tar.gz
```

### Remote Backups
```bash
# rsync over SSH
rsync -avz -e ssh /var/home-assistant/backups/ user@backup-server:/backups/hass/

# with encryption
tar -czf - /var/home-assistant/config | gpg --symmetric --cipher-algo AES256 | ssh user@backup-server 'cat > /backups/hass/config-$(date +%Y%m%d).tar.gz.gpg'
```

## 🚨 Incident Response

### In Case of Breach
1. **Immediate Steps:**
   ```bash
   # Disconnect from network
   sudo ip link set eth0 down
   
   # Check active connections
   sudo ss -tulpn
   sudo lsof -i
   
   # Check processes
   sudo ps aux
   ```

2. **Analysis:**
   ```bash
   # Audit logs
   sudo ausearch -ts recent
   sudo journalctl --since "1 hour ago"
   
   # File changes
   sudo find /var/home-assistant -mtime -1 -type f
   ```

3. **Recovery:**
   ```bash
   # Rollback to previous bootc version
   sudo bootc rollback
   sudo reboot
   
   # Or restore from backup
   sudo /opt/hass-scripts/restore-hass.sh /var/home-assistant/backups/hass-backup-YYYYMMDD
   ```

## 📋 Security Checklist

- [ ] SSH configured with keys only
- [ ] Root login disabled
- [ ] Firewall configured
- [ ] Fail2ban active
- [ ] SSL/TLS certificates set up
- [ ] Automatic updates enabled
- [ ] Backups encrypted
- [ ] Monitoring configured
- [ ] ZeroTier securely configured
- [ ] Unnecessary services disabled
- [ ] Strong passwords used
- [ ] 2FA activated in Home Assistant

## 🔗 Additional Resources

- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [Home Assistant Security Documentation](https://www.home-assistant.io/docs/configuration/securing/)
- [SSH Hardening Guide](https://linux-audit.com/audit-and-harden-your-ssh-configuration/)
- [Fail2ban Documentation](https://www.fail2ban.org/wiki/index.php/MANUAL_0_8)