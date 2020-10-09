import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

import 'connect.dart';
import 'tools.dart';

VmService service;

void main() async {
  print('Connecting…');
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
