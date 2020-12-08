import 'dart:io';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vm_service/utils.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

import 'main.dart';

class ConnectPage extends StatefulWidget {
  @override
  _ConnectPageState createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  final _uriController = TextEditingController();
  String _message = '';

  Future<void> _connect() async {
    final text = _uriController.text;
    String uri;

    if (text.isEmpty) {
      _message = '';
    } else if (text.startsWith('http://')) {
      if (text.endsWith('/')) {
        // Turn http://127.0.0.1:8181/7GOC9eKQrbA=/
        // into ws://127.0.0.1:8181/7GOC9eKQrbA=/ws
        uri = 'ws://${text.substring('http://'.length)}ws';
      } else {
        _message = 'The URL should end with "/".';
      }
    } else if (text.startsWith('ws://')) {
      if (text.endsWith('/ws')) {
        uri = text;
      } else {
        _message = 'The URL should end with "/ws".';
      }
    } else {
      _message = 'Make sure your URL starts with http:// or ws://.';
    }

    if (uri != null) {
      _message = 'Connecting…';
    }
    setState(() {});
    if (uri == null) return;

    try {
      service = await vmServiceConnectUri(uri);
      print('Connected to service $service');
    } catch (e, st) {
      print('ERROR: Unable to connect to VMService $uri');
      print(e);
      print(st);
      setState(() {
        _message = "Can't connect to this VMService: $e";
      });
      return null;
    }
    Navigator.of(context).pushReplacementNamed('tools');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Chest',
                style: GoogleFonts.rajdhani(
                  fontWeight: FontWeight.bold,
                  fontSize: 48,
                ),
              ),
              Text('To connect, simply paste a URL to a Dart or Flutter '
                  'application that is running in debug mode and using Chest.'),
              SizedBox(height: 16),
              TextField(
                controller: _uriController,
                onChanged: (_) => _connect(),
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'http://127.0.0.1:38500/auth_code',
                ),
              ),
              SizedBox(height: 8),
              Text(_message),
            ],
          ),
        ),
      ),
    );
  }
}
