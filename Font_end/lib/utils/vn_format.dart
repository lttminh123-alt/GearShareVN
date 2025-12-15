import 'package:intl/intl.dart';

class VnFormat {
  static final NumberFormat currency = NumberFormat.decimalPattern('vi_VN');

  /// Format số → 100.000
  static String format(dynamic number) {
    if (number == null) return "";
    return currency.format(int.tryParse(number.toString()) ?? 0);
  }

  /// "100.000" → 100000
  static int parse(String text) {
    if (text.isEmpty) return 0;
    return int.parse(text.replaceAll('.', ''));
  }
}
