class Recibo {
  final String idPago;
  final String cedula;
  final String nombreCliente;
  // Usamos String para los valores de moneda ya que la lógica de formato
  // está en la pantalla y vienen como string de la API.
  final String valorAbonado; 
  final String saldoRestante; 
  // La fecha viene como string del servidor (e.g., 'YYYY-MM-DD HH:MM:SS')
  final String fechaPago; 
  final String mensajeCuota;
  final String cuotaActualNumero;

  Recibo({
    required this.idPago,
    required this.cedula,
    required this.nombreCliente,
    required this.valorAbonado,
    required this.saldoRestante,
    required this.fechaPago,
    required this.mensajeCuota,
    required this.cuotaActualNumero,
  });

  // Constructor factory para crear un objeto Recibo a partir de datos JSON (Map)
  factory Recibo.fromJson(Map<String, dynamic> json) {
    return Recibo(
      // Usamos .toString() y fallback 'N/A' o '0.00' para seguridad
      idPago: json['idPago']?.toString() ?? 'N/A',
      cedula: json['cedula']?.toString() ?? 'N/A',
      nombreCliente: json['nombre_cliente']?.toString() ?? 'Cliente Desconocido',
      valorAbonado: json['valor_abonado']?.toString() ?? '0.00',
      saldoRestante: json['saldo_restante']?.toString() ?? '0.00',
      fechaPago: json['fecha_pago']?.toString() ?? DateTime.now().toIso8601String(),
      mensajeCuota: json['mensaje_cuota']?.toString() ?? 'N/A',
      cuotaActualNumero: json['cuota_actual_numero']?.toString() ?? '0',
    );
  }
}
// NOTA: Si usas la clase PagoCliente en otra parte, debes definirla aquí también.
// Si solo usas Recibo, con esta definición es suficiente para la pantalla de consulta.
