// models/Measurement.js

const mongoose = require('mongoose');

// Esquema que define la estructura del documento de medición
const MeasurementSchema = new mongoose.Schema({
    sensorId: {
        type: String,
        required: true,
        trim: true,
        // Usamos index para buscar rápidamente por ID de sensor
        index: true 
    },
    temperatureC: {
        type: Number,
        required: true
    },
    voltageV: {
        type: Number,
        required: true
    },
    timestamp: {
        type: Date,
        default: Date.now // Guarda automáticamente la fecha y hora de la medición
    }
});

// Exporta el modelo para usarlo en server.js
module.exports = mongoose.model('Measurement', MeasurementSchema);