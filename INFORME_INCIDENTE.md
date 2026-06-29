# INFORME TÉCNICO DE RESPUESTA A INCIDENTES (LABORATORIO S16)
**Autor:** Lia Flores
**Servidor Afectado:** Webserver (10.160.10.200)

## FASE 5: Problema Resuelto (Verificación)

Para validar científicamente el éxito de las contramedidas aplicadas en el cortafuegos, se procedió a monitorear nuevamente los subsistemas críticos del servidor en tiempo real.

### Verificación de Tráfico de Red (`nload`)
Se ejecutó el monitor de tráfico en la interfaz principal `ens33`. 
* **Resultado:** El tráfico de salida (*Outgoing*) cayó drásticamente de 21.39 MB/s a tan solo **20.27 kBit/s**. Esto demuestra que el bloqueo por firma (`"db.sql"`) cortó de raíz el flujo de descarga masiva provocado por el atacante, liberando el ancho de banda por completo.

### Verificación de Hardware (`iostat`)
Se evaluó la carga del sistema mediante `iostat -x 1`.
* **Resultado:** La CPU reporta un estado inactivo (`%idle`) superior al 98%, y el porcentaje de utilización de los discos (`%util`) se mantiene estable en **0.00%**. Esto certifica que las reglas del Kernel descartaron los paquetes maliciosos sin generar sobrecarga de hardware.

**Conclusión de la Fase 5:** El servicio web fue restaurado exitosamente. El servidor vuelve a responder a peticiones legítimas y el ataque DDoS (Capa 4) con robo de datos (Capa 7) ha sido neutralizado.

---

## FASE 6: Medidas Preventivas

**Análisis Socrático: ¿Cómo convertirías tu script de defensa en un servicio o tarea programada (cron) que se active solo si el tráfico supera un umbral de peligro?**

Para automatizar la defensa sin mantener el firewall restringido de forma permanente, implementaría la siguiente arquitectura de prevención:
1. **Script Centinela:** Crearía un script en Bash (`monitor.sh`) que evalúe periódicamente el estado de las conexiones. Utilizaría el comando `ss -ant | grep SYN-RECV | wc -l` para contar cuántas conexiones están atascadas en la cola de TCP.
2. **Lógica de Umbral:** Dentro del script, agregaría una condicional `if`. Si el número de conexiones supera un umbral de peligro (ej. > 100), el script mandaría a ejecutar automáticamente el archivo `./defensa.sh` y registraría una alerta en `/var/log/syslog`.
3. **Automatización con Cron:** Para que este proceso sea desatendido, registraría el centinela en el planificador del sistema con `crontab -e`, añadiendo la regla `* * * * * /ruta/al/monitor.sh`. De esta forma, el sistema operativo vigilará el tráfico cada 1 minuto de forma silenciosa y activará los escudos únicamente cuando detecte un comportamiento anómalo.
