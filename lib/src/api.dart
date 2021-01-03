// Dummy annotation classes.

import 'content.dart';
import 'tapers.dart';

/// Main API for the tape part.
const tape = TapeApi._();

class TapeApi {
  const TapeApi._();

  void register(Map<int, Taper<dynamic>> typeCodesToTapers) {
    registry.register({
      ...tapers.forChest,
      ...typeCodesToTapers,
    });
  }

  bool get isInitialized => registry.hasTapers;
}

class TapeKey {
  const TapeKey(String key);
}

const doNotTape = Object();

const taper = TaperNamespace._();

class TaperNamespace {
  const TaperNamespace._();
}

const tapers = TapersNamespace._();

class TapersNamespace {
  const TapersNamespace._();
}
