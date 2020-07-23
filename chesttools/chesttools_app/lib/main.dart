import 'package:flutter/material.dart';

import 'connect.dart';
import 'tools.dart';

void main() {
  runApp(ChestToolsApp());
}

class ChestToolsApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChestTools',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      routes: {
        '': (_) => ConnectPage(),
        'connect': (_) => ConnectPage(),
        'tools': (_) => ToolsPage(),
      },
      home: ConnectPage(),
    );
  }
}
