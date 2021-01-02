// Dummy annotation classes.

import 'content.dart';
import 'tapers.dart';

/// Main API for the tape part.
const tape = TapeApi();

class TapeApi {
  const TapeApi();

  void register(Map<int, Taper<dynamic>> typeCodesToTapers) {
    registry.register({
      ...tapersForContent,
      ...typeCodesToTapers,
    });
  }

  bool get isInitialized => registry.hasTapers;
}

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
