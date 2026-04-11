class VehicleModel {
  final int id;
  final int clientId;
  final String matricula;
  final String? marca;
  final String modelo;
  final int anio;
  final String? color;
  final String? imagen;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  VehicleModel({
    required this.id,
    required this.clientId,
    required this.matricula,
    this.marca,
    required this.modelo,
    required this.anio,
    this.color,
    this.imagen,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'] as int,
      clientId: json['client_id'] as int,
      matricula: json['matricula'] as String,
      marca: json['marca'] as String?,
      modelo: json['modelo'] as String,
      anio: json['anio'] as int,
      color: json['color'] as String?,
      imagen: json['imagen'] as String?,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'matricula': matricula,
      'marca': marca,
      'modelo': modelo,
      'anio': anio,
      'color': color,
      'imagen': imagen,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get displayName => '$marca $modelo ($anio)';
  String get shortName => marca != null ? '$marca $modelo' : modelo;
}
