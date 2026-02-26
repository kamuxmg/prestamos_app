import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Importación para llamadas HTTP
import 'dart:convert'; // Importación para JSON
import 'config.dart'; // Importación para la URL base

import 'crear_cliente.dart';
import 'consulta_clientes.dart'; 
import 'crear_prestamos.dart'; 
import 'modificar_cliente.dart'; 
import 'pagosscreen.dart'; 
import 'consultapagosscreen.dart'; 
import 'cartera_clientes.dart';
import 'comprobantes_de_pago.dart'; 
import 'recaudo_cartera.dart'; 
import 'reporte_rentabilidad.dart'; 
// --- NUEVA IMPORTACIÓN ---
import 'edicion_comprobantes_pago.dart'; 
import 'edades_estado_cartera.dart'; // Agregada sin quitar las anteriores


// Convertimos MainMenu a StatefulWidget para manejar el estado del contador
class MainMenu extends StatefulWidget {
  final String userName;
  
  const MainMenu({super.key, required this.userName});

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  int _cobrosPendientesCount = 0;
  bool _isLoadingCobros = true;

  @override
  void initState() {
    super.initState();
    _fetchCobrosPendientes();
  }

  // Función para obtener el conteo de cobros pendientes de la API PHP
  Future<void> _fetchCobrosPendientes() async {
    setState(() {
      _isLoadingCobros = true;
    });

    try {
      final url = Uri.parse("${Config.apiBase}/consultar_cobros_pendientes.php");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] == true) {
          setState(() {
            _cobrosPendientesCount = data['count'] ?? 0;
          });
        } else {
          // Si hay error en la lógica PHP, el contador será 0.
          debugPrint('Error en la API de cobros: ${data['message']}');
        }
      } else {
        debugPrint('Error HTTP al obtener cobros: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error de conexión al obtener cobros: $e');
    } finally {
      setState(() {
        _isLoadingCobros = false;
      });
    }
  }

  // Helper para items de menú estándar
  Widget _tile(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }
  
  // Nuevo Helper para mostrar el ítem con el contador (Badge)
  Widget _cobrosTile(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.red),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          if (_isLoadingCobros)
            const SizedBox(
              width: 16, 
              height: 16, 
              child: CircularProgressIndicator(strokeWidth: 2)
            )
          else if (_cobrosPendientesCount > 0)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$_cobrosPendientesCount',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      onTap: onTap,
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Panel Principal"),
        backgroundColor: Colors.blue,
        elevation: 4,
        centerTitle: true,
      ),
      drawer: Drawer(
        child: Column(
          children: [
            // 1. UserAccountsDrawerHeader (Fijo en la parte superior)
            UserAccountsDrawerHeader( 
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF0077B6), Color(0xFF00B4D8)], 
                begin: Alignment.topLeft, 
                end: Alignment.bottomRight), // Degradado de azul
              ),
              accountName: Text(widget.userName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              accountEmail: const Text("Préstamos JV App"),
              currentAccountPicture: Container( // Se reemplaza CircleAvatar por un Container para el logo
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10), // Opcional: bordes redondeados para un aspecto moderno
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(8.0),
                child: Image.asset( // Asegúrate de que esta ruta sea correcta
                  'assets/images/logo_prestamos_jv.png', 
                  fit: BoxFit.contain,
                  // El logo debe ser un archivo PNG con fondo transparente
                ),
              ),
            ),
            
            // 2. Menú Desplazable (Usa Expanded + ListView para evitar el overflow)
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero, 
                children: <Widget>[
                  // --- COBROS PENDIENTES (Nuevo ítem en la parte superior del menú) ---
                  _cobrosTile(context, Icons.notifications_active, "Cobros Pendientes Hoy", () {
                    // Cierra el drawer y navega a la pantalla de Cartera, 
                    // donde se supone que se hará la gestión de cobros.
                    Navigator.pop(context); 
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CarteraClientesScreen()), 
                    );
                  }),
                  const Divider(),
                  
                  // --- Menú Estándar ---
                  _tile(context, Icons.people, "Clientes", () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CrearClientePage()), 
                    );
                  }),
                  _tile(context, Icons.search, "Consulta Clientes", () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ConsultaClientesPage()), 
                    );
                  }),
                  _tile(context, Icons.request_page, "Préstamos", () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CrearPrestamoPage()), 
                    );
                  }),
                  _tile(context, Icons.edit, "Modificar Clientes", () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ModificarClienteForm()),
                    );
                  }),
                  _tile(context, Icons.payment, "Pagos", () {
                    Navigator.pop(context);
                    Navigator.push( 
                      context,
                      MaterialPageRoute(builder: (_) => PagosScreen()), 
                    );
                  }),

                  // --- NUEVO VÍNCULO: DEVOLUCIÓN ---
                  _tile(context, Icons.assignment_return, "Devolución", () {
                    Navigator.pop(context);
                    Navigator.push( 
                      context,
                      MaterialPageRoute(builder: (_) => const EdicionComprobantesPagoScreen()), 
                    );
                  }),
                  
                  // Navegación a Cartera de Clientes
                  _tile(context, Icons.account_balance_wallet, "Cartera", () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CarteraClientesScreen()), 
                    );
                  }),
                  
                  // --- Reportes con Submenú Acordeón (ExpansionTile) ---
                  ExpansionTile(
                    leading: const Icon(Icons.bar_chart, color: Colors.blue),
                    title: const Text("Reportes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    children: <Widget>[
                      // --- NUEVO LINK: ESTADO CARTERA ---
                      ListTile(
                        title: const Text('Estado Cartera'),
                        leading: const Icon(Icons.assignment_late, color: Colors.redAccent),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const EstadoCarteraScreen()),
                          );
                        },
                      ),
                      // 1. Comprobantes (Abre la nueva pantalla)
                      ListTile(
                        title: const Text('Comprobantes'),
                        leading: const Icon(Icons.receipt, color: Colors.blueAccent),
                        onTap: () {
                          Navigator.pop(context); // Cierra el Drawer
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ComprobantesDePagoScreen()),
                          );
                        },
                      ),
                      // 2. Recaudo
                      ListTile(
                        title: const Text('Recaudo'),
                        leading: const Icon(Icons.paid, color: Colors.green),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push( 
                            context,
                            MaterialPageRoute(builder: (_) => const RecaudoCarteraScreen()), 
                          );
                        },
                      ),
                      // 3. Finanzas (Reporte de Rentabilidad)
                      ListTile(
                        title: const Text('Finanzas'),
                        leading: const Icon(Icons.analytics, color: Colors.orange),
                        onTap: () {
                          Navigator.pop(context); // Cierra el Drawer
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ReporteRentabilidadScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // FIN: Contenido Desplazable
            
            // 3. Footer (Fijo en la parte inferior)
            const Divider(),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red),
              title: const Text("Cerrar sesión", style: TextStyle(color: Colors.red)),
              onTap: () {
                // Vuelve a la ruta inicial (Login)
                Navigator.pushReplacementNamed(context, '/');
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
        // FIN: AJUSTE CRÍTICO DE LAYOUT
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo grande en el centro de la pantalla principal
            Image.asset(
              'assets/images/logo_prestamos_jv.png', // Usa la misma ruta
              height: 120, // Ajusta el tamaño según tu preferencia
              width: 120,
            ),
            const SizedBox(height: 24),
            Text(
              "Bienvenido ${widget.userName}",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text("Selecciona una opción en el menú lateral", style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}