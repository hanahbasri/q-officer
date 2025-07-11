import 'package:intl/intl.dart';

String formatTanggal(dynamic date) {
  if (date is String) {
    try {
      date = DateTime.parse(date);
    } catch (e) {
      return "Invalid Date Format";
    }
  }

  if (date is DateTime) {
    return DateFormat("EEEE, dd MMMM yyyy HH:mm", "id_ID").format(date);
  } else {
    return "Invalid Input";
  }
}