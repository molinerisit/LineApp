// lib/screens/history_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart'; // NECESARIO para el gráfico

import '../models/measurement.dart';
import '../main.dart'; // Importa main.dart para acceder a SERVER_IP

// Nota: SERVER_IP se importa desde main.dart

class HistoryScreen extends StatefulWidget {
  final String sensorId;
  final String friendlyName; // ⭐️ NUEVO PARÁMETRO ⭐️
  const HistoryScreen({
    super.key,
    required this.sensorId,
    required this.friendlyName,
  }); // ⭐️ ACTUALIZAR CONSTRUCTOR ⭐️
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Measurement>> futureHistory;

  @override
  void initState() {
    super.initState();
    futureHistory = fetchHistory(widget.sensorId);
  }

  // Llama al endpoint /api/history usando la IP de main.dart
  Future<List<Measurement>> fetchHistory(String sensorId) async {
    // Usamos el parámetro 'limit=100' para obtener hasta 100 puntos en el gráfico.
    final String url =
        'http://$SERVER_IP:3000/api/history?sensorId=$sensorId&limit=100';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((json) => Measurement.fromJson(json)).toList();
    } else {
      throw Exception(
        'Falló la carga del historial. Código: ${response.statusCode}',
      );
    }
  }

  // Helper para crear y configurar el widget de gráfico
  Widget buildLineChart(List<Measurement> historyData) {
    // Invertimos la lista para que el tiempo corra de izquierda (viejo) a derecha (nuevo) en el gráfico.
    final List<Measurement> reversedData = historyData.reversed.toList();

    // Calcula la frecuencia de etiquetas X para no saturar el gráfico
    final double intervaloEjeX = (reversedData.length / 5)
        .floorToDouble()
        .clamp(1, 100)
        .toDouble();

    // Convierte los datos de Measurement a FlSpot (X=índice, Y=temperatura)
    final List<FlSpot> spots = reversedData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.temperatureC);
    }).toList();

    return LineChart(
      LineChartData(
        // Configuraciones básicas
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey, width: 1),
        ),

        // Títulos y etiquetas
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),

          // Etiquetas Eje X (Tiempo)
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: intervaloEjeX,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < reversedData.length) {
                  final time = reversedData[index].timestamp;
                  // Muestra la hora y minutos de la medición
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 8.0,
                    child: Text(
                      '${time.hour}:${time.minute}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),

          // Etiquetas Eje Y (Temperatura)
          leftTitles: const AxisTitles(
            axisNameWidget: Text('Temp (°C)'),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 1.0,
            ),
          ),
        ),

        // Línea de Datos
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Histórico de ${widget.friendlyName}'),
      ), // ⭐️ USAR friendlyName ⭐️
      body: FutureBuilder<List<Measurement>>(
        future: futureHistory,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text('Error al cargar el historial: ${snapshot.error}'),
            );
          } else if (snapshot.hasData) {
            final historyData = snapshot.data!;
            if (historyData.isEmpty) {
              return const Center(child: Text('No hay datos históricos.'));
            }

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ⭐️ GRÁFICO DE TEMPERATURA
                  Container(
                    height: 300,
                    padding: const EdgeInsets.all(12.0),
                    child: buildLineChart(
                      historyData,
                    ), // Llama al helper del gráfico
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Text(
                      'Detalles del Historial (Más Reciente Primero):',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // LISTADO COMPLETO DEL HISTORIAL
                  // historyData ya está ordenado del más nuevo al más viejo por la API
                  ...historyData
                      .map(
                        (m) => ListTile(
                          title: Text(
                            '${m.temperatureC.toStringAsFixed(2)} °C',
                          ),
                          subtitle: Text('Fecha: ${m.timestamp}'),
                          trailing: Text(
                            'Pila: ${m.voltageV.toStringAsFixed(2)} V',
                          ),
                        ),
                      )
                      .toList(),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
