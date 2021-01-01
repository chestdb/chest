// Dummy annotation classes.

import 'tapers.dart';

class TapeKey {
  const TapeKey(String key);
}

const doNotTape = Object();

/// Namespace for single, user-defined tapers.
const taper = TaperApi();

class TaperApi {
  const TaperApi();
}

/// Namespace for tapers for a package.
const tapers = TapersForPackageApi();

class TapersForPackageApi {
  const TapersForPackageApi();
}

/// Main API for the tape part.
const tape = TapeApi();

class TapeApi {
  const TapeApi();

  void register(Map<int, Taper<dynamic>> typeCodesToTapers) {
    registry.register(typeCodesToTapers);
  }

  bool get isInitialized => registry.hasTapers;
}
