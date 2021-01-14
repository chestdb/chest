import 'dart:typed_data';

import 'basics.dart';

extension TapersForDartTypedData on TapersNamespace {
  Map<int, Taper<dynamic>> get forDartTypedData {
    return {
      -40: taper.forUint8List(),
    };
  }
}

extension TaperForUint8ListExtension on TaperNamespace {
  Taper<Uint8List> forUint8List() => const TaperForUint8List();
}

class TaperForUint8List extends BytesTaper<Uint8List> {
  const TaperForUint8List();

  @override
  List<int> toBytes(Uint8List uint8List) => uint8List;

  @override
  Uint8List fromBytes(List<int> bytes) => Uint8List.fromList(bytes);
}
