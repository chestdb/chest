import 'dart:io';
import 'dart:collection';

import 'package:flutter/material.dart';
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

  Future<void> _connect() async {
    print('Connecting…');
    final httpUri = _uriController.text;
    assert(httpUri.startsWith('http://'));
    assert(httpUri.endsWith('=/'));

    // Turn http://127.0.0.1:8181/7GOC9eKQrbA=/
    // into ws://127.0.0.1:8181/7GOC9eKQrbA=/ws
    final uri = 'ws://${httpUri.substring('http://'.length)}ws';

    try {
      service = await vmServiceConnectUri(uri);
      print('Connected to service $service');
    } catch (e, st) {
      print('ERROR: Unable to connect to VMService $uri');
      print(e);
      print(st);
      return null;
    }
    Navigator.of(context).pushReplacementNamed('tools');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Connect to a running app'),
            Text('Enter a URL to a running Dart or Flutter application that '
                'uses chest.'),
            SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: 400,
                  child: TextField(
                    controller: _uriController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'http://127.0.0.1:38500/auth_code',
                    ),
                  ),
                ),
                SizedBox(width: 16),
                RaisedButton(
                  onPressed: _connect,
                  color: Theme.of(context).primaryColor,
                  child: Text('Connect'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
