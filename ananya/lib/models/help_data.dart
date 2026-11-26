import 'package:flutter/material.dart';
import 'package:ananya/l10n/app_localizations.dart';

/// Emergency helplines, grouped so the list can be scanned by what is wrong
/// rather than read end to end.
class HelpProvider {
  /// Category keys. 'violence' is flagged urgent and rendered in the brand red.
  static const String medical = 'medical';
  static const String violence = 'violence';
  static const String mental = 'mental';
  static const String sexual = 'sexual';

  static String categoryLabel(String key, bool isBangla) {
    switch (key) {
      case medical:
        return isBangla ? 'চিকিৎসা পরামর্শ' : 'Medical advice';
      case violence:
        return isBangla ? 'নির্যাতন ও নিরাপত্তা' : 'Violence & safety';
      case mental:
        return isBangla ? 'মানসিক স্বাস্থ্য সহায়তা' : 'Mental health support';
      case sexual:
        return isBangla ? 'যৌন স্বাস্থ্য' : 'Sexual health';
    }
    return '';
  }

  static List<Map<String, String>> helpData(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return [
      {
        "category": medical,
        "number": l.help_number_16263,
        "name": l.help_name_16263,
        "description": l.help_description_16263,
        "badge": "24/7",
      },
      {
        "category": violence,
        "number": l.help_number_109,
        "name": l.help_name_109,
        "description": l.help_description_109,
      },
      {
        "category": violence,
        "number": l.help_number_10921,
        "name": l.help_name_10921,
        "description": l.help_description_10921,
      },
      {
        "category": violence,
        "number": l.help_number_333,
        "name": l.help_name_333,
        "description": l.help_description_333,
      },
      {
        "category": mental,
        "number": l.help_number_01779554391_01779554392,
        "name": l.help_name_01779554391_01779554392,
        "description": l.help_description_01779554391_01779554392,
      },
      {
        "category": mental,
        "number": l.help_number_01776632344,
        "name": l.help_name_01776632344,
        "description": l.help_description_01776632344,
      },
      {
        "category": mental,
        "number": l.help_number_09678771511,
        "name": l.help_name_09678771511,
        "description": l.help_description_09678771511,
      },
      {
        "category": sexual,
        "number": l.help_number_09612600600,
        "name": l.help_name_09612600600,
        "description": l.help_description_09612600600,
      },
    ];
  }
}
