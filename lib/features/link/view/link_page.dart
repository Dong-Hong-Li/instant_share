import 'package:flutter/material.dart';
import 'package:instant_share/core/ui/platform_state_factory.dart';
import 'package:instant_share/features/mutual_share/provider/mutual_share_provide.dart';
import 'package:instant_share/infrastructure/websocket/room_ws_models.dart';
import 'package:instant_share/resource/color/color_value.dart';
import 'package:instant_share/resource/screen_utils/font_size.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_h.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_s.dart';
import 'package:instant_share/resource/screen_utils/layout_dimens_w.dart';

part 'link_page_mixin.dart';
part 'link_page_pc.dart';
part 'link_page_app.dart';

/// 链接 Tab：待审批与已连接成员。
class LinkPage extends StatefulWidget {
  const LinkPage({super.key, required this.colorValue, required this.mutual});

  final ColorValue colorValue;
  final MutualShareProvider mutual;

  @override
  // ignore: no_logic_in_create_state
  State<LinkPage> createState() =>
      createPlatformState(pc: _LinkPagePcState.new, app: _LinkPageAppState.new);
}

class _LinkPageContent extends StatelessWidget {
  const _LinkPageContent({required this.colorValue, required this.mutual});

  final ColorValue colorValue;
  final MutualShareProvider mutual;

  @override
  Widget build(BuildContext context) {
    final title = colorValue.homeTitleColor;

    return Padding(
      padding: EdgeInsets.fromLTRB(w24, h24, w24, h24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '连接',
            style: TextStyle(
              fontSize: f20,
              fontWeight: FontWeight.w700,
              color: title,
            ),
          ),
          SizedBox(height: h6),
          Text(
            '审批对方加入共享房间的申请',
            style: TextStyle(
              fontSize: f13,
              color: title.withValues(alpha: 0.72),
            ),
          ),
          SizedBox(height: h22),
          _SectionLabel(color: title, text: '待审批'),
          SizedBox(height: h10),
          if (mutual.pending.isEmpty)
            _EmptyCard(colorValue: colorValue, text: '暂无连接申请')
          else
            for (final item in mutual.pending) ...[
              _PendingTile(colorValue: colorValue, mutual: mutual, item: item),
              SizedBox(height: h10),
            ],
          SizedBox(height: h20),
          _SectionLabel(color: title, text: '已连接'),
          SizedBox(height: h10),
          if (mutual.members.isEmpty)
            _EmptyCard(colorValue: colorValue, text: '暂无已连接设备')
          else
            for (final member in mutual.members) ...[
              _MemberTile(colorValue: colorValue, member: member),
              SizedBox(height: h10),
            ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: f13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: color.withValues(alpha: 0.88),
      ),
    );
  }
}

class _PendingTile extends StatelessWidget {
  const _PendingTile({
    required this.colorValue,
    required this.mutual,
    required this.item,
  });

  final ColorValue colorValue;
  final MutualShareProvider mutual;
  final PendingRequestDto item;

  @override
  Widget build(BuildContext context) {
    final ink = colorValue.homeUploadIconColor;
    final name = item.displayName.isEmpty ? item.deviceId : item.displayName;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorValue.homeUploadButtonFill,
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
        padding: EdgeInsets.fromLTRB(w14, h14, w12, h14),
        child: Row(
          children: [
            Container(
              width: w40,
              height: w40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ink.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(s12),
              ),
              child: Icon(Icons.devices_rounded, size: f20, color: ink),
            ),
            SizedBox(width: w12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: f14,
                      fontWeight: FontWeight.w600,
                      color: ink,
                    ),
                  ),
                  SizedBox(height: h3),
                  Text(
                    item.peerBaseUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: f12,
                      color: ink.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: w8),
            TextButton(
              onPressed: () =>
                  mutual.decidePairing(item.deviceId, approve: false),
              style: TextButton.styleFrom(
                foregroundColor: ink.withValues(alpha: 0.65),
                padding: EdgeInsets.symmetric(horizontal: w10, vertical: h8),
              ),
              child: Text('拒绝', style: TextStyle(fontSize: f13)),
            ),
            FilledButton(
              onPressed: () =>
                  mutual.decidePairing(item.deviceId, approve: true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4A90B8),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: w14, vertical: h8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(s10),
                ),
              ),
              child: Text(
                '同意',
                style: TextStyle(fontSize: f13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.colorValue, required this.member});

  final ColorValue colorValue;
  final RoomMemberDto member;

  @override
  Widget build(BuildContext context) {
    final ink = colorValue.homeUploadIconColor;
    final name =
        member.displayName.isEmpty ? member.deviceId : member.displayName;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorValue.homeUploadButtonFill.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(s16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: s14,
            offset: Offset(0, h3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(w14, h14, w14, h14),
        child: Row(
          children: [
            Container(
              width: w40,
              height: w40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF34B45B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(s12),
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 20,
                color: Color(0xFF2F9E52),
              ),
            ),
            SizedBox(width: w12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: f14,
                      fontWeight: FontWeight.w600,
                      color: ink,
                    ),
                  ),
                  SizedBox(height: h3),
                  Text(
                    member.peerBaseUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: f12,
                      color: ink.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.colorValue, required this.text});

  final ColorValue colorValue;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: w16, vertical: h18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(s14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: f13,
          color: colorValue.homeTitleColor.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
