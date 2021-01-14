// Dummy annotation classes.

import 'content.dart';
import 'tapers.dart';

/// Main API for the tape part.
///
/// Used for two things:
///
/// - Registering tapers:
///   ```dart
///   tape.register({
///     ...
///   });
///   ```
/// - Annotating classes for taper generation:
///   ```dart
///   @tape({
///     v0: {#name, #age},
///     v1: {#name},
///   })
///   class Fruit { ... }
///   ```
class tape {
  static void register(Map<int, Taper<dynamic>> typeCodesToTapers) {
    registry.register({
      ...tapers.forChest,
      ...typeCodesToTapers,
    });
  }

  static bool get isInitialized => registry.hasTapers;

  const tape(this.fieldsByVersion);

  final Map<Version, Set<Symbol>> fieldsByVersion;
}

class Version {
  const Version(this.value);

  final int value;
}

const v0 = Version(0);
const v1 = Version(1);
const v2 = Version(2);
const v3 = Version(3);
const v4 = Version(4);

class TapeKey {
  const TapeKey(this.key);

  final Symbol key;
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
