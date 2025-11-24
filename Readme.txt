# 🚀 README del Proyecto: Monitoreo de Trazabilidad de Heladeras

Este documento describe el estado actual del sistema de monitoreo IoT (ESP32) con su API de backend (Node.js) y la aplicación frontend (Flutter).

## 1. 🎯 Estado Actual del Proyecto

| Capa | Estado | Descripción |
| :--- | :--- | :--- |
| **Hardware (ESP32)** | **Funcional** | El ESP32 se conecta al Wi-Fi y envía lecturas de temperatura/voltaje (simuladas) al servidor. |
| **Backend (Node.js/Express)** | **Completo** | Recibe datos del ESP32, los guarda en MongoDB y sirve los datos recientes e historial a Flutter. |
| **Base de Datos** | **MongoDB** | Configurado para usar el host local: `mongodb://localhost:27017/trazabilidadDB`. |
| **Frontend (Flutter)** | **Funcional** | Muestra la última temperatura por heladera y la carga de la batería. Incluye la vista de "Historial" con **gráfico funcional** (utiliza `fl_chart`). |

---

## 2. 🔌 Parámetros de Conexión

Estos valores deben estar configurados en el código del ESP32 (`serverHost`) y en la aplicación Flutter (`SERVER_IP`).

| Parámetro | Valor Predeterminado | Uso |
| :--- | :--- | :--- |
| **IP del Servidor (Tu PC)** | `192.168.100.4` | Dirección local para la comunicación entre ESP32 y Node.js. |
| **Puerto de la API** | `3000` | Puerto del servidor Express. |
| **Endpoint de Recepción** | `/api/data` | Ruta donde el ESP32 envía datos. |
| **Endpoint de Historial** | `/api/history?sensorId=` | Ruta que Flutter consume para el gráfico. |

---

## 3. ⌨️ Instrucciones de Ejecución

Para iniciar el sistema completo, se requieren dos terminales abiertas:

### A. Iniciar el Backend (Servidor Node.js)

1.  Abre una terminal en el directorio `trazabilidad-backend`.
2.  Asegúrate de que el servicio de **MongoDB (puerto 27017)** esté corriendo.
3.  Ejecuta el servidor:
    ```bash
    npm start
    ```
    *(Mantener esta terminal abierta y verificar los logs para ver la recepción de datos del ESP32.)*

### B. Iniciar el Frontend (Aplicación Flutter)

1.  Abre una **segunda terminal** en el directorio `trazabilidad_frontend`.
2.  Asegúrate de que un emulador o dispositivo esté conectado.
3.  Ejecuta la aplicación:
    ```bash
    flutter run
    ```

---

## 4. 📝 Pendientes y Próximos Pasos (Hardware)

1.  **Reemplazo del Sensor:** Instalar el **sensor DS18B20 sumergible** (requiere $\mathbf{4.7\text{k}\Omega}$ pull-up).
2.  **Alimentación:** Instalar el **divisor de voltaje** ($\mathbf{100\text{k}\Omega}$ y $\mathbf{47\text{k}\Omega}$) para el monitoreo real de la pila. 

[Image of Voltage Divider Circuit]

3.  **Firmware (ESP32):** Actualizar el código para leer el sensor **DS18B20** y obtener la lectura de **voltaje de batería real** (en lugar de valores simulados).
4.  **Modularidad:** Implementar la lógica para leer y registrar **múltiples sensores** DS18B20 utilizando su ID único.