import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart'; // <-- NUEVA IMPORTACIÓN

class CrearPrestamoPage extends StatefulWidget {
  const CrearPrestamoPage({super.key});

  @override
  State<CrearPrestamoPage> createState() => _CrearPrestamoPageState();
}

class _CrearPrestamoPageState extends State<CrearPrestamoPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _totalController = TextEditingController();
  final TextEditingController _tipoCuotaController = TextEditingController();
  final TextEditingController _fechasCobroController = TextEditingController();
  final TextEditingController _fechaCreacionController = TextEditingController();
  final TextEditingController _clienteController = TextEditingController();
  final TextEditingController _consecutivoController = TextEditingController();
  final TextEditingController _cantidadCuotasController = TextEditingController();
  final TextEditingController _valorCuotaController = TextEditingController();  
  final TextEditingController _fechaFinalController = TextEditingController();

  String _estado = 'activo';
  bool _cargando = false;
  String _consecutivo = '1';
  List _clientes = []; 
  
  double _montoSeleccionado = 100000.00;  
  double _tasaInteresTotalAplicada = 0.0;  

  String? _clienteIdSeleccionado;  
  String? _telefonoClienteSeleccionado; // <-- NUEVA VARIABLE PARA EL TELÉFONO

  List<String> _festivos = ["2025-12-25", "2025-11-02"];

  // Formatear/Desformatear valores (Lógica de formato CO)
  String _formatearValor(double valor) {
    final formato = NumberFormat.currency(
      locale: "es_CO",
      symbol: "\$",
      decimalDigits: 2,
    );
    return formato.format(valor).replaceAll('\$', '').trim();
  }

  double _desformatearValor(String valor) {
    String cleaned = valor.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0.0;
  }

  // --- OBTENER CONSECUTIVO AUTOMÁTICO ---
  Future<void> _obtenerConsecutivo() async {
    final url = Uri.parse("${Config.apiBase}/consecutivo_crear_prestamos.php");
    try {
      final response = await http.get(url);
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        setState(() {
          _consecutivo = data['consecutivo'].toString();
          _consecutivoController.text = _consecutivo;
        });
      } else {
        _consecutivoController.text = _consecutivo;
      }
    } catch (e) {
      _consecutivoController.text = _consecutivo;
    }
  }

  // --- BÚSQUEDA DE CLIENTE ---
  Future<void> _buscarCliente() async {
    final query = _clienteController.text.trim();
    if (query.isEmpty || query.length < 2) {
      setState(() { _clientes = []; });
      return;
    }
    final url = Uri.parse("${Config.apiBase}/buscar_cliente_prestamos.php?search=$query");
    setState(() { _cargando = true; });

    try {
      final response = await http.get(url);
      final cleanBody = response.body.trim();
      final data = jsonDecode(cleanBody);
      if (data['success'] == true) {
        setState(() { _clientes = data['clientes']; });
      } else {
        setState(() { _clientes = []; });
      }
    } catch (e) {
      setState(() { _clientes = []; });
    } finally {
      setState(() { _cargando = false; });
    }
  }
  
  // Lógica principal de recálculo:
  void _recalcularTotalEInteres() {
    final cantidadCuotasStr = _cantidadCuotasController.text;
    final valorCuotaStr = _valorCuotaController.text;
    
    final cantidadCuotas = int.tryParse(cantidadCuotasStr) ?? 0;
    final valorCuota = _desformatearValor(valorCuotaStr);

    if (cantidadCuotas <= 0 || valorCuota <= 0 || _montoSeleccionado <= 0) {
      _totalController.clear();
      setState(() { _tasaInteresTotalAplicada = 0.0; });
      _actualizarFechasYFechaFinal();
      return;
    }

    // 1. CÁLCULO DEL VALOR TOTAL A RETORNAR
    final double totalARetornar = cantidadCuotas * valorCuota;
    _totalController.text = _formatearValor(totalARetornar);

    // 2. CÁLCULO DEL PORCENTAJE DE INTERÉS
    if (totalARetornar > _montoSeleccionado) {
      final double totalInteres = totalARetornar - _montoSeleccionado;
      final double tasaAplicada = totalInteres / _montoSeleccionado;
      setState(() {
        _tasaInteresTotalAplicada = tasaAplicada;  
      });
    } else {
      setState(() {
        _tasaInteresTotalAplicada = 0.0;
      });
    }

    // 3. ACTUALIZAR FECHAS 
    _actualizarFechasYFechaFinal();
  }

  // Lógica de fechas
  void _actualizarFechasYFechaFinal() {
    final cantidadCuotasStr = _cantidadCuotasController.text;
    final cantidadCuotas = int.tryParse(cantidadCuotasStr);
    final tipoCuota = _tipoCuotaController.text;
    final fechaCreacion = _fechaCreacionController.text;

    if (cantidadCuotas == null || cantidadCuotas <= 0 || tipoCuota.isEmpty || fechaCreacion.isEmpty) {
      _fechasCobroController.clear();
      _fechaFinalController.clear();
      return;
    }

    try {
      DateTime fechaInicio = DateFormat('yyyy-MM-dd').parse(fechaCreacion);

      List<DateTime> fechasCalculadas = _generarPlanDePagos(fechaInicio, tipoCuota, cantidadCuotas);

      List<String> fechasCobroStr = fechasCalculadas.map((d) => DateFormat('yyyy-MM-dd').format(d)).toList();

      setState(() {
        _fechasCobroController.text = fechasCobroStr.join(', ');
        if (fechasCalculadas.isNotEmpty) {
          _fechaFinalController.text = DateFormat('yyyy-MM-dd').format(fechasCalculadas.last);
        } else {
          _fechaFinalController.clear();
        }
      });
    } catch (e) {
      _fechasCobroController.clear();
      _fechaFinalController.clear();
    }
  }

  // Generador de plan de pagos
  List<DateTime> _generarPlanDePagos(DateTime fechaInicio, String tipoCuota, int cantidadCuotas) {
    List<DateTime> fechas = [];
    DateTime currentDate = fechaInicio;  
    int cuotasGeneradas = 0;
    String periodicidad = tipoCuota.toLowerCase();

    while (cuotasGeneradas < cantidadCuotas) {
      // Avanzar al siguiente período según la periodicidad
      switch (periodicidad) {
        case "diario":
          currentDate = currentDate.add(const Duration(days: 1));
          break;
        case "semanal":
          currentDate = currentDate.add(const Duration(days: 7));
          break;
        case "quincenal":
          currentDate = currentDate.add(const Duration(days: 15));
          break;
        case "mensual":
          int newMonth = currentDate.month + 1;
          int newYear = currentDate.year;
          int newDay = currentDate.day;

          if (newMonth > 12) {
            newMonth = 1;
            newYear++;
          }
          try {
            currentDate = DateTime(newYear, newMonth, newDay);
          } catch (e) {
            currentDate = DateTime(newYear, newMonth + 1, 0);  
          }
          break;
        default:
          return fechas;
      }

      // Comprobar y ajustar si la fecha cae en Domingo o Festivo (Día No Hábil)
      if (currentDate.weekday == DateTime.sunday || _festivos.contains(DateFormat('yyyy-MM-dd').format(currentDate))) {
        currentDate = _avanzarAlSiguienteDiaHabil(currentDate);
      }

      fechas.add(currentDate);
      cuotasGeneradas++;
    }

    return fechas;
  }

  // Función auxiliar para avanzar al siguiente día hábil
  DateTime _avanzarAlSiguienteDiaHabil(DateTime date) {
    DateTime nextDay = date;  
    while (nextDay.weekday == DateTime.sunday || _festivos.contains(DateFormat('yyyy-MM-dd').format(nextDay))) {
      nextDay = nextDay.add(const Duration(days: 1));  
    }
    return nextDay;
  }

  // --- NUEVA FUNCIÓN PARA ENVIAR WHATSAPP (CORREGIDA) ---
  Future<void> _enviarComprobanteWhatsApp() async {
    if (_telefonoClienteSeleccionado == null || _telefonoClienteSeleccionado!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("El cliente no tiene un número de teléfono guardado para notificarle."), backgroundColor: Colors.orange),
      );
      return;
    }

    // Limpiar el número de formato (espacios, guiones, etc)
    String telefono = _telefonoClienteSeleccionado!.replaceAll(RegExp(r'\D'), '');
    
    // Asumiendo código de Colombia (+57). Ajústalo al código de tu país si es necesario.
    if (!telefono.startsWith('57') && telefono.length == 10) {
      telefono = '57$telefono';
    }

    final String mensaje = '''
✅ *NUEVO PRÉSTAMO APROBADO* ✅
--------------------------------------
👤 *Cliente:* ${_clienteController.text}
🔢 *N° de Préstamo:* $_consecutivo
📅 *Fecha de Emisión:* ${_fechaCreacionController.text}

💰 *RESUMEN DEL CRÉDITO*
▫️ *Monto Aprobado:* \$${_formatearValor(_montoSeleccionado)}
▫️ *Total a Retornar:* \$${_totalController.text}

🗓 *PLAN DE PAGOS*
▫️ *Frecuencia:* ${_tipoCuotaController.text}
▫️ *Número de Cuotas:* ${_cantidadCuotasController.text}
▫️ *Valor por Cuota:* \$${_valorCuotaController.text}
▫️ *Fecha Final Estimada:* ${_fechaFinalController.text}

--------------------------------------
🤝 _Gracias por confiar en nosotros. Si tienes alguna duda, responde a este mensaje._
''';

    final String urlEncoded = Uri.encodeComponent(mensaje);
    
    // 🛑 CAMBIO CLAVE AQUÍ: Usamos la URL oficial de la API de WhatsApp
    final Uri urlWhatsApp = Uri.parse("https://api.whatsapp.com/send?phone=$telefono&text=$urlEncoded");

    try {
      // Usamos LaunchMode.externalApplication para forzar que salga de la app y abra el navegador/WhatsApp
      await launchUrl(urlWhatsApp, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Error al abrir WhatsApp: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No se pudo abrir WhatsApp. Verifica tu conexión o instalación."), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  // FUNCIÓN DE CREACIÓN DE PRÉSTAMO 
  Future<void> _crearPrestamo() async {
    if (!_formKey.currentState!.validate()) return;
    if (_clienteIdSeleccionado == null || _clienteIdSeleccionado!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Debe seleccionar un cliente de la lista."), backgroundColor: Colors.orange),
        );
        return;
    }
    
    _recalcularTotalEInteres();

    final totalCalculado = _desformatearValor(_totalController.text);
    if (totalCalculado <= _montoSeleccionado) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("El Valor Total a Retornar debe ser estrictamente mayor al Monto de Crédito."), backgroundColor: Colors.red),
        );
        return;
    }

    setState(() { _cargando = true; });

    try {
      final url = Uri.parse("${Config.apiBase}/crear_prestamo_v3.php");  

      final Map<String, String> prestamoData = {
        'monto': _montoSeleccionado.toString(),      
        'total': totalCalculado.toString(),          
        'tasa_interes': (_tasaInteresTotalAplicada * 100).toStringAsFixed(2),  
        'valor_cuota': _desformatearValor(_valorCuotaController.text).toString(),  
        
        'cuotas': _cantidadCuotasController.text,
        'tipo_cuota': _tipoCuotaController.text, 
        'fechas_cobro': _fechasCobroController.text,
        'estado': _estado,
        'fecha_creacion': _fechaCreacionController.text,
        'consecutivo': _consecutivo,
        'cliente': _clienteIdSeleccionado!, 
        'fecha_final': _fechaFinalController.text,
      };

      final response = await http.post(
        url,
        headers: { 
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: prestamoData,  
      );
      
      final data = jsonDecode(response.body.trim());

      if (data["success"] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Préstamo creado exitosamente")),
          );
        }
        
        // --- AQUÍ LLAMAMOS A LA FUNCIÓN DE WHATSAPP ---
        await _enviarComprobanteWhatsApp();

        // Limpiar y re-inicializar
        setState(() {
          _cantidadCuotasController.clear();
          _valorCuotaController.clear();
          _totalController.clear();
          _fechasCobroController.clear();
          _fechaFinalController.clear();
          _clienteController.clear();
          _clienteIdSeleccionado = null;
          _telefonoClienteSeleccionado = null; // Limpiar teléfono también
          _montoSeleccionado = 100000.00;  
          _tasaInteresTotalAplicada = 0.0;
          _obtenerConsecutivo(); // Vuelve a obtener el consecutivo
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data["message"]), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al enviar: $e. Si el error persiste, revise el log de errores de Apache."), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() { _cargando = false; });
    }
  }

  @override
  void initState() {
    super.initState();
    _obtenerConsecutivo(); 
    _tipoCuotaController.text = 'Quincenal'; // Valor inicial para el Dropdown
    _fechaCreacionController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());

    _cantidadCuotasController.addListener(_recalcularTotalEInteres);
    _valorCuotaController.addListener(_recalcularTotalEInteres);
    
    _tipoCuotaController.addListener(_actualizarFechasYFechaFinal);
    _fechaCreacionController.addListener(_actualizarFechasYFechaFinal);
    _cantidadCuotasController.addListener(_actualizarFechasYFechaFinal);  
  }

  @override
  void dispose() {
    _cantidadCuotasController.removeListener(_recalcularTotalEInteres);
    _valorCuotaController.removeListener(_recalcularTotalEInteres);
    _tipoCuotaController.removeListener(_actualizarFechasYFechaFinal);
    _fechaCreacionController.removeListener(_actualizarFechasYFechaFinal);
    _cantidadCuotasController.removeListener(_actualizarFechasYFechaFinal);

    _totalController.dispose();
    _tipoCuotaController.dispose();
    _fechasCobroController.dispose();
    _fechaCreacionController.dispose();
    _clienteController.dispose();
    _consecutivoController.dispose();
    _cantidadCuotasController.dispose();
    _valorCuotaController.dispose();
    _fechaFinalController.dispose();
    super.dispose();
  }

  List<DropdownMenuItem<double>> _generarListaMontos() {
    List<DropdownMenuItem<double>> items = [];
    
    // Rango 1: De 100,000 a 1,000,000 de 10,000 en 10,000
    for (double monto = 100000.00; monto <= 1000000.00; monto += 10000.00) {
      items.add(DropdownMenuItem<double>(
        value: monto,
        child: Text(_formatearValor(monto)),
      ));
    }

    // Rango 2: De 1,050,000 hasta 50,000,000 de 50,000 en 50,000
    for (double monto = 1050000.00; monto <= 50000000.00; monto += 50000.00) {
      items.add(DropdownMenuItem<double>(
        value: monto,
        child: Text(_formatearValor(monto)),
      ));
    }
    
    return items;
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Crear Préstamo"),
        backgroundColor: Colors.blue,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CONSECUTIVO
                TextFormField(
                  controller: _consecutivoController,
                  decoration: const InputDecoration(
                    labelText: 'Consecutivo del Préstamo',
                    prefixIcon: Icon(Icons.assignment),
                  ),
                  readOnly: true,
                ),
                const SizedBox(height: 16),
                // CLIENTE
                TextFormField(
                  controller: _clienteController,
                  decoration: const InputDecoration(
                    labelText: 'ID/Nombre del Cliente',
                    prefixIcon: Icon(Icons.person),
                  ),
                  onChanged: (value) { _buscarCliente(); }, // Dispara la búsqueda
                  validator: (value) {
                    if (_clienteIdSeleccionado == null) {
                       return 'Debe seleccionar un cliente de la lista';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                // LISTA DE SUGERENCIAS DE CLIENTE
                _cargando
                    ? const CircularProgressIndicator()
                    : _clientes.isNotEmpty
                          ? ListView.builder(
                              shrinkWrap: true,
                              itemCount: _clientes.length,
                              itemBuilder: (context, index) {
                                final cliente = _clientes[index];
                                return ListTile(
                                  title: Text(cliente['nombre']),
                                  subtitle: Text('ID: ${cliente['id']}'),
                                  onTap: () {
                                    setState(() {
                                      _clienteIdSeleccionado = cliente['id'].toString();
                                      _clienteController.text = cliente['nombre'];  
                                      
                                      // --- AQUÍ CAPTURAMOS EL TELÉFONO ---
                                      _telefonoClienteSeleccionado = cliente['telefono']?.toString() ?? '';
                                      
                                      _clientes = []; // Limpiar sugerencias al seleccionar
                                      _formKey.currentState!.validate();  
                                    });
                                  },
                                );
                              },
                            )
                          : Container(),
                const SizedBox(height: 16),
                
                // FECHA DE CREACIÓN
                TextFormField(
                  controller: _fechaCreacionController,
                  decoration: const InputDecoration(
                    labelText: 'Fecha de Creación (Inicio del Crédito)',
                    prefixIcon: Icon(Icons.date_range),
                  ),
                  keyboardType: TextInputType.datetime,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Este campo es obligatorio';
                    }
                    return null;
                  },
                  onTap: () async {
                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2101),
                    );
                    if (pickedDate != null) {
                      setState(() {
                        _fechaCreacionController.text =
                            DateFormat('yyyy-MM-dd').format(pickedDate);
                        _recalcularTotalEInteres();  
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                
                // MONTO DE CRÉDITO
                DropdownButtonFormField<double>(
                  value: _montoSeleccionado,
                  onChanged: (double? newValue) {
                    setState(() {
                      _montoSeleccionado = newValue!;
                      _recalcularTotalEInteres();  
                    });
                  },
                  items: _generarListaMontos(),
                  decoration: const InputDecoration(
                    labelText: 'Monto de Crédito',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                ),
                const SizedBox(height: 16),
                
                // PERIODICIDAD (Tipo Cuota)
                DropdownButtonFormField<String>(
                  value: _tipoCuotaController.text.isEmpty
                      ? null
                      : _tipoCuotaController.text,
                  onChanged: (String? newValue) {
                    setState(() {
                      _tipoCuotaController.text = newValue!;
                      _recalcularTotalEInteres();  
                    });
                  },
                  items: const [
                    'Diario',
                    'Semanal',  
                    'Quincenal',  
                    'Mensual'
                  ] 
                      .map((tipo) => DropdownMenuItem<String>(
                                value: tipo,
                                child: Text(tipo),
                              ))
                      .toList(),
                  decoration: const InputDecoration(
                    labelText: 'Periodicidad de Pago',
                    prefixIcon: Icon(Icons.calendar_view_day),
                  ),
                ),
                const SizedBox(height: 16),
                
                // CANTIDAD DE CUOTAS
                TextFormField(
                  controller: _cantidadCuotasController,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad de Cuotas (Días/Períodos)',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  keyboardType: TextInputType.number,
                  readOnly: false,  
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Este campo es obligatorio';
                    }
                    if (int.tryParse(value) == null || int.parse(value) <= 0) {
                      return 'Ingrese un número de cuotas válido (> 0)';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),
                
                // VALOR CUOTA
                TextFormField(
                  controller: _valorCuotaController,
                  decoration: const InputDecoration(
                    labelText: 'Valor Cuota a Pagar',
                    prefixIcon: Icon(Icons.monetization_on),
                    hintText: 'Ej: 100000',
                  ),
                  keyboardType: TextInputType.number,
                  readOnly: false,  
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Este campo es obligatorio';
                    }
                    if (_desformatearValor(value) <= 0) {
                      return 'Ingrese un valor de cuota válido (> 0)';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // INTERÉS APLICADO (Calculado)
                Text(
                  'Porcentaje de Interés Aplicado: ${(_tasaInteresTotalAplicada * 100).toStringAsFixed(2)}%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                
                const SizedBox(height: 16),

                // VALOR TOTAL A RETORNAR (Calculado)
                TextFormField(
                  controller: _totalController,
                  decoration: const InputDecoration(
                    labelText: 'Valor Total a Retornar (Calculado)',
                    prefixIcon: Icon(Icons.monetization_on),
                  ),
                  readOnly: true,
                ),
                const SizedBox(height: 16),
                
                // FECHA FINAL (Calculada)
                TextFormField(
                  controller: _fechaFinalController,
                  decoration: const InputDecoration(
                    labelText: 'Fecha Final del Préstamo',
                    prefixIcon: Icon(Icons.event_available),
                    hintText: 'Se calcula automáticamente',
                  ),
                  readOnly: true,
                ),
                const SizedBox(height: 16),

                // FECHAS DE COBRO (Generadas)
                TextFormField(
                  controller: _fechasCobroController,
                  decoration: const InputDecoration(
                    labelText: 'Fechas de Cobro (Generadas)',
                    prefixIcon: Icon(Icons.date_range),
                  ),
                  readOnly: true,
                  maxLines: 5,  
                ),
                const SizedBox(height: 16),

                // ESTADO
                DropdownButtonFormField<String>(
                  value: _estado,
                  onChanged: (String? newValue) {
                    setState(() {
                      _estado = newValue!;
                    });
                  },
                  items: const ['activo', 'cerrado']
                      .map((estado) => DropdownMenuItem<String>(
                                value: estado,
                                child: Text(estado),
                              ))
                      .toList(),
                  decoration: const InputDecoration(
                    labelText: 'Estado del Préstamo',
                    prefixIcon: Icon(Icons.toggle_on),
                  ),
                ),
                const SizedBox(height: 20),
                
                // BOTÓN DE CREAR (Estilo Azul Moderno)
                _cargando
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                          onPressed: _crearPrestamo,  
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E88E5), // Azul más vibrante y moderno (Blue 600)
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Crear Préstamo'),
                        ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}