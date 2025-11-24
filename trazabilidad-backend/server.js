// server.js (CÓDIGO ACTUALIZADO)

const express = require('express');
const mongoose = require('mongoose');
const bodyParser = require('body-parser');
const cors = require('cors');
const Measurement = require('./models/Measurement'); // Importa el modelo

const app = express();
const PORT = 3000;

// --- 1. CONFIGURACIÓN DE MONGO DB ---
// REEMPLAZA ESTA CADENA con tu URL de MongoDB (local o Atlas)
// Ejemplo de URL local: 'mongodb://localhost:27017/trazabilidadDB'
// Si usas Atlas, será una URL https://...
const dbURI = 'mongodb://localhost:27017/trazabilidadDB';
mongoose.connect(dbURI)
    .then(() => console.log('✅ Conectado a MongoDB'))
    .catch(err => console.error('❌ Error de conexión a DB:', err));
// -------------------------------------

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));
// Permitir CORS solo desde el frontend en desarrollo
app.use(cors({ origin: '*' }));


// =========================================================
// RUTA 1: Endpoint de Recepción del ESP32 (ALMACENAMIENTO)
// =========================================================
app.get('/api/data', async (req, res) => {
    // Los datos vienen como strings desde el ESP32 (query parameters)
    const { sensorId, temp, voltage } = req.query;

    console.log(`=== NUEVO DATO RECIBIDO DEL ESP32 ===`);
    console.log(`ID del Sensor: ${sensorId}, Temp: ${temp}, Volt: ${voltage}`);
    console.log(`=====================================`);
    
    // Validar y convertir los datos
    if (!sensorId || isNaN(parseFloat(temp)) || isNaN(parseFloat(voltage))) {
        return res.status(400).send('Faltan parámetros o son inválidos.');
    }

    try {
        // Crear un nuevo documento de medición
        const newMeasurement = new Measurement({
            sensorId: sensorId,
            temperatureC: parseFloat(temp),
            voltageV: parseFloat(voltage)
        });

        // Guardar en la base de datos
        await newMeasurement.save();
        console.log(`[DB] Medición guardada con éxito: ${newMeasurement.id}`);

        res.status(200).send('Datos recibidos y almacenados.');

    } catch (error) {
        console.error('Error al guardar la medición:', error);
        res.status(500).send('Error interno del servidor al almacenar datos.');
    }
});

// =========================================================
// RUTA 2: Endpoint para la Aplicación Web/Flutter (RECUPERACIÓN)
// =========================================================
app.get('/api/temperaturas', async (req, res) => {
    try {
        // Enviar las 50 mediciones más recientes, ordenadas por timestamp descendente
        const measurements = await Measurement.find()
            .sort({ timestamp: -1 })
            .limit(50);
        
        // La respuesta JSON que consumirá Flutter/Web
        res.json(measurements);
    } catch (error) {
        console.error('Error al obtener datos:', error);
        res.status(500).send('Error al recuperar mediciones.');
    }
});

app.get('/api/latest', async (req, res) => {
    try {
        // Agregación para obtener la última medición única por cada sensor
        const latestMeasurements = await Measurement.aggregate([
            { $sort: { timestamp: -1 } }, // Ordenar por más reciente
            {
                $group: {
                    _id: "$sensorId", // Agrupar por ID del sensor
                    temperatureC: { $first: "$temperatureC" },
                    voltageV: { $first: "$voltageV" },
                    timestamp: { $first: "$timestamp" }
                }
            },
            { // Proyectar los campos finales
                $project: {
                    _id: 0, 
                    sensorId: "$_id",
                    temperatureC: 1,
                    voltageV: 1,
                    timestamp: 1
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
// RUTA 2: Endpoint para la Aplicación Web/Flutter (DATOS HISTÓRICOS)
// =========================================================
// Acepta un parámetro 'sensorId' para filtrar la historia
app.get('/api/history', async (req, res) => {
    // Si no se especifica sensorId, devolvemos un error o una lista vacía
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