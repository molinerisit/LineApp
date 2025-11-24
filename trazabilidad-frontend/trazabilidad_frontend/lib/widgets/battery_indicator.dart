// lib/widgets/battery_indicator.dart

import 'package:flutter/material.dart';

class BatteryIndicator extends StatelessWidget {
  final double voltage;

  const BatteryIndicator({super.key, required this.voltage});

  // Simple lógica para convertir Voltaje a Porcentaje y color.
  // Asume 6.0V = 100% y 4.0V = 0%
  double get batteryPercentage {
    // Escala (6.0 - 4.0) = 2.0V de rango
    final maxVoltage = 6.0;
    final minVoltage = 4.0;
    final percentage = ((voltage - minVoltage) / (maxVoltage - minVoltage)) * 100;
    return percentage.clamp(0.0, 100.0); // Asegura que esté entre 0 y 100
  }

  Color get batteryColor {
    if (batteryPercentage > 50) return Colors.green;
    if (batteryPercentage > 20) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      color: Colors.grey[200],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Batería del Sistema:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              Text(
                '${batteryPercentage.toStringAsFixed(0)}%', 
                style: TextStyle(color: batteryColor, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.battery_full,
                color: batteryColor,
              ),
              Text('(${voltage.toStringAsFixed(2)} V)'),
            ],
          ),
        ],
      ),
    );
  }
}