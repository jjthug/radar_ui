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

  Future<void> joinTopic() async {
    var geohash = getGeohash();
    var currentTopic = 'geohash:$geohash';
    currentChannel = _socket!.addChannel(topic: currentTopic, parameters: {'lat': latController.text, 'long': longController.text});
    currentChannel!.join().future.then((_) {
      setState(() {
        _isConnected = true;
        _status = "Connected to $currentTopic";
      });
    }).catchError((error) {
      setState(() {
        _status = "Failed to join: $error";
      });
    });

    currentChannel!.messages.listen((message) {
      switch (message.event.value) {
        // case 'switch_topic':
        //   _joinGeohashChannel(message.payload!['new_topic']);
        //   break;
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
  }

  Future<void> sendLoc() async{
    try{
      currentChannel!.push('update_location', {'lat': latController.text, 'long': longController.text});
      setState(() {
        _status = "Pushed update location";
      });
    }catch (e){
      print("error occurred");
    }
  }

  Future<void> _connectWebSocket() async {
    try {
      _socket = PhoenixSocket('ws://10.0.0.2:4001/socket/websocket?token=${widget.authToken}');
      await _socket!.connect();
      
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
      
      setState(() {
        _isConnected = true;
        _status = "Connected";
      });
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
