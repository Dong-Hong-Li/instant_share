import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:instant_share/core/ui/widget/cross_dissolve/cross_fade.dart';
import 'package:instant_share/core/ui/widget/cross_dissolve/expand_able_controller.dart';
import 'package:instant_share/features/home/widget/home_share_page_shell.dart';
import 'package:instant_share/features/setting/data/setting_port_messages.dart';
import 'package:instant_share/features/setting/provider/setting_provide.dart';
import 'package:instant_share/resource/color/color_value.dart';
import 'package:instant_share/resource/color/home_palette.dart';
import 'package:instant_share/resource/screen_utils/font_size.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_h.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_s.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_w.dart';

/// 自定义端口被占用时的引导对话框；返回 true 表示前往设置。
Future<bool> showSharePortOccupiedDialog(BuildContext context) async {
  /// result。
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('端口已被占用'),
        content: const Text('当前自定义端口不可用，请前往设置修改端口。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('去设置'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// 设置页：自定义端口开关 + 输入 + 空闲检测。
class SettingPortSection extends ConsumerStatefulWidget {
  const SettingPortSection({
    super.key,
    required this.colorValue,
    required this.isSharing,
  });

  /// 颜色配置。
  final ColorValue colorValue;

  /// 是否正在分享。
  final bool isSharing;

  /// 创建状态对象。
  @override
  ConsumerState<SettingPortSection> createState() => _SettingPortSectionState();
}

class _SettingPortSectionState extends ConsumerState<SettingPortSection> {
  late final ExpandAbleController _expandController;

  late final TextEditingController _textController;

  late final FocusNode _portFocusNode;
  int _lastFocusTick = 0;
  bool _syncingText = false;

  /// 初始化状态。
  @override
  void initState() {
    super.initState();
    final provider = ref.read(settingProvider);
    _expandController = ExpandAbleController(
      initialExpanded: provider.expanded,
    );
    _textController = TextEditingController(text: provider.draftPortText);
    _textController.addListener(_onTextChanged);
    _portFocusNode = FocusNode();
    _portFocusNode.addListener(_onFocusChanged);
    _lastFocusTick = provider.focusTick;
  }

  /// 释放资源。
  @override
  void dispose() {
    _portFocusNode.removeListener(_onFocusChanged);
    _textController.removeListener(_onTextChanged);
    _expandController.dispose();
    _textController.dispose();
    _portFocusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_syncingText) return;
    ref.read(settingProvider).onDraftChanged(_textController.text);
  }

  void _onFocusChanged() {
    ref.read(settingProvider).setPortFieldFocused(_portFocusNode.hasFocus);
  }

  void _applyProviderToControls(SettingProvider provider) {
    if (_expandController.isExpanded != provider.expanded) {
      _expandController.isExpanded = provider.expanded;
    }
    if (!_portFocusNode.hasFocus &&
        _textController.text != provider.draftPortText) {
      _syncingText = true;
      _textController.text = provider.draftPortText;
      _syncingText = false;
    }
    if (provider.focusTick != _lastFocusTick) {
      _lastFocusTick = provider.focusTick;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _portFocusNode.requestFocus();
      });
    }
  }

  void _showApplyResult(SettingPortApplyResult result) {
    switch (result) {
      case SettingPortApplyResult.rebindOk:
        showHomeShareSnackBar(context, SettingPortMessages.portApplied);
      case SettingPortApplyResult.rebindFailed:
        showHomeShareSnackBar(context, SettingPortMessages.rebindFailed);
      case SettingPortApplyResult.noop:
      case SettingPortApplyResult.saved:
        break;
    }
  }

  Future<void> _onToggle(bool enabled) async {
    final result = await ref
        .read(settingProvider)
        .onToggle(enabled: enabled, isSharing: widget.isSharing);
    if (!mounted) return;
    _showApplyResult(result);
  }

  Future<void> _onSave() async {
    final result = await ref
        .read(settingProvider)
        .savePort(isSharing: widget.isSharing);
    if (!mounted) return;
    _showApplyResult(result);
  }

  Future<void> _onCheck() async {
    await ref.read(settingProvider).checkPort(isSharing: widget.isSharing);
  }

  /// 构建界面。
  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(settingProvider);
    ref.listen<SettingProvider>(settingProvider, (previous, next) {
      _applyProviderToControls(next);
    });

    final c = widget.colorValue;
    final titleColor = c.homeTitleColor;
    final surface = c.homeUploadButtonFill;
    final ink = c.homeUploadIconColor;
    final muted = ink.withValues(alpha: 0.55);
    final softFill = ink.withValues(alpha: 0.08);
    final softBorder = ink.withValues(alpha: 0.12);
    final enabled = provider.isEnabled(widget.isSharing);
    final expanded = provider.expanded;

    return ExpandAbleInherited(
      notifier: _expandController,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: w24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '设置',
              style: TextStyle(
                fontSize: f18,
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
            ),
            SizedBox(height: h20),
            DecoratedBox(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(s16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: s16,
                    offset: Offset(0, h4),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(w16, h14, w16, h16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '自定义端口',
                            style: TextStyle(
                              fontSize: f15,
                              fontWeight: FontWeight.w600,
                              color: ink,
                            ),
                          ),
                        ),
                        Switch.adaptive(
                          value: expanded,
                          onChanged: enabled ? _onToggle : null,
                          activeTrackColor:
                              HomePalette.switchOnGradient.colors.last,
                          activeThumbColor: HomePalette.switchIconOn,
                          inactiveTrackColor: HomePalette
                              .switchOffGradient
                              .colors
                              .last
                              .withValues(alpha: 0.55),
                          inactiveThumbColor: HomePalette.switchIconOff,
                        ),
                      ],
                    ),
                    SizedBox(height: h6),
                    Text(
                      SettingPortMessages.subtitle,
                      style: TextStyle(
                        fontSize: f12,
                        height: 1.4,
                        color: muted,
                      ),
                    ),
                    CrossFade(
                      collapsed: const SizedBox.shrink(),
                      expanded: Padding(
                        padding: EdgeInsets.only(top: h14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _textController,
                                    focusNode: _portFocusNode,
                                    enabled: enabled,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(5),
                                    ],
                                    style: TextStyle(
                                      fontSize: f14,
                                      fontWeight: FontWeight.w500,
                                      color: ink,
                                    ),
                                    cursorColor: ink,
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: softFill,
                                      isDense: true,
                                      labelText: '端口',
                                      hintText:
                                          SettingPortMessages.portRangeHint,
                                      labelStyle: TextStyle(
                                        fontSize: f13,
                                        color: muted,
                                      ),
                                      hintStyle: TextStyle(
                                        fontSize: f13,
                                        color: muted,
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: w14,
                                        vertical: h12,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          s12,
                                        ),
                                        borderSide: BorderSide(
                                          color: softBorder,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          s12,
                                        ),
                                        borderSide: BorderSide(
                                          color: ink.withValues(alpha: 0.45),
                                          width: 1.4,
                                        ),
                                      ),
                                      disabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          s12,
                                        ),
                                        borderSide: BorderSide(
                                          color: softBorder,
                                        ),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          s12,
                                        ),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFD97A6C),
                                        ),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          s12,
                                        ),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFD97A6C),
                                          width: 1.4,
                                        ),
                                      ),
                                    ),
                                    onSubmitted: (_) => _onSave(),
                                    onEditingComplete: _onSave,
                                  ),
                                ),
                                SizedBox(width: w10),
                                Padding(
                                  padding: EdgeInsets.only(top: h2),
                                  child: _PortActionChip(
                                    label: provider.checking
                                        ? SettingPortMessages.checking
                                        : SettingPortMessages.check,
                                    enabled: enabled && !provider.checking,
                                    ink: ink,
                                    softFill: softFill,
                                    onTap: _onCheck,
                                  ),
                                ),
                              ],
                            ),
                            if (provider.fieldError != null) ...[
                              SizedBox(height: h8),
                              Text(
                                provider.fieldError!,
                                style: TextStyle(
                                  fontSize: f12,
                                  height: 1.35,
                                  color: const Color(0xFFB85A4E),
                                ),
                              ),
                            ],
                            if (provider.checkMessage != null) ...[
                              SizedBox(height: h8),
                              Text(
                                provider.checkMessage!,
                                style: TextStyle(
                                  fontSize: f12,
                                  height: 1.35,
                                  color: provider.checkOk
                                      ? const Color(0xFF2F9E55)
                                      : const Color(0xFFB85A4E),
                                ),
                              ),
                            ],
                            if (provider.isDirty) ...[
                              SizedBox(height: h12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: _PortActionChip(
                                  label: SettingPortMessages.save,
                                  enabled: enabled,
                                  ink: ink,
                                  softFill: softFill,
                                  emphasized: true,
                                  onTap: _onSave,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (widget.isSharing) ...[
                      SizedBox(height: h12),
                      Text(
                        SettingPortMessages.sharingLocked,
                        style: TextStyle(fontSize: f12, color: muted),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortActionChip extends StatelessWidget {
  const _PortActionChip({
    required this.label,
    required this.enabled,
    required this.ink,
    required this.softFill,
    required this.onTap,
    this.emphasized = false,
  });

  /// label。
  final String label;

  /// 是否启用。
  final bool enabled;

  /// ink。
  final Color ink;

  /// softFill。
  final Color softFill;

  /// 点击回调。
  final VoidCallback onTap;

  /// emphasized。
  final bool emphasized;

  /// 构建界面。
  @override
  Widget build(BuildContext context) {
    final fg = enabled ? ink : ink.withValues(alpha: 0.35);
    return Material(
      color: emphasized ? softFill : Colors.transparent,
      borderRadius: BorderRadius.circular(s12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(s12),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: w14, vertical: h10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: f13,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}
