import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ananya/l10n/app_localizations.dart';

class HelpCardPage extends StatefulWidget {
  const HelpCardPage({super.key});

  @override
  State<HelpCardPage> createState() => _HelpCardPageState();
}

class _HelpCardPageState extends State<HelpCardPage> {
  int _selectedIndex = 2;

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 0:
        // '/userhome' was never a registered route, so this threw and the
        // tab appeared dead. Pop back to the landing page already underneath
        // rather than building a second copy of it.
        if (Navigator.canPop(context)) {
          Navigator.popUntil(context, (r) => r.isFirst);
        } else {
          Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
        }
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/knowledge-hub');
        break;
      case 2:
        break; // already on Help
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F0E4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F0E4),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF151435)),
        title: Text(
          AppLocalizations.of(context)!.emergency_numbers,
          style: const TextStyle(color: Color(0xFF151435)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          HelpCard(number: '102', text: 'Emergency Ambulance'),
          HelpCard(number: '999', text: 'Police'),
          HelpCard(number: '106', text: 'Women Helpline'),
          HelpCard(number: '108', text: 'Medical Emergency'),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFFF8F0E4),
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFFEA2249),
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: ""),
          BottomNavigationBarItem(icon: Icon(Icons.language), label: ""),
          BottomNavigationBarItem(icon: Icon(Icons.help_outline), label: ""),
        ],
      ),
    );
  }
}

class HelpCard extends StatelessWidget {
  final String number, text;
  const HelpCard({required this.number, required this.text, super.key});

  Future<void> _makePhoneCall(String number) async {
    final Uri uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEA2249), // Landing red
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => _makePhoneCall(number),
            child: SizedBox(
              width: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.call, size: 30, color: Colors.white),
                  Text(
                    AppLocalizations.of(context)!.view_numbers,
                    style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(number,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white)),
                const SizedBox(height: 5),
                Text(text,
                    softWrap: true,
                    style: const TextStyle(fontSize: 14, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}