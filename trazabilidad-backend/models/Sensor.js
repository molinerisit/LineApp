// models/Sensor.js
const mongoose = require('mongoose');

const sensorSchema = new mongoose.Schema({
    // ID única del hardware (ej: "HELADERA-A001"). Es el campo clave.
    hardwareId: {
        type: String,
        required: true,
        unique: true
    },
    // Nombre amigable para mostrar en Flutter (ej: "Heladera Cocina Principal")
    friendlyName: {
        type: String,
        required: true,
        default: 'Sensor Sin Nombre'
    },
    // Umbral de temperatura máximo en Celsius para disparar una alerta.
    alertThreshold: {
        type: Number,
        required: true,
        default: 5.0 // Por defecto, alerta a partir de 5.0 °C
    },
    // Umbral de voltaje mínimo para la alerta de batería baja
    voltageThreshold: {
        type: Number,
        default: 4.2 // Por defecto, alerta si el voltaje cae bajo 4.2V
    }
}, { 
    timestamps: true // Añade createdAt y updatedAt
});

const Sensor = mongoose.model('Sensor', sensorSchema);

module.exports = Sensor;