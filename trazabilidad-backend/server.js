// server.js (VERSION CON MODELO SENSOR, ALERTAS Y RUTAS DE GESTIÓN)

const express = require('express');
const mongoose = require('mongoose');
const bodyParser = require('body-parser');
const cors = require('cors');

const Measurement = require('./models/Measurement'); 
const Sensor = require('./models/Sensor');           // ⭐️ NUEVO: Importa el modelo Sensor

const app = express();
const PORT = 3000;

// --- CONFIGURACIÓN DE MONGO DB ---
const dbURI = 'mongodb://localhost:27017/trazabilidadDB';
mongoose.connect(dbURI)
    .then(() => console.log('✅ Conectado a MongoDB'))
    .catch(err => console.error('❌ Error de conexión a DB:', err));
// -------------------------------------

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));
app.use(cors({ origin: '*' }));
// ⭐️ LISTA DE IDs FIJOS (REFLEJA EL FIRMWARE DEL ESP32) ⭐️
const ESP_HARDWARE_IDS = [
    "HELADERA-01", 
    "HELADERA-02", 
    "HELADERA-03", 
    "HELADERA-04", 
    "HELADERA-05"
];

// =========================================================
// RUTA 1: Endpoint de Recepción del ESP32 (ALMACENAMIENTO y ALERTAS)
// =========================================================
app.post('/api/data', async (req, res) => {
    // Si el ESP32 usa GET (query parameters), usa req.query. Si usa POST/JSON, usa req.body.
    const { sensorId, tempC, voltageV } = req.body || req.query; // Soporte para GET y POST

    if (!sensorId || isNaN(parseFloat(tempC)) || isNaN(parseFloat(voltageV))) {
        return res.status(400).send('Faltan parámetros o son inválidos.');
    }

    try {
        const temp = parseFloat(tempC);
        const voltage = parseFloat(voltageV);
        
        // 1. BUSCAR/CREAR CONFIGURACIÓN DEL SENSOR (AUTOCONFIGURACIÓN)
        let sensorConfig = await Sensor.findOneAndUpdate(
            { hardwareId: sensorId },
            { $setOnInsert: { 
                friendlyName: sensorId, 
                alertThreshold: 5.0, 
                voltageThreshold: 4.2 
            }},
            { new: true, upsert: true, setDefaultsOnInsert: true }
        );
        
        const { alertThreshold, voltageThreshold, friendlyName } = sensorConfig;
        
        // 2. LOGUEAR LA MEDICIÓN EN LA BD
        const newMeasurement = new Measurement({ sensorId, temperatureC: temp, voltageV: voltage });
        await newMeasurement.save();

        // 3. CHECKEO DE ALERTA (Aquí iría la lógica de notificación push)
        if (temp > alertThreshold) {
            console.warn(`🚨 ALERTA DE TEMP: ${friendlyName} (${sensorId}) superó el umbral (${alertThreshold}°C).`);
        }
        if (voltage < voltageThreshold) {
            console.warn(`⚠️ ALERTA DE BATERÍA: ${friendlyName} (${sensorId}) tiene batería baja (${voltage.toFixed(2)}V).`);
        }
        
        console.log(`[DB] Medición guardada de: ${friendlyName}. Temp: ${temp.toFixed(2)}°C`);
        res.status(200).send('Datos recibidos y guardados OK.');

    } catch (error) {
        console.error('Error procesando los datos:', error);
        res.status(500).send('Error interno del servidor.');
    }
});


// =========================================================
// RUTA 2: Endpoint de Gestión de Configuración (Desde Flutter)
// =========================================================
app.post('/api/sensors/config', async (req, res) => {
    const { hardwareId, friendlyName, alertThreshold, voltageThreshold } = req.body;

    if (!hardwareId) {
        return res.status(400).json({ message: 'El hardwareId es requerido.' });
    }

    try {
        const sensor = await Sensor.findOneAndUpdate(
            { hardwareId: hardwareId },
            { 
                friendlyName, 
                alertThreshold,
                voltageThreshold
            },
            { new: true, upsert: true, runValidators: true }
        );

        res.status(200).json({ 
            message: 'Configuración de sensor actualizada con éxito.', 
            sensor: sensor 
        });

    } catch (error) {
        console.error("Error al configurar el sensor:", error);
        res.status(500).json({ message: 'Error interno del servidor.' });
    }
});

// =========================================================
// RUTA 3: Endpoint de Datos Recientes (Versión 2.0: Listar TODO configurado)
// =========================================================
app.get('/api/latest', async (req, res) => {
    try {
        // 1. Empezamos buscando TODOS los sensores configurados.
        const allSensors = await Sensor.aggregate([
            // 2. Por cada sensor, buscamos todas sus mediciones históricas.
            {
                $lookup: {
                    from: 'measurements',
                    localField: 'hardwareId',
                    foreignField: 'sensorId',
                    as: 'historicalMeasurements',
                }
            },
            // 3. Ordenamos las mediciones históricas para encontrar la más reciente (por timestamp descendente)
            {
                $unwind: { path: '$historicalMeasurements', preserveNullAndEmptyArrays: true }
            },
            {
                $sort: { 'historicalMeasurements.timestamp': -1 }
            },
            // 4. Agrupamos por hardwareId y tomamos la primera (más reciente) medición.
            {
                $group: {
                    _id: "$hardwareId",
                    friendlyName: { $first: "$friendlyName" },
                    alertThreshold: { $first: "$alertThreshold" },
                    voltageThreshold: { $first: "$voltageThreshold" },
                    // Tomar los campos de la medición más reciente si existe
                    temperatureC: { $first: "$historicalMeasurements.temperatureC" },
                    voltageV: { $first: "$historicalMeasurements.voltageV" },
                    timestamp: { $first: "$historicalMeasurements.timestamp" },
                }
            },
            // 5. Proyectar el resultado para que coincida con el modelo SensorState de Flutter.
            {
                $project: {
                    _id: 0, // Excluir _id del output
                    sensorId: "$_id",
                    friendlyName: 1,
                    alertThreshold: 1,
                    voltageThreshold: { $ifNull: ["$voltageThreshold", 4.2] },
                    // Establecemos null para los datos si el sensor aún no ha enviado nada.
                    temperatureC: { $ifNull: ["$temperatureC", null] }, 
                    voltageV: { $ifNull: ["$voltageV", null] },
                    timestamp: { $ifNull: ["$timestamp", null] },
                }
            }
        ]);
        
        res.json(allSensors);

    } catch (error) {
        console.error('Error al obtener datos más recientes (versión 2.0):', error);
        res.status(500).send('Error al recuperar datos recientes.');
    }
});


// =========================================================
// RUTA 4: Endpoint de Datos Históricos (Mantiene /api/history)
// =========================================================
app.get('/api/history', async (req, res) => {
    // ... (El código de /api/history se mantiene igual)
    const { sensorId, limit = 200 } = req.query; 

    if (!sensorId) {
        return res.status(400).send('Se requiere el parámetro sensorId para el historial.');
    }

    try {
        const measurements = await Measurement.find({ sensorId: sensorId })
            .sort({ timestamp: -1 })
            .limit(parseInt(limit));
        
        res.json(measurements);
    } catch (error) {
        console.error('Error al obtener datos históricos:', error);
        res.status(500).send('Error al recuperar mediciones históricas.');
    }
});

// =========================================================
// RUTA 5: Endpoint para obtener la lista de Hardware IDs
// ⭐️ CORRECCIÓN: Devolvemos la lista fija para permitir la configuración inicial ⭐️
// =========================================================
app.get('/api/sensors/ids', async (req, res) => {
    try {
        // En lugar de consultar la BD, devolvemos la lista fija de IDs que el hardware usa
        res.json(ESP_HARDWARE_IDS);
    } catch (error) {
        console.error('Error al obtener la lista de IDs:', error);
        res.status(500).send('Error al recuperar las IDs de sensores.');
    }
});

// Iniciar el servidor
app.listen(PORT, () => {
    console.log(`Servidor de Trazabilidad corriendo en http://localhost:${PORT}`);
});