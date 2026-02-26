import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config.dart'; // 👈 Importa config.dart

class CrearClientePage extends StatefulWidget {
  const CrearClientePage({super.key});

  @override
  State<CrearClientePage> createState() => _CrearClientePageState();
}

class _CrearClientePageState extends State<CrearClientePage> {
  final _formKey = GlobalKey<FormState>();

  // Controladores cliente
  final TextEditingController fechaController = TextEditingController();
  final TextEditingController fechaEnviarController = TextEditingController(); // 👈 Fecha en formato para MySQL
  final TextEditingController cedulaController = TextEditingController();
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController direccionController = TextEditingController();
  final TextEditingController telefonoController = TextEditingController();
  final TextEditingController correoController = TextEditingController();
  final TextEditingController zonaController = TextEditingController();

  // Controladores fiador
  final TextEditingController fiadorNombreController = TextEditingController();
  final TextEditingController fiadorDireccionController = TextEditingController();
  final TextEditingController fiadorTelefonoController = TextEditingController();
  final TextEditingController fiadorCorreoController = TextEditingController();

  bool cargando = false;

  @override
  void dispose() {
    fechaController.dispose();
    fechaEnviarController.dispose();
    cedulaController.dispose();
    nombreController.dispose();
    direccionController.dispose();
    telefonoController.dispose();
    correoController.dispose();
    zonaController.dispose();
    fiadorNombreController.dispose();
    fiadorDireccionController.dispose();
    fiadorTelefonoController.dispose();
    fiadorCorreoController.dispose();
    super.dispose();
  }

  // Validación de email
  String? _validarEmail(String? value) {
    if (value == null || value.isEmpty) return null;
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!regex.hasMatch(value)) {
      return "Ingrese un correo válido";
    }
    return null;
  }

  Future<void> guardarCliente() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => cargando = true);

    try {
      final url = Uri.parse("${Config.apiBase}/crear_cliente.php");

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "fecha": fechaEnviarController.text.trim(), // 👈 Enviamos la fecha en formato yyyy-MM-dd
          "nombre": nombreController.text.trim(),
          "cedula": cedulaController.text.trim(),
          "telefono": telefonoController.text.trim(),
          "direccion": direccionController.text.trim(),
          "email": correoController.text.trim(),
          "zona": zonaController.text.trim(),
          "nombre_fiador": fiadorNombreController.text.trim(),
          "direccion_fiador": fiadorDireccionController.text.trim(),
          "telefono_fiador": fiadorTelefonoController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data["message"], style: const TextStyle(color: Colors.white)), backgroundColor: Colors.green),
          );
          _formKey.currentState!.reset();
          fechaController.clear();
          fechaEnviarController.clear();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data["message"]), backgroundColor: Colors.red),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error de servidor: ${response.statusCode}"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error de conexión: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Crear Cliente"),
        backgroundColor: Colors.blue,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Datos del Cliente",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              TextFormField(
                controller: fechaController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "Fecha",
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    locale: const Locale("es", "ES"),
                  );
                  if (picked != null) {
                    // Mostrar fecha en formato amigable
                    fechaController.text =
                        "${picked.day.toString().padLeft(2, '0')}/"
                        "${picked.month.toString().padLeft(2, '0')}/"
                        "${picked.year}";
                    
                    // Guardar fecha en formato MySQL
                    fechaEnviarController.text =
                        "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                  }
                },
                validator: (value) => value == null || value.isEmpty ? "Seleccione fecha" : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: cedulaController,
                decoration: const InputDecoration(labelText: "Cédula"),
                validator: (value) => value == null || value.isEmpty ? "Campo obligatorio" : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: nombreController,
                decoration: const InputDecoration(labelText: "Nombre Cliente"),
                validator: (value) => value == null || value.isEmpty ? "Campo obligatorio" : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: direccionController,
                decoration: const InputDecoration(labelText: "Dirección"),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: telefonoController,
                decoration: const InputDecoration(labelText: "Teléfono"),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: correoController,
                decoration: const InputDecoration(labelText: "Correo"),
                keyboardType: TextInputType.emailAddress,
                validator: _validarEmail,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: zonaController,
                decoration: const InputDecoration(labelText: "Zona"),
              ),
              const SizedBox(height: 24),

              const Text("Datos del Fiador",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              TextFormField(
                controller: fiadorNombreController,
                decoration: const InputDecoration(labelText: "Nombre Fiador"),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: fiadorDireccionController,
                decoration: const InputDecoration(labelText: "Dirección Fiador"),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: fiadorTelefonoController,
                decoration: const InputDecoration(labelText: "Teléfono Fiador"),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: fiadorCorreoController,
                decoration: const InputDecoration(labelText: "Correo Fiador"),
                keyboardType: TextInputType.emailAddress,
                validator: _validarEmail,
              ),
              const SizedBox(height: 30),

              Center(
                child: ElevatedButton.icon(
                  onPressed: cargando ? null : guardarCliente,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  ),
                  icon: cargando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    cargando ? "Guardando..." : "Guardar Cliente",
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
