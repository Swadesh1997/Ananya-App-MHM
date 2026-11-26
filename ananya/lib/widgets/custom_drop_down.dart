import 'package:flutter/material.dart';

import 'package:ananya/l10n/app_localizations.dart';
import 'package:ananya/utils/constants.dart';
import 'package:ananya/widgets/form_field_shell.dart';

/// A labelled dropdown.
///
/// The label used to sit inside its own 140px white box to the LEFT of the
/// control, so every row read as two competing fields and long labels wrapped
/// inside a cramped tile. It now sits above the control like every other field
/// on the form, which also gives the dropdown the full width it needs — the
/// district list has 60-odd entries and some names are long.
class CustomDropdown extends StatefulWidget {
  final String header;
  final List<String> options;
  final ValueChanged<String?>? onChanged;

  /// Leading icon, matching the text fields.
  final IconData? icon;

  const CustomDropdown({
    required this.options,
    required this.header,
    this.onChanged,
    this.icon,
    super.key,
  });

  @override
  State<CustomDropdown> createState() => _CustomDropdownState();
}

class _CustomDropdownState extends State<CustomDropdown> {
  String? _selectedValue;

  @override
  Widget build(BuildContext context) {
    final chosen = _selectedValue != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(widget.header),
          DropdownButtonFormField<String>(
            initialValue: _selectedValue,
            isExpanded: true,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(kFieldRadius),
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: kFieldIcon),
            style: const TextStyle(
              color: ACCENT,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: widget.icon == null ? 16 : 4,
                vertical: 17,
              ),
              prefixIcon: widget.icon == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(left: 14, right: 10),
                      child: Icon(widget.icon, size: 20, color: kFieldIcon),
                    ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
              border: appFieldBorder(kFieldBorder),
              enabledBorder: appFieldBorder(kFieldBorder),
              // Brand red on focus, the same signal the text fields give.
              focusedBorder: appFieldBorder(kFieldFocus, 1.8),
            ),
            hint: Text(
              AppLocalizations.of(context)!.choose_a,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: kFieldHint,
              ),
            ),
            items: widget.options.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (newValue) {
              setState(() => _selectedValue = newValue);
              widget.onChanged?.call(newValue);
            },
          ),
          // Nothing is shown once a value is picked; the value itself is the
          // confirmation.
          if (!chosen) const SizedBox.shrink(),
        ],
      ),
    );
  }
}
