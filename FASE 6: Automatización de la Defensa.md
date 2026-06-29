## FASE 6: Automatización de la Defensa (Medidas Preventivas)

**Elaborado por:** Lia Gabriela Flores Mendoza

Como parte final de mi metodología de respuesta a incidentes, y para asegurar que el servidor no dependa de mi intervención manual ante futuros ataques, procedí a implementar un script centinela. Este script evaluará el tráfico y activará mis defensas únicamente cuando detecte un umbral de peligro real.

A continuación, documento los pasos exactos que seguí en mi servidor para crear, programar y respaldar esta automatización en mi repositorio oficial.

### 1. Creación del Script Centinela (`monitor_trafico.sh`)

Dentro de la raíz de mi repositorio local (`~/LABORATORIO-S16`), creé un nuevo archivo ejecutable que se encargará de monitorear la cola de conexiones TCP de mi servidor.

**Código de mi script:**

```bash
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
```

### 2. Asignación de Permisos y Configuración de Cron

Para que mi sistema operativo ejecute este script de manera silenciosa y desatendida, tuve que darle permisos de ejecución y agregarlo al planificador de tareas (Cron) del usuario administrador (root), ya que el script manipulará las tablas de iptables.

Ejecuté la siguiente secuencia en mi terminal:

**A. Asignación de permisos de ejecución:**

```bash
chmod +x monitor_trafico.sh
```

**B. Integración al planificador del sistema:**

Ingresé al editor de cron con privilegios elevados:

```bash
sudo crontab -e
```

Al final del archivo, añadí la siguiente directiva para instruir al Kernel que ejecute mi script cada 1 minuto:

```bash
* * * * * /home/alumno/LABORATORIO-S16/monitor_trafico.sh
```

Guardé los cambios y el sistema confirmó la instalación con el mensaje `crontab: installing new crontab`.

### 3. Sincronización del Entregable con mi GitHub

Finalmente, para respaldar mi trabajo y enviar mi entregable completo, sincronicé este nuevo archivo hacia la nube (mi repositorio `liafloresm-hub`).

Utilicé el siguiente flujo de comandos de control de versiones:

```bash
# 1. Verifiqué estar en el directorio de mi repositorio
cd ~/LABORATORIO-S16

# 2. Añadí mi nuevo script al área de preparación (Staging Area)
git add monitor_trafico.sh

# 3. Confirmé los cambios con un mensaje claro y descriptivo
git commit -m "Fase 6: Añadido script centinela por Lia Flores para automatización de defensas"

# 4. Empujé el código hacia mi rama principal en GitHub
git push origin main
```

**Conclusión Final:** Con este último paso, mi servidor cuenta ahora con una barrera reactiva que monitorea la red minuto a minuto. El laboratorio de mitigación de ataques DDoS (Capa 4 y Capa 7) ha sido resuelto y documentado en su totalidad.
