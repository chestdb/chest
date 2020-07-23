import 'package:flutter/material.dart';

class ToolsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        body: Column(
          children: <Widget>[
            SizedBox(
              width: double.infinity,
              child: Material(
                elevation: 2,
                child: Row(
                  children: <Widget>[
                    SizedBox(width: 16),
                    FlutterLogo(),
                    SizedBox(width: 16),
                    TabBar(
                      indicatorSize: TabBarIndicatorSize.label,
                      isScrollable: true,
                      labelColor: Colors.black,
                      tabs: <Widget>[
                        Tab(text: 'Data'),
                        Tab(text: 'Queries'),
                        Tab(text: 'Indizes'),
                        Tab(text: 'Performance'),
                        Tab(text: 'Storage'),
                      ],
                    ),
                    Spacer(),
                    IconButton(
                      onPressed: () => print('Help'),
                      icon: Icon(Icons.info_outline),
                    ),
                    IconButton(
                      onPressed: () => print('Settings'),
                      icon: Icon(Icons.settings),
                    ),
                    IconButton(
                      onPressed: () => print('Help'),
                      icon: Icon(Icons.help_outline),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(child: Center(child: Text('Hello world.'))),
          ],
        ),
      ),
    );
  }
}
