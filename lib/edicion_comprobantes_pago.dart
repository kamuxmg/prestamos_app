import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart'; // Librería para formato de números
import 'config.dart';

class EdicionComprobantesPagoScreen extends StatefulWidget {
  const EdicionComprobantesPagoScreen({super.key});

  @override
  State<EdicionComprobantesPagoScreen> createState() => _EdicionComprobantesPagoScreenState();
}

class _EdicionComprobantesPagoScreenState extends State<EdicionComprobantesPagoScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _pagos = [];
  bool _isLoading = false;

  // Formateador con patrón explícito para asegurar el $ a la izquierda
  final NumberFormat _currencyFormat = NumberFormat.decimalPattern('es_CO');

  // Función auxiliar para dar formato de miles con $ a la izquierda
  String _formatCurrency(dynamic value) {
    if (value == null) return "\$ 0";
    try {
      final double number = double.parse(value.toString());
      // Forzamos el símbolo al inicio y usamos el formato de miles
      return "\$ ${_currencyFormat.format(number)}";
    } catch (e) {
      return "\$ $value";
    }
  }

  // Función para buscar coincidencias en tiempo real
  Future<void> _buscarPagos(String termino) async {
    if (termino.length < 3) {
      setState(() => _pagos = []);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("${Config.apiBase}/obtener_historial_pagos.php"),
        body: {'termino': termino},
      );

      final data = json.decode(response.body);
      if (data['success']) {
        setState(() => _pagos = data['pagos']);
      } else {
        setState(() => _pagos = []);
      }
    } catch (e) {
      debugPrint("Error de conexión: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _ejecutarAnulacion(String idRecibo) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse("${Config.apiBase}/anular_pago.php"),
        body: {'id_pago': idRecibo},
      );

      final data = json.decode(response.body);
      if (data['success']) {
        _showSnack("¡Recibo #$idRecibo anulado correctamente!");
        _buscarPagos(_searchController.text); 
      } else {
        _showSnack("Error: ${data['message']}");
      }
    } catch (e) {
      _showSnack("Error al procesar la anulación");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _confirmarAnulacion(Map pago) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text("Confirmar Reversa"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("¿Está seguro de anular el recibo #${pago['recibo']}?"),
            const SizedBox(height: 10),
            Text("Cliente: ${pago['cliente']}", style: const TextStyle(fontWeight: FontWeight.bold)),
            Text("Monto: ${_formatCurrency(pago['valor_abonado'])}", 
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            const Text("Se restaurará el saldo en la tabla de cuotas y el préstamo volverá a estar activo.", 
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _ejecutarAnulacion(pago['recibo'].toString());
            },
            child: const Text("ANULAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], 
      appBar: AppBar(
        title: const Text("Reversar Abonos"),
        backgroundColor: const Color(0xFF004D40), 
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Buscador Profesional
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            decoration: const BoxDecoration(
              color: Color(0xFF004D40),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(25), bottomRight: Radius.circular(25)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _buscarPagos, 
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: "Buscar por nombre o cédula...",
                prefixIcon: const Icon(Icons.search, color: Color(0xFF004D40)),
                suffixIcon: _searchController.text.isNotEmpty 
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                      _searchController.clear();
                      setState(() => _pagos = []);
                    }) 
                  : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
          ),

          if (_isLoading) const LinearProgressIndicator(color: Colors.orange),

          Expanded(
            child: _pagos.isEmpty 
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _pagos.length,
                    itemBuilder: (context, index) {
                      final pago = _pagos[index];
                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                                    child: Text("RECIBO #${pago['recibo']}", 
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                                  ),
                                  Text("${pago['fecha_pago']}".substring(0, 10), 
                                    style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                ],
                              ),
                              const Divider(height: 20),
                              Row(
                                children: [
                                  const Icon(Icons.person, size: 20, color: Colors.blueGrey),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text("${pago['cliente']}", 
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("CUOTA", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                      Text("#${pago['numero_cuota']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text("VALOR ABONADO", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                      Text(_formatCurrency(pago['valor_abonado']), 
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 18)),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red[50],
                                    foregroundColor: Colors.red,
                                    elevation: 0,
                                    side: const BorderSide(color: Colors.red, width: 0.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.delete_forever, size: 18),
                                  label: const Text("ANULAR ESTE ABONO", style: TextStyle(fontWeight: FontWeight.bold)),
                                  onPressed: () => _confirmarAnulacion(pago),
                                ),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("Escriba el nombre del cliente", style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }
}