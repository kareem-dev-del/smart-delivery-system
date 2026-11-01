import 'dart:io';

class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.cause,
  });

  final String message;
  final int? statusCode;
  final Object? cause;

  bool get isUnauthorized => statusCode == HttpStatus.unauthorized;
  bool get isForbidden => statusCode == HttpStatus.forbidden;
  bool get isNotFound => statusCode == HttpStatus.notFound;
  bool get isConflict => statusCode == HttpStatus.conflict;
  bool get isValidationError => statusCode == HttpStatus.unprocessableEntity;
  bool get isServerError =>
      statusCode != null && statusCode! >= HttpStatus.internalServerError;

  @override
  String toString() => message;
}
