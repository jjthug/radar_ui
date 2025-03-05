import 'package:flutter/material.dart';

class RadarScreen extends StatelessWidget {
  final String authToken;

  const RadarScreen({super.key, required this.authToken});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login Successful')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Login Successful!'),
            Text('Token: $authToken'), // Display token (optional)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
