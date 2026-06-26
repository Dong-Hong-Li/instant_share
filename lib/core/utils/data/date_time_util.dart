import 'package:intl/intl.dart';

/// 时间相关工具包
class DateTimeUtil {
  /// 获取当前时间字符串，格式：2025-06-16 17:24:00
  static String getNowString() {
    final now = DateTime.now();
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
  }

  /// 获取当前时间，格式为自定义
  static String getFormattedNow({String pattern = 'yyyy-MM-dd HH:mm:ss'}) {
    final now = DateTime.now();
    return DateFormat(pattern).format(now);
  }

  /// 传入时间Duration，格式为自定义
  /// 返回格式为 12:34:56
  static String getFormattedDuration(
    Duration duration, {
    String pattern = 'HH:mm:ss',
  }) {
    return DateFormat(pattern).format(
      DateTime(
        0,
        0,
        0,
        duration.inHours,
        duration.inMinutes % 60,
        duration.inSeconds % 60,
      ),
    );
  }

  /// 获取创建时间距离今天凌晨相差几天
  static int getCreateTimeDay(int createTime) {
    // 今天凌晨
    DateTime todayMidnight = DateTime.now();
    todayMidnight = DateTime(
      todayMidnight.year,
      todayMidnight.month,
      todayMidnight.day,
    );

    DateTime createDateTime = DateTime.fromMillisecondsSinceEpoch(createTime);

    return todayMidnight.difference(createDateTime).inDays;
  }

  /// 将时间戳转为字符串格式
  static String formatTimestamp(
    int timestamp, {
    String pattern = 'yyyy-MM-dd HH:mm:ss',
  }) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat(pattern).format(dt);
  }

  /// 毫秒级时间戳转 DateTime
  static DateTime fromMillisecondsSinceEpoch(int milliseconds) {
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }

  /// 将字符串时间转 DateTime
  static DateTime parse(String time, {String pattern = 'yyyy-MM-dd HH:mm:ss'}) {
    return DateFormat(pattern).parse(time);
  }

  /// 格式化时间（按日历天）：可选带时分。
  /// [includeTime] true：今天·HH:mm、昨天·HH:mm、n天前·HH:mm、M月d日·HH:mm；
  /// false：今天、昨天、n天前、n周前、n个月前、n年前。
  static String formatTime(DateTime d, {bool includeTime = true}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final t = DateTime(d.year, d.month, d.day);
    final diff = today.difference(t).inDays;
    final timePart =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final suffix = includeTime ? ' · $timePart' : '';
    if (diff == 0) return '今天$suffix';
    if (diff == 1) return '昨天$suffix';
    if (diff < 7) return '$diff天前$suffix';
    if (includeTime) return '${d.month}月${d.day}日 · $timePart';
    if (diff < 30) return '${(diff / 7).floor()}周前';
    if (diff < 365) return '${(diff / 30).floor()}个月前';
    return '${(diff / 365).floor()}年前';
  }

  /// 从字符串解析后格式化（无效或空返回 ''）
  static String formatTimeFromString(
    String? timeStr, {
    bool includeTime = true,
  }) {
    if (timeStr == null || timeStr.isEmpty) return '';
    final d = DateTime.tryParse(timeStr);
    if (d == null) return timeStr;
    return formatTime(d, includeTime: includeTime);
  }

  /// 相对“当前时刻”的时间差展示：刚刚、n分钟前、n小时前、n天前
  static String formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    final minutes = diff.inMinutes;
    if (minutes < 1) return '刚刚';
    if (minutes < 60) return '$minutes 分钟前';
    final hours = diff.inHours;
    if (hours < 24) return '$hours 小时前';
    return '${diff.inDays} 天前';
  }

  // /// 获取“刚刚”、“5分钟前”等聊天时间显示样式
  // static String getChatTimeText(int timestamp) {
  //   final now = DateTime.now();
  //   final diff = now.difference(DateTime.fromMillisecondsSinceEpoch(timestamp));

  //   //'刚刚'
  //   if (diff.inSeconds < 60) return CommonModule.justNow.tKey.tr;
  //   //'X分钟前'
  //   if (diff.inMinutes < 60) {
  //     return '${diff.inMinutes}${CommonModule.minuteAgo.tKey.tr}';
  //   }
  //   //'X小时前'
  //   if (diff.inHours < 24) {
  //     return '${diff.inHours}${CommonModule.hourAgo.tKey.tr}';
  //   }
  //   //'X天前'
  //   if (diff.inDays < 7) return '${diff.inDays}${CommonModule.dayAgo.tKey.tr}';
  //   return DateFormat(
  //     'yyyy/MM/dd',
  //   ).format(DateTime.fromMillisecondsSinceEpoch(timestamp));
  // }

  /// 补零
  static String zeroFill(int i) {
    return i >= 10 ? "$i" : "0$i";
  }

  // 格式化时间 格式为 比如 600s = 10:00
  static String second2MS(int sec, {bool isEasy = true}) {
    String hms = "00:00";
    if (sec > 0) {
      int m = sec ~/ 60;
      int s = sec % 60;
      hms = "${zeroFill(m)}:${zeroFill(s)}";
    }
    return hms;
  }

  /// 秒转时分秒
  static String second2HMS(int sec, {bool isEasy = true}) {
    String hms = "00:00:00";
    if (!isEasy) hms = "00时00分00秒";
    if (sec > 0) {
      int h = sec ~/ 3600;
      int m = (sec % 3600) ~/ 60;
      int s = sec % 60;
      hms = "${zeroFill(h)}:${zeroFill(m)}:${zeroFill(s)}";
      if (!isEasy) hms = "${zeroFill(h)}时${zeroFill(m)}分${zeroFill(s)}秒";
    }
    return hms;
  }

  /// 秒转天时分秒
  static String second2DHMS(int sec) {
    String hms = "00天00时00分00秒";
    if (sec > 0) {
      int d = sec ~/ 86400;
      int h = (sec % 86400) ~/ 3600;
      int m = (sec % 3600) ~/ 60;
      int s = sec % 60;
      hms = "${zeroFill(d)}天${zeroFill(h)}时${zeroFill(m)}分${zeroFill(s)}秒";
    }
    return hms;
  }

  /// 秒转天时分秒
  /// 补零列表长度4，0-日(00) 1-时(00) 2-分(00) 3-秒(00)
  static List<String> second2ListStr(int sec) {
    List<String> list = List.filled(4, "00");
    if (sec > 0) {
      list[0] = zeroFill(sec ~/ 86400); //日
      list[1] = zeroFill((sec % 86400) ~/ 3600); //时
      list[2] = zeroFill((sec % 3600) ~/ 60); //分
      list[3] = zeroFill(sec % 60); //秒
    }
    return list;
  }

  /// 秒转天时分秒
  /// 列表长度4，0-日 1-时 2-分 3-秒
  static List<int> second2List(int sec) {
    List<int> list = List.filled(4, 0);
    if (sec > 0) {
      list[0] = sec ~/ 86400; //日
      list[1] = (sec % 86400) ~/ 3600; //时
      list[2] = (sec % 3600) ~/ 60; //分
      list[3] = sec % 60; //秒
    }
    return list;
  }

  /// 判断两个时间,前者是否大于后者
  static bool isAfter({required DateTime end, DateTime? start}) {
    final DateTime start0 = start ?? DateTime.now();
    return start0.isAfter(end);
  }

  /// 将 yyyy-MM-dd-HH-mm 格式的字符串转换为 ISO 8601 格式
  /// @param dateTimeStr 格式：yyyy-MM-dd-HH-mm，例如：2025-01-26-14-30
  /// @return ISO 8601 格式字符串，例如：2025-01-26T14:30:00Z，如果转换失败返回 null
  static String? ymdHToIso8601(String dateTimeStr) {
    try {
      // 解析 yyyy-MM-dd-HH-mm 格式（支持4部分或5部分，兼容旧格式）
      final parts = dateTimeStr.split('-');
      if (parts.length < 4 || parts.length > 5) {
        return null;
      }

      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      final hour = int.parse(parts[3]);
      final minute = parts.length == 5 ? int.parse(parts[4]) : 0;

      // 格式化为 ISO 8601 格式：yyyy-MM-ddTHH:mm:ssZ
      return '${year.toString().padLeft(4, '0')}-'
          '${month.toString().padLeft(2, '0')}-'
          '${day.toString().padLeft(2, '0')}T'
          '${hour.toString().padLeft(2, '0')}:'
          '${minute.toString().padLeft(2, '0')}:00Z';
    } catch (e) {
      return null;
    }
  }
}
