#!/bin/bash
# ==========================================
# Script de Restauración (Regreso al inicio)
# ==========================================

echo "[*] Limpiando el cortafuegos y eliminando defensas..."
sudo iptables -F
sudo iptables -X
sudo iptables -Z

echo "[+] El servidor ha vuelto a su estado original (Vulnerable)."
sudo iptables -L -n -v
