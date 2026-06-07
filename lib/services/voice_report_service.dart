import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../core/config/api_config.dart';
import '../core/config/environment.dart';

class VoiceCommandResult {
  final String action;
  final String? type;
  final Map<String, dynamic> filters;
  final double confidence;
  final String responseText;

  VoiceCommandResult({
    required this.action,
    this.type,
    required this.filters,
    required this.confidence,
    required this.responseText,
  });

  factory VoiceCommandResult.fromJson(Map<String, dynamic> json) {
    return VoiceCommandResult(
      action: json['action'] ?? 'unknown',
      type: json['type'],
      filters: Map<String, dynamic>.from(json['filters'] ?? {}),
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      responseText: json['response_text'] ?? '',
    );
  }
}

class VoiceProcessResult {
  final String textoTranscrito;
  final VoiceCommandResult comando;

  VoiceProcessResult({required this.textoTranscrito, required this.comando});

  factory VoiceProcessResult.fromJson(Map<String, dynamic> json) {
    final cmd = json['comando'] ?? {};
    return VoiceProcessResult(
      textoTranscrito: json['texto_transcrito'] ?? '',
      comando: VoiceCommandResult.fromJson(cmd is Map<String, dynamic> ? cmd : {}),
    );
  }
}

class VoiceReportService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: Duration(seconds: EnvironmentConfig.current.connectTimeout),
    receiveTimeout: Duration(seconds: EnvironmentConfig.current.receiveTimeout),
    headers: ApiConfig.defaultHeaders,
  ));

  bool _initialized = false;

  Future<bool> initialize() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onStatus: (status) {},
      onError: (error) {},
    );
    return _initialized;
  }

  bool get isAvailable => _speech.isAvailable;
  bool get isListening => _speech.isListening;

  Stream<String> listen({String locale = 'es_ES'}) async* {
    if (!_initialized) await initialize();
    String lastResult = '';
    await _speech.listen(
      onResult: (result) {
        lastResult = result.recognizedWords;
      },
      localeId: locale,
    );
    await for (final _ in Stream.periodic(Duration(milliseconds: 300))) {
      if (!_speech.isListening) {
        if (lastResult.isNotEmpty) yield lastResult;
        break;
      }
    }
  }

  Future<String?> listenOnce({String locale = 'es_ES'}) async {
    if (!_initialized) await initialize();
    final completer = Completer<String?>();
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          _speech.stop();
          completer.complete(result.recognizedWords);
        }
      },
      localeId: locale,
    );
    Future.delayed(Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        _speech.stop();
        completer.complete(null);
      }
    });
    return completer.future;
  }

  void stop() => _speech.stop();

  Future<VoiceProcessResult> sendVoiceCommand(String texto, {String? token}) async {
    final response = await _dio.post(
      '/api/v1/voice/command',
      data: {'texto': texto},
      options: token != null ? Options(headers: {'Authorization': 'Bearer $token'}) : null,
    );
    final data = response.data['data'];
    return VoiceProcessResult.fromJson(data);
  }

  Future<VoiceProcessResult> sendVoiceReport(String audioBase64, {String mimeType = 'audio/webm', String? token}) async {
    final response = await _dio.post(
      '/api/v1/voice/report',
      data: {'audio_base64': audioBase64, 'mime_type': mimeType},
      options: token != null ? Options(headers: {'Authorization': 'Bearer $token'}) : null,
    );
    final data = response.data['data'];
    return VoiceProcessResult.fromJson(data);
  }
}
