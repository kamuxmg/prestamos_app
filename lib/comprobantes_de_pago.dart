import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

// 🚨 IMPORTANTE: Asegúrate de que esta ruta sea correcta para importar tu archivo config.dart
// Si config.dart está en lib/, la ruta debe ser algo como:
import 'config.dart'; // O ajusta el path de tu proyecto

// -------------------------------------------------------------------------
// INICIO DE LA APLICACIÓN
// -------------------------------------------------------------------------
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Comprobantes de Pago',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const ComprobantesDePagoScreen(),
    );
  }
}
// -------------------------------------------------------------------------

// Nombre del script PHP (se añade al final de Config.apiBase)
const String phpScriptName = '/comprobante_pago_cliente_reenviar.php';

// ----------------------------------------------------
// MODELOS DE DATOS
// ----------------------------------------------------

// Modelo para los datos básicos del Cliente
class Cliente {
  final int id;
  final String nombre;
  final String cedula;
  final String telefono;

  Cliente(
      {required this.id,
      required this.nombre,
      required this.cedula,
      required this.telefono});

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      id: int.tryParse(json['id'].toString()) ?? 0,
      nombre: json['nombre'] ?? 'N/A',
      cedula: json['cedula'] ?? 'N/A',
      telefono: json['telefono'] ?? '',
    );
  }
}

// Modelo para el Comprobante de Pago completo
class ComprobantePago {
  final int idCuota;
  final String nombreCliente;
  final String cedula;
  final String telefono;
  final double valorAbonado;
  final String mensajeCuota; // Ej: "Cuota 1 de 5"
  final DateTime fechaPago;
  final DateTime fechaVencimiento;

  ComprobantePago({
    required this.idCuota,
    required this.nombreCliente,
    required this.cedula,
    required this.telefono,
    required this.valorAbonado,
    required this.mensajeCuota,
    required this.fechaPago,
    required this.fechaVencimiento,
  });

  factory ComprobantePago.fromJson(Map<String, dynamic> json) {
    return ComprobantePago(
      idCuota: int.tryParse(json['id_pago'].toString()) ?? 0,
      nombreCliente: json['nombre_cliente'] ?? 'N/A',
      cedula: json['cedula'] ?? 'N/A',
      telefono: json['telefono'] ?? '',
      valorAbonado: double.tryParse(json['valor_abonado'].toString()) ?? 0.0,
      mensajeCuota: json['mensaje_cuota'] ?? 'Cuota',
      fechaPago: DateTime.tryParse(json['fecha_pago'] ?? '') ?? DateTime.now(),
      fechaVencimiento:
          DateTime.tryParse(json['fecha_vencimiento'] ?? '') ?? DateTime.now(),
    );
  }
}

// ----------------------------------------------------
// WIDGET PRINCIPAL Y LÓGICA
// ----------------------------------------------------
class ComprobantesDePagoScreen extends StatefulWidget {
  const ComprobantesDePagoScreen({super.key});

  @override
  State<ComprobantesDePagoScreen> createState() =>
      _ComprobantesDePagoScreenState();
}

class _ComprobantesDePagoScreenState extends State<ComprobantesDePagoScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Cliente> _searchResults = [];
  Cliente? _selectedClient;
  List<ComprobantePago> _paymentList = [];
  bool _isLoadingClients = false;
  bool _isLoadingPayments = false;

  // Rango de fechas inicial (últimos 30 días)
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  // Formateadores para moneda y fechas
  final currencyFormatter = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0, 
    customPattern: '¤#,##0', 
  );
  final dateFormatter = DateFormat('dd/MM/yyyy');
  final dateTimeFormatter = DateFormat('dd/MM/yyyy HH:mm'); 

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // Lógica de búsqueda con filtro de 3 caracteres
  void _onSearchChanged() {
    if (_searchController.text.length >= 3) {
      _fetchClients(_searchController.text);
    } else if (_searchController.text.isEmpty) {
      setState(() {
        _searchResults = [];
        _selectedClient = null;
        _paymentList = [];
      });
    }
  }

  // ----------------------------------------------------
  // MANEJO DE SERVICIOS (HTTP)
  // ----------------------------------------------------

  Future<void> _fetchClients(String initials) async {
    setState(() {
      _isLoadingClients = true;
      _searchResults = [];
    });

    final Uri url = Uri.parse("${Config.apiBase}$phpScriptName");

    try {
      final response = await http.post(
        url, 
        body: {'action': 'getClients', 'initials': initials},
      ).timeout(const Duration(seconds: 15)); 

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _searchResults = (data['clients'] as List)
              .map((json) => Cliente.fromJson(json))
              .toList();
        });
      } else {
        _showSnackbar(
            'Error ${response.statusCode}: El servidor respondió con un error.',
            isError: true);
      }
    } on Exception catch (e) {
      String errorMessage = 'Error de conexión: El servidor no está disponible.';
      if (e.toString().contains('TimeoutException')) {
        errorMessage =
            'Error de conexión: Tiempo de espera agotado (15s). Verifica la IP y la red (Usando: ${Config.apiBase}).';
      } else {
        errorMessage = 'Error de conexión: ${e.toString()}';
      }
      _showSnackbar(errorMessage, isError: true);
    } finally {
      setState(() {
        _isLoadingClients = false;
      });
    }
  }

  Future<void> _fetchPayments() async {
    if (_selectedClient == null) return;

    setState(() {
      _isLoadingPayments = true;
      _paymentList = [];
    });

    final String start = DateFormat('yyyy-MM-dd').format(_startDate);
    final String end = DateFormat('yyyy-MM-dd').format(_endDate);

    final Uri url = Uri.parse("${Config.apiBase}$phpScriptName");

    try {
      final response = await http.post(
        url, 
        body: {
          'action': 'getPayments',
          'cliente_id': _selectedClient!.id.toString(),
          'start_date': start,
          'end_date': end,
        },
      ).timeout(const Duration(seconds: 15)); 

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('error')) {
          _showSnackbar('Error de backend: ${data['error']}', isError: true);
          return;
        }

        setState(() {
          _paymentList = (data['payments'] as List)
              .map((json) => ComprobantePago.fromJson(json))
              .toList();
        });
        if (_paymentList.isEmpty) {
          _showSnackbar('No se encontraron pagos en el rango de fechas.',
              isError: false);
        }
      } else {
        _showSnackbar(
            'Error ${response.statusCode}: El servidor respondió con un error.',
            isError: true);
      }
    } on Exception catch (e) {
      String errorMessage = 'Error de conexión: El servidor no está disponible.';
      if (e.toString().contains('TimeoutException')) {
        errorMessage =
            'Error de conexión: Tiempo de espera agotado (15s). Verifica la IP y la red (Usando: ${Config.apiBase}).';
      } else {
        errorMessage = 'Error de conexión: ${e.toString()}';
      }
      _showSnackbar(errorMessage, isError: true);
    } finally {
      setState(() {
        _isLoadingPayments = false;
      });
    }
  }

  // ----------------------------------------------------
  // UTILERÍAS Y LÓGICA DE WHATSAPP
  // ----------------------------------------------------

  void _showSnackbar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.redAccent : Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // Selector de Rango de Fechas
  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      helpText: 'Seleccionar Rango de Fechas de Pago',
      fieldStartHintText: 'Fecha Inicio',
      fieldEndHintText: 'Fecha Fin',
    );

    if (picked != null &&
        (picked.start != _startDate || picked.end != _endDate)) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      if (_selectedClient != null) {
        await _fetchPayments(); 
      }
    }
  }

  // Genera el mensaje de WhatsApp (LIMPIADO DE UNICODE)
  String _generateWhatsAppMessage(ComprobantePago recibo) {
    final String fechaHora = dateTimeFormatter.format(recibo.fechaPago);
    final String valorAbonadoStr = currencyFormatter.format(recibo.valorAbonado);

    // Formato de WhatsApp
    return '*----------------------------------------*\n'
        '* PRESTAMOS JV                            *\n'
        '*----------------------------------------*\n\n'
        '*¡Hola ${recibo.nombreCliente.split(' ').first}!* 👋\n\n'
        '📄 *COMPROBANTE DE PAGO DE PRÉSTAMO*\n'
        '----------------------------------------\n'
        '🧾 *ID Pago:* #${recibo.idCuota}\n'
        '🗓️ *Fecha y Hora:* $fechaHora\n'
        '👤 *Cédula:* ${recibo.cedula}\n'
        '----------------------------------------\n'
        '💵 *VALOR ABONADO:* $valorAbonadoStr\n'
        '🔖 *Cuota Aplicada:* ${recibo.mensajeCuota}\n'
        '----------------------------------------\n\n'
        '¡Gracias por preferir nuestros servicios!';
  }

  // Lanza la aplicación de WhatsApp
  void _sendWhatsApp(ComprobantePago pago) async {
    final message = _generateWhatsAppMessage(pago);
    final String phoneNumber = pago.telefono.replaceAll(RegExp(r'[^\d]'), '');

    if (phoneNumber.isEmpty) {
      _showSnackbar('El cliente no tiene un número de teléfono registrado.',
          isError: true);
      return;
    }

    final String encodedMessage = Uri.encodeComponent(message);

    final Uri whatsappUrl =
        Uri.parse('https://wa.me/$phoneNumber?text=$encodedMessage');

    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } else {
      _showSnackbar(
          'No se pudo abrir WhatsApp. Asegúrate de tener una aplicación de navegador o WhatsApp instalada.',
          isError: true);
    }
  }

  // ----------------------------------------------------
  // WIDGETS AUXILIARES DENTRO DEL STATE
  // ----------------------------------------------------

  // Auxiliar para construir filas de detalle en el modal (VERSION FINAL)
  Widget _buildDetailRow(String label, String value, IconData icon,
      {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon,
              size: 20, color: highlight ? Colors.redAccent : Colors.grey[600]),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 16,
                fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
                color: highlight ? Colors.redAccent : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }


  // Diseño profesional del Comprobante (Card)
  Widget _buildPaymentCard(ComprobantePago pago) {
    return Card(
      elevation: 5,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        // Hace la tarjeta clickeable para abrir el modal
        onTap: () => _showPaymentModal(pago),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Encabezado
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('COMPROBANTE DE PAGO',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                          fontSize: 14)),
                  Text('ID Pago: #${pago.idCuota}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.grey[600])),
                ],
              ),
              const Divider(height: 10, thickness: 1),

              // Valor y Cuota
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('VALOR ABONADO',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        currencyFormatter.format(pago.valorAbonado),
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.green),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Cuota Aplicada',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(pago.mensajeCuota,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Fechas
              Row(
                children: [
                  const Icon(Icons.calendar_month, size: 18, color: Colors.black54),
                  const SizedBox(width: 5),
                  Text('Pagado el: ${dateTimeFormatter.format(pago.fechaPago)}',
                      style: const TextStyle(fontSize: 14)),
                ],
              ),

              // Botón de Acción
              const Divider(height: 20, thickness: 1),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () => _showPaymentModal(pago),
                  icon: const Icon(Icons.visibility),
                  label: const Text('Visualizar / Enviar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // MODAL DE DETALLE (showModalBottomSheet)
  // ----------------------------------------------------
  void _showPaymentModal(ComprobantePago pago) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Detalle de Comprobante',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent),
                textAlign: TextAlign.center,
              ),
              const Divider(height: 20, thickness: 2, color: Colors.grey),

              // Tarjeta de Resumen con Diseño
              Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Cliente:', pago.nombreCliente, Icons.person),
                      _buildDetailRow('Cédula:', pago.cedula, Icons.credit_card),
                      _buildDetailRow(
                          'Teléfono:',
                          pago.telefono.isNotEmpty ? pago.telefono : 'N/A',
                          Icons.phone),
                      const Divider(height: 15),
                      _buildDetailRow('ID Pago:', '#${pago.idCuota}',
                          Icons.receipt_long,
                          highlight: true),
                      _buildDetailRow('Cuota:', pago.mensajeCuota, Icons.payment),
                      _buildDetailRow(
                          'F. Vencimiento:',
                          dateFormatter.format(pago.fechaVencimiento),
                          Icons.calendar_today),
                      _buildDetailRow(
                          'F. Pago:',
                          dateTimeFormatter.format(pago.fechaPago),
                          Icons.access_time),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),
              // Valor Abonado Destacado
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blueAccent),
                ),
                child: Center(
                  child: Text(
                    'Valor Abonado: ${currencyFormatter.format(pago.valorAbonado)}',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.blueAccent),
                  ),
                ),
              ),

              const SizedBox(height: 30),
              // Botón de WhatsApp
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Cierra el modal
                  _sendWhatsApp(pago); // Lanza WhatsApp
                },
                icon: const Icon(Icons.chat, color: Colors.white), 
                label: const Text('Enviar WhatsApp al Cliente',
                    style: TextStyle(fontSize: 18, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366), // Color de WhatsApp
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }
  
  // ----------------------------------------------------
  // LAYOUT PRINCIPAL DEL SCREEN
  // ----------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comprobantes de Pago'),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      // 💡 SOLUCIÓN: El SingleChildScrollView permite que el contenido sea scrollable
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            // 1. Panel de Búsqueda de Clientes
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Buscar Cliente (Mínimo 3 iniciales)',
                      hintText: 'Ej: MAR o mar',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  if (_isLoadingClients)
                    const Center(
                        child: Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: LinearProgressIndicator(color: Colors.blueAccent),
                    )),
                ],
              ),
            ),

            // 2. Resultados de Búsqueda de Clientes (ListView para selección)
            if (_searchResults.isNotEmpty)
              Container(
                constraints: const BoxConstraints(
                    maxHeight: 180), // Limitar altura para no ocupar toda la pantalla
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final client = _searchResults[index];
                    final isSelected = client.id == _selectedClient?.id;
                    return ListTile(
                      tileColor: isSelected ? Colors.blue.shade50 : null,
                      leading:
                          const Icon(Icons.person_pin, color: Colors.blueAccent),
                      title: Text(client.nombre,
                          style: TextStyle(
                              fontWeight:
                                  isSelected ? FontWeight.bold : FontWeight.normal)),
                      subtitle: Text(
                          'Cédula: ${client.cedula} | Teléfono: ${client.telefono}'),
                      onTap: () {
                        setState(() {
                          _selectedClient = client;
                          _searchResults = []; // Ocultar resultados
                        });
                        _fetchPayments(); // Iniciar la búsqueda de pagos automáticamente
                      },
                    );
                  },
                ),
              ),

            // 3. Panel de Cliente Seleccionado y Filtro de Fechas
            if (_selectedClient != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Card(
                  elevation: 4,
                  color: Colors.blue.shade50,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cliente Seleccionado: ${_selectedClient!.nombre}',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)),
                        Text('Cédula: ${_selectedClient!.cedula}',
                            style: TextStyle(color: Colors.grey.shade700)),
                        const SizedBox(height: 8),

                        // INICIO DEL AJUSTE DE REDIMENSIÓN DE FILTROS
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // 🚀 SOLUCIÓN: Usar Expanded y FittedBox para forzar el ajuste del texto del filtro
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown, // Permite que el texto se achique
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Filtro: ${dateFormatter.format(_startDate)} - ${dateFormatter.format(_endDate)}',
                                    style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),
                            ),
                            
                            // Botón de Cambiar Fechas (pequeño y legible)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero, // Reduce padding por defecto
                                minimumSize: Size.zero, // Permite que ocupe menos espacio
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Lo hace compacto
                              ),
                              icon: const Icon(Icons.calendar_today,
                                  size: 18, color: Colors.blue),
                              label: const Text('Fechas', // Se redujo el texto para ahorrar espacio
                                  style: TextStyle(color: Colors.blue, fontSize: 13)),
                              onPressed: _selectDateRange,
                            ),
                            const SizedBox(width: 8),

                            // Botón para recargar (compacto)
                            ElevatedButton(
                              onPressed: _fetchPayments,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.pink.shade100, // Cambio de color para diferenciar
                                foregroundColor: Colors.blueAccent,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Padding reducido
                                minimumSize: Size.zero,
                              ),
                              child: const Text('Recargar', style: TextStyle(fontSize: 13)),
                            )
                          ],
                        ),
                        // FIN DEL AJUSTE
                      ],
                    ),
                  ),
                ),
              ),

            // 4. Título de Pagos
            if (_selectedClient != null)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Pagos Realizados (Resultado del Filtro):',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                ),
              ),

            // 5. Lista de Pagos
            if (_isLoadingPayments)
              const SizedBox(
                  height: 200,
                  child: Center(
                      child: CircularProgressIndicator(
                          color: Colors.blueAccent)))
            else if (_selectedClient == null)
              const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text(
                      'Busca y selecciona un cliente para ver sus pagos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey)))
            else if (_paymentList.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                    'No hay pagos registrados para este cliente en el rango de fechas seleccionado.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.redAccent, fontSize: 16)),
              )
            else
              // La lista real de pagos, permitiendo que el SingleChildScrollView la desplace
              ListView.builder(
                shrinkWrap: true, // OBLIGATORIO: Se encoge para ocupar solo el espacio de sus hijos
                physics: const NeverScrollableScrollPhysics(), // OBLIGATORIO: Delega el scroll al padre
                padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
                itemCount: _paymentList.length,
                itemBuilder: (context, index) {
                  final pago = _paymentList[index];
                  return _buildPaymentCard(pago);
                },
              ),
          ],
        ),
      ),
    );
  }
}