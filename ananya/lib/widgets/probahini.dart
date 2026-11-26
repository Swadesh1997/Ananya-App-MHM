import 'package:ananya/widgets/dotted_container.dart';
import 'package:ananya/widgets/web-view-screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:ananya/l10n/app_localizations.dart';

class Probahini extends StatefulWidget {
  final bool autoStartChat;

  const Probahini({
    super.key,
    this.autoStartChat = false,
  });

  @override
  State<Probahini> createState() => _ProbahiniState();
}

class _ProbahiniState extends State<Probahini> {
  void _navigateToWebView() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WebViewScreen(),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    if (widget.autoStartChat) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToWebView();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.5,
      child: Column(
        children: [
          const DottedContainer(),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: SvgPicture.asset(
                    'assets/images/Anannya Anim 1.svg',
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  left: MediaQuery.of(context).size.width * 0.08,
                  top: MediaQuery.of(context).size.height * 0.07,
                  child: Text(
                    AppLocalizations.of(context)!
                        .hi_i_am_probahini_your_menstrual_companion_ask_me_anything,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                Positioned(
                  bottom: MediaQuery.of(context).size.height * 0.035,
                  left: MediaQuery.of(context).size.width * 0.035,
                  child: ElevatedButton(
                    onPressed: _navigateToWebView,
                    child: Text(
                      AppLocalizations.of(context)!.chat,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
