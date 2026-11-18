# 🔒 SSH Layer 3 Tunnel (tun10): Bulletproof WireGuard Alternative

While WireGuard is fast and lightweight, mobile carrier CGNATs (including Jio 5G in certain regions) occasionally drop or throttle persistent UDP traffic.

If you observe that WireGuard (`wg0`) sends handshake packets but receives 0 bytes back, OpenSSH's native **Layer 3 TUN mode (`-w 10:10`)** provides an encrypted point-to-point IP tunnel over standard TCP (Port 22 / 2222) that bypasses UDP carrier blocks.

---

## 🛠️ Step 1: Enable Tunneling on your VPS (`sshd_config`)

On your cloud server (VPS):
```bash
sudo nano /etc/ssh/sshd_config
```
Ensure the following line is set:
```text
PermitTunnel yes
```
Restart SSH:
```bash
sudo systemctl restart ssh
```

---

## 🛠️ Step 2: Establish the L3 Tunnel from OpenWrt

From your OpenWrt router, establish the tunnel and assign IP addresses:

```bash
# 1. Establish background SSH tunnel on device tun10
ssh -f -N -w 10:10 -p 2222 -i /root/.ssh/id_ed25519 root@<YOUR_VPS_IP>

# 2. Configure IP addresses on both endpoints
# On OpenWrt router:
ip link set tun10 up
ip addr add 10.10.10.2/24 dev tun10

# On VPS:
ip link set tun10 up
ip addr add 10.10.10.1/24 dev tun10
```

---

## 🛠️ Step 3: Verify Bidirectional Routing

Test ping across the tunnel:
```bash
# From OpenWrt router:
ping -c 2 10.10.10.1

# From VPS:
ping -c 2 10.10.10.2
```

Asterisk connects to the router endpoint (`10.10.10.2:5068`) across `tun10` with zero UDP packet loss.
