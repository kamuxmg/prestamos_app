import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

// Asume que tienes un archivo config.dart con la URL base de tu API
import 'config.dart';

// --- 1. MODELO DE DATOS (AJUSTADO) ---
class ClienteCartera {
  final String nombre;
  final String cedula;
  final String telefono;
  final String direccion;
  final String zona;
  final double valorTotal; // Valor a Devolver (Capital + Intereses)
  final double valorCapitalPrestado; // ✅ Campo 'valor_credito' del PHP
  final int cantidadCuotas;
  final int cuotasPagadas;
  final double saldoRestante;
  final String nombreFiador;
  final String direccionFiador;
  
  // Campos de estado
  final int diasAtraso;
  final String fechaUltimoPago;
  final double valorUltimoPago;

  final double valorDiferidoAcumulado; 

  ClienteCartera({
    required this.nombre,
    required this.cedula,
    required this.telefono,
    required this.direccion,
    required this.zona,
    required this.valorTotal,
    required this.valorCapitalPrestado,
    required this.cantidadCuotas,
    required this.cuotasPagadas,
    required this.saldoRestante,
    required this.nombreFiador,
    required this.direccionFiador,
    required this.diasAtraso,
    required this.fechaUltimoPago,
    required this.valorUltimoPago,
    this.valorDiferidoAcumulado = 0.0,
  });

  factory ClienteCartera.fromJson(Map<String, dynamic> json) {
    final int totalCuotas = int.tryParse(json['cantidad_cuotas'].toString()) ?? 0;
    int pagadas = int.tryParse(json['cuotas_pagadas']?.toString() ?? '0') ?? 0;

    if (pagadas > totalCuotas) {
      pagadas = totalCuotas;
    }

    return ClienteCartera(
      nombre: json['nombre']?.toString() ?? '',
      cedula: json['cedula']?.toString() ?? '',
      telefono: json['telefono']?.toString() ?? '',
      direccion: json['direccion']?.toString() ?? '',
      zona: json['zona']?.toString() ?? '',
      
      valorTotal: double.tryParse(json['valor_total']?.toString() ?? '0') ?? 0.0, 
      // 🛑 CAMBIO CLAVE AQUÍ: Usamos 'valor_credito' que corresponde al capital prestado
      valorCapitalPrestado: double.tryParse(json['valor_credito']?.toString() ?? '0') ?? 0.0, 
      
      cantidadCuotas: totalCuotas,
      cuotasPagadas: pagadas,
      saldoRestante: double.tryParse(json['total_pagar']?.toString() ?? '0') ?? 0.0,
      nombreFiador: json['nombre_fiador']?.toString() ?? 'N/A',
      direccionFiador: json['direccion_fiador']?.toString() ?? 'N/A',
      
      diasAtraso: int.tryParse(json['dias_atraso']?.toString() ?? '0') ?? 0,
      fechaUltimoPago: json['fecha_ultimo_pago']?.toString() ?? 'Sin pagos',
      valorUltimoPago: double.tryParse(json['valor_ultimo_pago']?.toString() ?? '0') ?? 0.0,
      valorDiferidoAcumulado: double.tryParse(json['valor_diferido']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class CarteraClientesScreen extends StatefulWidget {
  const CarteraClientesScreen({super.key});

  @override
  State<CarteraClientesScreen> createState() => _CarteraClientesScreenState();
}

class _CarteraClientesScreenState extends State<CarteraClientesScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  Future<List<ClienteCartera>> _futureClientes = Future.value([]);
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- 2. PETICIÓN GET CLIENTES ---
  Future<List<ClienteCartera>> _fetchClientes(String searchTerm) async {
    if (searchTerm.trim().isEmpty) return [];

    final url = Uri.parse('${Config.apiBase}/cartera_clientes.php?search=$searchTerm');

    try {
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final decodedBody = json.decode(response.body);

        if (decodedBody is Map<String, dynamic> && decodedBody.containsKey('clientes')) {
          final List<dynamic> listaClientes = decodedBody['clientes'];
          
          if (listaClientes.isEmpty) return [];

          final todosLosClientes = listaClientes.map((data) => ClienteCartera.fromJson(data)).toList();
          
          final clientesDeudores = todosLosClientes.where((c) {
             return c.saldoRestante > 0;
          }).toList();

          return clientesDeudores;

        } else {
          // Si el servidor devuelve un error o JSON vacío
          if (decodedBody is Map<String, dynamic> && decodedBody.containsKey('message')) {
             // throw Exception(decodedBody['message']); 
          }
          return [];
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } on SocketException {
      _showSnackBar("Sin conexión a internet o al servidor.", Colors.red);
      return [];
    } catch (e) {
      _showSnackBar("Error al cargar: $e", Colors.red);
      return [];
    }
  }

  // --- 3. FUNCIÓN PARA REGISTRAR VALOR DIFERIDO ---
  Future<void> _registrarValorDiferido(String cedula, double valor) async {
    final url = Uri.parse('${Config.apiBase}/actualizar_diferido.php'); 

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()),
      );

      final response = await http.post(url, body: {
        'cedula': cedula,
        'valor_diferido': valor.toString(), 
      });

      Navigator.pop(context);

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['status'] == 'success') {
          _showSnackBar("Valor diferido aplicado correctamente.", Colors.green);
          // Recargar la búsqueda para mostrar el nuevo saldo
          _performSearch(_searchController.text);
        } else {
          _showSnackBar("Error: ${result['message']}", Colors.red);
        }
      } else {
        _showSnackBar("Error de servidor al guardar. Código: ${response.statusCode}", Colors.red);
      }
    } on SocketException {
      if (Navigator.canPop(context)) Navigator.pop(context); 
      _showSnackBar("Sin conexión a internet.", Colors.red);
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context); 
      _showSnackBar("Error de conexión: $e", Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white)),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _hasSearched = false;
        _futureClientes = Future.value([]); 
      });
      return;
    }

    setState(() {
      _hasSearched = true;
      _futureClientes = _fetchClientes(query);
    });
  }
  
  // --- 4. MODAL DE SELECCIÓN DE VALOR ---
  void _mostrarModalDiferido(ClienteCartera cliente) {
    double valorSeleccionado = 10000.0; // Valor inicial
    
    // Generar lista de valores de 10.000 a 1.000.000
    List<double> valores = [];
    for (int i = 10000; i <= 1000000; i += 10000) {
      valores.add(i.toDouble());
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              title: const Text("Aplicar Valor Diferido"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Seleccione el valor a cargar por mora/retraso. Este valor se sumará al saldo pendiente.",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<double>(
                        value: valorSeleccionado,
                        isExpanded: true,
                        items: valores.map((valor) {
                          return DropdownMenuItem<double>(
                            value: valor,
                            child: Text("COP \$${_formatCurrency(valor)}"),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setStateModal(() {
                            valorSeleccionado = val!;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Nuevo saldo proyectado:\nCOP \$${_formatCurrency(cliente.saldoRestante + valorSeleccionado)}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  )
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
                  onPressed: () {
                    Navigator.pop(context); // Cerrar modal
                    _registrarValorDiferido(cliente.cedula, valorSeleccionado);
                  },
                  child: const Text("Aplicar Cargo", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cartera de Clientes', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Buscador
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              controller: _searchController,
              onChanged: _performSearch,
              decoration: InputDecoration(
                labelText: 'Buscar Cliente (Nombre o Cédula)',
                hintText: 'Escribe las iniciales...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _performSearch('');
                      },
                    )
                  : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
          ),
          
          // Resultados
          Expanded(
            child: FutureBuilder<List<ClienteCartera>>(
              future: _futureClientes,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.blue));
                } 
                
                if (!_hasSearched || _searchController.text.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 80, color: Colors.blue.shade100),
                        const SizedBox(height: 20),
                        Text(
                          'Ingresa un nombre para consultar.',
                          style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 60, color: Colors.green.shade300),
                        const SizedBox(height: 10),
                        const Text(
                          'No hay deudas pendientes con este criterio.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                } 
                
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final cliente = snapshot.data![index];
                    return _buildClienteCard(cliente);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClienteCard(ClienteCartera cliente) {
    final cuotasPendientes = cliente.cantidadCuotas - cliente.cuotasPagadas;
    // Aseguramos que no sea negativo
    final int cuotasPendientesInt = cuotasPendientes < 0 ? 0 : cuotasPendientes;
    
    final bool enMora = cliente.diasAtraso > 0;
    final Color estadoColor = enMora ? Colors.red.shade800 : Colors.green.shade700;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: enMora ? Colors.red.shade200 : Colors.blue.shade100, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(cliente.nombre, cliente.cedula),
            const Divider(height: 20, color: Colors.blueGrey),
            
            _buildSectionTitle('Contacto y Ubicación'),
            _buildInfoRow(Icons.phone, 'Teléfono:', cliente.telefono),
            _buildInfoRow(Icons.location_on, 'Dirección:', cliente.direccion),
            _buildInfoRow(Icons.map, 'Zona:', cliente.zona, color: Colors.orange.shade800),
            
            const Divider(height: 20, color: Colors.blueGrey),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle('Estado del Crédito'),
                if (enMora)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(5)
                    ),
                    child: Text("EN MORA", style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold, fontSize: 12)),
                  )
              ],
            ),
            _buildInfoRow(Icons.warning_amber_rounded, 'Días Atraso:', '${cliente.diasAtraso}', color: estadoColor, boldValue: enMora),
            
            // ✅ Muestra el Capital Prestado (Corregido)
            _buildInfoRow(Icons.monetization_on, 'Valor Prestado (Capital):', 'COP \$${_formatCurrency(cliente.valorCapitalPrestado)}'),
            
            // ✅ Muestra el Valor Total a Devolver (Capital + Intereses)
            _buildInfoRow(Icons.attach_money, 'Valor Total Credito:', 'COP \$${_formatCurrency(cliente.valorTotal)}', color: Colors.blueGrey.shade700),
            
            // ✅ Muestra las cuotas pendientes correctamente
            _buildInfoRow(Icons.watch_later, 'Cuotas Pendientes:', '${cuotasPendientesInt} de ${cliente.cantidadCuotas}', color: Colors.black87),
            
            _buildInfoRow(Icons.account_balance_wallet, 'Saldo Restante:', 'COP \$${_formatCurrency(cliente.saldoRestante)}', color: Colors.red.shade900, boldValue: true),

            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Text("Último Abono Registrado:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                   const SizedBox(height: 4),
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                      Text(cliente.fechaUltimoPago, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                      Text('COP \$${_formatCurrency(cliente.valorUltimoPago)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green)),
                     ],
                   )
                ],
              ),
            ),

            const Divider(height: 20, color: Colors.blueGrey),
            
            _buildSectionTitle('Información del Fiador'),
            _buildInfoRow(Icons.person_outline, 'Nombre:', cliente.nombreFiador),
            _buildInfoRow(Icons.home, 'Dirección:', cliente.direccionFiador),

            const SizedBox(height: 20),
            
            // --- BOTÓN: VALOR DIFERIDO ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  _mostrarModalDiferido(cliente);
                },
                icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                label: const Text(
                  "AGREGAR VALOR DIFERIDO (INTERÉS MORA)",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    // Función auxiliar para formatear a COP (ej: 1.000.000)
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  Widget _buildHeader(String title, String subtitle) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: Colors.blue.shade50,
          child: Icon(Icons.person, color: Colors.blue.shade700, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Cédula: $subtitle',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 6.0),
      child: Text(
        title,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? color, bool boldValue = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color ?? Colors.black54),
          const SizedBox(width: 8),
          SizedBox(
            width: 130, 
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: color ?? Colors.black87,
                fontWeight: boldValue ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}