import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart'; 
import 'config.dart';

class ConsultaPagosScreen extends StatefulWidget {
  final Map<String, dynamic> cliente;

  const ConsultaPagosScreen({super.key, required this.cliente});

  @override
  State<ConsultaPagosScreen> createState() => _ConsultaPagosScreenState();
}

class _ConsultaPagosScreenState extends State<ConsultaPagosScreen> {
  final TextEditingController _montoAbonoController = TextEditingController();
  bool _pagarCuotaChecked = false;
  bool _pagarTotalChecked = false;
  
  double _saldoActualizado = 0.0;
  double _saldoPendienteCuotaActual = 0.0; 
  // Nueva variable para manejar el saldo pendiente arrastrado de cuotas anteriores
  double _saldoMoraAcumulado = 0.0; 
  int _numeroCuotaActual = 0;
  
  bool _isLoadingSaldo = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _obtenerUltimoSaldo();
  }

  String _fCurrency(dynamic value) {
    double amount = double.tryParse(value.toString()) ?? 0.0;
    return NumberFormat.currency(
      customPattern: '\$ #,##0.00',
      decimalDigits: 2,
    ).format(amount);
  }

  Future<void> _enviarWhatsApp({
    required String nombre,
    required String telefonoCliente, // NUEVO PARÁMETRO
    required String idPago,
    required String cedula,
    required double valorAbonado,
    required double saldoRestante,
    required String detalleCuotas,
    required int restanCuotas, 
    required double saldoPendienteAnterior, // NUEVO
    required double nuevoSaldoPendiente,    // NUEVO
  }) async {
    
    // Limpiar el número de formato (espacios, guiones, etc)
    String telefonoDestino = telefonoCliente.replaceAll(RegExp(r'\D'), '');
    
    // Asumiendo código de Colombia (+57). Ajústalo al código de tu país si es necesario.
    if (!telefonoDestino.startsWith('57') && telefonoDestino.length == 10) {
      telefonoDestino = '57$telefonoDestino';
    }

    if (telefonoDestino.isEmpty) {
      _showSnackBar("El cliente no tiene un teléfono registrado para enviar el comprobante.", Colors.orange);
      return;
    }

    final String fechaHora = DateFormat('dd/MM/yyyy - hh:mm a').format(DateTime.now());
    final String valorAbonadoStr = _fCurrency(valorAbonado);
    final String saldoRestanteStr = _fCurrency(saldoRestante);

    // Solo mostramos estas líneas si hay un valor pendiente real
    String infoMoraAnterior = saldoPendienteAnterior > 0 
        ? '⚠️ *Saldo Pend. Anterior:* ${_fCurrency(saldoPendienteAnterior)}\n' 
        : '';
        
    String infoMoraNueva = nuevoSaldoPendiente > 0 
        ? '⚠️ *Pasa a Sig. Cuota:* ${_fCurrency(nuevoSaldoPendiente)}\n' 
        : '';

    final String mensaje = 
        '*----------------------------------------*\n'
        '* AC INVERSIONES                          *\n'
        '*----------------------------------------*\n\n'
        '*¡Hola $nombre!* 👋\n\n'
        '📄 *COMPROBANTE DE PAGO *\n'
        '----------------------------------------\n'
        '🧾 *ID Pago:* #$idPago\n'
        '🗓️ *Fecha y Hora:* $fechaHora\n'
        '👤 *Cédula:* $cedula\n'
        '----------------------------------------\n'
        '$infoMoraAnterior'
        '💵 *VALOR ABONADO:* $valorAbonadoStr\n'
        '$infoMoraNueva'
        '🔖 *Cuota Aplicada:* $detalleCuotas\n'
        '----------------------------------------\n'
        '➡️ *Saldo Restante:* *$saldoRestanteStr*\n'
        '----------------------------------------\n'
        '📌 *Nota:* Restan $restanCuotas cuotas para terminar.\n'
        '----------------------------------------\n\n'
        '¡Gracias por preferir nuestros servicios!';

    final Uri whatsappUrl = Uri.parse(
      "https://api.whatsapp.com/send?phone=$telefonoDestino&text=${Uri.encodeComponent(mensaje)}"
    );

    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } else {
      _showSnackBar("No se pudo abrir WhatsApp", Colors.red);
    }
  }

  Future<void> _obtenerUltimoSaldo() async {
    try {
      final response = await http.post(
        Uri.parse("${Config.apiBase}/obtener_saldo_actual_modal_pagos.php"),
        body: {'id_prestamo': widget.cliente['id_prestamo'].toString()},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _saldoActualizado = double.tryParse(data['saldo_restante'].toString()) ?? 0.0;
            _saldoPendienteCuotaActual = double.tryParse(data['saldo_cuota_actual'].toString()) ?? 0.0;
            _numeroCuotaActual = int.tryParse(data['numero_cuota_actual'].toString()) ?? 0;
            
            // Aquí capturaremos el saldo pendiente acumulado cuando ajustemos el PHP
            // Si el PHP no lo envía aún, será 0.0 y no afectará nada.
            _saldoMoraAcumulado = double.tryParse(data['saldo_pendiente_anterior'].toString()) ?? 0.0;
            
            _isLoadingSaldo = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSaldo = false);
        debugPrint("Error al cargar saldo: $e");
      }
    }
  }

  Future<void> _procesarPago() async {
    final String montoStr = _montoAbonoController.text.trim();
    final double? monto = double.tryParse(montoStr);

    if (monto == null || monto <= 0) {
      _showSnackBar("Por favor, ingrese un monto válido", Colors.orange);
      return;
    }

    setState(() => _isProcessing = true);

    // Calculamos previo al envío cuánto se espera pagar exactamente hoy
    final double valorCuotaFijaOriginal = double.tryParse(widget.cliente['valor_cuota'].toString()) ?? 0.0;
    final double valorTotalCuotaActual = valorCuotaFijaOriginal + _saldoMoraAcumulado;
    final double montoParaCompletarCuota = (_saldoPendienteCuotaActual > 0) 
        ? _saldoPendienteCuotaActual 
        : valorTotalCuotaActual;

    // Calculamos el posible faltante para pasarlo al recibo (por si el backend no lo manda aún)
    double faltanteCalculado = montoParaCompletarCuota - monto;
    if (faltanteCalculado < 0) faltanteCalculado = 0.0; // Pagó completo o de más

    try {
      final response = await http.post(
        Uri.parse("${Config.apiBase}/procesar_abono_recalculo.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'id_prestamo': widget.cliente['id_prestamo'].toString(),
          'valor_abonado': monto, 
          'metodo_pago': 'Efectivo',
          'observaciones': 'Abono con redistribución de saldo',
        }),
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        
        final int totalCuotasGlobal = int.tryParse(widget.cliente['cantidad_cuotas'].toString()) ?? 0;
        final int nCuotaActual = int.tryParse(data['numero_cuota_actual']?.toString() ?? _numeroCuotaActual.toString()) ?? 0;
        final int cuotasRestantes = int.tryParse(data['cuotas_restantes']?.toString() ?? "0") ?? 0;

        // Si el backend nos envía el "saldo_pendiente_cuota", lo tomamos. Si no, usamos el que calculamos arriba.
        final double nuevoSaldoPendienteReal = double.tryParse(data['saldo_pendiente_cuota']?.toString() ?? faltanteCalculado.toString()) ?? 0.0;

        if (mounted) {
          setState(() {
            if (data['nueva_cuota_fija'] != null) {
              widget.cliente['valor_cuota'] = data['nueva_cuota_fija'].toString();
            }
            _saldoActualizado = double.tryParse(data['nuevo_saldo_global'].toString()) ?? (_saldoActualizado - monto);
            _montoAbonoController.clear();
            _pagarCuotaChecked = false;
            _pagarTotalChecked = false;
          });
        }

        _showSnackBar("Pago registrado correctamente.", Colors.green);
        
        await _enviarWhatsApp(
          nombre: widget.cliente['nombre'].toString().toUpperCase(),
          telefonoCliente: widget.cliente['telefono']?.toString() ?? '', // PASAMOS EL TELÉFONO AQUÍ
          idPago: data['id_pago']?.toString() ?? "N/A", 
          cedula: widget.cliente['cedula'].toString(),
          valorAbonado: monto,
          saldoRestante: _saldoActualizado,
          detalleCuotas: "Cuota $nCuotaActual de $totalCuotasGlobal",
          restanCuotas: cuotasRestantes,
          saldoPendienteAnterior: _saldoMoraAcumulado,
          nuevoSaldoPendiente: nuevoSaldoPendienteReal,
        );

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context, true);
        });

      } else {
        _showSnackBar(data['message'] ?? "Error en el servidor", Colors.red);
      }
    } catch (e) {
      debugPrint("Error en petición: $e");
      _showSnackBar("Error crítico: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSnackBar(String mensaje, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje), 
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 20, left: 10, right: 10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double valorCuotaFijaOriginal = double.tryParse(widget.cliente['valor_cuota'].toString()) ?? 0.0;
    
    // El valor a completar ahora es: Saldo Pendiente Anterior + Valor Cuota Original
    // Si _saldoMoraAcumulado es > 0, se suma.
    final double valorTotalCuotaActual = valorCuotaFijaOriginal + _saldoMoraAcumulado;

    // Si ya ha pagado algo parcial de ESTA cuota, usamos el _saldoPendienteCuotaActual
    // pero debemos asegurarnos de no duplicar la mora si el backend ya la sumó.
    // Lógica segura para el front: Sugerir pagar lo que falte.
    final double montoParaCompletarCuota = (_saldoPendienteCuotaActual > 0) 
        ? _saldoPendienteCuotaActual 
        : valorTotalCuotaActual;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.only(top: 60, left: 15, right: 15),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85, 
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 15, spreadRadius: 1)],
          ),
          child: Material(
            color: Colors.transparent,
            child: _isLoadingSaldo 
            ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 15),
                  Text("Préstamo #${widget.cliente['id_prestamo']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0077B6))),
                  const Divider(),
                  
                  _dataLabel("Cliente", widget.cliente['nombre'].toString().toUpperCase()),
                  _dataLabel("Cédula", widget.cliente['cedula'].toString()),
                  const Divider(),
                  
                  // Fila de información Principal
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Muestra valor cuota base
                      _infoBox("Cuota Base", _fCurrency(valorCuotaFijaOriginal), Colors.black87),
                      _infoBox("Saldo Global", _fCurrency(_saldoActualizado), Colors.redAccent),
                    ],
                  ),
                  
                  const SizedBox(height: 10),

                  // --- SECCIÓN DE MORA / PENDIENTE ANTERIOR ---
                  if (_saldoMoraAcumulado > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Saldo Pendiente Anterior:", style: TextStyle(fontSize: 12, color: Colors.red)),
                                Text(_fCurrency(_saldoMoraAcumulado), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                                const Text("Este valor se ha sumado a su cuota actual.", style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Alerta de pago parcial de la cuota actual
                  if (_saldoPendienteCuotaActual > 0 && _saldoPendienteCuotaActual < valorTotalCuotaActual)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 10), 
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orangeAccent),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.orange),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "La Cuota #$_numeroCuotaActual tiene un saldo restante de ${_fCurrency(_saldoPendienteCuotaActual)}.",
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 10),

                  // CHECKBOX: Pagar Cuota (Ahora considera la mora si existe)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                       // Si hay un saldo pendiente específico mostramos "Completar", si no "Pagar Cuota Total"
                       (_saldoPendienteCuotaActual > 0 && (_saldoPendienteCuotaActual - valorTotalCuotaActual).abs() > 1.0)
                        ? "Completar Cuota #$_numeroCuotaActual (${_fCurrency(_saldoPendienteCuotaActual)})"
                        : "Pagar Cuota Total (${_fCurrency(valorTotalCuotaActual)})", 
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)
                    ),
                    subtitle: (_saldoMoraAcumulado > 0) 
                        ? const Text("Incluye saldo pendiente anterior", style: TextStyle(fontSize: 11, color: Colors.grey)) 
                        : null,
                    value: _pagarCuotaChecked,
                    activeColor: const Color(0xFF0077B6),
                    onChanged: (val) {
                      setState(() {
                        _pagarCuotaChecked = val!;
                        if (val) {
                          _pagarTotalChecked = false;
                          _montoAbonoController.text = montoParaCompletarCuota.toStringAsFixed(0);
                        }
                      });
                    },
                  ),

                  // CHECKBOX: Pagar Todo
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Pagar Saldo Total Deuda", style: TextStyle(fontSize: 14)),
                    value: _pagarTotalChecked,
                    activeColor: Colors.green,
                    onChanged: (val) {
                      setState(() {
                        _pagarTotalChecked = val!;
                        if (val) {
                          _pagarCuotaChecked = false;
                          _montoAbonoController.text = _saldoActualizado.toStringAsFixed(0);
                        }
                      });
                    },
                  ),

                  const SizedBox(height: 10),
                  
                  // Input de Monto
                  TextField(
                    controller: _montoAbonoController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: "Monto del abono",
                      prefixIcon: const Icon(Icons.attach_money),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    onChanged: (val) {
                      setState(() {
                        double? v = double.tryParse(val);
                        if (v != null) {
                          // Verificar checkbox de cuota
                          _pagarCuotaChecked = (v - montoParaCompletarCuota).abs() < 50; // Margen de error pequeño por decimales
                          // Verificar checkbox de total
                          _pagarTotalChecked = (v - _saldoActualizado).abs() < 50;
                        } else {
                          _pagarCuotaChecked = false;
                          _pagarTotalChecked = false;
                        }
                      });
                    },
                  ),

                  const SizedBox(height: 20),

                  // Botones de acción
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: _isProcessing ? null : () => Navigator.pop(context),
                          child: const Text("CANCELAR", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _procesarPago,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isProcessing 
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("PAGAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dataLabel(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 13),
          children: [
            TextSpan(text: "$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _infoBox(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}