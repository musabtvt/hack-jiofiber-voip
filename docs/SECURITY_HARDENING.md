# 🛡️ Security Hardening Guide: Cloud PBX

Securing an internet-facing Asterisk PBX against SIP scanners (Friendly-Scanner, sipvicious) and unauthorized toll fraud.

---

## 1. Fail2ban Integration

Automate IP banning for repeated authentication failures:

```ini
# /etc/fail2ban/jail.d/asterisk.conf
[asterisk]
enabled  = true
filter   = asterisk
action   = iptables-allports[name=ASTERISK, protocol=all]
logpath  = /var/log/asterisk/messages
maxretry = 4
bantime  = 86400
findtime = 600
```

Restart fail2ban:
```bash
sudo systemctl restart fail2ban
```

---

## 2. SIP Port Scrambling (Optional)

By default, automated botnets scan port `5060`. You can change the external SIP port to an unassigned port (e.g., `55060`):

In `asterisk/pjsip.conf`:
```ini
[transport-udp]
bind=0.0.0.0:55060
```
Update your softphone to connect to `<VPS_IP>:55060`.

---

## 3. Strict Outbound Context Boundaries

Our provided `extensions.conf` strictly sandboxes calls:
- Only registered endpoints (`1001`, `1002`) in context `[from-phones]` can dial outbound numbers.
- Incoming calls from the Internet or anonymous endpoints are rejected by default.
- International premium-rate numbers outside India (+91) are disabled by default to prevent toll fraud.

---

## 4. Full WireGuard VPN Isolation (Maximum Security)

If you prefer never to expose SIP ports to the public Internet:
1. Bind Asterisk strictly to the WireGuard interface IP: `10.10.10.1:5060`.
2. Connect your mobile phone to the VPS via the WireGuard mobile app.
3. Softphones communicate exclusively over the encrypted WireGuard VPN.
