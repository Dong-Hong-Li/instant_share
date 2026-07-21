import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:instant_share/resource/color/color_value.dart';
import 'package:instant_share/resource/screen_utils/font_size.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_h.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_s.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_w.dart';

/// 连接对方设备：输入局域网 IP（可选端口）。
Future<String?> showConnectPeerDialog(
  BuildContext context, {
  required ColorValue colorValue,
}) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (context) => _ConnectPeerDialog(colorValue: colorValue),
  );
}

class _ConnectPeerDialog extends StatefulWidget {
  const _ConnectPeerDialog({required this.colorValue});

  final ColorValue colorValue;

  @override
  State<_ConnectPeerDialog> createState() => _ConnectPeerDialogState();
}

class _ConnectPeerDialogState extends State<_ConnectPeerDialog> {
  static const _ink = Color(0xFF4A5260);

  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: widget.colorValue.homeUploadButtonFill,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: w40, vertical: h24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(s16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: w320),
        child: Padding(
          padding: EdgeInsets.fromLTRB(w24, h24, w24, h20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '连接对方设备',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: f16,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
              SizedBox(height: h20),
              TextField(
                controller: _controller,
                autofocus: true,
                style: TextStyle(fontSize: f15, color: _ink, height: 1.3),
                cursorColor: _ink,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.:]')),
                ],
                decoration: InputDecoration(
                  hintText: '192.168.1.10:8080',
                  hintStyle: TextStyle(
                    fontSize: f14,
                    color: _ink.withValues(alpha: 0.35),
                  ),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: w14,
                    vertical: h14,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF2F4F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(s12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(s12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(s12),
                    borderSide: BorderSide(
                      color: _ink.withValues(alpha: 0.25),
                    ),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              SizedBox(height: h24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: h40,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: _ink.withValues(alpha: 0.65),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(s12),
                          ),
                        ),
                        child: Text('取消', style: TextStyle(fontSize: f14)),
                      ),
                    ),
                  ),
                  SizedBox(width: w10),
                  Expanded(
                    child: SizedBox(
                      height: h40,
                      child: FilledButton(
                        onPressed: _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: _ink,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(s12),
                          ),
                        ),
                        child: Text(
                          '连接',
                          style: TextStyle(
                            fontSize: f14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }
}
