import 'dart:io' show Platform;

/// Configuración centralizada de la URL base de la API.
///
/// Usage:
///   final base = Config.apiBase;
class Config {
  // Modo de trabajo:
  // true  -> desarrollo local (usa localhost o 10.0.2.2)
  // false -> producción (usa la IP de tu VPS 104.167.199.84)
  // CAMBIA A 'false' PARA CONECTAR AL VPS REAL
  static const bool useLocal = false;

  // URL de tu servidor real (VPS)
  // Configurada con la IP proporcionada: 104.167.199.84
  static const String productionBaseUrl = "http://104.167.199.84/prestamos_api";

  // Reglas para entornos locales:
  // - Si estás ejecutando en Android emulator -> 10.0.2.2
  // - Si estás en Windows/Mac/Linux desktop -> localhost
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