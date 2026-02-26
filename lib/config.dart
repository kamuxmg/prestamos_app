// lib/config.dart
import 'dart:io' show Platform;

/// Configuración centralizada de la URL base de la API.
///
/// Usage:
///   final base = Config.apiBase;
class Config {
  // Modo de trabajo:
  // true  -> desarrollo local (usa las reglas de abajo)
  // false -> producción (usa productionBaseUrl)
  // Cambia esto a false cuando muevas tu backend a un hosting/servidor real.
  static const bool useLocal = true;

  // Si vas a desplegar en un hosting público, pon aquí la URL completa (con http/https)
  // Ej: "https://miservidor.com/prestamos_api"
  static const String productionBaseUrl = "https://TU_DOMINIO_O_IP/public_path/prestamos_api";

  // Reglas para entornos locales:
  // - Si estás ejecutando en Android emulator -> 10.0.2.2
  // - Si estás en Windows/Mac/Linux desktop -> localhost
  // - Si quieres probar en un teléfono físico, cambia manualmente productionBaseUrl
  static String get _localBase {
    try {
      if (Platform.isAndroid) {
        return "http://10.0.2.2/prestamos_api";
      } else {
        // Desktop (Windows/Linux/Mac) usa localhost
        return "http://localhost/prestamos_api";
      }
    } catch (e) {
      // Fallback por si Platform falla en alguna plataforma
      return "http://localhost/prestamos_api";
    }
  }

  /// URL base final que debes usar para construir endpoints:
  /// e.g. Uri.parse("${Config.apiBase}/crear_cliente.php")
  static String get apiBase => useLocal ? _localBase : productionBaseUrl;
}
