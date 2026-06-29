#!/bin/bash
# ==========================================
# Script Centinela de Monitoreo de Tráfico TCP
# Autor: Lia Gabriela Flores Mendoza - Lab S16
# Objetivo: Prevenir DDoS automatizando la defensa
# ==========================================

# 1. Defino el umbral de peligro (conexiones SYN-RECV máximas toleradas)
UMBRAL=100

# 2. Defino la ruta absoluta de mi script de defensa
# (Es necesario usar la ruta completa para que el servicio cron lo encuentre)
RUTA_DEFENSA="/home/alumno/LABORATORIO-S16/defensa.sh"

# 3. Cuento las conexiones TCP atascadas en la cola de sincronización
# Utilizo 'ss' para leer los sockets y 'grep -c' para contar las coincidencias
CONEXIONES_SYN=$(ss -ant | grep -c "SYN-RECV")

# 4. Lógica condicional de activación por umbral
if [ "$CONEXIONES_SYN" -gt "$UMBRAL" ]; then
    # Registro una alerta de seguridad en el log del sistema (/var/log/syslog)
    logger -p auth.alert "ALERTA DDoS LAB-S16 (Lia Flores): Se superó el umbral con $CONEXIONES_SYN peticiones SYN-RECV. Activando mitigación automática..."

    # Ejecuto mi script de mitigación
    sudo bash "$RUTA_DEFENSA"
fi
