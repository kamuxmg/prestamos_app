import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart'; // <--- Uso la configuración centralizada
import 'package:intl/intl.dart'; // <--- 1. Importación necesaria para el formato de moneda

// Se elimina la constante _apiUrl codificada. La URL se construye usando Config.apiBase.

class ReporteRentabilidadScreen extends StatefulWidget {
  const ReporteRentabilidadScreen({super.key});

  @override
  State<ReporteRentabilidadScreen> createState() => _ReporteRentabilidadScreenState();
}

class _ReporteRentabilidadScreenState extends State<ReporteRentabilidadScreen> {
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  Map<String, double> _reporteData = {};
  bool _isLoading = false;
  String? _errorMessage;

  // --- NUEVA FUNCIÓN DE FORMATO DE MONEDA ---
  // Utiliza el paquete intl para dar formato con separador de miles y símbolo de moneda.
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_CO', // o la localización que necesites
    symbol: '\$',
    decimalDigits: 2, // Muestra 2 decimales
    // AJUSTE CLAVE: Define el patrón para forzar el símbolo a la izquierda: $#,##0.00
    // La localización es_CO debería usarlo a la izquierda, pero este patrón lo asegura.
    customPattern: '\u00A4#,##0.00', // \u00A4 es el placeholder del símbolo de moneda
  );

  String _formatCurrency(double value) {
    return _currencyFormat.format(value);
  }
  // ------------------------------------------

  // Función para seleccionar la fecha
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _fechaInicio = picked;
        } else {
          _fechaFin = picked;
        }
      });
    }
  }

  // Función principal para obtener los datos del reporte
  Future<void> _fetchReporte() async {
    if (_fechaInicio == null || _fechaFin == null) {
      setState(() {
        _errorMessage = 'Por favor, selecciona las fechas de inicio y fin.';
      });
      return;
    }

    if (_fechaInicio!.isAfter(_fechaFin!)) {
      setState(() {
        _errorMessage = 'La fecha de inicio no puede ser posterior a la fecha de fin.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // AJUSTE CLAVE: Usar Config.apiBase y adjuntar el nombre del script PHP.
      final url = Uri.parse("${Config.apiBase}/reporte_rentabilidad.php");

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'fecha_inicio': _fechaInicio!.toIso8601String().split('T').first,
          'fecha_fin': _fechaFin!.toIso8601String().split('T').first,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // Verifica si la respuesta contiene un error del servidor (PHP)
        if (data.containsKey('success') && data['success'] == false) {
              setState(() {
                _errorMessage = 'Error del servidor: ${data['message']}';
              });
              return;
        }

        // El PHP retorna los valores como strings (decimales), los parseamos a double
        setState(() {
          _reporteData = {
            'Recaudo_Total': double.parse(data['Recaudo_Total'].toString()),
            'Capital_Retornado_Recaudado': double.parse(data['Capital_Retornado_Recaudado'].toString()),
            'Rentabilidad_Ganancia_Recaudada': double.parse(data['Rentabilidad_Ganancia_Recaudada'].toString()),
          };
        });
      } else {
        setState(() {
          _errorMessage = 'Error al cargar datos: Código HTTP ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        // Mensaje de error mejorado para el usuario
        _errorMessage = 'Error de conexión: Asegúrate que XAMPP esté corriendo. Detalle: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte de Rentabilidad 💰'),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // --- Selector de Fechas ---
            _buildDateSelector(context, Icons.calendar_today, 'Fecha de Inicio', _fechaInicio, true),
            const SizedBox(height: 10),
            _buildDateSelector(context, Icons.calendar_today, 'Fecha de Fin', _fechaFin, false),
            const SizedBox(height: 20),

            // --- Botón de Generar Reporte ---
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _fetchReporte,
              icon: _isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.show_chart),
              label: Text(_isLoading ? 'Cargando...' : 'Generar Reporte', style: const TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),

            const SizedBox(height: 30),

            // --- Mensajes de Estado ---
            if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),

            // --- Resultados del Reporte ---
            if (_reporteData.isNotEmpty)
              _buildReporteResultados(),
          ],
        ),
      ),
    );
  }

  // Helper para el selector de fecha
  Widget _buildDateSelector(BuildContext context, IconData icon, String label, DateTime? date, bool isStartDate) {
    return InkWell(
      onTap: () => _selectDate(context, isStartDate),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blueGrey),
          border: const OutlineInputBorder(),
        ),
        child: Text(
          date == null ? 'Seleccionar fecha' : '${date.day}/${date.month}/${date.year}',
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  // Helper para mostrar los resultados
  Widget _buildReporteResultados() {
    return Column(
      children: [
        const Text('Resultados del Recaudo por Período:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const Divider(),

        // Recaudo Total
        _buildMetricCard(
          'Recaudo Total',
          _reporteData['Recaudo_Total']!,
          Colors.blue,
          Icons.attach_money
        ),

        // Capital Retornado
        _buildMetricCard(
          'Retorno de Capital',
          _reporteData['Capital_Retornado_Recaudado']!,
          Colors.green,
          Icons.paid
        ),

        // Rentabilidad/Ganancia (El KPI clave)
        _buildMetricCard(
          'Rentabilidad (Ganancia)',
          _reporteData['Rentabilidad_Ganancia_Recaudada']!,
          Colors.orange,
          Icons.trending_up
        ),
      ],
    );
  }

  // Helper para mostrar cada métrica en una tarjeta
  Widget _buildMetricCard(String title, double value, Color color, IconData icon) {
    // 2. Uso de la nueva función de formato
    final formattedValue = _formatCurrency(value); 

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: color, size: 35),
        title: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        trailing: Text(
          formattedValue, // <--- Ahora el formato incluye el '$' a la izquierda
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}