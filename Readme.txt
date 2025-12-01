🌡️ Proyecto de Trazabilidad IoT de Heladeras (Deep Sleep Architecture)
Este repositorio contiene el código completo y la documentación técnica de un sistema de monitoreo de temperatura y voltaje diseñado para entornos de refrigeración, optimizado para la eficiencia energética mediante el modo Deep Sleep del ESP32.
1. ⚙️ Arquitectura General y Tecnologías
El sistema utiliza una arquitectura de servicios desacoplados (API RESTful) para manejar la comunicación de datos y la configuración.
Componente
	Tecnología
	Rol Principal
	Microcontrolador
	ESP32 WROOM-32E
	Medición, filtrado de datos y Deep Sleep (300s).
	Backend
	Node.js (Express)
	API RESTful, gestión de umbrales y alertas.
	Base de Datos
	MongoDB
	Almacenamiento de mediciones (Measurement) y configuraciones (Sensor).
	Frontend
	Flutter (Dart)
	Visualización de datos en tiempo real, gráficos (fl_chart) y gestión de configuración.
	2. 🔌 Componentes de Hardware y Calibración
2.1. Eficiencia Energética y Deep Sleep
El firmware está diseñado para maximizar la vida útil de la batería:
* Ciclo de Trabajo: El ESP32 se despierta, mide, envía datos y vuelve a dormir por 300 segundos (5 minutos).
* Activación: Mediante el temporizador interno del ESP32 (esp_sleep_enable_timer_wakeup).
2.2. Monitoreo de Batería (Voltaje)
El sistema monitorea 4 pilas AA ($\sim 6\text{V}$) utilizando un divisor de voltaje para reducir la entrada al ADC del ESP32 (máx. $\sim 3.3\text{V}$).
Parámetro
	Valor Calibrado
	Componente
	Voltaje Reportado
	$\sim 6.0\text{V}$ (Máx.)
	[Firmware: *.ino]
	Factor Divisor
	$\mathbf{1.82}$
	[Firmware: *.ino]
	Pin de Medición
	GPIO 34 (ADC)
	$R_1=100\text{k}\Omega / R_2=47\text{k}\Omega$
	Nota: El factor $\mathbf{1.82}$ es un valor calibrado para corregir la lectura inicial de $10.32\text{V}$ a la tensión nominal correcta de $6.0\text{V}$.
2.3. Sensores de Temperatura
* Sensor: DS18B20 Sumergible (Múltiples unidades).
* Conexión: Bus One-Wire (GPIO 4 / ONE_WIRE_BUS).
3. 🤖 Lógica del Firmware (ESP32)
* Mapeo de Sensores: Se asigna una ID Lógica Fija (HELADERA-01, etc.) a cada dirección física del sensor DS18B20.
* Lectura de Voltaje: La función readBatteryVoltage() usa un promedio de 20 muestras para estabilizar la lectura antes de aplicar el factor de corrección.
* Envío de Datos: Se realiza un POST con un payload JSON a la API del servidor.
4. 🖥️ Lógica del Backend (Node.js/Express)
4.1. Escalabilidad y Endpoints
El servidor está configurado para permitir la escalabilidad y la fácil adición de nuevos sensores:
Endpoint
	Uso
	Lógica de Recuperación
	POST /api/sensors/config
	Configuración de Umbrales y Nombre Amigable.
	Crea/actualiza la configuración en la colección sensors.
	GET /api/sensors/ids
	Obtiene la lista de IDs disponibles para configuración.
	Devuelve la lista fija de IDs del firmware (HELADERA-01 a HELADERA-05), permitiendo al usuario configurar nuevos sensores sin modificar el código.
	GET /api/latest (MODIFICADO)
	Pantalla principal.
	Prioriza la consulta en la tabla sensors. Lista todos los sensores configurados, mostrando "Sin datos" si el ESP32 aún no ha enviado su primera medición (UX mejorada).
	4.2. Corrección de Horario (UTC a Local)
* Problema: MongoDB guarda las marcas de tiempo en UTC, lo que causaba un desfase de 3 horas al ser interpretado en Flutter.
* Solución Aplicada: La conversión a la hora local se fuerza en el modelo Measurement.fromJson (Dart) utilizando la lógica DateTime.toUtc().toLocal().
5. 📱 Lógica del Frontend (Flutter)
5.1. Estabilidad y Visualización
* Manejo de Nulls: Los campos de medición (temperatureC, voltageV, timestamp) se definieron como opcionales (?) en el modelo SensorState para manejar de forma segura los valores null devueltos por /api/latest cuando un sensor aún no ha reportado datos.
* Refresco Automático (UX): La pantalla principal (MeasurementScreen) utiliza un Timer para consultar la API cada 30 segundos, eliminando la necesidad de recargas manuales.
* Recarga Forzada: El botón "Reintentar conexión" ahora utiliza Navigator.pushReplacement para forzar un reinicio completo de la pantalla y el Timer en caso de errores de conexión, asegurando la máxima estabilidad.
5.2. Vista de Historial
* Gráfico (HistoryScreen): Muestra los últimos 100 puntos de medición de temperatura utilizando fl_chart. El layout fue mejorado con altura fija ($\mathbf{250\text{px}}$) y espaciado corregido en el eje X para el indicador "Tiempo".