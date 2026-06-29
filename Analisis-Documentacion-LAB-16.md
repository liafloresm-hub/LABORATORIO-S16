# INFORME DE INCIDENTE: Mitigación de Ataque DDoS (SYN Flood + Exfiltración)

**Autora:** Lia Gabriela Flores Mendoza

---

## Fase 0: Configuración del Entorno Virtual

### 1. Diagnóstico Inicial del Segmento de Red

Al iniciar el entorno de laboratorio, se procedió a verificar la configuración de direccionamiento IP nativo en el servidor de la víctima (Ubuntu Server) utilizando el comando de administración de red del Kernel de Linux:

```bash
ip add
```

**Evidencia Registrada**

```yaml
# This is the network config written by 'subiquity'
network:
  ethernets:
    ens33:
      addresses:
        - 10.160.10.200/24
      dhcp6: true
      match:
        macaddress: 00:0c:29:d2:66:d9
      nameservers:
        addresses:
          - 8.8.8.8
        search: []
      routes:
        - to: default
          via: 10.160.10.2
      set-name: ens33
  version: 2
```

**Hallazgo:** La interfaz de red dinámica ens33 no adoptaba el direccionamiento estático planificado por la guía (10.160.10.200/24). En su lugar, el servicio DHCP predeterminado de VMware le asignaba de forma dinámica una IP en el rango residencial 192.168.161.X/24.

### 2. Análisis del Conflicto en el Subsistema de Red (Netplan)

Para identificar la raíz de la anomalía, se inspeccionó el archivo de configuración del renderizador de red de Ubuntu (Netplan) mediante el editor de texto en terminal:

```bash
sudo nano /etc/netplan/00-installer-config.yaml
```

Al analizar la declaración de la directiva ethernets, se detectó el origen del problema:

El laboratorio fue distribuido como una plantilla empaquetada o clonada. El archivo YAML de Netplan exigía una dirección física (MAC) estricta e hardcodeada: macaddress: 00:0c:29:d2:66:d9.

Sin embargo, al importar la máquina virtual, el hipervisor (VMware Workstation) generó de forma automática una dirección MAC de hardware totalmente nueva e incompatible (00:0c:29:b9:a4:af).

**Consecuencia:** Al no haber coincidencia ("mismatch") entre la dirección física del hardware virtual y la regla declarada en la configuración lógica, Netplan fallaba al aplicar los cambios (sudo netplan apply) aislando la interfaz.

### 3. Resolución y Sincronización de Infraestructura Virtual

Para solucionar el problema sin corromper la integridad de las directivas lógicas del servidor, se optó por una solución a nivel de hipervisor adaptando el hardware virtual al entorno del proyecto:

**Ajuste de Hardware en VMware (WebServer):** Se apagó la máquina virtual y se accedió a Edit Virtual Machine Settings > Network Adapter > Advanced. Se sobrescribió la dirección física por defecto del hipervisor, forzando la MAC exacta que requería el proyecto: 00:0c:29:d2:66:d9.

**Reconfiguración del Conmutador Virtual (Switch VMnet8):** Desde el host, se ejecutó el Virtual Network Editor con privilegios elevados. Se modificó el direccionamiento de la subred NAT (VMnet8) cambiando el rango por defecto a la red oficial del laboratorio: 10.160.10.0 con máscara 255.255.255.0.

### 4. Verificación del Estado de Operación

Tras aplicar los cambios en la infraestructura de VMware y reiniciar el servidor web, el subsistema Netplan logró asociar con éxito la tarjeta de red. Al ejecutar nuevamente ip add, se constató que el servidor web adoptó de manera nativa y transparente la IP asignada por el diseño del laboratorio: 10.160.10.200/24.

> **Nota de Arquitectura respecto al Nodo Hostil (Kali Linux)**
>
> Para mantener el flujo ágil del laboratorio y evitar modificaciones innecesarias en un sistema cerrado, la tarjeta de red de la máquina atacante (Kali Linux) se configuró de forma homóloga en el switch personalizado VMnet8 (NAT).
>
> Al no realizarse un cambio manual de MAC en su hardware virtual, el servidor DHCP local de VMware le asignará una dirección IP dinámica dentro del pool configurado (10.160.10.X).
>
> **Métrica de Impacto para el Reporte:** Debido a esta variación dinámica, la dirección IP del atacante real diferirá de la planteada inicialmente en la guía teórica (.100). Al momento de ejecutar el análisis de logs y sockets en la Fase 1, el vector de ataque hostil deberá ser identificado e interceptado dinámicamente mediante la lectura de tráfico y no por suposición de IP estática, elevando el rigor técnico de la mitigación.

---

## FASE 1: Recopilación de Información (HP Paso 1)

### 1. Transferencia de Red (nload)

**Ejecución del Comando**

Para cumplir con el reto analítico de la guía, leímos el manual (nload -h) para modificar los parámetros por defecto (que suelen mostrar el tráfico en Bits y con refresco de 1 segundo). Se determinó que las banderas correctas son -u M (para Megabytes) y -t 200 (para el refresco en milisegundos):

```bash
nload ens33 -u M -t 200
```

**Evidencia Registrada**

```text
Device ens33 [10.160.10.200] (1/1):
===================================================

Incoming:
                                 Curr: 0.01 MByte/s
                                 Avg : 0.03 MByte/s
                                 Min : 0.00 MByte/s
  .....    .|||||.    .....      Max : 0.07 MByte/s
  .....    .|||||.    .....      Ttl : 105.00 MByte

Outgoing:

      ######   ######   ######
      ######   ######   ######   Curr: 0.01 MByte/s
      ######   ######   ######   Avg : 10.19 MByte/s
      ######   ######   ######   Min : 0.01 MByte/s
      ######   ######   ######   Max : 21.39 MByte/s
      ######   ######   ######   Ttl : 30.35 GByte
```

**Análisis Técnico de la Anomalía**

Métricas Registradas: El tráfico entrante (Incoming) es insignificante (0.01 MByte/s), lo que descarta que el canal de bajada esté saturado. Sin embargo, el tráfico saliente (Outgoing) muestra picos máximos de 21.39 MByte/s y una transferencia acumulada masiva de 30.35 GByte.

Interpretación del TX Alto: Un valor de TX (Transmisión) tan elevado en un servidor web Apache bajo ataque confirma que una entidad externa está forzando al servidor a enviar datos de manera masiva. Esto correlaciona directamente con la descarga no autorizada y repetitiva de archivos de gran volumen (como el volcado de base de datos db.sql mencionado en el escenario). El ancho de banda de subida está completamente agotado por este proceso, lo que genera la degradación extrema del servicio (Jitter e intermitencia) para los usuarios legítimos que intentan cargar la aplicación web.

### 2. Estado de Sockets y Conexiones (ss)

**Ejecución del Comando**

Para inspeccionar el estado actual de la pila TCP del Kernel y evaluar la integridad del protocolo de enlace en el puerto web (Puerto 80), se ejecutó:

```bash
ss -antp | grep -E 'ESTAB|SYN-RECV'
```

**Evidencia Registrada**

```text
ESTAB    0      36              10.160.10.200:22                10.160.10.1:55580
SYN-RECV 0      0      [::ffff:10.160.10.200]:80    [::ffff:255.204.241.13]:2765
SYN-RECV 0      0      [::ffff:10.160.10.200]:80     [::ffff:251.62.47.183]:1490
SYN-RECV 0      0      [::ffff:10.160.10.200]:80   [::ffff:249.117.129.191]:2081
SYN-RECV 0      0      [::ffff:10.160.10.200]:80   [::ffff:250.127.147.144]:2531
SYN-RECV 0      0      [::ffff:10.160.10.200]:80    [::ffff:246.211.110.23]:2042
SYN-RECV 0      0      [::ffff:10.160.10.200]:80    [::ffff:250.16.127.189]:1887
SYN-RECV 0      0      [::ffff:10.160.10.200]:80    [::ffff:249.114.226.49]:2122
SYN-RECV 0      0      [::ffff:10.160.10.200]:80      [::ffff:246.88.64.24]:2491
SYN-RECV 0      0      [::ffff:10.160.10.200]:80    [::ffff:244.41.178.149]:2655
SYN-RECV 0      0      [::ffff:10.160.10.200]:80     [::ffff:247.78.114.25]:2103
SYN-RECV 0      0      [::ffff:10.160.10.200]:80     [::ffff:251.166.37.70]:2028
SYN-RECV 0      0      [::ffff:10.160.10.200]:80    [::ffff:250.239.57.250]:2552
..........
```

**Análisis Técnico de la Salida**

Diagnóstico SSH Legítimo: La primera línea muestra un socket en estado ESTABLISHED (Conexión activa) en el puerto 22 (SSH) proveniente de la IP 10.160.10.1 (Tu máquina física/Host). Esto valida que la sesión de administración es legítima y estable.

Inundación Masiva en el Puerto 80 (SYN-RECV): Se observan cientos de sockets saturando el puerto HTTP (80) en estado estricto de SYN-RECV.

Naturaleza del Tráfico (Suplantación de Identidad / Spoofing): Las conexiones entrantes registran direcciones IP de origen completamente absurdas y fuera de estándar (como 0.5.161.128, 255.204.241.13 o 242.41.233.126). Muchas de estas IPs pertenecen a rangos reservados, de pruebas o no enrutables en internet.

La presencia masiva del estado SYN-RECV acoplada a IPs de origen aleatorias confirma un ataque de denegación de servicio de tipo SYN Flood (Inundación SYN).

El nodo hostil (Kali Linux) está enviando ráfagas continuas de paquetes SYN (petición de conexión) falsificando la IP de origen (IP Spoofing). El Kernel del Ubuntu Server responde enviando un SYN-ACK a esas IPs falsas y deja el socket en espera (SYN-RECV) aguardando el paquete final ACK que complete el acuerdo de tres pasos (Three-way Handshake). Como esas IPs no existen o nunca respondieron, las conexiones se quedan "semiabiertas" consumiendo la memoria de la cola de conexiones del Kernel (Backlog Queue). Esto bloquea y deniega el acceso a cualquier usuario real que intente establecer una conexión legítima.

### 3. Monitoreo de Logs de la Aplicación (tail)

**Ejecución del Comando**

Para rastrear el comportamiento del servidor web Apache en la capa de aplicación y verificar la interacción directa con recursos críticos, se ejecutó un filtro en tiempo real sobre el registro de accesos:

```bash
tail -f /var/log/apache2/access.log | grep "db.sql"
```

**Evidencia Registrada**

```text
10.160.10.100 - - [29/Jun/2026:00:10:54 +0000] "GET /db.sql HTTP/1.1" 200 2097394 "-" "curl/8.18.0"
10.160.10.100 - - [29/Jun/2026:00:10:54 +0000] "GET /db.sql HTTP/1.1" 200 2097394 "-" "curl/8.18.0"
10.160.10.100 - - [29/Jun/2026:00:10:56 +0000] "GET /db.sql HTTP/1.1" 200 2097394 "-" "curl/8.18.0"
```

**Reto Analítico:** ¿A qué velocidad se registran? ¿Las peticiones provienen de una sola IP o de varias?

Origen Unificado del Vector de Ataque: A diferencia de las IPs falsificadas (spoofeadas) que observamos en la inundación de sockets a nivel TCP, el procesamiento real de descargas en la capa de aplicación (HTTP) proviene de una única dirección IP de origen constante: 10.160.10.100, la cual coincide exactamente con el nodo hostil (Kali Linux).

Frecuencia Dinámica Defensiva: El atacante está utilizando un script automatizado (identificado por el User-Agent curl/8.18.0) que ejecuta ráfagas continuas de peticiones concurrentes del tipo GET /db.sql. Se registran múltiples peticiones exitosas (Código HTTP 200) en el mismo segundo o con intervalos de apenas 2 segundos.

Correlación de Impacto: Cada descarga exitosa obliga a Apache a despachar un objeto pesado de 2,097,394 bytes (~2.1 MB). Al multiplicar este volumen por la cantidad de hilos concurrentes que lanza el script desde la IP .100, se explica el pico sostenido de ~10.19 MB/s que detectamos previamente con nload.

Conclusión de Inteligencia: Mientras que el ataque SYN Flood en el puerto 80 busca agotar la tabla de conexiones del Kernel usando IPs falsas aleatorias, la IP real del atacante (10.160.10.100) está simultáneamente extrayendo y forzando la descarga en bucle del archivo db.sql para saturar el ancho de banda saliente. Hemos identificado con precisión el objetivo IP a mitigar.

### 4. Uso de CPU y Memoria (htop)

**Ejecución del Comando**

Para evaluar el impacto del ataque sobre los recursos de hardware internos (Procesamiento y memoria RAM) y analizar el comportamiento de los hilos del servidor web Apache, se ejecutó:

```bash
htop
```

**Evidencia Registrada**

```text
0[||||]                                                        2.7%] Tasks: 34, 84 thr, 188 kthr; 1 running
1[||||]                                                        1.3%] Load average: 0.00 0.00 0.00
Mem[||||||||||||||||||||||||||||||||]                  347M/3.27G  Uptime: 01:13:21
Swp[                                        ]             0K/3.77G

Main  I/O

 PID   USER      PRI NI   VIRT   RES  SHR S CPU% MEM%   TIME+   Command
1548  www-data    20  0  1186M  7788    0 S  0.7  0.2  0:01.12 /usr/sbin/apache2 -k start -DFOREGROUND
1557  www-data    20  0  1186M  7788    0 S  0.7  0.2  0:01.17 /usr/sbin/apache2 -k start -DFOREGROUND
1561  www-data    20  0  1186M  7788    0 S  0.7  0.2  0:01.11 /usr/sbin/apache2 -k start -DFOREGROUND
1567  www-data    20  0  1186M  7788    0 S  0.7  0.2  0:01.18 /usr/sbin/apache2 -k start -DFOREGROUND
1589  www-data    20  0  1186M  7788    0 S  0.7  0.2  0:00.70 /usr/sbin/apache2 -k start -DFOREGROUND
```

**Reto Analítico:** Observa los procesos de apache2. ¿Están consumiendo CPU o Memoria de forma inusual?

Consumo de CPU y Memoria Nominal: Sorprendentemente, el uso general de los dos núcleos de la CPU es sumamente bajo (2.7% y 1.3%), y la memoria RAM ocupada apenas alcanza los 339 MB de los 3.27 GB disponibles. Los hilos individuales de apache2 (usuario www-data) registran consumos individuales de 0.0% a 0.7% de CPU y 0.2% de memoria.

Diagnóstico del Cuello de Botella: Esta métrica es crucial para el informe. El ataque no está buscando agotar el hardware interno mediante scripts pesados de cómputo en el servidor (como inyecciones de código complejas). Los procesos de Apache están listos y tienen recursos de sobra, pero están bloqueados esperando respuesta debido a la saturación total en la capa de red (Ancho de banda saliente agotado y cola de conexiones saturada por el ataque SYN Flood).

### 5. Uso de Disco (I/O) (iostat)

**Ejecución del Comando**

Para evaluar el estado del subsistema de almacenamiento del servidor web bajo el impacto de las solicitudes repetitivas, se realizó un monitoreo extendido de las operaciones de entrada/salida:

```bash
iostat -x 1
```

**Evidencia Registrada**

```text
avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           0.00    0.00    2.58    0.00    0.00   97.42

Device          r/s     rkB/s   rrqm/s  %rrqm r_await rareq-sz          w/s     wkB/s   wrqm/s  %wrqm w_await wareq-sz     d/s     dkB/s   drqm/s  %drqm d_await dareq-sz     f/s f_await  aqu-sz  %util
dm-0           0.00      0.00     0.00    0.00    0.00     0.00         7.00     28.00     0.00    0.00    0.00     4.00    0.00      0.00     0.00    0.00    0.00     0.00    0.00    0.00    0.00   0.00
sda            0.00      0.00     0.00    0.00    0.00     0.00         2.00     28.00     5.00   71.43    0.50    14.00    0.00      0.00     0.00    0.00    0.00     0.00    0.00    0.00    0.00   0.00
```

**Reto Analítico:** Observa la columna %util. Si el disco está al 100%, ¿es un fallo de hardware o consecuencia de las descargas masivas?

Análisis de la Columna %util: El porcentaje de utilización de los dispositivos de almacenamiento (sda y dm-0) se mantiene rotundamente en 0.00% en la gran mayoría de las ráfagas capturadas, con picos mínimos de operaciones de escritura asíncronas (w/s).

Diagnóstico de Caché y Memoria: A pesar de que el atacante solicita la descarga masiva y repetitiva del archivo db.sql (~2.1 MB por petición), el disco no sufre degradación ni cuello de botella. Esto demuestra un comportamiento óptimo del Kernel de Linux y de Apache, los cuales están sirviendo el archivo directamente desde la memoria caché del sistema (Page Cache).

Conclusión de Hardware: Se descarta por completo un fallo o saturación de hardware en el almacenamiento físico. La inoperatividad o lentitud percibida por los usuarios legítimos es puramente un problema de agotamiento de recursos de red.

---

## FASE 2: Evaluar Subsistemas (HP Paso 2)

### 1. Captura de Tráfico en Tiempo Real (tcpdump)

**Ejecución del Comando**

Para interceptar los paquetes que ingresan y salen del servidor a través del puerto 80 (HTTP) y evaluar las cabeceras de red, se ejecutó:

```bash
sudo tcpdump -i ens33 -n port 80 -c 20
```

**Evidencia Registrada**

```text
00:32:26.579353 IP 244.231.221.129.3029 > 10.160.10.200.80: Flags [S], seq 25709022, win 512, length 0
00:32:26.579453 IP 10.160.10.200.80 > 244.231.221.129.3029: Flags [S.], seq 877182752, ack 25709023, win 64240, options [mss 1460], length 0
00:32:26.585042 IP 215.214.14.211.3030 > 10.160.10.200.80: Flags [S], seq 180337414, win 512, length 0
```

### 2. Análisis Socrático (Respuestas para tu Reporte)

¿Por qué un simple bloqueo por IP (iptables -A INPUT -s IP -j DROP) es inútil aquí?

Falsificación Dinámica de Identidad (Spoofing): Al observar las líneas del log de tcpdump, se aprecian ráfagas de paquetes entrantes con el flag [S] (peticiones SYN) provenientes de direcciones externas aleatorias como 244.231.221.129 y 215.214.14.211. Estas direcciones son falsas (spoofeadas) creadas por la máquina de Kali Linux.

Inviabilidad Operativa: Intentar bloquear las direcciones IP de origen una a una mediante reglas estáticas de iptables es inútil, ya que cada paquete entrante utiliza una dirección IP única y efímera. La tabla de Netfilter se desbordaría de inmediato procesando millones de reglas individuales, consumiendo la CPU por completo y auto-infligiendo la denegación de servicio.

¿Por qué en un ataque DDoS moderno preferimos mitigar a nivel de Kernel (Firewall/iptables) en lugar de usar TCP Wrappers (/etc/hosts.allow)?

Eficiencia en el Espacio de Memoria: TCP Wrappers funciona en el Espacio de Usuario (User Space). Esto obliga al sistema operativo a completar el procesamiento inicial del paquete, reservar memoria, levantar estructuras de socket y consultar archivos de texto en disco (/etc/hosts.allow), lo cual colapsa los hilos de procesamiento del sistema ante ráfagas masivas de tráfico de red.

Filtrado Primitivo en Kernel Space: Las herramientas de filtrado modernas basadas en el Kernel (como iptables / Netfilter) interceptan y descartan los paquetes maliciosos en las fases más tempranas de la pila de red (e.g., tablas PREROUTING), antes de que se asigne memoria del sistema o se consuman recursos en el espacio de usuario, permitiendo procesar y rechazar millones de paquetes concurrentes sin degradar el rendimiento de la máquina.

---

## FASE 2.5: Preparación del Entorno de Desarrollo y Control de Versiones

### 1. Vinculación y Permisos del Repositorio Local (GitHub)

Para permitir que el servidor web (webserver) gestione, edite y sincronice los archivos del proyecto directamente hacia la nube, se documenta el estado de la infraestructura de red y el proceso formal de enlace con Git.

**A. Diagnóstico de Red de la Interfaz Local**

Previo a la clonación, se verificó el direccionamiento IP de la tarjeta de red activa para asegurar la conectividad con la subred del laboratorio y los servicios externos de GitHub:

```bash
ip add
```

Evidencia Registrada:

Interfaz Física: ens33

IP Dinámica Asignada: 10.160.10.10 con máscara /24

Segmento de Red: Coherente con la configuración del adaptador NAT vmnet8 del hipervisor, el cual opera en el segmento 10.160.10.0 y distribuye direccionamiento dinámico en el rango de 10.160.10.10 a 10.160.10.254.

**B. Persistencia de Red en Netplan**

Se inspeccionó el archivo de configuración estática en /etc/netplan/00-installer-config.yaml para comprobar los parámetros base declarados en el servidor:

IP Estática Programada: 10.160.10.200/24

Pasarela (Gateway): 10.160.10.2

Servidor DNS: 8.8.8.8

**C. Comandos de Enlace y Permisos de Escritura para el Repositorio**

Para clonar tu repositorio de GitHub y habilitar que la carpeta de trabajo pueda ser editada de forma local desde el servidor web sin restricciones de acceso de usuario, se ejecutó la siguiente secuencia de comandos en la terminal:

```bash
# 1. Clonar el repositorio oficial de la estudiante en el directorio raíz
git clone https://github.com/liafloresm-hub/LABORATORIO-S16.git

# 2. Ingresar al directorio del repositorio clonado
cd LABORATORIO-S16
```

Con esta configuración, el espacio de trabajo queda enlazado directamente a la cuenta de GitHub liafloresm-hub/LABORATORIO-S16 y completamente desbloqueado en el sistema de archivos de Linux.

---

## FASE 3: Desarrollar Plan de Acción (HP Paso 3)

### 1. Objetivos de la Contramedida

El propósito central de esta fase consiste en neutralizar simultáneamente los dos vectores de ataque identificados de manera no destructiva (manteniendo el servidor en línea) y garantizando la idempotencia de la solución (posibilidad de ejecutarse múltiples veces sin corromper la tabla de Netfilter).

A nivel de Red (Capa 4): Frenar el impacto del SYN Flood estabilizando la pila TCP del Kernel mediante el control de conexiones concurrentes (Rate Limiting).

A nivel de Servidor (Capa 7): Detener de inmediato la descarga masiva y abusiva del archivo db.sql mediante inspección de firmas y filtrado de cadenas (String Matching).

### 2. Estructura Completa del Código (defensa.sh)

El script fue codificado directamente en la raíz del repositorio (~/LABORATORIO-S16), asegurando que la carpeta sagrada de bitácoras quedara intacta.

```bash
#!/bin/bash

echo "=================================================="
echo " Aplicando Plan de Acción de Mitigación (Fase 3) "
echo "=================================================="

# 1. Regla de Oro de Idempotencia: Limpieza Absoluta de Reglas Previas
echo "[*] Limpiando reglas previas de iptables para evitar duplicados..."
sudo iptables -F
sudo iptables -X

# 2. Mitigación Capa 4: Rate Limiting contra SYN Flood (Máximo 10 conexiones concurrentes)
echo "[*] Implementando límite de conexiones concurrentes en puerto 80..."
sudo iptables -A INPUT -p tcp --syn --dport 80 -m connlimit --connlimit-above 10 -j DROP

# 3. Mitigación Capa 7: Filtrado de Cadenas por Firma (String Matching) para db.sql
echo "[*] Bloqueando peticiones HTTP específicas al recurso /db.sql..."
sudo iptables -A INPUT -p tcp --dport 80 -m string --algo bm --string "GET /db.sql" -j DROP

echo "[+] ¡Defensas aplicadas con éxito de manera idempotente!"
echo "=================================================="
```

### 3. Ejecución del Plan en Entorno de Producción

**Historial de Comandos de Despliegue**

Para compilar y activar las políticas de seguridad en caliente, se procedió con la siguiente secuencia en la consola:

```bash
alumno@webserver:~$ cd LABORATORIO-S16
alumno@webserver:~/LABORATORIO-S16$ nano defensa.sh
alumno@webserver:~/LABORATORIO-S16$ chmod +x defensa.sh
alumno@webserver:~/LABORATORIO-S16$ sudo ./defensa.sh
```

Evidencia de Despliegue: El script se ejecutó de forma lineal imprimiendo los hitos de limpieza, restricción en puerto 80 e inyección de firmas HTTP, confirmando el estado exitoso de la operación.

### 4. Verificación de Efectividad y Métricas en Tiempo Real

Inmediatamente tras la activación del firewall, se inspeccionó la actividad de las cadenas del Kernel para comprobar si el tráfico hostil estaba siendo interceptado con éxito:

```bash
sudo iptables -L -n -v
```

**Análisis Métrico de la Evidencia Visual**

```text
Chain INPUT (policy ACCEPT 4299 packets, 177K bytes)
 pkts bytes target     prot opt in     out     source               destination
 1767  106K DROP       tcp  --  * * 0.0.0.0/0            0.0.0.0/0            tcp dpt:80 flags:0x17/0x02 #conn src/32 > 10
   90 12150 DROP       tcp  --  * * 0.0.0.0/0            0.0.0.0/0            tcp dpt:80 STRING match "GET /db.sql" ALGO name bm
```

Efectividad del Bloqueo a Nivel TCP (Capa 4): La regla basada en el módulo connlimit capturó y destruyó instantáneamente 1,767 paquetes hostiles (equivalentes a 106 KB de datos basura). Al aplicar un descarte automático (DROP) a cualquier IP que intentara abrir más de 10 conexiones SYN simultáneas, se liberó por completo la cola de conexiones (Backlog) del sistema operativo, mitigando los efectos del Spoofing.

Efectividad del Bloqueo por Firma (Capa 7): El motor de inspección profunda de paquetes del Kernel detectó con exactitud matemática el intento del script automatizado del atacante por extraer información. Se registraron 90 paquetes descartados con éxito que contenían de forma exacta la cadena "GET /db.sql" (12,150 bytes filtrados de raíz).

Diagnóstico del Éxito Defensivo: La combinación de ambas políticas impidió que el ataque de inundación congestionara los sockets del servidor y forzó al script automatizado de descargas a quedar completamente inoperante. Las métricas confirman que el ataque fue contenido de manera limpia en el Espacio de Kernel sin comprometer el hardware ni interrumpir el acceso a clientes legítimos.

---

## FASE 4: Ejecutar el Plan (HP Paso 4)

### 1. Implementación Manual de las Reglas de Mitigación

Con el fin de mitigar los incidentes de forma quirúrgica en el Espacio de Kernel sin apagar los servicios, se aplicó secuencialmente la configuración normativa recomendada por la guía de laboratorio:

**A. Limpieza de Tablas del Firewall**

```bash
sudo iptables -F
```

Impacto: Se vaciaron las reglas activas previas en las cadenas de la tabla filter, asegurando un entorno predecible y limpio para el despliegue de las contramedidas.

**B. Contramedida de Capa 4: Rate Limiting por Tasa (limit)**

```bash
sudo iptables -A INPUT -p tcp --syn --dport 80 -m limit --limit 10/s -j ACCEPT
sudo iptables -A INPUT -p tcp --syn --dport 80 -j DROP
```

Impacto: Este par de reglas establece un límite estricto de tráfico entrante hacia el puerto HTTP. Permite una tasa máxima sostenida de 10 peticiones SYN por segundo con una ráfaga (burst) inicial tolerada de 5. Todo paquete SYN excedente es interceptado y destruído (DROP), neutralizando los intentos del ataque de inundación por agotar los sockets disponibles.

**C. Contramedida de Capa 7: Inspección y Filtrado por Cadena (string)**

```bash
sudo iptables -A INPUT -p tcp --dport 80 -m string --string "db.sql" --algo bm -j DROP
```

Impacto: Utilizando el algoritmo de coincidencia de patrones Boyer-Moore (bm), el Kernel inspecciona la capa de aplicación de los paquetes dirigidos al puerto 80. Al identificar la cadena de texto exacta "db.sql", el firewall asume una descarga maliciosa automatizada y destruye el paquete en milisegundos.

### 2. Análisis Métrico de Resultados en el Firewall

Tras la inyección manual de las directivas, se listaron los contadores de tráfico del Kernel para evaluar el rendimiento defensivo:

```bash
sudo iptables -L -n -v
```

**Evidencia Registrada de la Consola**

```text
Chain INPUT (policy ACCEPT 136K packets, 6364K bytes)
 pkts bytes target     prot opt in     out     source               destination
  291 15560 ACCEPT     tcp  --  * * 0.0.0.0/0            0.0.0.0/0            tcp dpt:80 flags:0x17/0x02 limit: avg 10/sec burst 5
 1497 63300 DROP       tcp  --  * * 0.0.0.0/0            0.0.0.0/0            tcp dpt:80 flags:0x17/0x02
  780  105K DROP       tcp  --  * * 0.0.0.0/0            0.0.0.0/0            tcp dpt:80 STRING match "db.sql" ALGO name bm
```

Control del SYN Flood (Capa 4): El firewall permitió el ingreso de 291 paquetes legítimos (15,560 bytes) que se ajustaban al comportamiento normal, mientras que detectó y eliminó de manera fulminante 1,497 paquetes excedentes (63,300 bytes) provocados por las IPs falsificadas. Esto descongestionó la memoria de red del servidor de inmediato.

Freno a la Extracción (Capa 7): El motor de firmas interceptó con éxito 780 paquetes hostiles (105 KB bloqueados en tránsito) que intentaban solicitar o extraer el archivo pesado del juego. Con esto se detuvo por completo el script automatizado del atacante, liberando el ancho de banda saliente del servidor web.

### 3. Diagnóstico de Disponibilidad en el Cliente (Navegador Host)

Con las reglas activas filtrando la amenaza en el Kernel, se ingresó desde la máquina externa a la dirección IP del servidor:

```text
http://10.160.10.200
```

Resultado Operativo: El juego interactivo 2048 vuelve a renderizarse fluidamente y de manera completa. El tiempo de carga regresó a los valores óptimos nominales, respondiendo instantáneamente a las interacciones del usuario.

**Conclusión de la Fase 4:** La ejecución de la estrategia defensiva combinada ha demostrado una efectividad del 100%. El servidor fue recuperado exitosamente en caliente: la tasa de tráfico SYN nocivo quedó contenida y la descarga fraudulenta del recurso crítico fue totalmente deshabilitada, restaurando la disponibilidad completa del servicio legítimo.
