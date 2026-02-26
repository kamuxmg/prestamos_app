import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';

// ******************************************************************************
// CONFIGURACIÓN
// ******************************************************************************
// Ajusta esta URL si es necesario
const String baseUrl = "http://127.0.0.1/prestamos_api"; 

// ******************************************************************************
// PANTALLA DE CONSULTA (Esta es la clase que faltaba)
// ******************************************************************************

class ConsultaClientesPage extends StatefulWidget {
  const ConsultaClientesPage({super.key});

  @override
  State<ConsultaClientesPage> createState() => _ConsultaClientesPageState();
}

class _ConsultaClientesPageState extends State<ConsultaClientesPage> {
  final TextEditingController _searchController = TextEditingController();
  
  // Lista dinámica para recibir los datos del servidor
  List<dynamic> _searchResults = [];
  
  bool _isLoading = false;
  Timer? _debounce;
  
  // Filtro de estado
  String estadoSeleccionado = 'SELECCIONA'; 

  // Formateador de moneda
  final NumberFormat _currencyFormatter = NumberFormat.simpleCurrency(locale: 'es_CO', name: 'COP', decimalDigits: 0);

  String _formatCurrency(String value) {
    try {
      final formatter = NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 0);
      String formatted = formatter.format(double.parse(value));
      return '\$${formatted.replaceAll(',', '.')}'; 
    } catch (e) {
      return '\$$value';
    }
  }

  @override
  void initState() {
    super.initState();
    // No cargamos nada al inicio para optimizar
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // --- LÓGICA DE BÚSQUEDA ---
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () => _fetchClientes());
  }

  void _onEstadoChanged(String? nuevoEstado) {
    setState(() {
      estadoSeleccionado = nuevoEstado ?? 'SELECCIONA';
    });
    _fetchClientes();
  }

  Future<void> _fetchClientes() async {
    String searchTerm = _searchController.text.trim();

    // 🛑 LOGICA DE PROTECCIÓN: 
    // Si no hay texto Y no se ha seleccionado un estado específico, limpiamos y salimos.
    if (searchTerm.isEmpty && estadoSeleccionado == 'SELECCIONA') {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Preparar parámetros
      Map<String, String> params = {};
      if (searchTerm.isNotEmpty) params['search'] = searchTerm;
      
      // Mapeo de estado para la BD
      if (estadoSeleccionado == 'Activo') params['estado'] = 'activo';
      if (estadoSeleccionado == 'Cancelado') params['estado'] = 'cerrado';

      // Construir URL con query params (GET es mejor para filtros opcionales)
      Uri uri = Uri.parse('$baseUrl/buscar_cliente_prestamos.php').replace(queryParameters: params);

      // Usamos GET o POST según como tengas tu PHP. 
      // El PHP que te pasé soporta ambos, pero GET es ideal para "?search=abc&estado=activo"
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final dynamic decodedBody = jsonDecode(response.body);
        
        if (decodedBody is Map && decodedBody['success'] == true) {
          setState(() {
            _searchResults = decodedBody['clientes'];
          });
        } else {
          setState(() => _searchResults = []);
        }
      } else {
        _showErrorSnackBar('Error servidor: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackBar('Error de conexión: $e');
      setState(() => _searchResults = []);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- LÓGICA DE REFINANCIACIÓN (Opcional si la quieres aquí también) ---
  Future<void> _aplicarRefinanciacion(dynamic cliente, String multa, String nuevoTotal, String nuevaCuota) async {
    try {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

      final response = await http.post(
        Uri.parse('$baseUrl/refinanciar_prestamo.php'),
        body: {
          'id_prestamo': cliente['id_prestamo'].toString(),
          'valor_multa': multa,
          'nuevo_saldo_total': nuevoTotal,
          'nueva_cuota': nuevaCuota
        },
      );

      Navigator.pop(context); 

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _showSuccessSnackBar('Refinanciación aplicada con éxito.');
          _fetchClientes(); // Recargar
        } else {
          _showErrorSnackBar(data['error'] ?? 'Error al refinanciar');
        }
      }
    } catch (e) {
      Navigator.pop(context);
      _showErrorSnackBar('Error: $e');
    }
  }

  // DIÁLOGO REFINANCIAR
  void _showRefinanceDialog(dynamic cliente) {
    final TextEditingController moraController = TextEditingController();
    // Parseo seguro de valores dinámicos
    double saldoActual = double.tryParse(cliente['total_pagar']?.toString() ?? '0') ?? 0;
    int cuotasPendientes = int.tryParse(cliente['cuotas_pendientes']?.toString() ?? '1') ?? 1;
    if (cuotasPendientes <= 0) cuotasPendientes = 1;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            double valorMora = double.tryParse(moraController.text) ?? 0;
            double nuevoSaldoTotal = saldoActual + valorMora;
            double nuevaCuotaCalculada = nuevoSaldoTotal / cuotasPendientes;

            return AlertDialog(
              title: const Text('Refinanciar Deuda', style: TextStyle(color: Colors.orange)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cliente: ${cliente['nombre']}'),
                    Text('Saldo Actual: ${_formatCurrency(saldoActual.toString())}'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: moraController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Valor Multa/Interés', border: OutlineInputBorder()),
                      onChanged: (val) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    Text('Nuevo Saldo: ${_formatCurrency(nuevoSaldoTotal.toString())}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Nueva Cuota: ${_formatCurrency(nuevaCuotaCalculada.ceil().toString())}', style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  onPressed: valorMora > 0 ? () {
                    Navigator.pop(context);
                    _aplicarRefinanciacion(
                      cliente, 
                      valorMora.toString(), 
                      nuevoSaldoTotal.toString(), 
                      nuevaCuotaCalculada.ceil().toString()
                    );
                  } : null,
                  child: const Text('Aplicar', style: TextStyle(color: Colors.white)),
                )
              ],
            );
          },
        );
      },
    );
  }

  void _showErrorSnackBar(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }
  
  void _showSuccessSnackBar(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  // *******************************************************************
  // UI
  // *******************************************************************

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Consulta de Clientes"),
        backgroundColor: Colors.blue,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // FILTROS
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: const InputDecoration(
                    labelText: "Buscar por nombre o cédula",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: estadoSeleccionado,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  ),
                  items: <String>['SELECCIONA', 'Activo', 'Cancelado']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value == 'SELECCIONA' ? 'Filtrar por Estado (Opcional)' : value),
                    );
                  }).toList(),
                  onChanged: _onEstadoChanged,
                ),
              ],
            ),
          ),

          // RESULTADOS
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _searchResults.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.manage_search, size: 50, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            const Text(
                              "Usa el buscador o selecciona un estado para ver clientes.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(10),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final cliente = _searchResults[index];
                        
                        // Lógica de Atraso Visual
                        int diasAtraso = int.tryParse(cliente['dias_atraso']?.toString() ?? '0') ?? 0;
                        bool estaAtrasado = diasAtraso > 0;

                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: estaAtrasado ? const BorderSide(color: Colors.red, width: 1.5) : BorderSide.none
                          ),
                          
                          child: ListTile(
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    "${cliente['nombre']} (${cliente['cedula']})",
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (estaAtrasado)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                                    child: Text("Mora: $diasAtraso días", style: const TextStyle(color: Colors.white, fontSize: 10)),
                                  )
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Dir: ${cliente['direccion'] ?? ''}"),
                                Text("Tel: ${cliente['telefono'] ?? ''}"),
                                const SizedBox(height: 4),
                                Text(
                                  "Total a Pagar: ${_formatCurrency(cliente['total_pagar']?.toString() ?? '0')}",
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800),
                                ),
                                Text("Cuotas Restantes: ${cliente['cuotas_pendientes']}"),
                                const Divider(),
                                Text("Fiador: ${cliente['nombre_fiador'] ?? 'N/A'}"),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Botón Refinanciar
                                IconButton(
                                  icon: const Icon(Icons.warning_amber_rounded, color: Colors.deepOrange),
                                  tooltip: 'Refinanciar',
                                  onPressed: () => _showRefinanceDialog(cliente),
                                ),
                                // Botón Editar (Placeholder)
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () {},
                                ),
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
}