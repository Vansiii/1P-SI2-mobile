import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../core/config/api_config.dart';
import '../../../data/services/storage_service.dart';

class ClientReportsScreen extends ConsumerStatefulWidget {
  const ClientReportsScreen({super.key});
  @override
  ConsumerState<ClientReportsScreen> createState() => _ClientReportsScreenState();
}

class _ClientReportsScreenState extends ConsumerState<ClientReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final stt.SpeechToText _speech = stt.SpeechToText();
  final StorageService _storage = StorageService();

  Map<String, dynamic>? _summary;
  Map<String, dynamic>? _spending;
  List<Map<String, dynamic>> _vehicles = [];
  final Map<int, Map<String, dynamic>> _vehicleHistory = {};
  bool _loading = true;
  int? _selectedVehicleId;

  bool _voiceReady = false;
  bool _isListening = false;
  String _voiceText = '';
  String _voiceResponse = '';
  String? _lastFilePath;
  bool _showVoiceChips = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    _initVoice();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _speech.cancel();
    super.dispose();
  }

  Future<void> _initVoice() async {
    _voiceReady = await _speech.initialize();
    if (mounted) setState(() {});
  }

  Future<String?> _getToken() => _storage.getAccessToken();

  // ═══════════════════════════════════════════════════════
  // VOICE
  // ═══════════════════════════════════════════════════════

  Future<void> _startListening() async {
    if (!_voiceReady) {
      _voiceReady = await _speech.initialize();
      if (!_voiceReady) { _showMsg('Reconocimiento de voz no disponible'); return; }
    }
    if (_isListening) { _speech.stop(); setState(() => _isListening = false); return; }
    setState(() { _isListening = true; _voiceText = ''; _voiceResponse = ''; });
    await _speech.listen(
      onResult: (r) {
        setState(() => _voiceText = r.recognizedWords);
        if (r.finalResult) { _speech.stop(); setState(() => _isListening = false); if (_voiceText.isNotEmpty) _executeVoiceCommand(_voiceText); }
      },
      localeId: 'es_ES', listenFor: const Duration(seconds: 10), pauseFor: const Duration(seconds: 3),
    );
  }

  Future<void> _executeVoiceCommand(String text) async {
    final lower = text.toLowerCase();
    final wantsPdf = lower.contains('pdf'); final wantsExcel = lower.contains('excel');
    final fmt = wantsPdf ? 'pdf' : (wantsExcel ? 'excel' : null);
    if (fmt != null) {
      if (lower.contains('gasto') || lower.contains('gasté') || lower.contains('dinero')) {
        setState(() => _voiceResponse = 'Generando gastos ${fmt.toUpperCase()}...');
        await _downloadReport('spending', fmt); return;
      }
      if (lower.contains('resumen') || lower.contains('general')) {
        setState(() => _voiceResponse = 'Generando resumen ${fmt.toUpperCase()}...');
        await _downloadReport('summary', fmt); return;
      }
      if (lower.contains('vehículo') || lower.contains('auto') || lower.contains('carro') || lower.contains('historial')) {
        if (_selectedVehicleId != null) {
          setState(() => _voiceResponse = 'Generando historial ${fmt.toUpperCase()}...');
          await _downloadReport('vehicle', fmt, vehicleId: _selectedVehicleId); return;
        } else { setState(() => _voiceResponse = 'Selecciona un vehículo primero'); return; }
      }
    }
    if (lower.contains('resumen') || lower.contains('general')) { _tabController.animateTo(0); setState(() => _voiceResponse = 'Resumen'); }
    else if (lower.contains('gasto') || lower.contains('dinero')) { _tabController.animateTo(1); setState(() => _voiceResponse = 'Gastos'); }
    else if (lower.contains('vehículo') || lower.contains('auto') || lower.contains('historial')) { _tabController.animateTo(2); setState(() => _voiceResponse = 'Vehículos'); }
    else if (lower.contains('generar') || lower.contains('exportar')) { setState(() => _voiceResponse = 'Di: "gastos en PDF" o "resumen en Excel"'); }
    else { setState(() => _voiceResponse = 'Di: "gastos en PDF", "resumen en Excel", "historial del vehículo en PDF"'); }
    Future.delayed(const Duration(seconds: 5), () { if (mounted) setState(() => _voiceResponse = ''); });
  }

  // ═══════════════════════════════════════════════════════
  // DOWNLOAD
  // ═══════════════════════════════════════════════════════

  Future<void> _downloadReport(String type, String fmt, {int? vehicleId}) async {
    final token = await _getToken(); if (token == null) { _showMsg('Sesión expirada'); return; }
    String url, name;
    switch (type) {
      case 'spending': url = '/api/v1/client/reports/spending/download/$fmt'; name = 'gastos'; break;
      case 'vehicle':  url = '/api/v1/client/reports/vehicle/$vehicleId/history/download/$fmt'; name = 'historial_vehiculo'; break;
      default:         url = '/api/v1/client/reports/summary/download/$fmt'; name = 'resumen';
    }
    try {
      final dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl, connectTimeout: const Duration(seconds: 30), receiveTimeout: const Duration(seconds: 30),
          headers: {'Authorization': 'Bearer $token'}, responseType: ResponseType.bytes));
      final bytes = (await dio.get(url)).data as List<int>;
      final ext = fmt == 'pdf' ? 'pdf' : 'xlsx';
      final dir = await getApplicationDocumentsDirectory();
      final filename = 'mecanicoya_$name.${DateTime.now().millisecondsSinceEpoch}.$ext';
      final file = File('${dir.path}/$filename'); await file.writeAsBytes(bytes);
      _lastFilePath = file.path;
      if (mounted) {
        setState(() => _voiceResponse = '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$fmt ${fmt == 'pdf' ? 'PDF' : 'Excel'} generado'),
          backgroundColor: Colors.green.shade700, duration: const Duration(seconds: 6),
          action: SnackBarAction(label: 'Abrir', textColor: Colors.white, onPressed: () => OpenFilex.open(file.path)),
        ));
      }
    } catch (e) { if (mounted) { setState(() => _voiceResponse = 'Error'); _showMsg('Error: $e'); } }
  }

  void _showMsg(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  // ═══════════════════════════════════════════════════════
  // DATA
  // ═══════════════════════════════════════════════════════

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final token = await _getToken(); if (token == null) { setState(() => _loading = false); return; }
    final dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl, headers: {'Authorization': 'Bearer $token'},
        connectTimeout: const Duration(seconds: 60), receiveTimeout: const Duration(seconds: 60)));
    try {
      final r = await Future.wait([dio.get('/api/v1/client/reports/summary'), dio.get('/api/v1/client/reports/spending'), dio.get('/api/v1/vehiculos')]);
      if (mounted) setState(() {
        _summary = r[0].data['data']; _spending = r[1].data['data'];
        _vehicles = ((r[2].data['data'] as List?) ?? []).map<Map<String, dynamic>>((v) => Map<String, dynamic>.from(v)).toList();
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _loadVehicleHistory(int vid) async {
    if (_vehicleHistory.containsKey(vid)) return;
    final token = await _getToken(); if (token == null) return;
    try {
      final dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl, headers: {'Authorization': 'Bearer $token'},
          connectTimeout: const Duration(seconds: 60), receiveTimeout: const Duration(seconds: 60)));
      final resp = await dio.get('/api/v1/client/reports/vehicle/$vid/history');
      if (mounted) setState(() => _vehicleHistory[vid] = resp.data['data']);
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Reportes', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (_lastFilePath != null)
            IconButton(icon: const Icon(Icons.folder_open), tooltip: 'Último reporte', onPressed: () => OpenFilex.open(_lastFilePath!)),
          if (_voiceReady)
            IconButton(
              icon: AnimatedSwitcher(duration: const Duration(milliseconds: 300),
                child: Icon(_isListening ? Icons.mic : Icons.mic_outlined,
                    key: ValueKey(_isListening), color: _isListening ? Colors.redAccent : null)),
              tooltip: 'Comando de voz', onPressed: _startListening,
            ),
          IconButton(icon: Icon(_showVoiceChips ? Icons.keyboard_arrow_up : Icons.help_outline),
              tooltip: 'Comandos de voz', onPressed: () => setState(() => _showVoiceChips = !_showVoiceChips)),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined, size: 22), text: 'Resumen'),
            Tab(icon: Icon(Icons.payments_outlined, size: 22), text: 'Gastos'),
            Tab(icon: Icon(Icons.directions_car_outlined, size: 22), text: 'Vehículos'),
          ],
        ),
      ),
      body: Column(children: [
        if (_voiceText.isNotEmpty || _voiceResponse.isNotEmpty) _voiceBar(),
        if (_showVoiceChips) _buildVoiceChips(),
        Expanded(
          child: _loading ? _buildSkeleton() : TabBarView(controller: _tabController, children: [
            _summaryTab(), _spendingTab(), _vehiclesTab(),
          ]),
        ),
      ]),
      floatingActionButton: _isListening ? _listeningFab() : _micFab(),
    );
  }

  Widget _micFab() {
    return FloatingActionButton(
      onPressed: _startListening,
      tooltip: 'Generar reporte por voz',
      elevation: 3,
      child: const Icon(Icons.mic),
    );
  }

  Widget _listeningFab() {
    final text = _voiceText.isEmpty ? 'Escuchando...' : (_voiceText.length > 25 ? '${_voiceText.substring(0, 25)}…' : _voiceText);
    return FloatingActionButton.extended(
      onPressed: () { _speech.stop(); setState(() => _isListening = false); },
      backgroundColor: Colors.redAccent, icon: const Icon(Icons.mic, color: Colors.white),
      label: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }

  // ═══════════════════════════════════════════════════════
  // VOICE BAR + CHIPS
  // ═══════════════════════════════════════════════════════

  Widget _voiceBar() {
    final isErr = _voiceResponse.contains('Error');
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: isErr ? Colors.red.shade50 : Colors.blue.shade50,
          border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Row(children: [
        Icon(isErr ? Icons.error_outline : Icons.record_voice_over, color: isErr ? Colors.red : Colors.blue, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(
          _voiceResponse.isNotEmpty ? _voiceResponse : '"$_voiceText"',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
              color: isErr ? Colors.red.shade800 : Colors.blue.shade800, fontStyle: _voiceResponse.isEmpty ? FontStyle.italic : FontStyle.normal),
          maxLines: 2, overflow: TextOverflow.ellipsis,
        )),
        GestureDetector(onTap: () => setState(() { _voiceText = ''; _voiceResponse = ''; }), child: Icon(Icons.close, size: 16, color: Colors.grey.shade500)),
      ]),
    );
  }

  Widget _buildVoiceChips() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      child: Container(
        width: double.infinity, padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.blue.shade50, border: Border(bottom: BorderSide(color: Colors.blue.shade100))),
        child: Wrap(spacing: 6, runSpacing: 4, children: [
          _vc('"resumen PDF"', Icons.picture_as_pdf, 'summary', 'pdf'),
          _vc('"resumen Excel"', Icons.table_chart, 'summary', 'excel'),
          _vc('"gastos PDF"', Icons.picture_as_pdf, 'spending', 'pdf'),
          _vc('"gastos Excel"', Icons.table_chart, 'spending', 'excel'),
          _vc('"historial PDF"', Icons.picture_as_pdf, 'vehicle', 'pdf'),
          _vc('"historial Excel"', Icons.table_chart, 'vehicle', 'excel'),
        ]),
      ),
    );
  }

  Widget _vc(String text, IconData icon, String type, String fmt) {
    return ActionChip(
      avatar: Icon(icon, size: 13), label: Text(text, style: const TextStyle(fontSize: 10)),
      padding: EdgeInsets.zero, visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onPressed: () {
        if (type == 'vehicle' && _selectedVehicleId == null) {
          _tabController.animateTo(2); setState(() => _showVoiceChips = false); return;
        }
        _downloadReport(type, fmt, vehicleId: type == 'vehicle' ? _selectedVehicleId : null);
        setState(() => _showVoiceChips = false);
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // SKELETON
  // ═══════════════════════════════════════════════════════

  Widget _buildSkeleton() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [Expanded(child: _skelBox()), const SizedBox(width: 10), Expanded(child: _skelBox())]),
      const SizedBox(height: 10),
      Row(children: [Expanded(child: _skelBox()), const SizedBox(width: 10), Expanded(child: _skelBox())]),
      const SizedBox(height: 20),
      _skelBox(height: 120),
    ]);
  }

  Widget _skelBox({double height = 90}) {
    return Container(height: height, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(14)));
  }

  // ═══════════════════════════════════════════════════════
  // TAB: RESUMEN
  // ═══════════════════════════════════════════════════════

  Widget _summaryTab() {
    final s = _summary; if (s == null) return _empty('Sin datos');
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(padding: const EdgeInsets.all(14), children: [
        _sectionTitle('Indicadores'),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _statCard('Incidentes', '${s['total_incidentes']}', Icons.receipt_long_outlined, const Color(0xFF3B82F6), '${s['incidentes_activos']} activos')),
          const SizedBox(width: 10),
          Expanded(child: _statCard('Gastado', 'Bs. ${_fmtMoney(s['total_gastado'])}', Icons.payments_outlined, const Color(0xFF22C55E), '${s['total_vehiculos']} vehículos')),
        ]),
        if (s['rating_promedio'] != null) ...[
          const SizedBox(height: 20),
          _sectionTitle('Tu reputación'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(18), decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.amber.shade100, Colors.amber.shade50], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.amber.shade200)),
            child: Row(children: [
              Container(width: 56, height: 56, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.amber.shade400),
                child: const Icon(Icons.star_rounded, color: Colors.white, size: 32)),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${s['rating_promedio']} / 5.0', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.amber.shade900)),
                Text('Calificación promedio', style: TextStyle(color: Colors.amber.shade800, fontSize: 13)),
              ]),
            ]),
          ),
        ],
        const SizedBox(height: 24),
        _sectionTitle('Exportar resumen'),
        const SizedBox(height: 8),
        _exportRow('summary'),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════
  // TAB: GASTOS
  // ═══════════════════════════════════════════════════════

  Widget _spendingTab() {
    final sp = _spending; if (sp == null) return _empty('Sin datos de gastos');
    final porMes = (sp['por_mes'] as List?) ?? [];
    final maxAmount = porMes.isEmpty ? 1.0 : porMes.map((m) => (m['total'] as num).toDouble()).reduce((a, b) => a > b ? a : b);
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(padding: const EdgeInsets.all(14), children: [
        Container(
          width: double.infinity, padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [const Color(0xFF059669), const Color(0xFF10B981)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: const Color(0xFF059669).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]),
          child: Column(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
              child: const Text('TOTAL GASTADO', style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 2))),
            const SizedBox(height: 10),
            Text('Bs. ${_fmtMoney(sp['total_gastado'])}', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1)),
            const SizedBox(height: 4),
            Text('${sp['total_transacciones']} transacciones', style: const TextStyle(color: Colors.white60, fontSize: 14)),
          ]),
        ),
        const SizedBox(height: 24),
        _sectionTitle('Desglose mensual'),
        const SizedBox(height: 10),
        ...porMes.map((m) => _monthRow(m, maxAmount)),
        const SizedBox(height: 24),
        _sectionTitle('Exportar gastos'),
        const SizedBox(height: 8),
        _exportRow('spending'),
      ]),
    );
  }

  Widget _monthRow(Map<String, dynamic> m, double maxAmount) {
    final total = (m['total'] as num).toDouble();
    final ratio = maxAmount > 0 ? total / maxAmount : 0.0;
    final monthName = _fmtMonth(m['mes'] ?? '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(width: 48, child: Text(monthName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        const SizedBox(width: 8),
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(children: [
            Container(height: 28, color: Colors.grey.shade100),
            FractionallySizedBox(widthFactor: ratio, child: Container(
              decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFF059669), const Color(0xFF10B981)])),
            )),
          ]),
        )),
        const SizedBox(width: 10),
        SizedBox(width: 80, child: Text('Bs. ${_fmtMoney(total)}',
            textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════
  // TAB: VEHICULOS
  // ═══════════════════════════════════════════════════════

  Widget _vehiclesTab() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
        child: Container(
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: DropdownButtonFormField<int>(
            value: _selectedVehicleId,
            decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), prefixIcon: Icon(Icons.directions_car)),
            hint: const Text('Seleccionar vehículo'),
            items: _vehicles.map((v) => DropdownMenuItem<int>(value: v['id'] as int, child: Text(v['matricula'] ?? 'Veh ${v['id']}', style: const TextStyle(fontWeight: FontWeight.w600)))).toList(),
            onChanged: (id) { if (id != null) { setState(() => _selectedVehicleId = id); _loadVehicleHistory(id); } },
          ),
        ),
      ),
      if (_selectedVehicleId != null && _vehicleHistory.containsKey(_selectedVehicleId))
        Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 0), child: _exportRow('vehicle', vehicleId: _selectedVehicleId)),
      const SizedBox(height: 8),
      Expanded(
        child: _selectedVehicleId != null && _vehicleHistory.containsKey(_selectedVehicleId)
            ? _vehicleContent(_vehicleHistory[_selectedVehicleId]!)
            : Center(child: _emptyIllustration(Icons.touch_app_outlined, 'Selecciona un vehículo\npara ver su historial')),
      ),
    ]);
  }

  Widget _vehicleContent(Map<String, dynamic> h) {
    final servicios = (h['servicios'] as List?) ?? [];
    if (servicios.isEmpty) return _empty('Sin servicios registrados');
    return ListView(padding: const EdgeInsets.symmetric(horizontal: 14), children: [
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.directions_car, color: Color(0xFF3B82F6), size: 24)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(h['matricula'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            Text('${h['total_servicios']} servicios registrados', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ]),
        ]),
      ),
      const SizedBox(height: 12),
      ...servicios.map((s) => _serviceCard(s)),
    ]);
  }

  Widget _serviceCard(Map<String, dynamic> s) {
    final resolved = s['estado'] == 'resuelto';
    final color = resolved ? const Color(0xFF22C55E) : const Color(0xFFF59E0B);
    return Card(
      margin: const EdgeInsets.only(bottom: 8), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade200)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {}, // futuro: navegar a detalle
        child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(resolved ? Icons.check_circle_rounded : Icons.timelapse_rounded, color: color, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((s['categoria'] ?? 'Sin clasificar').toString().replaceAll('_', ' ').capitalize(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 3),
            Text('${s['fecha']?.toString().substring(0, 10) ?? ''}  •  ${s['taller_nombre'] ?? 'Sin taller'}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ])),
          if (s['costo'] != null)
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: const Color(0xFF22C55E).withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                child: Text('Bs. ${_fmtMoney(s['costo'])}', style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w700, fontSize: 13))),
        ])),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // SHARED WIDGETS
  // ═══════════════════════════════════════════════════════

  Widget _sectionTitle(String title) {
    return Row(children: [
      Container(width: 3, height: 18, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
    ]);
  }

  Widget _statCard(String label, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, color: color, size: 20), const Spacer(),
          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color))]),
        const SizedBox(height: 12),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
      ]),
    );
  }

  Widget _exportRow(String type, {int? vehicleId}) {
    return Row(children: [
      Expanded(child: _expBtn('PDF', Icons.picture_as_pdf_rounded, const Color(0xFFDC2626), () => _downloadReport(type, 'pdf', vehicleId: vehicleId))),
      const SizedBox(width: 10),
      Expanded(child: _expBtn('Excel', Icons.table_chart_rounded, const Color(0xFF16A34A), () => _downloadReport(type, 'excel', vehicleId: vehicleId))),
    ]);
  }

  Widget _expBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(14),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 20), const SizedBox(width: 8),
          Text('Exportar $label', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
        ])),
      ),
    );
  }

  Widget _empty(String msg) => _emptyIllustration(Icons.inbox_outlined, msg);

  Widget _emptyIllustration(IconData icon, String msg) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey.shade100),
          child: Icon(icon, size: 36, color: Colors.grey.shade400)),
      const SizedBox(height: 16),
      Text(msg, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
    ]));
  }

  String _fmtMoney(dynamic v) {
    final n = (v as num).toDouble();
    if (n >= 1000) return n.toStringAsFixed(0);
    return n.toStringAsFixed(2);
  }

  String _fmtMonth(String ym) {
    const m = ['', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    final p = ym.split('-'); if (p.length != 2) return ym;
    final mi = int.tryParse(p[1]) ?? 0; return '${m[mi]} ${p[0]}';
  }
}

extension StringCapitalize on String {
  String capitalize() => isEmpty ? '' : '${this[0].toUpperCase()}${substring(1)}';
}
