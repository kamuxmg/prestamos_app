import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'main_menu.dart';

// 👇 Importamos localizations
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  runApp(const PrestamosApp());
}

class PrestamosApp extends StatelessWidget {
  const PrestamosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prestamos App',
      debugShowCheckedModeBanner: false, // <- quita la etiqueta DEBUG
      theme: ThemeData(primarySwatch: Colors.blue),

      // 👇 Añadimos soporte de idiomas
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'), // Español
        Locale('en', 'US'), // Inglés
      ],

      initialRoute: '/',
      onGenerateRoute: (settings) {
        if (settings.name == '/main') {
          final args = settings.arguments as String?;
          return MaterialPageRoute(
            builder: (_) => MainMenu(userName: args ?? 'Usuario'),
          );
        }
        // default route -> LoginPage
        return MaterialPageRoute(builder: (_) => const LoginPage());
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController userController = TextEditingController();
  final TextEditingController passController = TextEditingController();
  bool loading = false;
  String message = "";

  // Detecta la base URL según la plataforma:
  String getApiBase() {
    // emulador Android necesita 10.0.2.2; Windows/desktop puede usar localhost
    if (Platform.isAndroid) {
      return 'http://10.0.2.2/prestamos_api';
    } else {
      return 'http://localhost/prestamos_api';
    }
  }

  Future<void> login() async {
    setState(() {
      loading = true;
      message = "";
    });

    try {
      final base = getApiBase();
      var url = Uri.parse("$base/login.php");
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": userController.text.trim(),
          "password": passController.text,
        }),
      );

      if (response.statusCode != 200) {
        setState(() {
          message = "Error del servidor: ${response.statusCode}";
        });
        return;
      }

      var data = jsonDecode(response.body);
      if (data["success"] == true) {
        // Navega al main con nombre del usuario como argumento
        Navigator.pushReplacementNamed(context, '/main', arguments: data["name"]);
      } else {
        setState(() {
          message = data["message"] ?? "Usuario o contraseña incorrectos";
        });
      }
    } catch (e) {
      setState(() {
        message = "Error de conexión: $e";
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar opcional — si quieres quitarla pon appBar: null
      appBar: AppBar(title: const Text("Inicio de Sesión")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: SizedBox(
          height: MediaQuery.of(context).size.height - kToolbarHeight - 40,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_circle, size: 96, color: Colors.blue),
              const SizedBox(height: 16),
              TextField(
                controller: userController,
                decoration: const InputDecoration(labelText: "Usuario"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Contraseña"),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: loading ? null : login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, // botón azul
                  foregroundColor: Colors.white, // texto blanco
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                ),
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text("Ingresar", style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  color: message.contains("Bienvenido") ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
