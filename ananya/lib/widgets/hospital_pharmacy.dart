import 'package:ananya/utils/custom_theme.dart';
import 'package:flutter/material.dart';
import 'package:ananya/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ananya/utils/app_dialog.dart';

class HospitalPharmacyComponent extends StatefulWidget {
  final bool autoOpenMap;

  const HospitalPharmacyComponent({
    super.key,
    this.autoOpenMap = false,
  });

  @override
  State<HospitalPharmacyComponent> createState() =>
      _HospitalPharmacyComponentState();
}

class _HospitalPharmacyComponentState
    extends State<HospitalPharmacyComponent> {

  Future<void> _launchMap(String query) async {
    final Uri url =
    Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  void _showMapSelectionDialog() {
    final loc = AppLocalizations.of(context);

    showAppDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(loc?.choose_nearby_care ?? "Choose nearby care"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(loc?.select_what_you_are_looking_for ??
                "Select what you are looking for"),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _launchMap("hospitals near me");
              },
              child:
              Text(loc?.nearby_hospital ?? "Nearby Hospital"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _launchMap("pharmacies near me");
              },
              child:
              Text(loc?.nearby_pharmacy ?? "Nearby Pharmacy"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc?.cancel ?? "Cancel"),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    if (widget.autoOpenMap) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showMapSelectionDialog();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: Theme.of(context).insideCardPadding,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(
          Radius.circular(10),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Image.asset(
              'assets/images/hospital_img.png',
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.hospital_and_pharmacy,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  AppLocalizations.of(context)!
                      .find_a_pharmacy_or_hospital_near_you,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _showMapSelectionDialog,
                  child: Text(
                    AppLocalizations.of(context)!.view_map,
                    style: const TextStyle(fontSize: 12),
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