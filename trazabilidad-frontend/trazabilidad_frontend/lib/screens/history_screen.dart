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
  final String friendlyName; 
  const HistoryScreen({
    super.key,
    required this.sensorId,
    required this.friendlyName,
  }); 
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

    // ⭐️ CÁLCULO DE RANGOS DEL EJE Y (Optimizado para legibilidad) ⭐️
    double minY = spots.map((spot) => spot.y).reduce((a, b) => a < b ? a : b);
    double maxY = spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);

    minY = (minY - 1).floorToDouble();
    maxY = (maxY + 1).ceilToDouble();
    
    // Aseguramos que el eje Y tenga al menos 4 divisiones visibles
    double intervalY = ((maxY - minY) / 4).ceilToDouble().clamp(1.0, 5.0);
    if (maxY - minY < 1) {
      intervalY = 0.5;
    }

    return LineChart(
      LineChartData(
        backgroundColor: Colors.blue.withOpacity(0.05),
        minX: 0,
        maxX: (reversedData.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,

        // Configuraciones de la grilla
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          getDrawingHorizontalLine: (value) {
            return const FlLine(
              color: Color(0xff37434d),
              strokeWidth: 0.5,
              dashArray: [5, 5], // Línea punteada
            );
          },
          getDrawingVerticalLine: (value) {
            return const FlLine(
              color: Color(0xff37434d),
              strokeWidth: 0.5,
            );
          },
        ),
        
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: const Color(0xff37434d), width: 1),
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
            axisNameWidget: const Text('Tiempo', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
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
                      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 10, color: Colors.black54),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),

          // Etiquetas Eje Y (Temperatura)
          leftTitles: AxisTitles(
            axisNameWidget: const Text('Temp (°C)', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: intervalY, 
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(intervalY < 1 ? 1 : 0),
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                );
              },
            ),
          ),
        ),

        // Línea de Datos
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: LinearGradient(
              colors: [
                Colors.blue.shade800,
                Colors.blue.shade400,
              ],
            ),
            barWidth: 3,
            dotData: const FlDotData(show: false), 
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Colors.blue.withOpacity(0.3),
                  Colors.blue.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
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
        backgroundColor: Theme.of(context).primaryColor, 
      ), 
      body: FutureBuilder<List<Measurement>>(
        future: futureHistory,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error al cargar el historial: ${snapshot.error}', textAlign: TextAlign.center),
              ),
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
                  // ⭐️ GRÁFICO: USAMOS SIZEDBOX DE ALTURA REDUCIDA (250) ⭐️
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                        child: SizedBox( // ⭐️ USAMOS SIZEDBOX EN LUGAR DE ASPECT RATIO ⭐️
                          height: 250, // ⭐️ ALTURA FIJA MÁS PEQUEÑA ⭐️
                          child: buildLineChart(
                            historyData,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 16.0,
                    ),
                    child: Text(
                      'Detalles del Historial:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),

                  // ⭐️ LISTADO MEJORADO CON DATATABLE ⭐️
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal, // Permite scroll horizontal si los datos son muy anchos
                        child: DataTable(
                          columnSpacing: 16,
                          dataRowMinHeight: 30,
                          dataRowMaxHeight: 40,
                          headingRowHeight: 40,
                          columns: const [
                            DataColumn(label: Text('Fecha y Hora', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Temp (°C)', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                            DataColumn(label: Text('Pila (V)', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                          ],
                          rows: historyData.map((m) {
                            final String formattedDate = 
                                '${m.timestamp.day.toString().padLeft(2, '0')}/${m.timestamp.month.toString().padLeft(2, '0')} '
                                '${m.timestamp.hour.toString().padLeft(2, '0')}:${m.timestamp.minute.toString().padLeft(2, '0')}:${m.timestamp.second.toString().padLeft(2, '0')}';
                            
                            final bool isLowVoltage = m.voltageV < 4.2;

                            return DataRow(cells: [
                              DataCell(Text(formattedDate, style: const TextStyle(fontSize: 12))),
                              DataCell(Text(m.temperatureC.toStringAsFixed(2), textAlign: TextAlign.right)),
                              DataCell(
                                Text(
                                  m.voltageV.toStringAsFixed(2),
                                  textAlign: TextAlign.right,
                                  style: TextStyle(color: isLowVoltage ? Colors.red : Colors.green.shade700, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
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