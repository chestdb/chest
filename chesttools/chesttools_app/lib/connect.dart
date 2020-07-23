import 'dart:io';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:vm_service/utils.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

class ConnectPage extends StatefulWidget {
  @override
  _ConnectPageState createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  final _uriController = TextEditingController();

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
                  onPressed: () async {
                    print('Connecting…');
                    final uri = 'ws://localhost:8181';
                    try {
                      final service = await vmServiceConnectUri(uri);

                      print('Connected to service $service');
                    } catch (_) {
                      print('ERROR: Unable to connect to VMService $uri');
                      return null;
                    }
                    Navigator.of(context).pushReplacementNamed('tools');
                  },
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
