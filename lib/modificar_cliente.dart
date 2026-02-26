import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// 🛑 CLASE ModificarClienteForm - AJUSTADA PARA BÚSQUEDA EN SERVIDOR
class ModificarClienteForm extends StatefulWidget {
  const ModificarClienteForm({super.key}); // Added key

  @override
  // Se cambia el nombre para consistencia
  State<ModificarClienteForm> createState() => _ModificarClienteFormState(); 
}

class _ModificarClienteFormState extends State<ModificarClienteForm> {
  TextEditingController _searchController = TextEditingController();
  // Solo se necesita una lista para los resultados de la búsqueda
  List<dynamic> _clientesFiltrados = []; 
  bool _cargando = false;

  // 🛑 Función para buscar clientes en el servidor, basada en el input del usuario.
  Future<void> _buscarClientesEnServidor(String query) async {
    // Si la búsqueda está vacía, no hacemos la llamada y limpiamos la lista
    if (query.isEmpty) {
        setState(() {
            _clientesFiltrados = [];
        });
        return;
    }

    setState(() {
        _cargando = true;
        _clientesFiltrados = []; // Limpiar antes de la nueva búsqueda
    });

    try {
      // 🛑 CAMBIO CLAVE: Envía el query al servidor
      final response = await http.get(Uri.parse('http://localhost/prestamos_api/buscar_cliente_editar.php?search=$query'));

      if (response.statusCode == 200) {
        var data = json.decode(response.body);

        if (data['success'] == true) {
          setState(() {
            _clientesFiltrados = data['clientes']; // Asignar la lista de clientes
          });
        } else {
            // Si success es false, solo limpiamos la lista y mostramos el mensaje del servidor
            setState(() {
                _clientesFiltrados = [];
            });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'No se encontraron clientes'), backgroundColor: Colors.orange));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al contactar el servidor: ${response.statusCode}'), backgroundColor: Colors.red));
      }
    } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error de conexión: $e'), backgroundColor: Colors.red));
    } finally {
        setState(() {
            _cargando = false;
        });
    }
  }

  // 🛑 Esta función se llama al escribir en el TextField
  void _buscarClientes(String text) {
      _buscarClientesEnServidor(text);
  }

  // Eliminar cliente con verificación de crédito activo (mantengo la lógica original)
  Future<void> _eliminarCliente(int id) async {
    final response = await http.post(
      Uri.parse('http://localhost/prestamos_api/verificar_credito_activo.php'),
      body: {'id': id.toString()},
    );

    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      
      if (data['success'] == false) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']), backgroundColor: Colors.red));
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirmar Eliminación'),
            content: const Text('Este cliente no presenta créditos activos. ¿Está seguro de que desea eliminarlo?'),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancelar'),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              TextButton(
                child: const Text('Eliminar'),
                onPressed: () {
                  _confirmarEliminacion(id);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al verificar el crédito'), backgroundColor: Colors.red));
    }
  }

  // Confirmación final para eliminar el cliente
  void _confirmarEliminacion(int id) async {
    final response = await http.post(
      Uri.parse('http://localhost/prestamos_api/eliminar_cliente.php'),
      body: {'id': id.toString()},
    );

    if (response.statusCode == 200) {
      // 🛑 AJUSTE: Eliminar solo de la lista filtrada
      setState(() {
        _clientesFiltrados.removeWhere((cliente) => cliente['id'] == id);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cliente eliminado'), backgroundColor: Colors.green));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al eliminar cliente'), backgroundColor: Colors.red));
    }
  }

  @override
  void initState() {
    super.initState();
    // 🛑 AJUSTE CLAVE: Se elimina la llamada a _cargarClientes() para evitar la carga inicial masiva.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modificar Cliente'),
        backgroundColor: Colors.blue, // Added color for consistency
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Buscar Cliente por nombre o cédula', // Improved hint
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _buscarClientes, // Llama a la búsqueda en el servidor
            ),
            const SizedBox(height: 20),
            _cargando
                ? const Center(child: CircularProgressIndicator())
                : Expanded(
                    child: _clientesFiltrados.isEmpty && _searchController.text.isNotEmpty
                        ? const Center(child: Text("No se encontraron coincidencias."))
                        : _clientesFiltrados.isEmpty && _searchController.text.isEmpty
                            ? const Center(child: Text("Escriba el nombre o cédula del cliente a buscar."))
                            : GridView.builder(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2, 
                                  crossAxisSpacing: 10.0,
                                  mainAxisSpacing: 10.0,
                                ),
                                itemCount: _clientesFiltrados.length, // Mostrar todos los resultados de la búsqueda
                                itemBuilder: (context, index) {
                                  var cliente = _clientesFiltrados[index];
                                  return Card(
                                    elevation: 4,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                            child: Text(cliente['nombre'] ?? 'N/A', 
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                            ),
                                        ),
                                        Text(cliente['cedula'] ?? 'N/A'),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit, color: Colors.blue),
                                              onPressed: () async {
                                                // Esperamos el resultado de la edición.
                                                await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => EdicionClienteForm(cliente: cliente),
                                                  ),
                                                );
                                                // Refrescar la búsqueda después de editar para ver los cambios
                                                _buscarClientes(_searchController.text);
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.red),
                                              onPressed: () {
                                                _eliminarCliente(cliente['id']);
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ),
          ],
        ),
      ),
    );
  }
}

// 🛑 CLASE EdicionClienteForm - AJUSTADA PARA VALIDACIÓN DE CÉDULA
class EdicionClienteForm extends StatefulWidget {
  final Map cliente;
  const EdicionClienteForm({super.key, required this.cliente}); // Added key

  @override
  State<EdicionClienteForm> createState() => _EdicionClienteFormState();
}

class _EdicionClienteFormState extends State<EdicionClienteForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreController;
  late TextEditingController _cedulaController;
  late TextEditingController _telefonoController;
  late TextEditingController _direccionController;
  late TextEditingController _emailController;
  late TextEditingController _zonaController;
  late TextEditingController _nombreFiadorController;
  late TextEditingController _direccionFiadorController;
  late TextEditingController _telefonoFiadorController;
  
  // Guardar la cédula original para la verificación
  late String _cedulaOriginal; 

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.cliente['nombre'] ?? '');
    _cedulaController = TextEditingController(text: widget.cliente['cedula'] ?? '');
    _telefonoController = TextEditingController(text: widget.cliente['telefono'] ?? '');
    _direccionController = TextEditingController(text: widget.cliente['direccion'] ?? '');
    _emailController = TextEditingController(text: widget.cliente['email'] ?? '');
    _zonaController = TextEditingController(text: widget.cliente['zona'] ?? '');
    _nombreFiadorController = TextEditingController(text: widget.cliente['nombre_fiador'] ?? '');
    _direccionFiadorController = TextEditingController(text: widget.cliente['direccion_fiador'] ?? '');
    _telefonoFiadorController = TextEditingController(text: widget.cliente['telefono_fiador'] ?? '');
    
    _cedulaOriginal = widget.cliente['cedula'] ?? '';
  }

  // 🛑 Función de validación de cédula antes de actualizar
  Future<bool> _verificarCambioCedula() async {
      // 1. Si la cédula no cambió, no hay necesidad de verificar.
      if (_cedulaController.text == _cedulaOriginal) {
          return true;
      }

      // 2. Si la cédula cambió, verificamos si tiene créditos activos.
      final response = await http.post(
          Uri.parse('http://localhost/prestamos_api/verificar_credito_activo.php'),
          body: {'id': widget.cliente['id'].toString()},
      );

      if (response.statusCode == 200) {
          var data = json.decode(response.body);
          
          if (data['success'] == false) {
              // success=false en este contexto significa que tiene crédito activo.
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('No se puede cambiar la cédula. El cliente tiene créditos activos.'), 
                           backgroundColor: Colors.red)
              );
              return false;
          }
          // success=true significa que NO tiene créditos activos.
          return true;
      }
      
      // Error de servidor al verificar
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al verificar créditos activos.'), 
                         backgroundColor: Colors.red)
      );
      return false;
  }

  // 🛑 Función para actualizar el cliente en el servidor PHP
  Future<void> _actualizarCliente() async {
    if (!_formKey.currentState!.validate()) {
        return;
    }

    // 🛑 Paso 1: Verificar la restricción de la cédula
    bool puedeCambiar = await _verificarCambioCedula();
    if (!puedeCambiar) {
        return;
    }

    // 🛑 Paso 2: Si es seguro, procedemos a actualizar.
    final response = await http.post(
      Uri.parse('http://localhost/prestamos_api/actualizar_cliente.php'),
      body: {
        'id': widget.cliente['id'].toString(),
        'nombre': _nombreController.text,
        'cedula': _cedulaController.text,
        'telefono': _telefonoController.text,
        'direccion': _direccionController.text,
        'email': _emailController.text,
        'zona': _zonaController.text,
        'nombre_fiador': _nombreFiadorController.text,
        'direccion_fiador': _direccionFiadorController.text,
        'telefono_fiador': _telefonoFiadorController.text,
      },
    );

    if (response.statusCode == 200) {
        var data = json.decode(response.body);
        if(data['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cliente actualizado'), backgroundColor: Colors.green));
            Navigator.pop(context); // Regresa a la lista de clientes
        } else {
            // Manejar errores de actualización del servidor (ej: cédula duplicada)
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Error desconocido al actualizar cliente'), backgroundColor: Colors.red));
        }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error de servidor al actualizar cliente'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Cliente'),
      ),
      body: SingleChildScrollView( // Usar SingleChildScrollView para evitar overflow
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              // Todos los TextFormField deben tener validator si son campos obligatorios.
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) => value!.isEmpty ? 'El nombre es obligatorio' : null,
              ),
              TextFormField(
                controller: _cedulaController,
                decoration: const InputDecoration(labelText: 'Cédula'),
                validator: (value) => value!.isEmpty ? 'La cédula es obligatoria' : null,
              ),
              TextFormField(
                controller: _telefonoController,
                decoration: const InputDecoration(labelText: 'Teléfono'),
              ),
              TextFormField(
                controller: _direccionController,
                decoration: const InputDecoration(labelText: 'Dirección'),
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextFormField(
                controller: _zonaController,
                decoration: const InputDecoration(labelText: 'Zona'),
              ),
              TextFormField(
                controller: _nombreFiadorController,
                decoration: const InputDecoration(labelText: 'Nombre del Fiador'),
              ),
              TextFormField(
                controller: _direccionFiadorController,
                decoration: const InputDecoration(labelText: 'Dirección del Fiador'),
              ),
              TextFormField(
                controller: _telefonoFiadorController,
                decoration: const InputDecoration(labelText: 'Teléfono del Fiador'),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _actualizarCliente,
                icon: const Icon(Icons.save),
                label: const Text('Actualizar Cliente'),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50), // Botón ancho
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}