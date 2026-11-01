// [جديد] — الباك اند بيبعت كل تواريخ الأوردر (date/estimatedDelivery/
// deliveredDate/step.timestamp) كـISO 8601 خام (مثلاً
// "2026-08-25T10:30:00.000Z") زي ما هو، والشاشات كانت بتعرضها زي ما هي من
// غير أي تنسيق — يعني العميل شايف حروف وأرقام زي كده بدل تاريخ مفهوم.
//
// معمول helper بسيط من غير أي package خارجي (زي intl) عمدًا: مش متأكدين
// إنه مضاف في pubspec.yaml أصلًا (مش موجود معانا في هيكل المشروع اللي
// اتبعت)، فأأمن حل هو تنسيق يدوي بسيط بـdart:core بس.
class DateFormatter {
  DateFormatter._();

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// بيحوّل ISO string لتاريخ مقروء زي "Aug 25, 2026". لو مقدرش يفهم
  /// الصيغة (نص مش ISO أصلًا)، بيرجّع النص زي ما هو بدل ما يكسر الشاشة.
  static String date(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    final parsed = DateTime.tryParse(isoString);
    if (parsed == null) return isoString;
    final local = parsed.toLocal();
    return '${_months[local.month - 1]} ${local.day}, ${local.year}';
  }

  /// زي [date] بس بيضيف الوقت كمان، مفيدة لخطوات التتبع الزمنية اللي
  /// الوقت بالظبط فيها مهم (مش بس اليوم) — زي "Aug 25, 2026 · 3:45 PM"
  static String dateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    final parsed = DateTime.tryParse(isoString);
    if (parsed == null) return isoString;
    final local = parsed.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final period = local.hour >= 12 ? 'PM' : 'AM';
    final minute = local.minute.toString().padLeft(2, '0');
    return '${_months[local.month - 1]} ${local.day}, ${local.year} · '
        '$hour12:$minute $period';
  }
}
