class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

class UnauthorizedException extends ApiException {
  UnauthorizedException([String message = 'Unauthorized access']) : super(message, 401);
}

class ForbiddenException extends ApiException {
  ForbiddenException([String message = 'You do not have permission to access this resource.']) : super(message, 403);
}

class NotFoundException extends ApiException {
  NotFoundException([String message = 'Resource not found']) : super(message, 404);
}

class RateLimitException extends ApiException {
  RateLimitException([String message = 'Too many requests. Please try again later.']) : super(message, 429);
}

class ServerException extends ApiException {
  ServerException([String message = 'Internal server error']) : super(message, 500);
}

class NetworkException extends ApiException {
  NetworkException([String message = 'No internet connection or timeout']) : super(message);
}
