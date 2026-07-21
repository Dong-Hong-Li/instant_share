import 'package:uuid/uuid.dart';

/// ID 生成器。
class IdGenerator {
  // 单例对象，立即创建
  static final IdGenerator instance = IdGenerator._();

  IdGenerator._();

  final Uuid _uuid = Uuid();

  /// maxSequence。
  static const int maxSequence = 99999999;

  // ---------------------- UUID 生成 ----------------------

  String generateV4() => _uuid.v4();

  String generateV1() => _uuid.v1();

  String generateV5(String namespace, String name) => _uuid.v5(namespace, name);
}
