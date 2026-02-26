import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart'; 

// Importa el archivo de configuración de tu proyecto
// Asegúrate de que 'config.dart' exista y contenga String apiBase = '...';
import 'config.dart'; 

// Definición de la URL completa para el endpoint de recaudo
final String recaudoApiUrl = '${Config.apiBase}/recaudo_cartera.php';

class RecaudoCarteraScreen extends StatefulWidget {
  const RecaudoCarteraScreen({super.key});

  @override
  State<RecaudoCarteraScreen> createState() => _RecaudoCarteraScreenState();
}

class _RecaudoCarteraScreenState extends State<RecaudoCarteraScreen> {
  // 1. Estados de la aplicación
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  double _recaudoTotal = 0.0;
  bool _isLoading = false;
  String _errorMessage = '';

  // 2. Formateadores
  // AJUSTE CRÍTICO AQUÍ: Usamos un patrón custom para forzar el símbolo '$' a la izquierda,
  // ya que el locale 'es_CO' por defecto lo coloca a la derecha.
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0, 
    // Patrón personalizado: '$' antes del número. Esto soluciona el problema visual.
    customPattern: '\u00A4#,##0', 
  );

  // Formateador de fecha para la API (yyyy-MM-dd)
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  // 3. Selección de Fecha
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      locale: const Locale('es', 'ES'),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _fechaInicio = picked;
        } else {
          _fechaFin = picked;
        }
        _recaudoTotal = 0.0;
        _errorMessage = '';
      });
    }
  }

  // 4. Petición HTTP para obtener el Recaudo
  Future<void> _fetchRecaudo() async {
    if (_fechaInicio == null || _fechaFin == null) {
      setState(() {
        _errorMessage = "Por favor, selecciona las dos fechas del rango.";
      });
      return;
    }
    
    if (_fechaInicio!.isAfter(_fechaFin!)) {
      setState(() {
        _errorMessage = "La fecha de inicio no puede ser posterior a la fecha de fin.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _recaudoTotal = 0.0;
    });

    try {
      final response = await http.post(
        Uri.parse(recaudoApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'fecha_inicio': _dateFormat.format(_fechaInicio!),
          'fecha_fin': _dateFormat.format(_fechaFin!),
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (data['success'] == true) {
          final total = data['recaudo_total'] ?? 0.0;
          setState(() {
            _recaudoTotal = double.tryParse(total.toString()) ?? 0.0;
          });
        } else {
          setState(() {
            _errorMessage = data['message'] ?? 'Error desconocido en la respuesta del servidor.';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Error del servidor: Código ${response.statusCode}. Intenta de nuevo.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error de conexión: Verifica tu red o la URL de la API.';
      });
      print('Error al consultar recaudo: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 5. Widget para mostrar la selección de fecha
  Widget _dateDisplayButton(BuildContext context, DateTime? date, String label, bool isStartDate) {
    return Expanded(
      child: OutlinedButton.icon(
        icon: const Icon(Icons.calendar_today, size: 18),
        label: Text(
          date == null ? label : _dateFormat.format(date),
          style: const TextStyle(fontSize: 16),
        ),
        onPressed: () => _selectDate(context, isStartDate),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: Colors.blue, width: 1),
        ),
      ),
    );
  }
  
  // 6. Card Profesional para mostrar el total
  Widget _buildRecaudoCard() {
    return Card(
      elevation: 8,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            colors: [Colors.green.shade700, Colors.green.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Recaudo Total Neto (Abonado)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 10),
            // Muestra el total formateado
            Text(
              _currencyFormat.format(_recaudoTotal),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _fechaInicio != null && _fechaFin != null
                  ? 'Período: ${_dateFormat.format(_fechaInicio!)} al ${_dateFormat.format(_fechaFin!)}'
                  : 'Seleccione un rango de fechas para consultar.',
              style: TextStyle(
                color: Colors.green.shade100,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte de Recaudo'),
        backgroundColor: Colors.green.shade600,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // -------------------- SELECTORES DE FECHA --------------------
            Row(
              children: <Widget>[
                _dateDisplayButton(context, _fechaInicio, 'Fecha Inicio', true),
                const SizedBox(width: 10),
                _dateDisplayButton(context, _fechaFin, 'Fecha Fin', false),
              ],
            ),
            
            const SizedBox(height: 20),

            // -------------------- BOTÓN DE CONSULTA --------------------
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _fetchRecaudo,
              icon: _isLoading 
                ? const SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                  )
                : const Icon(Icons.search),
              label: Text(
                _isLoading ? 'Consultando...' : 'Consultar Recaudo',
                style: const TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 5,
              ),
            ),

            const SizedBox(height: 30),

            // -------------------- CARD DE RESULTADOS --------------------
            _buildRecaudoCard(),

            // -------------------- MENSAJE DE ERROR --------------------
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Error: $_errorMessage',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
