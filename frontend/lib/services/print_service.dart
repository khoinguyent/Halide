import 'package:dio/dio.dart';

import 'api_service.dart';

class PrintCreateResult {
  PrintCreateResult({
    required this.id,
    required this.publicToken,
    required this.publicUrl,
    required this.expiresAt,
    required this.emailsSent,
    required this.emailFailed,
  });

  final String id;
  final String publicToken;
  final String publicUrl;
  final DateTime? expiresAt;
  final int emailsSent;
  final int emailFailed;

  factory PrintCreateResult.fromJson(Map<String, dynamic> json) {
    return PrintCreateResult(
      id: '${json['id']}',
      publicToken: '${json['public_token'] ?? ''}',
      publicUrl: '${json['public_url'] ?? ''}',
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse('${json['expires_at']}')
          : null,
      emailsSent: (json['emails_sent'] as num?)?.toInt() ?? 0,
      emailFailed: (json['email_failed'] as num?)?.toInt() ?? 0,
    );
  }
}

class PrintService {
  PrintService({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  Future<PrintCreateResult> createPrint({
    required String imageId,
    required List<String> recipientEmails,
    List<Map<String, dynamic>>? layers,
    String? note,
    String fontStyle = 'hand',
    double fontSize = 22,
    String textColor = '#2c2416',
    String textAlign = 'left',
    double posX = 0.1,
    double posY = 0.15,
    String paperStyle = 'cream',
    int expireDays = 30,
    bool sendEmail = true,
    String? fromName,
    Map<String, dynamic>? qrStamp,
  }) async {
    try {
      final payload = <String, dynamic>{
        'image_id': imageId,
        'paper_style': paperStyle,
        'recipient_emails': recipientEmails,
        'expire_days': expireDays.clamp(1, 30),
        'send_email': sendEmail,
        if (fromName != null && fromName.trim().isNotEmpty) 'from_name': fromName.trim(),
        if (qrStamp != null) 'qr_stamp': qrStamp,
      };
      if (layers != null && layers.isNotEmpty) {
        payload['layers'] = layers;
      } else {
        payload['note'] = note ?? '';
        payload['font_style'] = fontStyle;
        payload['font_size'] = fontSize;
        payload['text_color'] = textColor;
        payload['text_align'] = textAlign;
        payload['pos_x'] = posX;
        payload['pos_y'] = posY;
      }
      final res = await _api.post(
        '/api/v1/prints',
        data: payload,
      );
      return PrintCreateResult.fromJson(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (e) {
      final detail = e.response?.data;
      String msg = 'Failed to send print';
      if (detail is Map && detail['detail'] != null) {
        msg = '${detail['detail']}';
      } else if (e.message != null && e.message!.isNotEmpty) {
        msg = e.message!;
      }
      throw Exception(msg);
    }
  }
}
