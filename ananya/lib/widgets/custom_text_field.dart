import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ananya/l10n/app_localizations.dart';
import 'package:ananya/utils/constants.dart';
import 'package:ananya/widgets/form_field_shell.dart';

class CustomTextField extends StatefulWidget {
  final String text;
  final TextEditingController controller;

  final bool readOnly;
  final VoidCallback? onTap;
  final TextInputType? keyboardType;
  final bool? obscureText;

  /// Leading icon. Optional so existing call sites keep working; the sign-in
  /// and sign-up forms pass one for every field.
  final IconData? icon;

  /// Quiet line under the field, e.g. the password rule.
  final String? helperText;

  /// Placeholder shown inside an empty box.
  ///
  /// The dropdowns beside these fields already say 'একটি বেছে নিন', so a form
  /// of blank white rectangles left the label above each one carrying all the
  /// guidance — and a label says what a field is, not what to put in it.
  final String? hintText;

  const CustomTextField({
    super.key,
    required this.text,
    required this.controller,
    this.readOnly = false,
    this.onTap,
    this.keyboardType,
    this.obscureText,
    this.icon,
    this.helperText,
    this.hintText,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscureText = true;
  String? _warningText;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // The border colour depends on focus, so the field has to rebuild when it
    // gains or loses it.
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  bool get _isPasswordField =>
      widget.text.startsWith("Password") ||
      widget.text.startsWith("পাসওয়ার্ড") ||
      widget.text.startsWith("New password") ||
      widget.text.startsWith("নতুন পাসওয়ার্ড");

  bool get _isPhoneField =>
      widget.text == "Phone Number" || widget.text == "মোবাইল নম্বর";

  bool get _isDobField =>
      widget.text == "Date of Birth" || widget.text == "জন্ম তারিখ";

  Future<void> _selectDate(BuildContext context) async {
    DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (selectedDate != null) {
      widget.controller.text = "${selectedDate.toLocal()}".split(' ')[0];
    }
  }

  bool _isValidPhoneNumber(String number) {
    final regex = RegExp(r'^(?:\+8801|01)[3-9]\d{8}$');
    return regex.hasMatch(number);
  }

  /// Falls back to a sensible icon when the caller did not name one, so older
  /// screens gain the same look without being edited.
  IconData? get _icon {
    if (widget.icon != null) return widget.icon;
    if (_isPasswordField) return Icons.lock_outline_rounded;
    if (_isPhoneField) return Icons.phone_iphone_rounded;
    if (_isDobField) return Icons.calendar_today_rounded;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _warningText != null;
    final borderColour = hasError
        ? INCORRECT
        : _focusNode.hasFocus
            ? kFieldFocus
            : kFieldBorder;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(widget.text),
          TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            style: const TextStyle(
              color: ACCENT,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            readOnly: widget.readOnly || _isDobField,
            keyboardType: widget.keyboardType ??
                (_isPhoneField ? TextInputType.phone : TextInputType.text),
            obscureText:
                widget.obscureText ?? (_isPasswordField ? _obscureText : false),
            inputFormatters:
                _isPhoneField ? [FilteringTextInputFormatter.digitsOnly] : null,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              hintText: widget.hintText,
              // Same weight as the dropdowns' placeholder, so an empty field
              // reads as empty rather than as already filled in.
              hintStyle: TextStyle(
                color: kFieldHint,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: _icon == null ? 16 : 4,
                vertical: 17,
              ),
              prefixIcon: _icon == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(left: 14, right: 10),
                      child: Icon(_icon, size: 20, color: kFieldIcon),
                    ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
              border: appFieldBorder(kFieldBorder),
              enabledBorder: appFieldBorder(borderColour),
              focusedBorder: appFieldBorder(borderColour, 1.8),
              errorBorder: appFieldBorder(INCORRECT, 1.6),
              focusedErrorBorder: appFieldBorder(INCORRECT, 1.8),
              suffixIcon: _isPasswordField
                  ? IconButton(
                      icon: Icon(
                        _obscureText
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 20,
                        color: kFieldIcon,
                      ),
                      onPressed: () =>
                          setState(() => _obscureText = !_obscureText),
                    )
                  : null,
            ),
            onTap: () {
              if (widget.onTap != null) {
                widget.onTap!();
              } else if (_isDobField) {
                FocusScope.of(context).unfocus();
                _selectDate(context);
              }
            },
            onChanged: (value) {
              if (_isPasswordField) {
                setState(() {
                  _warningText = value.isNotEmpty && value.length < 6
                      ? AppLocalizations.of(context)!.password_is_too_short
                      : null;
                });
              } else if (_isPhoneField) {
                setState(() {
                  _warningText = value.isEmpty || _isValidPhoneNumber(value)
                      ? null
                      : AppLocalizations.of(context)!
                          .invalid_bangladeshi_phone_number;
                });
              }
            },
          ),
          if (hasError)
            FieldFootnote(_warningText!, isError: true)
          else if (widget.helperText != null)
            FieldFootnote(widget.helperText!),
        ],
      ),
    );
  }
}
