import 'dart:convert';
import 'package:ananya/widgets/app_loader.dart';

import 'package:ananya/utils/api_settings.dart';
import 'package:ananya/utils/constants.dart';
import 'package:ananya/utils/custom_theme.dart';
import 'package:ananya/widgets/history_component.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ananya/l10n/app_localizations.dart';
import 'package:ananya/utils/app_dialog.dart';


class IndividualHistory extends StatefulWidget {
  const IndividualHistory({super.key});

  @override
  State<IndividualHistory> createState() => _IndividualHistoryState();
}

class _IndividualHistoryState extends State<IndividualHistory> {
  final List<String> monthNames = [
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec"
  ];

  bool _isPurgeLoading = false;

  @override
  void initState() {
    super.initState();
  }

  Future<Map<String, List<dynamic>>> getAllHistoryData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString('userId');
      final response =
          await ApiSettings(endPoint: 'user/get-period-history/$id')
              .getMethod();
      if (response.statusCode == 200) {
        List<dynamic> historyData = json.decode(response.body);

        Map<String, List<dynamic>> groupedData = {};
        for (var history in historyData) {
          String year = history['period_start'].split('-')[0];
          if (!groupedData.containsKey(year)) {
            groupedData[year] = [];
          }
          groupedData[year]!.add(history);
        }
        return groupedData;
      }
      return {};
    } catch (e) {
      debugPrint("Error $e");
      return {};
    }
  }

  Future<void> requestDataPurge() async {
    setState(() {
      _isPurgeLoading = true;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('userId');

    http.Response response;
    try {
      response =
          await ApiSettings(endPoint: 'user/request-data-purge/$id').getMethod();
    } catch (e) {
      // There was no catch here at all. A dropped connection — the normal case
      // in the districts this app is built for — threw straight out of the
      // handler, so the spinner below never stopped and the screen hung.
      debugPrint('Purge request failed: $e');
      if (!mounted) return;
      setState(() => _isPurgeLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!.purge_request_failed)),
      );
      return;
    }

    // The request can outlast the screen: she may go back while it is in
    // flight, and this State is then disposed.
    if (!mounted) return;

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(AppLocalizations.of(context)!.purge_request_successful)),
      );
      // '/' is the splash screen, so this replayed the four-second
      // splash and left the finished page on the stack underneath.
      // Go to the landing page and clear what came before it.
      Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
      return; // This screen is gone; there is no spinner left to reset.
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(AppLocalizations.of(context)!.purge_request_failed)),
    );

    setState(() {
      _isPurgeLoading = false;
    });
  }

  void confirmPurge() {
    showAppDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.confirm_purge_title),
          content: Text(AppLocalizations.of(context)!.confirm_purge_message),
          actions: [
            TextButton(
              child: Text(AppLocalizations.of(context)!.discard),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(AppLocalizations.of(context)!.confirm),
              onPressed: () {
                Navigator.of(context).pop();
                requestDataPurge();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.your_period_history),
      ),
      body: Stack(
        children: [
          FutureBuilder<Map<String, List<dynamic>>>(
            future: getAllHistoryData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !_isPurgeLoading) {
                return const AppLoader();
              } else if (snapshot.hasError) {
                return Center(
                    child:
                        Text(AppLocalizations.of(context)!.error_loading_data));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                    child: Text(
                        AppLocalizations.of(context)!.no_history_available));
              } else {
                Map<String, List<dynamic>> groupedData = snapshot.data!;
                return SingleChildScrollView(
                  child: Padding(
                    padding: Theme.of(context).largemainPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: groupedData.entries.map((entry) {
                        String year = entry.key;
                        List<dynamic> historyList = entry.value;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              year,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: ACCENT,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              direction: Axis.horizontal,
                              spacing: 15.0,
                              runSpacing: 15.0,
                              children: historyList.map((history) {
                                int monthNumber = int.parse(
                                    history['period_start'].split('-')[1]);
                                String monthName = monthNames[monthNumber - 1];
                                return HistoryComponent(
                                  month: monthName,
                                  day: history['period_start'].split('-')[2],
                                  monthcycle:
                                      history['days_between_period'].toString(),
                                  anomalies:
                                      history['anomalies'] == 'Regular' ? 1 : 2,
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                );
              }
            },
          ),
          if (_isPurgeLoading)
            // The page cream, not white — a white sheet over a cream screen
            // reads as a panel that has appeared, rather than as the screen
            // waiting.
            const Positioned.fill(
              child: ColoredBox(
                color: BACKGROUND,
                child: AppLoader(),
              ),
            ),
        ],
      ),
      floatingActionButton: Padding(
        padding: Theme.of(context).largemainPadding,
        child: ElevatedButton(
          onPressed: confirmPurge,
          style: ElevatedButton.styleFrom(
            backgroundColor: ACCENT,
            minimumSize: const Size(double.infinity, 50),
            shadowColor: Colors.black,
            side: const BorderSide(width: 1),
          ),
          child: Text(
            AppLocalizations.of(context)!.request_data_purge,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
