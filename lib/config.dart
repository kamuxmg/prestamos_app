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
  // Se optimizó para evitar excepciones en iOS que disparen el fallback a localhost
  static String get _localBase {
    try {
      // Solo intentamos detectar Android. Si no lo es, asumimos entorno Desktop/Localhost.
      if (Platform.isAndroid) {
        return "http://10.0.2.2/prestamos_api";
      }
      return "http://localhost/prestamos_api";
    } catch (e) {
      // Si hay error detectando plataforma (común en web o ciertos builds de iOS),
      // devolvemos localhost como última instancia.
      return "http://localhost/prestamos_api";
    }
  }

  /// URL base final que debes usar para construir endpoints:
  /// Si useLocal es false, SIEMPRE devolverá la IP del VPS.
  static String get apiBase => useLocal ? _localBase : productionBaseUrl;
}