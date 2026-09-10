import 'package:url_launcher/url_launcher.dart';

class WhatsAppService {
  static String? sanitizeNumber(String? number) {
    if (number == null) {
      return null;
    }

    final sanitized = number.replaceAll(RegExp(r'[^0-9]'), '');
    return sanitized.isEmpty ? null : sanitized;
  }

  static Uri? buildWhatsAppUri(String? number, {String? message}) {
    final sanitizedNumber = sanitizeNumber(number);
    if (sanitizedNumber == null) {
      return null;
    }

    final queryParameters = <String, String>{};
    if (message != null && message.trim().isNotEmpty) {
      queryParameters['text'] = message.trim();
    }

    return Uri.https('wa.me', '/$sanitizedNumber', queryParameters.isEmpty ? null : queryParameters);
  }

  static Future<bool> openWhatsApp(String? number, {String? message}) async {
    final uri = buildWhatsAppUri(number, message: message);
    if (uri == null) {
      return false;
    }

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}