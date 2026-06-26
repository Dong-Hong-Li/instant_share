import 'dart:io';

import 'package:file_picker/file_picker.dart';

class FilePickerManager {
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
