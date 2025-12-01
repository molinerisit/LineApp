PROYECTO DE TRAZABILIDAD IOT DE HELADERAS  
Deep Sleep Architecture – ESP32 + Node + MongoDB + Flutter

Sistema completo de monitoreo y trazabilidad de temperatura y voltaje para heladeras comerciales o industriales, diseñado con enfoque en eficiencia energética utilizando Deep Sleep del ESP32.

ARQUITECTURA GENERAL – DIAGRAMA LÓGICO

Microcontrolador
- ESP32 WROOM-32E
- Rol: medición de sensores, filtrado de datos, envío, Deep Sleep (300s)

Backend
- Node.js + Express
- Rol: API REST, umbrales, alertas, endpoints de consulta y configuración

Base de Datos
- MongoDB
- Colecciones:
  - measurements
  - sensors

Frontend
- Flutter (Dart)
- Rol: visualización en tiempo real, historial, gráficos con fl_chart

COMPONENTES DE HARDWARE Y CALIBRACIÓN

2.1 Deep Sleep (Maximización de Batería)
- Ciclo:
  - Despertar
  - Medir sensores
  - POST de datos
  - Dormir 300s
- Timer: esp_sleep_enable_timer_wakeup

2.2 Monitoreo de Batería
Sistema alimentado con 4 pilas AA: ~6.0V total

Parámetros:
- Pin ADC: GPIO 34
- R1: 100kΩ
- R2: 47kΩ
- Factor divisor calibrado: 1.82

Notas:
- El factor 1.82 corrige la referencia de voltaje cruda del ADC
- Ejemplo: lectura inicial: 10.32V → calibrado: 6.0V

2.3 Sensores de Temperatura
- Tipo: DS18B20 sumergibles
- Conexión: One-Wire GPIO 4

LÓGICA DEL FIRMWARE (ESP32)

- IDs lógicas fijas para sensores (HELADERA-01, etc.)
- Filtrado y promedio de 20 lecturas de voltaje
- Payload JSON por POST al backend

Ejemplo de payload:

{
  "id": "HELADERA-02",
  "temp": -17.4,
  "battery": 5.89,
  "timestamp": "2025-11-10T18:22:10Z"
}

LÓGICA DEL BACKEND (Node.js / Express)

4.1 Endpoints principales

POST /api/sensors/config
- guarda/actualiza nombre y umbral de un sensor

GET /api/sensors/ids
- devuelve lista fija de IDs del firmware

GET /api/latest
- lista sensores configurados y muestra "Sin datos" si no hay primeras mediciones

4.2 Manejo horario UTC → Local
Conversión aplicada en Flutter:
DateTime.parse(value).toUtc().toLocal();

LÓGICA DEL FRONTEND (Flutter)

5.1 UX y estabilidad
- Modelos con campos opcionales
- Auto refresh cada 30s
- Navigator.pushReplacement ante error de conexión

5.2 Historial
- Últimos 100 puntos
- fl_chart con altura fija 250px
- Eje X optimizado para tiempo

RESUMEN BENEFICIOS CLAVE
- Modular y escalable
- Deep Sleep ultra eficiente
- IDs lógicas fijas
- Backend desacoplado
- Frontend robusto
- Lecturas calibradas reales

MEJORAS FUTURAS
- OTA
- MQTT
- Almacenamiento local
- Alertas push
- Gráficos comparativos

LICENCIA
MIT

CONTACTO / AUTOR
Proyecto real de monitoreo IoT para refrigeración.
