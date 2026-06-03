import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // PACOTE NECESSÁRIO PARA A PONTE NATIVA
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart'; 
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:simple_pip_mode/simple_pip.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // 👇 CANAL DE COMUNICAÇÃO NATIVA COM O KOTLIN 👇
  static const platform = MethodChannel('com.example.driverwatch/emergency');

  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  FaceDetector? _faceDetector;
  StreamSubscription<UserAccelerometerEvent>? _accelerometerSubscription;
  late FlutterTts _flutterTts;
  
  bool _isCameraReady = false;
  bool _isMonitoring = true;
  bool _isProcessingImage = false;

  String _statusMessage = "Iniciando sistema...";
  Color _statusColor = Colors.yellow;

  DateTime? _drowsinessStartTime; 
  DateTime? _distractionStartTime;
  bool _hasSpokenDrowsy = false;
  bool _hasSpokenDistracted = false;

  String _drowsinessStatus = "Iniciando...";
  String _distractionStatus = "Iniciando...";
  Color _drowsinessColor = Colors.green;
  Color _distractionColor = Colors.green;

  bool _alarmTriggered = false;
  Timer? _vibrationTimer; 

  double _gForce = 1.0; 
  bool _isEmergencyMode = false;
  int _collisionCountdown = 30;
  Timer? _emergencyTimer;
  String _emergencyNumber = "192"; 

  String _selectedSoundType = "Alarme"; 
  final List<String> _soundOptions = ["Notificação", "Alarme", "Toque"];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: true,
      ),
    );

    _initTts();
    _initHardware();

    try {
      SimplePip().setAutoPipMode();
    } catch (e) {
      debugPrint("Auto PiP não suportado");
    }
  }

  void _initTts() {
    _flutterTts = FlutterTts();
    _flutterTts.setLanguage("pt-BR");
    _flutterTts.setSpeechRate(0.5); 
    _flutterTts.setPitch(1.0);
  }

  Future<void> _speakAlert(String text) async {
    await _flutterTts.stop();
    await _flutterTts.speak(text);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      SimplePip.isPipActivated.then((isPip) {
        if (!isPip) {
          _cameraController?.stopImageStream();
          _accelerometerSubscription?.pause();
        }
      });
    } else if (state == AppLifecycleState.resumed) {
      _startLiveStream();
      _accelerometerSubscription?.resume();
    }
  }

  Future<void> _initHardware() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.phone, 
    ].request();

    if (statuses[Permission.camera]!.isDenied) {
      setState(() {
        _statusMessage = "Permissão da câmera negada";
        _statusColor = Colors.red;
      });
      return;
    }

    _initAccelerometer();

    _cameras = await availableCameras();
    if (_cameras == null || _cameras!.isEmpty) {
      setState(() {
        _statusMessage = "Nenhuma câmera encontrada";
        _statusColor = Colors.red;
      });
      return;
    }

    CameraDescription frontalCamera = _cameras!.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras![0],
    );

    _cameraController = CameraController(
      frontalCamera, 
      ResolutionPreset.low, 
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid 
          ? ImageFormatGroup.nv21 
          : ImageFormatGroup.bgra8888,
    );

    try {
      await _cameraController!.initialize();
      _startLiveStream();
      
      if (mounted) {
        setState(() {
          _isCameraReady = true;
          _statusMessage = "Sistema Ativo e Monitorando";
          _statusColor = Colors.green;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = "Erro ao iniciar câmera";
        _statusColor = Colors.red;
      });
    }
  }

  void _startLiveStream() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_cameraController!.value.isStreamingImages) return; 

    _cameraController!.startImageStream((CameraImage image) async {
      if (_isProcessingImage || !_isMonitoring || _isEmergencyMode) return;
      _isProcessingImage = true;

      try {
        final WriteBuffer allBytes = WriteBuffer();
        for (final Plane plane in image.planes) {
          allBytes.putUint8List(plane.bytes);
        }
        final Uint8List bytes = allBytes.done().buffer.asUint8List();

        final metadata = InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotationValue.fromRawValue(270) ?? InputImageRotation.values.first, 
          format: InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        );

        final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata);
        final List<Face> faces = await _faceDetector!.processImage(inputImage);

        _processFaces(faces);
      } catch (e) {
        debugPrint("Erro no frame: $e");
      } finally {
        _isProcessingImage = false;
      }
    });
  }

  void _processFaces(List<Face> faces) {
    if (!mounted || !_isMonitoring || _isEmergencyMode) return;

    if (faces.isEmpty) {
      setState(() {
        _drowsinessStatus = "Rosto Ausente";
        _drowsinessColor = Colors.orange;
        _distractionStatus = "Rosto Ausente";
        _distractionColor = Colors.orange;
        _distractionStartTime = null; 
        _drowsinessStartTime = null;
      });
      return;
    }

    final Face face = faces.first;

    if (face.leftEyeOpenProbability != null && face.rightEyeOpenProbability != null) {
      double eyeOpenAvg = (face.leftEyeOpenProbability! + face.rightEyeOpenProbability!) / 2;

      setState(() {
        if (eyeOpenAvg < 0.20) {
          _drowsinessStartTime ??= DateTime.now(); 
          _drowsinessStatus = "Olhos Fechados";
          _drowsinessColor = Colors.red;
        } else {
          _drowsinessStartTime = null; 
          _drowsinessStatus = "Olhos Abertos";
          _drowsinessColor = Colors.green;
          _hasSpokenDrowsy = false; 
        }
      });
    }

    if (face.headEulerAngleY != null || face.headEulerAngleX != null) {
      double yaw = face.headEulerAngleY!;   
      double pitch = face.headEulerAngleX!; 

      setState(() {
        if (yaw.abs() > 22.0 || pitch.abs() > 18.0) {
          _distractionStartTime ??= DateTime.now(); 
          _distractionStatus = "Desviou o Olhar!";
          _distractionColor = Colors.red;
        } else {
          _distractionStartTime = null; 
          _distractionStatus = "Atento à Via";
          _distractionColor = Colors.green;
          _hasSpokenDistracted = false; 
        }
      });
    }

    _checkThresholds();
  }

  void _initAccelerometer() {
    _accelerometerSubscription = userAccelerometerEventStream().listen((UserAccelerometerEvent event) {
      if (!mounted || !_isMonitoring || _isEmergencyMode) return;

      double magnitude = math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      double calculatedG = 1.0 + (magnitude / 9.80665);

      setState(() {
        _gForce = calculatedG;

        if (_gForce > 4.5 && !_isEmergencyMode) { 
          _triggerCollisionEmergency();
        }
      });
    });
  }

  void _triggerCollisionEmergency() {
    // 👇 GATILHO DA PONTE NATIVA: PUXA O APP PARA A TELA CHEIA 👇
    try {
      platform.invokeMethod('bringToFront');
    } catch (e) {
      debugPrint("Erro ao maximizar tela: $e");
    }

    setState(() {
      _isEmergencyMode = true;
      _collisionCountdown = 30;
      _statusMessage = "💥 COLISÃO DETECTADA!";
      _statusColor = Colors.red;
    });

    _stopAlarm();

    String numeroFalado = _emergencyNumber.split('').join(' ');
    _speakAlert("Colisão detectada. Em 30 segundos será realizada a ligação de emergência para o número $numeroFalado.");
    
    _playSelectedSystemSound();

    _emergencyTimer?.cancel();
    _emergencyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      
      setState(() {
        if (_collisionCountdown > 0) {
          _collisionCountdown--;
          _statusMessage = "EMERGÊNCIA EM $_collisionCountdown s";
          Vibration.vibrate(duration: 500, intensities: [255]);
        } else {
          timer.cancel();
          _makeEmergencyCall();
        }
      });
    });
  }

  Future<void> _makeEmergencyCall() async {
    _stopAlarm();
    
    setState(() {
      _statusMessage = "LIGANDO PARA $_emergencyNumber...";
    });

    bool? callSuccess = await FlutterPhoneDirectCaller.callNumber(_emergencyNumber);

    if (callSuccess == null || !callSuccess) {
      _speakAlert("Não foi possível realizar a chamada automaticamente. Verifique as permissões de ligação.");
      setState(() {
        _statusMessage = "FALHA NA LIGAÇÃO!";
      });
    }
  }

  void _cancelEmergency() {
    _emergencyTimer?.cancel();
    _stopAlarm();
    
    _speakAlert("Emergência cancelada. Retomando monitoramento.");
    
    setState(() {
      _isEmergencyMode = false;
      _statusMessage = "Monitorando...";
      _statusColor = Colors.green;
      _gForce = 1.0;
    });
  }

  void _showEmergencyConfigDialog() {
    TextEditingController controller = TextEditingController(text: _emergencyNumber);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF203A43),
          title: const Text("Número de Emergência", style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "Ex: 192, 190...",
              hintStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar", style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _emergencyNumber = controller.text;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Número atualizado para $_emergencyNumber")),
                );
              },
              child: const Text("Salvar"),
            ),
          ],
        );
      },
    );
  }

  void _checkThresholds() {
    bool isDrowsyCritical = false;
    bool isDistractedCritical = false;

    if (_drowsinessStartTime != null) {
      int elapsedDrowsy = DateTime.now().difference(_drowsinessStartTime!).inSeconds;
      
      if (elapsedDrowsy >= 1 && !_hasSpokenDrowsy) {
        _hasSpokenDrowsy = true;
        _speakAlert("Alerta de sono detectado. Pare o veículo em local seguro e descanse imediatamente.");
      }
      if (elapsedDrowsy >= 3) {
        isDrowsyCritical = true;
      }
    }

    if (_distractionStartTime != null) {
      int elapsedDistracted = DateTime.now().difference(_distractionStartTime!).inSeconds;
      
      if (elapsedDistracted >= 2 && !_hasSpokenDistracted) {
        _hasSpokenDistracted = true;
        _speakAlert("Alerta de distração. Por favor, mantenha os olhos na pista.");
      }
      if (elapsedDistracted >= 4) {
        isDistractedCritical = true;
      }
    }

    if ((isDrowsyCritical || isDistractedCritical) && !_alarmTriggered) {
      _triggerStandardAlarm();
    } else if (!isDrowsyCritical && !isDistractedCritical && _alarmTriggered) {
      _stopAlarm();
    }
  }

  void _triggerStandardAlarm() {
    if (_alarmTriggered) return;
    _alarmTriggered = true;

    setState(() {
      _statusMessage = "🚨 ALERTA MÁXIMO: FADIGA/DISTRAÇÃO!";
      _statusColor = Colors.red;
    });

    _playSelectedSystemSound();

    _vibrationTimer?.cancel();
    _vibrationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      Vibration.vibrate(pattern: [300, 200, 300], intensities: [1, 255, 1]);
    });
  }

  void _playSelectedSystemSound() {
    if (_selectedSoundType == "Alarme") {
      FlutterRingtonePlayer().play(android: AndroidSounds.alarm, ios: IosSounds.alarm, looping: true, volume: 1.0, asAlarm: true);
    } else if (_selectedSoundType == "Toque") {
      FlutterRingtonePlayer().play(android: AndroidSounds.ringtone, ios: IosSounds.glass, looping: true, volume: 1.0, asAlarm: true);
    } else {
      FlutterRingtonePlayer().play(android: AndroidSounds.notification, ios: IosSounds.triTone, looping: true, volume: 1.0, asAlarm: true);
    }
  }

  void _stopAlarm() {
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    _alarmTriggered = false;
    
    Vibration.cancel();
    FlutterRingtonePlayer().stop(); 
    
    if (!_isEmergencyMode) {
      setState(() {
        _statusMessage = "Monitorando...";
        _statusColor = Colors.green;
      });
    }
  }

  @override
  void dispose() {
    _stopAlarm();
    _emergencyTimer?.cancel();
    _cameraController?.dispose();
    _faceDetector?.close();
    _flutterTts.stop();
    _accelerometerSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DriverWatch - Segurança Ativa'),
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
            icon: const Icon(Icons.picture_in_picture_alt, color: Colors.white),
            tooltip: "Minimizar Janela (Waze)",
            onPressed: _isEmergencyMode ? null : () {
              SimplePip().enterPipMode();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_phone, color: Colors.white),
            tooltip: "Configurar Número de Emergência",
            onPressed: _isEmergencyMode ? null : _showEmergencyConfigDialog,
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
                        if (!_isEmergencyMode) _buildSoundPickerCard(), 
                        if (!_isEmergencyMode) _buildCameraPreview(),
                        if (!_isEmergencyMode) _buildMetricsPanel(),
                        const Spacer(),
                        _isEmergencyMode ? _buildEmergencyCancelButton() : _buildControlButton(),
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
      margin: const EdgeInsets.only(left: 16, right: 16, top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_statusColor.withValues(alpha: 0.2), _statusColor.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: _statusColor, width: _isEmergencyMode ? 5 : 2),
        boxShadow: [
          BoxShadow(color: _statusColor.withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 2),
        ],
      ),
      child: Column(
        children: [
          Icon(
            _isEmergencyMode ? Icons.car_crash : (_isMonitoring ? Icons.verified_user : Icons.warning_amber),
            color: _statusColor, size: _isEmergencyMode ? 80 : 50
          ),
          const SizedBox(height: 10),
          Text(_statusMessage,
              style: TextStyle(
                color: _statusColor, 
                fontSize: _isEmergencyMode ? 24 : 16, 
                fontWeight: FontWeight.bold
              ),
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          if (!_isEmergencyMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: _statusColor,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(_isMonitoring ? "MONITORAMENTO ATIVO" : "SISTEMA PAUSADO",
                  style: const TextStyle(
                    color: Colors.black, 
                    fontWeight: FontWeight.bold, 
                    fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildSoundPickerCard() {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.audiotrack, color: Colors.blueAccent, size: 20),
              SizedBox(width: 8),
              Text("Som do Alerta:", style: TextStyle(
                color: Colors.white, 
                fontSize: 13, 
                fontWeight: FontWeight.w500)),
            ],
          ),
          DropdownButton<String>(
            value: _selectedSoundType,
            dropdownColor: const Color(0xFF203A43),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.blueAccent),
            underline: Container(),
            style: const TextStyle(
              color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedSoundType = newValue;
                });
              }
            },
            items: _soundOptions.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_isCameraReady || _cameraController == null || !_cameraController!.value.isInitialized) {
      return Container(
        margin: const EdgeInsets.all(16),
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(25),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return Container(
      margin: const EdgeInsets.all(16),
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.blueAccent, width: 2),
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
          const Text("📊 DISPOSITIVO DE BORDA - TELEMETRIA",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetricItem(Icons.visibility, "Monitor de Sono", _drowsinessStatus, _drowsinessColor),
              const SizedBox(width: 16),
              _buildMetricItem(Icons.face, "Monitor de Atenção", _distractionStatus, _distractionColor),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetricItem(Icons.av_timer, "Sensor Inercial", "${_gForce.toStringAsFixed(2)} G", Colors.cyan),
              const SizedBox(width: 16),
              _buildMetricItem(Icons.g_mobiledata, "Status", _isMonitoring ? "Processando..." : "Aguardando...",
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
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            Text(value,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyCancelButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton.icon(
        onPressed: _cancelEmergency,
        icon: const Icon(Icons.thumb_up, size: 40),
        label: const Text("ESTOU BEM\nCANCELAR LIGAÇÃO", textAlign: TextAlign.center, style: TextStyle(fontSize: 20)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[600],
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 120),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 10,
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
              _drowsinessStartTime = null;
              _distractionStartTime = null;
              _stopAlarm();
            } else {
              _statusMessage = "Monitoramento suspenso";
              _statusColor = Colors.orange;
              _stopAlarm();
              _drowsinessStatus = "Pausado";
              _distractionStatus = "Pausado";
              _distractionStartTime = null;
              _drowsinessStartTime = null;
            }
          });
        },
        icon: Icon(_isMonitoring ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 30),
        label: Text(_isMonitoring ? "PAUSAR " : "RETOMAR "),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isMonitoring ? Colors.red[700] : Colors.green[700],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
        ),
      ),
    );
  }
}