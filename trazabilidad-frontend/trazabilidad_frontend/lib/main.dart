// lib/main.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// ⭐️ AGREGAR LAS SIGUIENTES DOS LÍNEAS ⭐️
import 'widgets/battery_indicator.dart'; // Importa el widget BatteryIndicator
import 'screens/history_screen.dart';
import 'models/measurement.dart';

// REEMPLAZA CON LA IP DE TU COMPUTADORA
const String SERVER_IP = '192.168.100.4'; 
const String API_URL = 'http://$SERVER_IP:3000/api/temperaturas';

void main() {
  runApp(const TrazabilidadApp());
}

class TrazabilidadApp extends StatelessWidget {
  const TrazabilidadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trazabilidad de Heladeras',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MeasurementScreen(),
    );
  }
}

class MeasurementScreen extends StatefulWidget {
  const MeasurementScreen({super.key});

  @override
  State<MeasurementScreen> createState() => _MeasurementScreenState();
}

class _MeasurementScreenState extends State<MeasurementScreen> {
  // Lista para almacenar las mediciones
  late Future<List<Measurement>> futureMeasurements;

  @override
  void initState() {
    super.initState();
    // Llama a la función de carga de datos al iniciar el widget
    futureMeasurements = fetchMeasurements();
  }

  // Función asíncrona para obtener datos de la API
  Future<List<Measurement>> fetchMeasurements() async {
    final response = await http.get(Uri.parse(API_URL));

    if (response.statusCode == 200) {
      // Si la llamada fue exitosa (código 200 OK)
      List<dynamic> jsonList = jsonDecode(response.body);
      
      // Mapea cada elemento JSON a una instancia de la clase Measurement
      return jsonList.map((json) => Measurement.fromJson(json)).toList();
    } else {
      // Si el servidor no devolvió una respuesta 200 OK
      throw Exception('Falló la carga de mediciones. Código: ${response.statusCode}');
    }
  }

  // Formateador simple de fecha
  String formatTimestamp(DateTime timestamp) {
    return '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute}:${timestamp.second}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoreo de Heladeras'),
        // Aquí agregaremos el indicador de batería si es un diseño más complejo
      ),
      body: FutureBuilder<List<Measurement>>(
        future: futureMeasurements,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator()); 
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            final measurements = snapshot.data!;
            // ⭐️ EXTRAER EL VOLTAJE GLOBAL (del primer sensor)
            final double systemVoltage = measurements.first.voltageV; 
            
            return Column(
              children: [
                // ⭐️ INDICADOR DE BATERÍA FIJO (Barra Superior)
                BatteryIndicator(voltage: systemVoltage),

                Expanded(
                  child: ListView.builder(
                    itemCount: measurements.length,
                    itemBuilder: (context, index) {
                      final measurement = measurements[index];
                      return Card(
                        child: ListTile(
                          // ⭐️ SOLO ID Y TEMPERATURA
                          leading: Text(measurement.sensorId, style: const TextStyle(fontWeight: FontWeight.bold)),
                          title: Text('${measurement.temperatureC.toStringAsFixed(2)} °C'),
                          subtitle: Text('Última lectura: ${formatTimestamp(measurement.timestamp)}'),
                          // ⭐️ BOTÓN HISTORIAL
                          trailing: ElevatedButton(
                            child: const Text('Historial'),
                            onPressed: () {
                              // Navegar a la nueva pantalla de historial
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => HistoryScreen(sensorId: measurement.sensorId),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          } else {
            return const Center(child: Text('No hay sensores activos.'));
          }
        },
      ),
    );
  }
}