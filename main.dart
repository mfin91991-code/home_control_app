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
        useMaterial3: true,
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
  
  late MqttServerClient client;
  String status = 'Disconnected';
  bool isConnected = false;

  // إعدادات الجهاز المستهدف (مثال: التلفاز)
  final String deviceMac = "AA:BB:CC:DD:EE:FF"; // استبدله بـ MAC Address الخاص بجهازك

  @override
  void initState() {
    super.initState();
    setupMqtt();
  }

  Future<void> setupMqtt() async {
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
      client.disconnect();
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

    final Map<String, dynamic> message = {
      'command': command,
      'mac_address': mac,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(message));
    
    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    debugPrint('Sent: $message to $topic');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Home Control'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
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
            const Text(
              'Device: Smart TV',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => sendCommand('WOL', deviceMac),
                  icon: const Icon(Icons.power_settings_new),
                  label: const Text('Turn On (WOL)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => sendCommand('SHUTDOWN', deviceMac),
                  icon: const Icon(Icons.power_off),
                  label: const Text('Shutdown'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            TextButton(
              onPressed: isConnected ? null : setupMqtt,
              child: const Text('Retry Connection'),
            )
          ],
        ),
      ),
    );
  }
}
