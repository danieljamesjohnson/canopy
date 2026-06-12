import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/models/completion_log.dart';

class ExportService {
  static Future<void> exportCompletionLog(List<CompletionLog> logs) async {
    final data = logs
        .map(
          (e) => {
            'id': e.id,
            'chunkId': e.chunkId,
            'goalId': e.goalId,
            'commitmentId': e.commitmentId,
            'dateYmd': e.dateYmd,
            'event': e.event.name,
            'recordedAt': e.recordedAt.toIso8601String(),
          },
        )
        .toList();

    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'canopy_export_$timestamp.json';

    if (kIsWeb) {
      // Web: use XFile.fromData with name parameter
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.fromList(utf8.encode(jsonString)),
              name: fileName,
              mimeType: 'application/json',
            ),
          ],
        ),
      );
      return;
    }

    // Mobile/Desktop: write to temp file, share the file path
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(jsonString);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }
}
