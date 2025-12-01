#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiManager.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <WebServer.h>      
#include <math.h>
#include <string.h> 

// =================== CONFIGURACIÓN DE TIEMPO Y RED ===================
const uint64_t SLEEP_TIME_SECONDS = 300; // ⭐️ TIEMPO DE SUEÑO PROFUNDO (5 minutos) ⭐️

char serverHostChar[20]; 
char serverPortChar[6]; 
// WebServer server(80); // Objeto WebServer no es necesario si no se usa en loop() o setup()

// =================== CONFIGURACIÓN DE SENSORES ===================
#define ONE_WIRE_BUS 4          // Pin GPIO 4 para el bus DS18B20 (DATA)
#define VOLTAGE_ADC_PIN 34      // Pin ADC 34 para la lectura del Divisor de Voltaje

// Coeficientes del Divisor de Voltaje (Para 100k y 47k)
const float VOLTAGE_DIVIDER_FACTOR = 1.82; 
const float MAX_ADC_VOLTAGE = 3.3; // Voltaje máximo de entrada del ADC del ESP32

// IDs Lógicas que Flutter usa para configurar (Máximo 5)
const int MAX_SENSORS = 5; 
const String SENSOR_HARDWARE_IDS[MAX_SENSORS] = {
    "HELADERA-01", "HELADERA-02", "HELADERA-03", "HELADERA-04", "HELADERA-05" 
};

// Estructuras y objetos DS18B20
struct SensorMapping {
    DeviceAddress address;
    String logicalId;
};
SensorMapping mappedSensors[MAX_SENSORS];
int sensorCount = 0; 
OneWire oneWire(ONE_WIRE_BUS);
DallasTemperature sensors(&oneWire);

// ================= FUNCIONES DE LECTURA REAL =================

void mapSensors() {
    sensors.begin();
    int detectedCount = sensors.getDeviceCount();
    Serial.printf("Sensores DS18B20 encontrados: %d\n", detectedCount);

    sensorCount = 0;
    
    // Asigna las IDs lógicas a los sensores físicos encontrados
    for (int i = 0; i < detectedCount && i < MAX_SENSORS; i++) {
        DeviceAddress deviceAddress;
        if (sensors.getAddress(deviceAddress, i)) {
            mappedSensors[sensorCount].logicalId = SENSOR_HARDWARE_IDS[i];
            memcpy(mappedSensors[sensorCount].address, deviceAddress, 8);
            sensorCount++;
            Serial.printf("Sensor #%d mapeado a ID: %s\n", i + 1, SENSOR_HARDWARE_IDS[i].c_str());
        }
    }
    
    if (sensorCount > 0) {
        sensors.setResolution(10); 
        Serial.printf("Total de sensores activos: %d\n", sensorCount);
    }
}

// ⭐️ FUNCIÓN DE LECTURA DE VOLTAJE CON FILTRADO (20 MUESTRAS) ⭐️
float readBatteryVoltage() {
    int rawValue = 0;
    const int numReadings = 20; 
    
    // 1. Sumar 20 lecturas rápidas del pin ADC
    for (int i = 0; i < numReadings; i++) {
        rawValue += analogRead(VOLTAGE_ADC_PIN); 
        delay(5); 
    }
    
    float avgAdcValue = (float)rawValue / numReadings;
    
    // 3. Aplicar la fórmula de conversión
    float pinVoltage = (avgAdcValue / 4095.0) * MAX_ADC_VOLTAGE;
    float batteryVoltage = pinVoltage * VOLTAGE_DIVIDER_FACTOR;
    
    return batteryVoltage;
}

// FUNCIÓN DE ENVÍO DE DATOS HTTP (POST/JSON)
void sendData(String sensorId, float tempC, float voltageV) {
    if (WiFi.status() != WL_CONNECTED) return;
    
    HTTPClient http;
    String url = "http://" + String(serverHostChar) + ":" + String(serverPortChar) + "/api/data";
    
    String jsonPayload = "{";
    jsonPayload += "\"sensorId\":\"" + sensorId + "\",";
    jsonPayload += "\"tempC\":" + String(tempC, 2) + ","; 
    jsonPayload += "\"voltageV\":" + String(voltageV, 2);  
    jsonPayload += "}";

    Serial.println("Enviando JSON a: " + url);
    Serial.println(jsonPayload);

    http.begin(url);
    http.addHeader("Content-Type", "application/json");
    int httpCode = http.POST(jsonPayload); 

    if (httpCode <= 0) { 
        Serial.printf("[HTTP] POST... falló, error: %s\n", http.errorToString(httpCode).c_str());
    }
    http.end(); 
}

// ⭐️ FUNCIÓN PARA DORMIR (DEEP SLEEP) ⭐️
void goToSleep() {
    Serial.printf("Durmiendo por %llu segundos...\n", SLEEP_TIME_SECONDS);
    // Configura el temporizador para despertar el chip
    esp_sleep_enable_timer_wakeup(SLEEP_TIME_SECONDS * 1000000ULL);
    
    // Inicia el modo Deep Sleep
    esp_deep_sleep_start();
}


// =================== SETUP (LÓGICA PRINCIPAL DE TRABAJO) ===================

void setup() {
    Serial.begin(115200);
    analogReadResolution(12); 
    
    // 1. Inicialización de WiFiManager (Portal Cautivo)
    WiFiManager wm;
    WiFiManagerParameter custom_server_host("server", "IP Servidor Node.js", "192.168.100.4", 20);
    WiFiManagerParameter custom_server_port("port", "Puerto (ej: 3000)", "3000", 6);

    // wm.resetSettings(); // Descomentar para prueba inicial del portal

    wm.addParameter(&custom_server_host);
    wm.addParameter(&custom_server_port);

    if (!wm.autoConnect("HELADERA_SETUP", "password")) {
        Serial.println("Fallo de conexión. Reiniciando...");
        delay(3000);
        ESP.restart();
    }
    
    Serial.println("\nConexión Wi-Fi establecida.");
    strcpy(serverHostChar, custom_server_host.getValue());
    strcpy(serverPortChar, custom_server_port.getValue());
    Serial.printf("IP del ESP32: %s\n", WiFi.localIP().toString().c_str());


    // 2. Mapeo de Sensores DS18B20
    mapSensors();

    // 3. MEDICIÓN Y ENVÍO DE DATOS
    if (sensorCount == 0) {
        Serial.println("No hay sensores DS18B20 conectados. No se enviarán datos.");
    } else {
        float currentVoltage = readBatteryVoltage();
        sensors.requestTemperatures(); 
        
        for (int i = 0; i < sensorCount; i++) {
            
            float currentTemp = sensors.getTempC(mappedSensors[i].address);
            String currentId = mappedSensors[i].logicalId;
            
            if (currentTemp != DEVICE_DISCONNECTED_C && currentTemp > -50.0) { 
                sendData(currentId, currentTemp, currentVoltage);
            } else {
                Serial.printf("⚠️ Error de lectura o desconexión para %s. Omitido.\n", currentId.c_str());
            }
        }
    }
    
    // 4. EL PASO FINAL: DORMIR
    goToSleep();
}

// ⭐️ FUNCIÓN LOOP (DEBE QUEDAR VACÍA) ⭐️
void loop() {
    // El ESP32 nunca ejecuta este código; se reinicia después de 5 minutos.
}