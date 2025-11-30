// lib/services/api_service.dart

import 'package:flutter/foundation.dart'; // Para print en debug mode
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../main.dart'; // Importa SERVER_IP y PORT
import '../models/sensor_state.dart';
import '../models/measurement.dart';

// URL Base del Backend
const String BASE_URL = 'http://$SERVER_IP:3000/api';

class ApiService {
  // ----------------------------------------------------
  // 1. GESTIÓN DE CONFIGURACIÓN (Llamado desde ModuleCreateScreen)
  // Ruta: POST /api/sensors/config
  // ----------------------------------------------------
  static Future<bool> createModule(
    String hardwareId,
    String friendlyName,
    String type, // Usamos solo para compatibilidad, el backend lo ignora
    {
    required double alertThresholdC, 
    required double voltageThresholdV,
    bool? desiredState, // Ignorado
    }
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$BASE_URL/sensors/config'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'hardwareId': hardwareId, // HELADERA-01
          'friendlyName': friendlyName, // Nombre de usuario (Lácteos)
          'alertThreshold': alertThresholdC,
          'voltageThreshold': voltageThresholdV,
        }),
      );

      if (response.statusCode == 200) {
        return true; // Configuración guardada con éxito
      } else {
        if (kDebugMode) {
          print('Error de Configuración (${response.statusCode}): ${response.body}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) print('Excepción al configurar módulo: $e');
      return false;
    }
  }


  // ----------------------------------------------------
  // 2. RECUPERACIÓN DE DATOS RECIENTES (Llamado desde MeasurementScreen)
  // Ruta: GET /api/latest
  // ----------------------------------------------------
  static Future<List<SensorState>> getLatestSensorStates() async {
    final response = await http.get(Uri.parse('$BASE_URL/latest'));

    if (response.statusCode == 200) {
      List<dynamic> jsonList = jsonDecode(response.body);
      
      // La API devuelve un array de objetos fusionados (última medición + config)
      return jsonList.map((json) => SensorState.fromJson(json)).toList();
    } else {
      if (kDebugMode) print('Error al obtener latest: ${response.statusCode}');
      throw Exception('Falló la carga de datos recientes.');
    }
  }

  // ----------------------------------------------------
  // 3. RECUPERACIÓN DE DATOS HISTÓRICOS (Llamado desde HistoryScreen)
  // Ruta: GET /api/history?sensorId=X
  // ----------------------------------------------------
  static Future<List<Measurement>> getHistory(String sensorId) async {
    final response = await http.get(Uri.parse('$BASE_URL/history?sensorId=$sensorId'));

    if (response.statusCode == 200) {
      List<dynamic> jsonList = jsonDecode(response.body);
      
      // La API devuelve el historial de mediciones puras
      return jsonList.map((json) => Measurement.fromJson(json)).toList();
    } else {
      if (kDebugMode) print('Error al obtener historial: ${response.statusCode}');
      throw Exception('Falló la carga del historial del sensor $sensorId.');
    }
  }
  
  // Nota: Las funciones login, signup, etc., de tu código AgriSense original
  // deben ser añadidas aquí si planeas implementarlas.
}