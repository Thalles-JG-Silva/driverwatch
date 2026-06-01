import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:vibration/vibration.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraReady = false;

  bool _isMonitoring = true;
  String _statusMessage = "Iniciando câmera...";
  Color _statusColor = Colors.yellow;

  // Simulação de sonolência e distração
  int _closedEyesCount = 0;
  int _lookAwayCount = 0;
  bool _alarmTriggered = false;
  Timer? _alarmTimer;
  Timer? _simulationTimer;

  String _drowsinessStatus = "Monitorando...";
  String _distractionStatus = "Monitorando...";
  Color _drowsinessColor = Colors.green;
  Color _distractionColor = Colors.green;

  double _gForce = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _startSimulation(); // Simula os eventos de detecção
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startCamera();
    } else if (state == AppLifecycleState.paused) {
      _stopCamera();
    }
  }

  Future<void> _initCamera() async {
    await Permission.camera.request();

    _cameras = await availableCameras();
    if (_cameras == null || _cameras!.isEmpty) {
      setState(() {
        _statusMessage = "Câmera não encontrada";
        _statusColor = Colors.red;
      });
      return;
    }

    _cameraController = CameraController(_cameras![0], ResolutionPreset.medium);
    await _cameraController!.initialize();
    await _startCamera();

    if (mounted) {
      setState(() {
        _isCameraReady = true;
        _statusMessage = "Monitorando...";
        _statusColor = Colors.green;
      });
    }
  }

  Future<void> _startCamera() async {
    if (_cameraController != null && !_cameraController!.value.isInitialized) {
      await _cameraController!.initialize();
    }
  }

  Future<void> _stopCamera() async {
    await _cameraController?.dispose();
  }

  // Simulação aleatória de sonolência/distração (para demonstração do TCC)
  void _startSimulation() {
    _simulationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isMonitoring) return;

      // Simula variação da força G
      setState(() {
        _gForce = (_gForce + (DateTime.now().millisecondsSinceEpoch % 3 - 1) * 0.2)
            .clamp(0.0, 5.0);
      });

      // A cada 12 segundos, simula um evento de risco (apenas para demonstração)
      final int second = DateTime.now().second;
      if (second % 12 == 0 && second != 0) {
        _simulateRisk();
      }
    });
  }

  void _simulateRisk() {
    // Alterna entre sonolência e distração
    bool isDrowsy = DateTime.now().millisecondsSinceEpoch % 2 == 0;

    if (isDrowsy) {
      _closedEyesCount = 6;
      setState(() {
        _drowsinessStatus = "Olhos fechados!";
        _drowsinessColor = Colors.red;
      });
    } else {
      _lookAwayCount = 4;
      setState(() {
        _distractionStatus = "Desviou o olhar!";
        _distractionColor = Colors.red;
      });
    }
    _checkAndTriggerAlarm();
  }

  void _checkAndTriggerAlarm() {
    bool drowsy = _closedEyesCount >= 5;
    bool distracted = _lookAwayCount >= 3;

    if ((drowsy || distracted) && !_alarmTriggered) {
      _triggerAlarm();
    } else if (!drowsy && !distracted && _alarmTriggered) {
      _stopAlarm();
    }

    // Reduz contadores gradualmente quando não há risco
    if (!drowsy && _closedEyesCount > 0) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _closedEyesCount = (_closedEyesCount - 1).clamp(0, 10);
            if (_closedEyesCount == 0 && _drowsinessStatus != "Monitorando...") {
              _drowsinessStatus = "Olhos abertos";
              _drowsinessColor = Colors.green;
            }
          });
        }
      });
    }
    if (!distracted && _lookAwayCount > 0) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _lookAwayCount = (_lookAwayCount - 1).clamp(0, 10);
            if (_lookAwayCount == 0 && _distractionStatus != "Monitorando...") {
              _distractionStatus = "Atento";
              _distractionColor = Colors.green;
            }
          });
        }
      });
    }
  }

  void _triggerAlarm() {
    if (_alarmTriggered) return;
    _alarmTriggered = true;
    setState(() {
      _statusMessage = "ALERTA! Motorista perigoso!";
      _statusColor = Colors.red;
    });

    // Tocar alarme repetido
    _alarmTimer?.cancel();
    _alarmTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      FlutterRingtonePlayer.playNotification();
      Vibration.vibrate(pattern: [500, 500, 500]);
    });

    // Reset automático após 8 segundos
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && _isMonitoring) {
        _closedEyesCount = 0;
        _lookAwayCount = 0;
        _stopAlarm();
        setState(() {
          _statusMessage = "Monitorando...";
          _statusColor = Colors.green;
          _drowsinessStatus = "Olhos abertos";
          _drowsinessColor = Colors.green;
          _distractionStatus = "Atento";
          _distractionColor = Colors.green;
        });
      }
    });
  }

  void _stopAlarm() {
    _alarmTimer?.cancel();
    _alarmTimer = null;
    _alarmTriggered = false;
    Vibration.cancel();
  }

  @override
  void dispose() {
    _stopAlarm();
    _simulationTimer?.cancel();
    _cameraController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ------------------ UI RENOVADA E RESPONSIVA ------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DriverWatch - Segurança Inteligente'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _showHistorySnackbar(),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F2027), Color(0xFF203A43)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        _buildStatusCard(),
                        _buildCameraPreview(),
                        _buildMetricsPanel(),
                        const Spacer(),
                        _buildControlButton(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_statusColor.withValues(alpha: 0.2), _statusColor.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: _statusColor, width: 2),
        boxShadow: [
          BoxShadow(color: _statusColor.withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 2),
        ],
      ),
      child: Column(
        children: [
          Icon(_isMonitoring ? Icons.verified_user : Icons.warning_amber,
              color: _statusColor, size: 50),
          const SizedBox(height: 10),
          Text(_statusMessage,
              style: TextStyle(color: _statusColor, fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: _statusColor,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(_isMonitoring ? "ATIVO" : "PAUSADO",
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_isCameraReady || _cameraController == null || !_cameraController!.value.isInitialized) {
      return Container(
        margin: const EdgeInsets.all(16),
        height: 250,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(25),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return Container(
      margin: const EdgeInsets.all(16),
      height: 280,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.blueAccent, width: 2),
        boxShadow: [BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.3), blurRadius: 15)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: CameraPreview(_cameraController!),
      ),
    );
  }

  Widget _buildMetricsPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
       color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("📊 ANÁLISE EM TEMPO REAL",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetricItem(Icons.visibility, "Olhos", _drowsinessStatus, _drowsinessColor),
              const SizedBox(width: 20),
              _buildMetricItem(Icons.headset_off, "Distração", _distractionStatus, _distractionColor),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetricItem(Icons.speed, "G-Force", "${_gForce.toStringAsFixed(1)} G", Colors.cyan),
              const SizedBox(width: 20),
              _buildMetricItem(Icons.timeline, "Status", _isMonitoring ? "ATIVO" : "PAUSADO",
                  _isMonitoring ? Colors.green : Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha:0.5)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text(value,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton.icon(
        onPressed: () {
          setState(() {
            _isMonitoring = !_isMonitoring;
            if (_isMonitoring) {
              _statusMessage = "Monitorando...";
              _statusColor = Colors.green;
              _closedEyesCount = 0;
              _lookAwayCount = 0;
              _stopAlarm();
            } else {
              _statusMessage = "Monitoramento pausado";
              _statusColor = Colors.orange;
              _stopAlarm();
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isMonitoring ? "Monitoramento iniciado" : "Monitoramento pausado"),
              duration: const Duration(seconds: 2),
              backgroundColor: _isMonitoring ? Colors.green : Colors.orange,
            ),
          );
        },
        icon: Icon(_isMonitoring ? Icons.stop_circle : Icons.play_circle, size: 32),
        label: Text(
          _isMonitoring ? "PARAR MONITORAMENTO" : "INICIAR MONITORAMENTO",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isMonitoring ? Colors.red : Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
          elevation: 8,
        ),
      ),
    );
  }

  void _showHistorySnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Histórico: em desenvolvimento para a próxima versão do TCC")),
    );
  }
}