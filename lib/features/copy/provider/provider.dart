import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

class CopyProvider extends ChangeNotifier {}

final copyProvider = ChangeNotifierProvider<CopyProvider>(
  (ref) => CopyProvider(),
);
