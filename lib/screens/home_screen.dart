import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

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
  double _gForce = 0.0;
  Timer? _simulateSensorTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCameraAndSensors();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startCamera();
    } else if (state == AppLifecycleState.paused) {
      _stopCamera();
    }
  }

  Future<void> _initCameraAndSensors() async {
    await _requestPermissions();
    await _initCamera();
    _startSensorSimulation(); // SIMULA sensores (seguro, sem consumo excessivo)
  }

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
  }

  Future<void> _initCamera() async {
    try {
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
    } catch (e) {
      setState(() {
        _statusMessage = "Erro na câmera: $e";
        _statusColor = Colors.red;
      });
    }
  }

  Future<void> _startCamera() async {
    if (_cameraController != null && !_cameraController!.value.isInitialized) {
      await _cameraController!.initialize();
    }
  }

  Future<void> _stopCamera() async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }
  }

  // SIMULAÇÃO segura da força G (evita travamento)
  void _startSensorSimulation() {
    _simulateSensorTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() {
          // Simula variação aleatória de G-Force
          _gForce = (_gForce + (DateTime.now().millisecondsSinceEpoch % 3 - 1) * 0.2).clamp(0.0, 5.0);
        });
      }
    });
  }

  @override
  void dispose() {
    _simulateSensorTimer?.cancel();
    _stopCamera();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DriverWatch - Monitoramento'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Histórico em breve")),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusCard(),
          _buildCameraPreview(),
          _buildSensorsStatus(),
          const Spacer(),
          _buildControlButton(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _statusColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _statusColor, width: 2),
      ),
      child: Column(
        children: [
          Icon(_isMonitoring ? Icons.verified : Icons.warning, color: _statusColor, size: 40),
          const SizedBox(height: 10),
          Text(_statusMessage,
              style: TextStyle(color: _statusColor, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            decoration: BoxDecoration(color: _statusColor, borderRadius: BorderRadius.circular(20)),
            child: Text(_isMonitoring ? "ATIVO" : "ALERTA",
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
        decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(15)),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return Container(
      margin: const EdgeInsets.all(16),
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: CameraPreview(_cameraController!),
      ),
    );
  }

  Widget _buildSensorsStatus() {
    String collisionStatus = _gForce > 3.0 ? "ALERTA" : "OK";
    Color collisionColor = _gForce > 3.0 ? Colors.red : Colors.green;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(15)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSensorStatus(Icons.face, "Rosto", "Detectado"),
          _buildSensorStatus(Icons.speed, "G-Force", "${_gForce.toStringAsFixed(1)} G"),
          _buildSensorStatus(Icons.warning, "Colisão", collisionStatus, iconColor: collisionColor),
        ],
      ),
    );
  }

  Widget _buildSensorStatus(IconData icon, String label, String value, {Color iconColor = Colors.blue}) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 30),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(value, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildControlButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton.icon(
        onPressed: () {
          setState(() {
            _isMonitoring = !_isMonitoring;
            _statusMessage = _isMonitoring ? "Monitorando..." : "Monitoramento pausado";
            _statusColor = _isMonitoring ? Colors.green : Colors.red;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isMonitoring ? "Monitoramento iniciado" : "Monitoramento pausado"),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        icon: Icon(_isMonitoring ? Icons.stop : Icons.play_arrow),
        label: Text(_isMonitoring ? "PARAR MONITORAMENTO" : "INICIAR MONITORAMENTO"),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isMonitoring ? Colors.red : Colors.green,
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        ),
      ),
    );
  }
}