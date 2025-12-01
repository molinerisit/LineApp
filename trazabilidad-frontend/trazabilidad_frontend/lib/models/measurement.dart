// lib/models/measurement.dart

import 'dart:convert';

class Measurement {
  final String id;
  final String sensorId;
  final double temperatureC;
  final double voltageV;
  final DateTime timestamp;

  Measurement({
    required this.id,
    required this.sensorId,
    required this.temperatureC,
    required this.voltageV,
    required this.timestamp,
  });

  // Constructor de fábrica para crear una instancia desde un mapa JSON
  factory Measurement.fromJson(Map<String, dynamic> json) {
    
    // ⭐️ CORRECCIÓN ZONA HORARIA: Forzar a UTC y luego a Local ⭐️
    final DateTime utcTimeCandidate = DateTime.parse(json['timestamp'] as String);
    // Aseguramos que la base es UTC antes de aplicar el huso local
    final DateTime localTime = utcTimeCandidate.toUtc().toLocal(); 

    return Measurement(
      // MongoDB usa '_id', Flutter lo usará como 'id'
      id: json['_id'] as String, 
      sensorId: json['sensorId'] as String,
      // Los datos vienen como números de la DB, se leen como double en Dart
      temperatureC: json['temperatureC'].toDouble(),
      voltageV: json['voltageV'].toDouble(),
      // ⭐️ Se usa la hora local corregida ⭐️
      timestamp: localTime, 
    );
  }
}