// lib/main.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; 

// ⭐️ Importaciones de tus archivos ⭐️
import 'models/sensor_state.dart'; 
import 'widgets/battery_indicator.dart'; 
import 'screens/history_screen.dart'; 
import 'screens/module_create_screen.dart'; 

// REEMPLAZA CON LA IP DE TU COMPUTADORA
const String SERVER_IP = '192.168.100.4'; 
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
  late Future<List<SensorState>> futureSensorStates;
  Timer? _timer;
  
  DateTime _lastRefreshTime = DateTime.now().toLocal(); 

  @override
  void initState() {
    super.initState();
    futureSensorStates = fetchSensorStates();
    
    _timer = Timer.periodic(const Duration(seconds: 30), (Timer t) {
      _refreshList();
    });
  }

  Future<List<SensorState>> fetchSensorStates() async {
    final response = await http.get(Uri.parse(API_URL));

    if (response.statusCode == 200) {
      List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((json) => SensorState.fromJson(json)).toList();
    } else {
      throw Exception('Falló la carga de datos. Código: ${response.statusCode}');
    }
  }

  String formatTimestamp(DateTime timestamp) {
    DateTime correctedTime = timestamp.toUtc().toLocal();
    
    final day = correctedTime.day.toString().padLeft(2, '0');
    final month = correctedTime.month.toString().padLeft(2, '0');
    final year = correctedTime.year;
    final hour = correctedTime.hour.toString().padLeft(2, '0');
    final minute = correctedTime.minute.toString().padLeft(2, '0');
    final second = correctedTime.second.toString().padLeft(2, '0');
    
    return '$day/$month/$year $hour:$minute:$second';
  }
  
  Future<void> _refreshList() async {
    if (mounted) {
      setState(() {
        futureSensorStates = fetchSensorStates();
        _lastRefreshTime = DateTime.now().toLocal();
      });
    }
  }

  // ⭐️ NUEVA FUNCIÓN PARA RECARGAR LA PANTALLA COMPLETA ⭐️
  void _relaunchScreen() {
    // Usamos pushReplacement para reemplazar la pantalla actual con una nueva instancia
    // Esto fuerza la ejecución de initState y la recarga total, imitando el refresh del navegador.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const MeasurementScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoreo de Heladeras'),
      ),
      
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Configurar Heladera'),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ModuleCreateScreen()),
          );
          
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error de conexión: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  // ⭐️ EL BOTÓN AHORA LLAMA A LA RECARGA COMPLETA ⭐️
                  ElevatedButton(
                    onPressed: _relaunchScreen, // ⭐️ LLAMADA MODIFICADA ⭐️
                    child: const Text('Reintentar conexión'),
                  ),
                ],
              ),
            );
          } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            final sensorStates = snapshot.data!;
            
            final double systemVoltage = sensorStates.first.voltageV ?? 0.0; 
            
            return Column(
              children: [
                // INDICADOR VISUAL DE LA HORA DEL ÚLTIMO REFRESH
                Container(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                  color: Colors.grey[100],
                  child: Center(
                    child: Text(
                      'Última Actualización: ${formatTimestamp(_lastRefreshTime)} (Auto)',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ),
                ),
                
                // INDICADOR DE BATERÍA FIJO
                BatteryIndicator(voltage: systemVoltage),

                Expanded(
                  child: ListView.builder(
                    itemCount: sensorStates.length,
                    itemBuilder: (context, index) {
                      final state = sensorStates[index];
                      
                      final bool hasData = state.temperatureC != null && state.timestamp != null;
                      
                      final bool isAlert = hasData 
                          ? state.temperatureC! > state.alertThreshold
                          : false; 

                      final String tempDisplay = hasData
                          ? '${state.temperatureC!.toStringAsFixed(2)} °C'
                          : '---'; 
                      
                      final String subtitleDisplay = hasData 
                          ? 'Umbral: ${state.alertThreshold}°C | Última: ${formatTimestamp(state.timestamp!)}'
                          : 'Umbral: ${state.alertThreshold}°C | Sin datos recientes';
                      
                      return Card(
                        color: isAlert ? Colors.red.shade100 : (hasData ? Colors.white : Colors.grey.shade50), 
                        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                        child: ListTile(
                          leading: Icon(
                            isAlert ? Icons.warning : Icons.thermostat,
                            color: isAlert ? Colors.red : (hasData ? Colors.blueGrey : Colors.grey),
                          ),
                          title: Text(
                            state.friendlyName, 
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(subtitleDisplay),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tempDisplay,
                                style: TextStyle(
                                  color: isAlert ? Colors.red : (hasData ? Colors.black : Colors.grey),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                child: const Text('Historial'),
                                onPressed: () {
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
            return const Center(child: Text('No hay sensores configurados o activos.'));
          }
        },
      ),
    );
  }
}