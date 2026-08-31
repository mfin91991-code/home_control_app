import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() {
  runApp(const SmartHomeApp());
}

class SmartHomeApp extends StatelessWidget {
  const SmartHomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Home Control',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // إعدادات MQTT
  final String broker = 'broker.hivemq.com';
  final String topic = 'home/devices/control';
  final String clientIdentifier = 'flutter_client_${DateTime.now().millisecondsSinceEpoch}';

  late MttServerClient client;
  String status = 'Disconnected';
  bool isConnected = false;

  // عنوان MAC الخاص بالجهاز المستهدف (افتراضي ويمكن تغييره من الأيقونة)
  String targetMacAddress = '00:11:22:33:44:55';
  final TextEditingController _macController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _macController.text = targetMacAddress;
    setupMqtt();
  }

  @override
  void dispose() {
    _macController.dispose();
    super.dispose();
  }

  Future<void> setuMqtt() async {
    client = MqttServerClient(broker, clientIdentifier);
    client.port = 1883;
    client.keepAlivePeriod = 20;
    client.onDisconnected = onDisconnected;
    client.onConnected = onConnected;

    final connMess = MqttConnectMessage()
        .withClientIdentifier(clientIdentifier)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    client.connectionMessage = connMess;

    try {
      await client.connect();
    } catch (e) {
      debugPrint('Exception: $e');
      lient.disconnect();
    }
  }

  void onConnected() {
    setState(() {
      isConnected = true;
      status = 'Connected to $broker';
    });
  }

  void onDisconnected() {
    setState(() {
      isConnected = false;
      status = 'Disconnected';
    });
  }

  void sendCommand(String command, String mac) {
    if (!isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not connected to MQTT Broker')),
      );
      return;
    }

    final Map<String dynamic> message = {
      'command': command,
      'mac_address': mac,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(message));

    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    debugPrint('Sent: $message to $topic');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم إرسال الأمر ($command) للجهاز: $mac')),
    );
  }

  // نافذة إدخال وتعديل عنوانالـ MAC
  void _showMacSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('إعدادات الجهاز المستهدف'),
          content: TextField(
            controller: _macController,
            decoration: const InputDecoration(
              labelText: 'عنوان MAC (MAC Address)',
              hintText: 'AA:BB:CC:DD:EE:FF',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
           TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  targetMacAddress = _macController.text.trim();
                });
                Navigator.pop(context);
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
   return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Home Control'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          // أيقونة الإعدادات لتحديد الـ MAC
          IconButton(
            icon: const Icon(Icons.settings_suggest),
            tooltip: 'تحديد عنوان MAC',
            onPressed: _showMacSettingsDialog,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeIsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isConnected ? Icons.cloud_done : Icons.cloud_off,
              size: 80,
              color: isConnected ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 10),
            Text('Status: $status', style: const TextStyle(fontWeight: FontWeight.bold)),
            const Divider(height: 40),
            
            // عرض الجهاز امحدد حالياً
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الجهاز الحالي (MAC):', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(targetMacAddress, styl: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // أزرار التحكم
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => sendCommand('WOL', targetMacAddress),
                  icon: const Icon(Icons.power_settings_new),
                  label: const Tex('تشغيل (WOL)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => sendCommand('SHUTDOWN', targetMacAddress),
                  icon: const Icon(Icons.power_off),
                  label: const Text('إيقاف (hutdown)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: () => sendCommand('REBOOT', targetMacAddress),
              icon: const Icon(Icos.restart_alt),
              label: const Text('إعادة تشغيل (Reboot)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              ),
            ),
            const SizedBox(height: 30),

            TextButton(
              onPressed: isConnected ? null : setupMqtt,
              child: const Text('Retry Connection'),
           ),
          ],
        ),
      ),
    );
  }
}
