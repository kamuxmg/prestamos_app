import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert'; // Necesario para decodificar el JSON
import 'package:http/http.dart' as http; // Necesario para conectarse al PHP

// Importamos tu archivo de configuración global
import 'config.dart'; 

class EstadoCarteraScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? dataRegistros;

  const EstadoCarteraScreen({super.key, this.dataRegistros});

  @override
  State<EstadoCarteraScreen> createState() => _EstadoCarteraScreenState();
}

class _EstadoCarteraScreenState extends State<EstadoCarteraScreen> {
  bool _cargando = false;

  // Iniciamos el filtro vacío para que no busque nada al abrir
  String _filtroFrecuencia = ''; 
  // Eliminamos 'Todos' de las opciones
  final List<String> _opcionesFrecuencia = ['Diaria', 'Semanal', 'Quincenal', 'Mensual'];

  final f = NumberFormat.currency(symbol: r'$', decimalDigits: 0);

  List<Map<String, dynamic>> _clientesEnMora = [];

  @override
  void initState() {
    super.initState();
    // Ya NO hacemos _recargarDatos() aquí. 
    // Solo procesamos datos si se enviaron de pantalla a pantalla por parámetro.
    if (widget.dataRegistros != null && widget.dataRegistros!.isNotEmpty) {
      _procesarData(widget.dataRegistros!);
    }
  }

  void _ajustarDecimales() {
    setState(() {
      _clientesEnMora.removeWhere((c) => (double.tryParse(c['total_deuda'].toString()) ?? 0) < 1.0);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Limpieza de residuos decimales completada.")),
    );
  }

  List<Map<String, dynamic>> get _clientesFiltrados {
    // Si no hay filtro seleccionado, devolvemos lista vacía
    if (_filtroFrecuencia.isEmpty) return [];
    
    return _clientesEnMora.where((c) {
      String tipoCuota = (c['tipo_cuota'] ?? '').toString();
      
      // En tu BD hay campos vacíos para la cuota diaria, por eso validamos isEmpty
      if (_filtroFrecuencia == 'Diaria') {
        return tipoCuota == 'Diaria' || tipoCuota.isEmpty;
      }
      if (_filtroFrecuencia == 'Semanal') return tipoCuota == 'Semanal';
      if (_filtroFrecuencia == 'Quincenal') return tipoCuota == 'Quincenal';
      if (_filtroFrecuencia == 'Mensual') return tipoCuota == 'Mensual';
      
      return false;
    }).toList();
  }

  void _procesarData(List<Map<String, dynamic>> dataRaw) {
    setState(() {
      _clientesEnMora = dataRaw.map((c) {
        var item = Map<String, dynamic>.from(c);
        item['dias_atraso'] = int.tryParse(item['dias_atraso'].toString()) ?? 0;
        
        // AJUSTE 1: Redondeo forzoso para matar decimales tipo 0.1
        double rawDeuda = double.tryParse(item['total_deuda'].toString()) ?? 0.0;
        item['total_deuda'] = rawDeuda.roundToDouble();

        double rawCuota = double.tryParse(item['valor_cuota'].toString()) ?? 0.0;
        item['valor_cuota'] = rawCuota.roundToDouble();
        
        return item;
      }).where((c) {
        bool esActivo = (c['estado'] ?? '').toString().toLowerCase() == 'activo';
        // Muestra todo préstamo activo que tenga saldo pendiente.
        return esActivo && c['total_deuda'] >= 1.0;
      }).toList();

      // Ordenamos para que los que tienen más atraso salgan primero
      _clientesEnMora.sort((a, b) => b['dias_atraso'].compareTo(a['dias_atraso']));
      _cargando = false;
    });
  }

  // --- CONEXIÓN REAL CON TU PHP USANDO CONFIG.DART ---
  Future<void> _recargarDatos() async {
    if (_filtroFrecuencia.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, selecciona un tipo de cuota primero.")),
      );
      return;
    }

    setState(() => _cargando = true);
    
    try {
      // Usamos Config.apiBase de tu archivo de configuración
      final url = Uri.parse('${Config.apiBase}/edades_estado_cartera.php');
      
      final response = await http.get(url);

      if (response.statusCode == 200) {
        // Decodificamos el JSON que nos envía el PHP
        final List<dynamic> decodedData = json.decode(response.body);
        final List<Map<String, dynamic>> fetchedData = List<Map<String, dynamic>>.from(decodedData);
        
        // Procesamos los datos reales
        _procesarData(fetchedData);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error del servidor: ${response.statusCode}")),
        );
        setState(() => _cargando = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error de conexión. Verifica la configuración del servidor.")),
      );
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Gestión de Cobros", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _recargarDatos, // Al presionar, vuelve a llamar al PHP si hay filtro activo
            tooltip: "Actualizar datos",
          ),
          if (_clientesEnMora.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.cleaning_services),
              onPressed: _ajustarDecimales,
              tooltip: "Limpiar residuos",
            )
        ],
      ),
      body: Column(
        children: [
          _buildFiltros(),
          Expanded(
            child: _cargando 
              ? const Center(child: CircularProgressIndicator())
              : _clientesFiltrados.isEmpty 
                  ? _buildEmptyState() 
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 10, bottom: 20),
                      itemCount: _clientesFiltrados.length,
                      itemBuilder: (context, index) => _buildClienteCard(_clientesFiltrados[index]),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white, 
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _opcionesFrecuencia.map((frecuencia) {
            final isSelected = _filtroFrecuencia == frecuencia;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(
                  frecuencia, 
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                  )
                ),
                selected: isSelected,
                selectedColor: Colors.blue[800],
                backgroundColor: Colors.grey[200],
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _filtroFrecuencia = frecuencia;
                    });
                    // Disparamos la consulta al servidor justo al seleccionar
                    _recargarDatos();
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildClienteCard(Map<String, dynamic> cliente) {
    int dias = cliente['dias_atraso'] ?? 0;
    bool critica = dias > 30;
    bool alDia = dias <= 0;
    
    String tipoCuota = (cliente['tipo_cuota'] ?? '').toString();
    if (tipoCuota.isEmpty) tipoCuota = 'Diaria';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        // Si está al día, borde azul. Si hay atraso leve, verde. Si es crítico, rojo.
        border: Border(left: BorderSide(
          color: alDia ? Colors.blue : (critica ? Colors.red : Colors.green[600]!), 
          width: 6
        )),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.only(left: 16, right: 8, top: 8, bottom: 8),
            title: Row(
              children: [
                Expanded(child: Text(cliente['nombre'] ?? "CLIENTE SIN NOMBRE", style: const TextStyle(fontWeight: FontWeight.bold))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(4)),
                  child: Text(tipoCuota, style: TextStyle(fontSize: 10, color: Colors.blue[900], fontWeight: FontWeight.bold)),
                )
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                // AJUSTE 2: Agregados datos del cliente ordenados (Cédula, Tel, Dir, Zona)
                Text(
                  "C.C: ${cliente['cedula'] ?? '-'} • Tel: ${cliente['telefono'] ?? '-'}", 
                  style: TextStyle(color: Colors.grey[800], fontSize: 13)
                ),
                const SizedBox(height: 2),
                Text(
                  "Dir: ${cliente['direccion'] ?? '-'} • Zona: ${cliente['zona'] ?? '-'}", 
                  style: TextStyle(color: Colors.grey[800], fontSize: 13)
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: alDia ? Colors.blue[50] : (critica ? Colors.red[50] : Colors.orange[50]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    alDia ? "AL DÍA" : "$dias DÍAS DE ATRASO", 
                    style: TextStyle(
                      color: alDia ? Colors.blue[900] : (critica ? Colors.red[900] : Colors.orange[900]), 
                      fontSize: 11, 
                      fontWeight: FontWeight.bold
                    )
                  ),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(f.format(cliente['valor_cuota'] ?? 0), 
                  style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.w900, fontSize: 19)),
                const Text("CUOTA A COBRAR", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 8, top: 4, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _miniInfo("DEUDA TOTAL", f.format(cliente['total_deuda'] ?? 0)),
                _miniInfo("ÚLT. VTO.", cliente['proximo_pago'] ?? cliente['fecha_vencimiento'] ?? "-"),
                
                IconButton(
                  icon: Icon(Icons.phone_in_talk, color: Colors.blue[700]),
                  tooltip: "Llamar al cliente",
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Llamando a ${cliente['nombre']}..."))
                    );
                  },
                ),
                IconButton(
                  icon: Icon(Icons.check_circle, color: Colors.green[600]),
                  tooltip: "Registrar Pago",
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Abrir modal de pago para ${cliente['nombre']}"))
                    );
                  },
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildEmptyState() {
    // Si aún no se ha seleccionado nada, mostramos un mensaje invitando a seleccionar
    if (_filtroFrecuencia.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app, size: 90, color: Colors.blue[200]),
            const SizedBox(height: 16),
            Text("SELECCIONE UNA FRECUENCIA", style: TextStyle(color: Colors.blue[800], fontSize: 20, fontWeight: FontWeight.w900)),
            const Text("Toque una opción arriba para buscar los cobros.", style: TextStyle(color: Colors.blueGrey)),
          ],
        ),
      );
    }

    // Si ya seleccionó, buscó y no hay nada, mostramos el "Cartera al día"
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 90, color: Colors.green[200]),
          const SizedBox(height: 16),
          Text("CARTERA AL DÍA", style: TextStyle(color: Colors.green[800], fontSize: 20, fontWeight: FontWeight.w900)),
          Text("No hay cobros de tipo $_filtroFrecuencia pendientes.", style: const TextStyle(color: Colors.blueGrey)),
        ],
      ),
    );
  }
}