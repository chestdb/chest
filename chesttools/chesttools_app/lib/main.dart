import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
        primarySwatch: MaterialColor(
          0xfffc7a44,
          <int, Color>{
            50: Color(0xfffff3da),
            100: Color(0xffffebc2),
            200: Color(0xffffd786),
            300: Color(0xfffcc444),
            400: Color(0xffff9f3e),
            500: Color(0xfffc7a44),
            600: Color(0xfff95c33),
            700: Color(0xfff53527),
            800: Color(0xffc2123c),
            900: Color(0xff880e3f),
          },
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        // textTheme: GoogleFonts.rajdhaniTextTheme(),
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
