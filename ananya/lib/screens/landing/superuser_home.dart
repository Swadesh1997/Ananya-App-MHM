import 'dart:async';
import 'dart:convert';

import 'package:ananya/services/cycle_snapshot.dart';
import 'package:ananya/utils/api_settings.dart';
import 'package:ananya/utils/constants.dart';
import 'package:ananya/widgets/hospital_pharmacy.dart';
import 'package:ananya/widgets/knowledge_nexus_component.dart';
import 'package:ananya/widgets/period_cycle_information.dart';
import 'package:ananya/widgets/probahini.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ananya/l10n/app_localizations.dart';

import '../help.dart';

class SuperuserHome extends StatefulWidget {
  final Function(int) onselect;
  const SuperuserHome({required this.onselect, super.key});

  @override
  State<SuperuserHome> createState() => _SuperuserHomeState();
}

class _SuperuserHomeState extends State<SuperuserHome> {
  late StreamController<void> _updateStreamController;

  /// Kept so dispose() can stop it. Without this the 5-second poll survived
  /// leaving the screen and ran for the rest of the app session.
  Timer? _pollTimer;
  late SharedPreferences _prefs;

  /// Built once. Written inline as `stream: getCombinedStream()` it produced a
  /// fresh pair of infinite async generators on every rebuild, each restarting
  /// the polling loop and leaving the previous ones running.
  late final Stream<Map<String, dynamic>> _combined;

  @override
  void initState() {
    super.initState();
    _updateStreamController = StreamController<void>.broadcast();
    _initializePreferences();
    _startPolling();
    _combined = getCombinedStream();
  }

  Future<void> _initializePreferences() async {
    _prefs = await SharedPreferences.getInstance();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _updateStreamController.close();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final String? cohortUser = _prefs.getString('cohort-user');
      if (cohortUser != null) {
        _updateStreamController.add(null);
      }
    });
  }

  Stream<Map<String, dynamic>> _fetchData(
      String endpoint, bool superuser) async* {
    while (true) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = superuser
          ? prefs.getString('cohort-user')
          : prefs.getString('userId');

      ApiSettings api = ApiSettings(endPoint: '$endpoint/$id');

      try {
        final response = await api.getMethod();
        if (response.statusCode == 200) {
          yield json.decode(response.body);
        } else {
          yield {};
        }
      } catch (e) {
        yield {};
      }

      await _updateStreamController.stream.first;
    }
  }

  Stream<Map<String, dynamic>> getCombinedStream() {
    return Rx.zip2(
      _fetchData('user/get-prediction-period', true),
      _fetchData('user/get-cohort-user', false),
          (periodData, cohortData) {
        return {
          'periodData': periodData,
          'cohortData': cohortData,
        };
      },
    );
  }

  Widget _imageWithDescription({
    required String image,
    required String title,
    required String description,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Image.asset(image, width: 160),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(description),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFEAAB9),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22)),
                  ),
                  onPressed: onPressed,
                  child: Text(buttonText),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, PRIMARY_COLOR],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),

            Image.asset(
              'assets/home2.jpg',
              width: double.infinity,
              height: 220,
              fit: BoxFit.cover,
            ),

            const SizedBox(height: 30),

            // 🔥 MASTER CALENDAR LOGIC WITH NEW UI
            StreamBuilder<Map<String, dynamic>>(
              stream: _combined,
              builder: (context, snapshot) {
                if (snapshot.hasData &&
                    snapshot.data!['periodData']!.isNotEmpty &&
                    snapshot.data!['cohortData']!.isNotEmpty) {
                  return PeriodCycleInformation(
                    data: snapshot.data!['periodData'],
                    snapshot: CycleSnapshot.fromLegacyMap(
                      Map<String, dynamic>.from(
                          snapshot.data!['periodData'] as Map),
                      today: DateTime.now(),
                    ),
                    cohort: snapshot.data!['cohortData'],
                    issuperuser: true,
                  );
                }

                return _imageWithDescription(
                  image: 'assets/home3.jpg',
                  title: AppLocalizations.of(context)!.track_your_cycle,
                  description:
                  AppLocalizations.of(context)!.calendar_description,
                  buttonText:
                  AppLocalizations.of(context)!.set_your_calendar,
                  onPressed: () async {
                    try {
                      SharedPreferences prefs =
                          await SharedPreferences.getInstance();
                      String? id = prefs.getString('userId');

                      ApiSettings api =
                          ApiSettings(endPoint: 'user/get-user/$id');
                      final response = await api.getMethod();

                      // The call takes up to 15s on a sleeping backend, and
                      // this screen can be gone by the time it answers.
                      if (!context.mounted) return;

                      if (response.statusCode != 200) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(AppLocalizations.of(context)!
                                .you_need_to_log_in_first),
                          ),
                        );
                        return;
                      }

                      Navigator.pushNamed(
                        context,
                        '/choose-user',
                        arguments: false,
                      );
                    } catch (e) {
                      // Nothing caught this before, so on a failed request the
                      // button just did nothing at all.
                      debugPrint('get-user failed: $e');
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            Localizations.localeOf(context).languageCode == 'bn'
                                ? 'সংযোগ করা যায়নি। ইন্টারনেট দেখে আবার চেষ্টা করুন।'
                                : 'Could not connect. Check your internet and '
                                    'try again.',
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            ),

            const SizedBox(height: 36),

            const Probahini(),
            KnowledgeNexusComponent(
              onselect: widget.onselect,
            ),

            const SizedBox(height: 10),
            const HospitalPharmacyComponent(),
            const SizedBox(height: 10),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Help(),
                SizedBox(width: 10),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
