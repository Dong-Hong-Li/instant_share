import '../rx/rx.dart';

/// `int.rx`，便于 `final n = 0.rx`。
extension RxIntExt on int {
  Rx<int> get rx => Rx<int>(this);
}

/// `double.rx`
extension RxDoubleExt on double {
  Rx<double> get rx => Rx<double>(this);
}

/// `bool.rx`
extension RxBoolExt on bool {
  Rx<bool> get rx => Rx<bool>(this);
}

/// `String.rx`
extension RxStringExt on String {
  Rx<String> get rx => Rx<String>(this);
}

/// `Rx<T>.rx`，便于 `final n = Rx<int>(0).rx`。
extension RxExt<T> on Rx<T> {
  Rx<T> get rx => this;
}
