import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart'; // Para kDebugMode
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'main_menu.dart';
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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'),
        Locale('en', 'US'),
      ],
      initialRoute: '/',
      onGenerateRoute: (settings) {
        if (settings.name == '/main') {
          final args = settings.arguments as String?;
          return MaterialPageRoute(
            builder: (_) => MainMenu(userName: args ?? 'Usuario'),
          );
        }
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

  // LÓGICA HÍBRIDA: LOCAL (XAMPP) + VPS
  String getApiBase() {
    const String vpsIP = '104.167.199.84';
    
    // Si estás ejecutando la app desde VS Code (Modo Debug)
    if (kDebugMode) {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2/prestamos_api'; // XAMPP para Emulador Android
      } else if (Platform.isWindows || Platform.isMacOS) {
        return 'http://localhost/prestamos_api'; // XAMPP para Desktop
      } else if (Platform.isIOS) {
        // OJO: Para iOS local, el iPhone debe estar en la misma red WiFi que tu PC
        // y aquí deberías poner la IP de tu PC (ej. 192.168.1.50)
        // Por ahora lo dejamos al VPS para que no te falle el .ipa
        return 'http://$vpsIP/prestamos_api';
      }
    }

    // SI LA APP ESTÁ EN PRODUCCIÓN (EL .IPA DE CODEMAGIC)
    return 'http://$vpsIP/prestamos_api';
  }

  Future<void> login() async {
    setState(() {
      loading = true;
      message = "";
    });

    try {
      final base = getApiBase();
      var url = Uri.parse("$base/login.php");
      
      print("Intentando conectar a: $url"); // Para ver en consola a dónde apunta

      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": userController.text.trim(),
          "password": passController.text,
        }),
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        setState(() {
          message = "Error servidor: ${response.statusCode}\nBase: $base";
        });
        return;
      }

      var data = jsonDecode(response.body);
      if (data["success"] == true) {
        Navigator.pushReplacementNamed(context, '/main', arguments: data["name"]);
      } else {
        setState(() {
          message = data["message"] ?? "Credenciales incorrectas";
        });
      }
    } catch (e) {
      setState(() {
        message = "No se pudo conectar al servidor.\n¿Internet o VPS activo?";
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
      appBar: AppBar(title: const Text("Acceso al Sistema")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.account_balance_wallet, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            TextField(
              controller: userController,
              decoration: const InputDecoration(
                labelText: "Nombre de Usuario",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: passController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Contraseña",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: loading ? null : login,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("ENTRAR", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
            ]
          ],
        ),
      ),
    );
  }
}