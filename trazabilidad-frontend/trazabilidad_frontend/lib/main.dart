// lib/main.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ⭐️ Importaciones de tus archivos ⭐️
import 'models/sensor_state.dart'; // Usamos el nuevo modelo SensorState
import 'widgets/battery_indicator.dart'; 
import 'screens/history_screen.dart'; 
import 'screens/module_create_screen.dart'; // ⭐️ Importación de la pantalla de creación

// REEMPLAZA CON LA IP DE TU COMPUTADORA
const String SERVER_IP = '192.168.100.4'; 
// Usamos el endpoint optimizado para la pantalla principal
const String API_URL = 'http://$SERVER_IP:3000/api/latest'; 

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
  // La lista ahora contendrá el nuevo modelo SensorState
  late Future<List<SensorState>> futureSensorStates;

  @override
  void initState() {
    super.initState();
    futureSensorStates = fetchSensorStates();
  }

  // Función asíncrona para obtener datos de la API (/api/latest)
  Future<List<SensorState>> fetchSensorStates() async {
    final response = await http.get(Uri.parse(API_URL));

    if (response.statusCode == 200) {
      List<dynamic> jsonList = jsonDecode(response.body);
      
      // Mapea cada elemento JSON a una instancia de la clase SensorState
      return jsonList.map((json) => SensorState.fromJson(json)).toList();
    } else {
      throw Exception('Falló la carga de datos. Código: ${response.statusCode}');
    }
  }

  // Formateador simple de fecha
  String formatTimestamp(DateTime timestamp) {
    return '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute}:${timestamp.second}';
  }
  
  // Función para refrescar la lista después de crear/editar un módulo
  Future<void> _refreshList() async {
    setState(() {
      futureSensorStates = fetchSensorStates();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoreo de Heladeras'),
      ),
      
      // ⭐️ BOTÓN FLOTANTE PARA AGREGAR/CONFIGURAR MÓDULOS ⭐️
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Configurar Heladera'),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ModuleCreateScreen()),
          );
          
          // Refrescar la lista si se hizo alguna acción (result es true)
          if (result == true) {
            _refreshList();
          }
        },
      ),
      
      body: FutureBuilder<List<SensorState>>(
        future: futureSensorStates,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator()); 
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            final sensorStates = snapshot.data!;
            
            // EXTRAER EL VOLTAJE GLOBAL (del primer sensor, como proxy)
            final double systemVoltage = sensorStates.first.voltageV; 
            
            return Column(
              children: [
                // INDICADOR DE BATERÍA FIJO
                BatteryIndicator(voltage: systemVoltage),

                Expanded(
                  child: ListView.builder(
                    itemCount: sensorStates.length,
                    itemBuilder: (context, index) {
                      final state = sensorStates[index];
                      // Determinar el color si la temperatura supera el umbral de alerta
                      final bool isAlert = state.temperatureC > state.alertThreshold;

                      return Card(
                        color: isAlert ? Colors.red.shade100 : Colors.white,
                        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                        child: ListTile(
                          // AHORA USAMOS friendlyName y el ícono de alerta
                          leading: Icon(
                            isAlert ? Icons.warning : Icons.thermostat,
                            color: isAlert ? Colors.red : Colors.blueGrey,
                          ),
                          title: Text(
                            state.friendlyName, // ⭐️ NOMBRE AMIGABLE ⭐️
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('Umbral: ${state.alertThreshold}°C | Última: ${formatTimestamp(state.timestamp)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${state.temperatureC.toStringAsFixed(2)} °C',
                                style: TextStyle(
                                  color: isAlert ? Colors.red : Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // BOTÓN HISTORIAL
                              ElevatedButton(
                                child: const Text('Historial'),
                                onPressed: () {
                                  // Pasamos el ID de hardware para que el historial pueda buscar datos
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => HistoryScreen(sensorId: state.hardwareId, friendlyName: state.friendlyName),
                                    ),
                                  );
                                },
                              ),
                            ],
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