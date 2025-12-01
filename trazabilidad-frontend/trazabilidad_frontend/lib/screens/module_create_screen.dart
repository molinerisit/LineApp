// lib/screens/module_create_screen.dart

import 'package:flutter/material.dart';
import '../services/api_service.dart';
// ⭐️ YA NO IMPORTAMOS constants.dart AQUÍ ⭐️

class ModuleCreateScreen extends StatefulWidget {
  const ModuleCreateScreen({super.key});

  @override
  State<ModuleCreateScreen> createState() => _ModuleCreateScreenState();
}

class _ModuleCreateScreenState extends State<ModuleCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _thresholdController = TextEditingController(text: '5.0');
  final _voltageThresholdController = TextEditingController(text: '4.2');

  // ⭐️ NUEVO: Future para cargar la lista de IDs ⭐️
  late Future<List<String>> _availableHardwareIdsFuture;

  String? _selectedHardwareId; 
  String _selectedType = 'sensor';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // ⭐️ INICIAMOS LA CARGA DE DATOS DESDE LA API ⭐️
    _availableHardwareIdsFuture = ApiService.getAvailableHardwareIds();
  }

  Future<void> _createModule() async {
    // Validar formulario y asegurar que se seleccionó un ID
    if (!_formKey.currentState!.validate() || _selectedHardwareId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleccione un ID de Hardware válido.')));
      return;
    }
    
    final alertThreshold = double.tryParse(_thresholdController.text.trim());
    final voltageThreshold = double.tryParse(_voltageThresholdController.text.trim());

    if (alertThreshold == null || voltageThreshold == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Umbrales inválidos')));
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    // LLAMADA A LA API PARA CONFIGURAR EL SENSOR
    final success = await ApiService.createModule(
      _selectedHardwareId!, 
      _nameController.text.trim(),
      _selectedType,
      alertThresholdC: alertThreshold, 
      voltageThresholdV: voltageThreshold,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? 'Heladera configurada con éxito' : 'Error al configurar heladera')),
    );

    if (success && mounted) Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _thresholdController.dispose();
    _voltageThresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurar Heladera')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // ⭐️ DROPDOWN CARGADO POR FUTUREBUILDER ⭐️
                FutureBuilder<List<String>>(
                  future: _availableHardwareIdsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return const Text('Error al cargar IDs. Verifique el servidor.');
                    } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      final availableIds = snapshot.data!;
                      return DropdownButtonFormField<String>(
                        value: _selectedHardwareId,
                        items: availableIds.map((String id) {
                          return DropdownMenuItem<String>(
                            value: id,
                            child: Text(id),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedHardwareId = newValue;
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'ID de Hardware (Puerto Lógico)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => (value == null || value.isEmpty) ? 'Seleccione un puerto' : null,
                      );
                    } else {
                       // Caso de que la lista esté vacía o el servidor no devolvió IDs
                      return const Text('No se encontraron IDs de hardware disponibles.');
                    }
                  },
                ),
                
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nombre Amigable (ej: Cocina Principal)', border: OutlineInputBorder()),
                  validator: (value) => (value == null || value.isEmpty) ? 'Ingrese el nombre' : null,
                ),
                
                // ⭐️ CAMPOS DE UMBRAL DE ALERTA ⭐️
                if (_selectedType == 'sensor') ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _thresholdController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Umbral Máximo de Temperatura (°C)', 
                      prefixIcon: Icon(Icons.thermostat),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => (value == null || double.tryParse(value) == null) ? 'Ingrese una temperatura válida' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _voltageThresholdController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Umbral Mínimo de Pila (V)', 
                      prefixIcon: Icon(Icons.battery_alert),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => (value == null || double.tryParse(value) == null) ? 'Ingrese un voltaje válido (ej: 4.2)' : null,
                  ),
                ],
                
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  items: const [
                    DropdownMenuItem(value: 'sensor', child: Text('Sensor de Temperatura')),
                    DropdownMenuItem(value: 'actuator', child: Text('Actuador (No usado aquí)')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedType = value);
                  },
                  decoration: const InputDecoration(labelText: 'Tipo de módulo', border: OutlineInputBorder()),
                ),
                
                const SizedBox(height: 24),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _createModule,
                          child: const Text('Guardar Configuración'),
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}