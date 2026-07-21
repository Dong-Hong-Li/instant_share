import 'dart:io';

import 'package:file_picker/file_picker.dart';

/// 文件Picker管理器。
class FilePickerManager {
  /// 选择本地文件。
  static Future<List<File>> pickFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.any,
      withData: false,
      withReadStream: false,
    );
    return result?.files.map((file) => File(file.path!)).toList() ?? [];
  }
}
