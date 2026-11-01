import 'package:uuid/uuid.dart';

const _uuid = Uuid();

String generateIdempotencyKey() {
  return _uuid.v4();
}