import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phoenix_socket/phoenix_socket.dart';
import 'package:flutter_geo_hash/flutter_geo_hash.dart';

class RadarScreen extends StatefulWidget {
  final String authToken;

  const RadarScreen({super.key, required this.authToken});

  @override
  _RadarScreenState createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  final radarFormKey = GlobalKey<FormState>();
  final latController = TextEditingController();
  final longController = TextEditingController();
  final topicController = TextEditingController();
  PhoenixSocket? _socket;
  PhoenixChannel? currentChannel;
  bool _isConnected = false;
  String _status = "Disconnected";


  String getGeohash() {
    final geoHash = MyGeoHash();

    try {

      final point = GeoPoint(double.tryParse(latController.text)!, double.tryParse(longController.text)!); // San Francisco
      
      try {
        geoHash.validateLocation(point);
        print('Valid GeoPoint: $point');
      } catch (e) {
        print('Invalid GeoPoint: $e');
      }

      geoHash.validateLocation(point);
      print('Valid GeoPoint: $point');

      final hash = geoHash.geoHashForLocation(point, precision: 7);

      return hash;
    } catch (e) {
      print('Error generating geohash: $e');
      return '';
    }
  }

  // ✅ Function to disconnect from a topic
  Future<void> disconnectFromTopic() async {
    if (currentChannel != null) {
      final leave = currentChannel!.leave();

      final response = await leave.future;
      print("Resp: $response");


      // Optionally, remove the channel from the socket
      _socket!.removeChannel(currentChannel!);
    }
  }

  Future<void> joinTopic() async {
    var geohash = getGeohash();
    var currentTopic = 'geohash:$geohash';

    if (currentChannel != null) {
      disconnectFromTopic();
    }

    if (_socket == null) {
      print("❌ Socket is not initialized.");
      return;
    }

    print("🔄 Attempting to join topic: $currentTopic");

    _socket!.closeStream.listen((event) {
      print("⚠️ Socket closed.");
      setState(() => _isConnected = false);
    });

    _socket!.openStream.listen((event) async {
      print("✅ Socket opened.");
      
      currentChannel = _socket!.addChannel(
        topic: currentTopic,
        parameters: {
          'lat': latController.text,
          'lng': longController.text,
        },
      );

      if (currentChannel == null) {
        print("❌ Failed to create channel.");
        return;
      }

      try {
        await currentChannel!.join().future;
        print("✅ Successfully joined channel: $currentTopic");

        setState(() {
          _status = "Connected to $currentTopic";
          _isConnected = true;
        });

        currentChannel?.messages.listen((message) {
          if (message.payload == null) return;

          print("📩 Received event: ${message.event.value}, Payload: ${message.payload}");

          switch (message.event.value) {
            case 'update_location':
              setState(() {
                _status = "User ${message.payload!['user_id']} at: (${message.payload!['lat']}, ${message.payload!['lng']})";
              });
              break;
            case 'user_disconnected':
              setState(() {
                _status = "User ${message.payload!['user_id']} disconnected";
              });
              break;
          }
        });
      } catch (e) {
        print("❌ Error joining channel: $e");
      }
    });
  }


  Future<void> sendLoc() async {
    try {
      if (currentChannel == null) {
        print("❌ Channel is not initialized.");
        return;
      }

      print("📤 Sending location update...");

      if (_socket == null || !_isConnected || currentChannel == null) {
        print("❌ WebSocket or Channel is not connected. Cannot update location.");
        return;
}

      final push = currentChannel!.push(
        'update_location',
        {
          'lat': double.parse(latController.text),
          'lng': double.parse(longController.text),
        },
      );

      // Wait for the server response
      final response = await push.future;

      print("✅ Server Response: $response");

      if (mounted) {
        setState(() {
          _status = "Server response: ${response.toString()}"; // Ensure UI updates
        });
      }

    } catch (e) {
      print("❌ Error occurred: $e");

      if (mounted) {
        setState(() {
          _status = "Error: $e";
        });
      }
    }
  }




  Future<void> _connectWebSocket() async {
    try {
      _socket = PhoenixSocket('ws://10.0.2.2:4000/socket/websocket?token=${widget.authToken}');
      await _socket!.connect();

      _socket!.closeStream.listen((event) {
        setState(() => _isConnected = false);
      });
      _socket!.openStream.listen((event) {
        setState(() {
          _isConnected = true;
        });
      });
      
      // var uuid = Uuid().v4();
      // _channel!.push('ping', {'from': uuid});
      
      // _channel!.messages.listen((message) {
      //   if (message.event == const PhoenixChannelEvent.custom('pong') &&
      //       message.payload?['from'] != uuid) {
      //     setState(() {
      //       _status = "Received pong from ${message.payload!['from']}";
      //     });
      //     Timer(const Duration(seconds: 1), () {
      //       _channel!.push('ping', {'from': uuid});
      //     });
      //   }
      // });
      
    } catch (e) {
      setState(() {
        _status = "Connection failed: $e";
      });
    }
  }

  @override
  void dispose() {
    _socket?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login Successful')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Login Successful!'),
            // Text('Token: ${widget.authToken}'),
            Text('Status: $_status'),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isConnected ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isConnected ? null : _connectWebSocket,
              child: const Text('Connect'),
            ),



            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Form(
                key: radarFormKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: latController, // Add controller
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'lat',
                        hintText: 'Enter lat',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter lat';
                        }
                        final double? lat = double.tryParse(value);
                        if (lat == null) {
                          return 'Enter a valid number';
                        }
                        return null;
                      },
                    ),
              
                    TextFormField(
                      controller: longController, // Add controller
                      decoration: const InputDecoration(
                        labelText: 'long',
                        hintText: 'Enter long',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter long';
                        }
                        final double? lat = double.tryParse(value);
                        if (lat == null) {
                          return 'Enter a valid number';
                        }
                        return null;
                      },
                    ),

                    MaterialButton(
                      minWidth: double.infinity,
                      onPressed: (){
                        joinTopic();
                      },
                      color: Colors.teal,
                      textColor: Colors.white,
                      child: const Text('Join Topic'),
                    ),
                    const SizedBox(height: 10),
              
                    const SizedBox(height: 20),
                    MaterialButton(
                      minWidth: double.infinity,
                      onPressed: () {
                        sendLoc(); // ✅ Pass context correctly
                      }, // Call _login function
                      color: Colors.teal,
                      textColor: Colors.white,
                      child: const Text('Send loc'),
                    ),
                  ],
              
              )),
            )
          ],
        ),
      ),
    );
  }
}
