// server.js (VERSION CON MODELO SENSOR, ALERTAS Y RUTAS DE GESTIÓN)

const express = require('express');
const mongoose = require('mongoose');
const bodyParser = require('body-parser');
const cors = require('cors');

const Measurement = require('./models/Measurement'); 
const Sensor = require('./models/Sensor');           // ⭐️ NUEVO: Importa el modelo Sensor

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


// =========================================================
// RUTA 1: Endpoint de Recepción del ESP32 (ALMACENAMIENTO y ALERTAS)
// Se recomienda usar POST para el envío de datos de dispositivos
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
// RUTA 3: Endpoint de Datos Recientes (Devuelve Nombre Amigable)
// =========================================================
app.get('/api/latest', async (req, res) => {
    try {
        // Agregación para obtener la última medición única por cada sensor
        const latestMeasurements = await Measurement.aggregate([
            { $sort: { timestamp: -1 } },
            {
                $group: {
                    _id: "$sensorId",
                    temperatureC: { $first: "$temperatureC" },
                    voltageV: { $first: "$voltageV" },
                    timestamp: { $first: "$timestamp" }
                }
            },
            { 
                $lookup: {
                    from: 'sensors', // Nombre de la colección de sensores en MongoDB
                    localField: '_id',
                    foreignField: 'hardwareId',
                    as: 'sensorInfo'
                }
            },
            { $unwind: { path: '$sensorInfo', preserveNullAndEmptyArrays: true } },
            { 
                $project: {
                    sensorId: "$_id",
                    temperatureC: 1,
                    voltageV: 1,
                    timestamp: 1,
                    friendlyName: { $ifNull: ["$sensorInfo.friendlyName", "$_id"] },
                    alertThreshold: { $ifNull: ["$sensorInfo.alertThreshold", 5.0] },
                }
            }
        ]);
        
        res.json(latestMeasurements);
    } catch (error) {
        console.error('Error al obtener datos más recientes:', error);
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


// Iniciar el servidor
app.listen(PORT, () => {
    console.log(`Servidor de Trazabilidad corriendo en http://localhost:${PORT}`);
});