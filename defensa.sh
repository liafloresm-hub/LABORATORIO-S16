# Script despues del analisis de (Fase 4)
#!/bin/bash
# ==========================================
# Script de Mitigación Híbrida (Capa 4 y 7)
# ==========================================

echo "[*] Vaciando reglas previas de iptables (Idempotencia)..."
sudo iptables -F

echo "[*] Aplicando Rate Limiting contra SYN Flood (Capa 4)..."
sudo iptables -A INPUT -p tcp --syn --dport 80 -m limit --limit 10/s -j ACCEPT
sudo iptables -A INPUT -p tcp --syn --dport 80 -j DROP

echo "[*] Aplicando String Matching contra descarga maliciosa (Capa 7)..."
sudo iptables -A INPUT -p tcp --dport 80 -m string --string "db.sql" --algo bm -j DROP

echo "[+] Defensa activada. Tráfico hostil bloqueado."
sudo iptables -L -n -v
