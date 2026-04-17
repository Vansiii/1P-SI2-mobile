class IncidentAiAnalysisModel {
  final int id;
  final int incidentId;
  final String status;
  final String modelName;
  final String promptVersion;
  final String requestHash;
  final int attemptNumber;
  final String? category;
  final String? priority;
  final String? summary;
  final bool isAmbiguous;
  final double? confidence;
  final List<String> findings;
  final List<String> missingData;
  final String? workshopRecommendation;
  final String? errorCode;
  final String? errorMessage;
  final int? latencyMs;
  final DateTime createdAt;
  final DateTime updatedAt;

  const IncidentAiAnalysisModel({
    required this.id,
    required this.incidentId,
    required this.status,
    required this.modelName,
    required this.promptVersion,
    required this.requestHash,
    required this.attemptNumber,
    this.category,
    this.priority,
    this.summary,
    required this.isAmbiguous,
    this.confidence,
    required this.findings,
    required this.missingData,
    this.workshopRecommendation,
    this.errorCode,
    this.errorMessage,
    this.latencyMs,
    required this.createdAt,
    required this.updatedAt,
  });

  factory IncidentAiAnalysisModel.fromJson(Map<String, dynamic> json) {
    return IncidentAiAnalysisModel(
      id: json['id'] as int,
      incidentId: json['incident_id'] as int,
      status: json['status'] as String,
      modelName: json['model_name'] as String,
      promptVersion: json['prompt_version'] as String,
      requestHash: json['request_hash'] as String,
      attemptNumber: json['attempt_number'] as int,
      category: json['category'] as String?,
      priority: json['priority'] as String?,
      summary: json['summary'] as String?,
      isAmbiguous: json['is_ambiguous'] as bool? ?? false,
      confidence: (json['confidence'] as num?)?.toDouble(),
      findings: (json['findings'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      missingData: (json['missing_data'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      workshopRecommendation: json['workshop_recommendation'] as String?,
      errorCode: json['error_code'] as String?,
      errorMessage: json['error_message'] as String?,
      latencyMs: json['latency_ms'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'processing':
        return 'Procesando';
      case 'completed':
        return 'Completado';
      case 'failed':
        return 'Fallido';
      default:
        return status;
    }
  }
}
