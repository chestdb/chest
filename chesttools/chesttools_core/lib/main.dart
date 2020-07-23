import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

void main() async {
  print('Connecting…');
  final uri = 'ws://127.0.0.1:8181/7GOC9eKQrbA=/ws';
  VmService service;

  try {
    service = await vmServiceConnectUri(uri);
    print('Connected to service $service');
  } catch (_) {
    print('ERROR: Unable to connect to VMService $uri');
    return;
  }

  final chestIsolates = (await service.getVM())
      .isolates
      .where((isolate) => isolate.name.startsWith('chest.'))
      .toList();
  final chestNames = chestIsolates
      .map((isolate) => isolate.name.substring('chest.'.length))
      .toList();
  print('The following chests are open: $chestNames');

  print('Inspecting the first one…');
  assert(chestIsolates.isNotEmpty);

  final isolate = chestIsolates.first;

  print('Getting number of chunks.');
  final result = await service.callServiceExtension('ext.chest.num_chunks',
      isolateId: isolate.id);
  print('The result was $result');
  print(result.json);
  print('There are ${result.json['size']} chunks.');

  service.dispose();
}
