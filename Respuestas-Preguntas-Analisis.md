Pregunta 1

El atacante usó IP Spoofing enviando paquetes SYN. El handshake TCP nunca se completa. ¿Por qué esto consume recursos si la conexión no se establece?

"Porque el sistema operativo debe reservar memoria. Cuando el servidor recibe un paquete SYN, asume que es una petición legítima, responde con un SYN-ACK y crea una estructura de datos en la memoria del Kernel llamada Transmission Control Block. Al ser miles de IPs falsas que nunca responden el ACK final, esta cola de conexiones a medio abrir se llena, agotando la memoria RAM y bloqueando nuevas conexiones."

Pregunta 2

¿Qué pasaría con los jugadores del juego 2048 si olvidaran poner la regla ESTABLISHED,RELATED y solo dejaran el Rate Limiting estricto?

"El cortafuegos tendría que inspeccionar cada paquete individual de las partidas en curso contra todas las reglas, lo que generaría muchísima latencia. Las reglas de estado (ESTABLISHED, RELATED) son un atajo: le dicen al firewall 'si este paquete pertenece a un jugador que ya pasó los filtros de seguridad, déjalo pasar rápido sin volver a procesarlo'."

Pregunta 3

Bloqueamos la cadena db.sql. ¿Qué sucedería si el servidor usara HTTPS (puerto 443)? ¿Funcionaría esta regla?

"No funcionaría en absoluto. HTTPS cifra todo el contenido del paquete en tránsito mediante TLS. El módulo string de iptables solo puede leer texto plano. Para bloquear ataques en HTTPS necesitaríamos descifrar el tráfico primero usando un Proxy Inverso o un Web Application Firewall (WAF) de Capa 7."

Pregunta 4

En su código usan iptables -A. ¿Qué pasaría si configuran un cron job para que ejecute el script cada 5 minutos por un mes y olvidan poner iptables -F?

"Sería catastrófico para el rendimiento. El parámetro -A añade la regla al final de la lista. Sin usar -F para limpiar primero, estaríamos duplicando las mismas reglas cada 5 minutos. En un mes tendríamos más de 8,000 reglas idénticas. El Kernel tendría que evaluar cada paquete contra miles de reglas, provocando que nosotros mismos causemos una Denegación de Servicio por consumo de CPU."

Pregunta 5

Si el disco llega al 100% de uso durante el ataque, ¿cómo afecta a los logs de Apache y al diagnóstico?

"Nos dejaría ciegos. Si el disco no puede procesar más operaciones de entrada y salida (I/O), Apache no podrá escribir los registros en access.log. Los procesos de red se quedarían congelados esperando al disco. Perderíamos la visibilidad del ataque porque no habría rastro de las IPs ni de lo que están solicitando."

Pregunta 6

¿Por qué un ataque SYN Flood no puede ser detenido por TCP Wrappers (hosts.deny)?

"Porque operan en capas distintas. TCP Wrappers trabaja a nivel de aplicación, es decir, solo evalúa la conexión después de que el Handshake TCP de 3 vías se ha completado. Como un SYN Flood nunca termina el Handshake, jamás llega a la capa de aplicación, saltándose por completo a los TCP Wrappers."

Pregunta 7

¿Qué pasaría si el atacante falsifica la dirección IP de nuestra propia puerta de enlace (Gateway)?

"Es un vector muy peligroso. Si el atacante falsifica la IP de nuestro router y nuestro script aplica un bloqueo estricto, terminaríamos bloqueando a nuestra propia puerta de enlace. Aislaríamos el servidor de internet nosotros mismos. Por eso es vital no bloquear ciegamente IPs sin entender la topología."

Pregunta 8

¿Cómo maneja una solución como Cloudflare el problema de bloquear a toda una universidad que sale bajo una sola IP pública (NAT)?

"En lugar de hacer bloqueos absolutos (DROP) a nivel de IP, los WAF modernos utilizan validación de cliente. Despliegan desafíos JavaScript invisibles o CAPTCHAs en el navegador. De esta forma, bloquean los scripts automatizados (bots) pero permiten que los estudiantes humanos pasen, aunque todos compartan la misma IP pública."

Pregunta 9

Si el atacante envía 100,000 peticiones por segundo al index.html (1KB), ¿su script actual seguiría siendo efectivo?

"No del todo. Nuestro filtro de texto busca la palabra db.sql, así que ignoraría el index.html. Además, si el atacante usa conexiones HTTP persistentes (Keep-Alive), enviaría miles de peticiones sobre una sola conexión ya establecida, burlando nuestra regla de límite SYN. Requeriríamos reglas de límite de peticiones HTTP en Apache (como mod_evasive) o en un proxy."

Pregunta 10

Para automatizar este diagnóstico antes de que el servidor caiga, ¿qué herramienta implementarían y qué métrica monitorearían?

"Implementaríamos una pila de observabilidad moderna como Prometheus con Node Exporter, visualizado en Grafana. La métrica exacta a vigilar de cerca sería el recuento de sockets TCP en estado SYN_RECV y el porcentaje de latencia de disco (iowait). Configuraríamos Alertmanager para que, si los SYN-RECV superan las 100 conexiones por más de un minuto, dispare una alerta inmediata a un bot de Slack o Telegram."
