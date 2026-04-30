import 'frb_generated.dart';

class RustInitializer {
  RustInitializer(this._init);

  final Future<void> Function() _init;
  Future<void>? _initFuture;

  Future<void> ensureInitialized() {
    return _initFuture ??= _init();
  }
}

final _rustInitializer = RustInitializer(RustLib.init);

Future<void> ensureRustInitialized() {
  return _rustInitializer.ensureInitialized();
}
