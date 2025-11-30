// lib/models/sensor_state.dart
import 'package:flutter/material.dart'; // Solo para la documentación, no esencial

class SensorState {
  // Datos de Configuración (Desde la colección Sensor/Modelo Sensor en Node.js)
  final String hardwareId;
  final String friendlyName; // Nombre dado por el usuario (ej: "Heladera Cocina")
  final double alertThreshold;
  
  // Datos de la Última Medición (Desde la colección Measurement)
  final double temperatureC;
  final double voltageV;
  final DateTime timestamp;

  SensorState({
    required this.hardwareId,
    required this.friendlyName,
    required this.alertThreshold,
    required this.temperatureC,
    required this.voltageV,
    required this.timestamp,
  });

  // Constructor de fábrica para crear una instancia desde el JSON de /api/latest
  factory SensorState.fromJson(Map<String, dynamic> json) {
    // Nota: El Backend de Node.js (con Aggregation/Lookup) ahora devuelve el 'friendlyName'
    return SensorState(
      hardwareId: json['sensorId'] as String,
      // Usamos 'friendlyName' si existe, o volvemos a usar 'sensorId' si no se configuró aún.
      friendlyName: json['friendlyName'] != null 
          ? json['friendlyName'] as String 
          : json['sensorId'] as String, 
      alertThreshold: json['alertThreshold'] != null 
          ? json['alertThreshold'].toDouble() 
          : 5.0, // Usar 5.0 como valor por defecto de seguridad
      temperatureC: json['temperatureC'].toDouble(),
      voltageV: json['voltageV'].toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}