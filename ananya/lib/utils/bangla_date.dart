/// Bangla numerals and date names.
///
/// The app never calls initializeDateFormatting(), so intl has no 'bn' locale
/// data and DateFormat('MMMM', 'bn') throws. Rather than falling back to
/// English inside otherwise-Bangla sentences, the names are held here. They are
/// the Gregorian months and weekdays as written in Bangladesh, not the Bangla
/// calendar.
library;

const List<String> _bnDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];

/// Rewrites every Latin digit in [input] as its Bangla equivalent, leaving
/// everything else alone.
String toBanglaDigits(String input) {
  final out = StringBuffer();
  for (final ch in input.split('')) {
    final d = int.tryParse(ch);
    out.write(d == null ? ch : _bnDigits[d]);
  }
  return out.toString();
}

/// A number in the digits of the active language.
String localeNumber(Object value, bool isBangla) =>
    isBangla ? toBanglaDigits('$value') : '$value';

const List<String> _bnMonthsShort = [
  'জানু', 'ফেব্রু', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
  'জুলাই', 'আগস্ট', 'সেপ্টে', 'অক্টো', 'নভে', 'ডিসে',
];

const List<String> _bnMonthsFull = [
  'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
  'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর',
];

const List<String> _enMonthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const List<String> _enMonthsFull = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// Monday-first, matching DateTime.weekday.
const List<String> _bnWeekdaysFull = [
  'সোমবার', 'মঙ্গলবার', 'বুধবার', 'বৃহস্পতিবার', 'শুক্রবার', 'শনিবার', 'রবিবার',
];

const List<String> _enWeekdaysFull = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];

/// Single-letter-ish column headings for a calendar, Monday-first.
const List<String> _bnWeekdayInitials = ['সো', 'ম', 'বু', 'বৃ', 'শু', 'শ', 'র'];
const List<String> _enWeekdayInitials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

String monthShort(DateTime d, bool isBangla) =>
    (isBangla ? _bnMonthsShort : _enMonthsShort)[d.month - 1];

String monthFull(DateTime d, bool isBangla) =>
    (isBangla ? _bnMonthsFull : _enMonthsFull)[d.month - 1];

String weekdayFull(DateTime d, bool isBangla) =>
    (isBangla ? _bnWeekdaysFull : _enWeekdaysFull)[d.weekday - 1];

String weekdayInitial(DateTime d, bool isBangla) =>
    (isBangla ? _bnWeekdayInitials : _enWeekdayInitials)[d.weekday - 1];

/// "১৪ আগস্ট" / "14 Aug".
String dayAndMonthShort(DateTime d, bool isBangla) =>
    '${localeNumber(d.day, isBangla)} ${monthShort(d, isBangla)}';

/// "২ সেপ্টেম্বর" / "2 September".
///
/// For the places with room to spell the month out. The abbreviated form
/// belongs in a dense list, not on a card with one date on it, where "2 Sep"
/// reads as something the app ran out of space to finish.
String dayAndMonthFull(DateTime d, bool isBangla) =>
    '${localeNumber(d.day, isBangla)} ${monthFull(d, isBangla)}';

/// "আগস্ট ২০২৬" / "August 2026".
String monthAndYear(DateTime d, bool isBangla) =>
    '${monthFull(d, isBangla)} ${localeNumber(d.year, isBangla)}';
