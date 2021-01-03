import 'dart:typed_data';

import 'basics.dart';

extension TapersForDartTypedData on TapersNamespace {
  Map<int, Taper<dynamic>> get forDartTypedData {
    return {
      -40: taper.forUint8List(),
    };
  }
}

extension TaperForUint8List on TaperNamespace {
  Taper<Uint8List> forUint8List() {
    return BytesTaper(
      toBytes: (uint8List) => uint8List,
      fromBytes: (bytes) => Uint8List.fromList(bytes),
    );
  }
}
