import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart'; 
import 'config.dart';
// IMPORTANTE: Asegúrate de que este nombre de archivo sea el correcto
import 'consultapagosscreen.dart'; 

class PagosScreen extends StatefulWidget {
  const PagosScreen({super.key});

  @override
  State<PagosScreen> createState() => _PagosScreenState();
}

class _PagosScreenState extends State<PagosScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _clientesEncontrados = [];
  bool _isSearching = false;

  /// Formateador de moneda: Fuerza el símbolo $ a la izquierda y usa separador de miles
  String _formatCurrency(dynamic value) {
    double amount = double.tryParse(value.toString()) ?? 0.0;
    final formatter = NumberFormat('#,##0.00', 'es_CO');
    return '\$ ${formatter.format(amount)}';
  }

  Future<void> _buscarClientes(String query) async {
    final String sanitizedQuery = query.trim();
    if (sanitizedQuery.isEmpty) {
      setState(() {
        _clientesEncontrados = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final url = Uri.parse("${Config.apiBase}/buscar_cliente_pagos.php");
      final response = await http.post(
        url,
        body: {'search_term': sanitizedQuery},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dynamic decodedData = json.decode(response.body);
        if (decodedData is List) {
          setState(() {
            _clientesEncontrados = List<Map<String, dynamic>>.from(decodedData);
          });
        }
      } else {
        _mostrarError("Error del servidor: ${response.statusCode}");
      }
    } catch (e) {
      _mostrarError("Error de conexión. Verifique su internet.");
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.redAccent),
    );
  }

  /// Muestra todas las fechas de cobro en un diálogo
  void _mostrarCalendarioPagos(String fechas) {
    List<String> listaFechas = fechas.split(',');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Calendario de Cobros", style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: listaFechas.length,
            itemBuilder: (context, i) => ListTile(
              leading: const Icon(Icons.calendar_today, size: 18, color: Color(0xFF0077B6)),
              title: Text(listaFechas[i].trim(), style: const TextStyle(fontSize: 14)),
              dense: true,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar", style: TextStyle(color: Color(0xFF0077B6))),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Gestión de Pagos", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0077B6),
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildSearchField(),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _buildResultsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF0077B6),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          hintText: "Nombre o Cédula del cliente...",
          prefixIcon: const Icon(Icons.search, color: Color(0xFF0077B6)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
        onChanged: _buscarClientes,
      ),
    );
  }

  Widget _buildResultsList() {
    if (_clientesEncontrados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Text(
              _searchController.text.isEmpty 
                  ? "Inicie la búsqueda de un cliente" 
                  : "No hay préstamos activos",
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _clientesEncontrados.length,
      itemBuilder: (context, index) => _buildClienteCard(_clientesEncontrados[index]),
    );
  }

  Widget _buildClienteCard(Map<String, dynamic> item) {
    final String nombre = (item['nombre'] ?? 'Sin nombre').toString().toUpperCase();
    final String cedula = (item['cedula'] ?? 'N/A').toString();
    final String totalFormateado = _formatCurrency(item['valor_total']);
    final String cuotaFormateada = _formatCurrency(item['valor_cuota']);
    final String cuotas = (item['cantidad_cuotas'] ?? '0').toString();
    
    String todasLasFechas = item['fechas_cobro'] ?? '';
    List<String> listaFechas = todasLasFechas.isNotEmpty ? todasLasFechas.split(',') : [];
    String proximaFecha = listaFechas.isNotEmpty ? listaFechas[0].trim() : 'No definida';

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Container(
              color: const Color(0xFF00B4D8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white70),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _infoRow(Icons.badge_outlined, "Cédula", cedula),
                  _infoRow(Icons.phone_outlined, "Teléfono", item['telefono'] ?? 'N/A'),
                  const Divider(height: 25),
                  _infoRow(Icons.calendar_month_outlined, "Fecha del Préstamo", item['fecha_creacion'] ?? 'N/A'),
                  _infoRow(Icons.attach_money, "Valor Total", totalFormateado, color: Colors.green[700], isBold: true),
                  _infoRow(Icons.payments, "Valor Cuota", cuotaFormateada, color: Colors.blue[800]),
                  _infoRow(Icons.numbers, "Cantidad de Cuotas", cuotas),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.event_note, size: 18, color: Colors.blueGrey[400]),
                        const SizedBox(width: 8),
                        const Text("Próx. Cobro: ", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Expanded(
                          child: Text(proximaFecha, textAlign: TextAlign.end, style: const TextStyle(fontSize: 14)),
                        ),
                        if(listaFechas.length > 1)
                          IconButton(
                            icon: const Icon(Icons.date_range, color: Color(0xFF0077B6), size: 20),
                            onPressed: () => _mostrarCalendarioPagos(todasLasFechas),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            visualDensity: VisualDensity.compact,
                            tooltip: "Ver todas las fechas",
                          )
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => _abrirFormularioAbono(item),
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text("REALIZAR ABONO", style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey[400]),
          const SizedBox(width: 8),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: color ?? Colors.black87,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Función actualizada para abrir el modal inferior con el formulario de abono
  void _abrirFormularioAbono(Map<String, dynamic> cliente) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Importante para que el teclado no tape el modal
      backgroundColor: Colors.transparent, // Permite bordes redondeados personalizados
      builder: (context) {
        return ConsultaPagosScreen(cliente: cliente);
      },
    );
  }
}