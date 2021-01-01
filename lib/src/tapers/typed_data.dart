import 'dart:typed_data';

import 'basics.dart';

extension TapersPackageForDartTypedData on TapersForPackageApi {
  Map<int, Taper<dynamic>> get forDartTypedData {
    return {
      -40: taper.forUint8List(),
    };
  }
}

extension TapersForForDartTypedData on TaperApi {
  Taper<Uint8List> forUint8List() => _TaperForUint8List();
}

class _TaperForUint8List extends BytesTaper<Uint8List> {
  const _TaperForUint8List();

  @override
  List<int> toBytes(Uint8List value) => value;

  @override
  Uint8List fromBytes(List<int> bytes) => Uint8List.fromList(bytes);
}
