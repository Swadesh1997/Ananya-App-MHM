import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en')
  ];

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get title;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @log_new_period.
  ///
  /// In en, this message translates to:
  /// **'Log new period'**
  String get log_new_period;

  /// No description provided for @add_a_user.
  ///
  /// In en, this message translates to:
  /// **'Add a User'**
  String get add_a_user;

  /// No description provided for @chat_with_ananya.
  ///
  /// In en, this message translates to:
  /// **'Chat with Probahini'**
  String get chat_with_ananya;

  /// No description provided for @knowledge_nexus.
  ///
  /// In en, this message translates to:
  /// **'Knowledge Hub'**
  String get knowledge_nexus;

  /// No description provided for @visit_shop.
  ///
  /// In en, this message translates to:
  /// **'Visit Shop'**
  String get visit_shop;

  /// No description provided for @period_history.
  ///
  /// In en, this message translates to:
  /// **'Period History'**
  String get period_history;

  /// No description provided for @get_help.
  ///
  /// In en, this message translates to:
  /// **'Get Help'**
  String get get_help;

  /// No description provided for @log_out.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get log_out;

  /// No description provided for @log_in.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get log_in;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @welcome_to_ananye.
  ///
  /// In en, this message translates to:
  /// **'Welcome \nto Ananya'**
  String get welcome_to_ananye;

  /// No description provided for @you_need_to_log_in_first.
  ///
  /// In en, this message translates to:
  /// **'You need to log in first.'**
  String get you_need_to_log_in_first;

  /// No description provided for @unlock_period_prediction.
  ///
  /// In en, this message translates to:
  /// **'UNLOCK PERIOD PREDICTION'**
  String get unlock_period_prediction;

  /// No description provided for @want_to_predict_when_your_next_period_will_happen.
  ///
  /// In en, this message translates to:
  /// **'Want to predict when your next period will happen?'**
  String get want_to_predict_when_your_next_period_will_happen;

  /// No description provided for @your_next_cycle_is_on.
  ///
  /// In en, this message translates to:
  /// **'Your next \ncycle is on'**
  String get your_next_cycle_is_on;

  /// No description provided for @check_out_our_curated_fertility_diet.
  ///
  /// In en, this message translates to:
  /// **'Check out our curated fertility diet'**
  String get check_out_our_curated_fertility_diet;

  /// No description provided for @cycle_variations.
  ///
  /// In en, this message translates to:
  /// **'Cycle \nvariations'**
  String get cycle_variations;

  /// No description provided for @unlocked_after_3rd_cycle_logged.
  ///
  /// In en, this message translates to:
  /// **'Unlocked after 3rd cycle logged'**
  String get unlocked_after_3rd_cycle_logged;

  /// No description provided for @average_cycle_interval.
  ///
  /// In en, this message translates to:
  /// **'Average cycle interval'**
  String get average_cycle_interval;

  /// No description provided for @days.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get days;

  /// No description provided for @expected_period.
  ///
  /// In en, this message translates to:
  /// **'Expected period'**
  String get expected_period;

  /// No description provided for @logged_period.
  ///
  /// In en, this message translates to:
  /// **'Logged period'**
  String get logged_period;

  /// No description provided for @cycle_status_regular.
  ///
  /// In en, this message translates to:
  /// **'Regular'**
  String get cycle_status_regular;

  /// No description provided for @cycle_status_irregular.
  ///
  /// In en, this message translates to:
  /// **'Irregular'**
  String get cycle_status_irregular;

  /// No description provided for @not_measured_yet.
  ///
  /// In en, this message translates to:
  /// **'Not measured yet'**
  String get not_measured_yet;

  /// No description provided for @keep_logging_to_learn_pattern.
  ///
  /// In en, this message translates to:
  /// **'Keep logging your periods to understand your cycle pattern.'**
  String get keep_logging_to_learn_pattern;

  /// No description provided for @any_day_now.
  ///
  /// In en, this message translates to:
  /// **'Any day now'**
  String get any_day_now;

  /// No description provided for @logged_dates_in_entry.
  ///
  /// In en, this message translates to:
  /// **'Dates logged for this entry:'**
  String get logged_dates_in_entry;

  /// No description provided for @remove_this_date.
  ///
  /// In en, this message translates to:
  /// **'Remove this date'**
  String get remove_this_date;

  /// No description provided for @cycle_out_of_range.
  ///
  /// In en, this message translates to:
  /// **'Please enter a number between {min} and {max} days.'**
  String cycle_out_of_range(Object min, Object max);

  /// No description provided for @bleed_out_of_range.
  ///
  /// In en, this message translates to:
  /// **'Please enter a number between 1 and {max} days.'**
  String bleed_out_of_range(Object max);

  /// No description provided for @how_long_did_this_period_last.
  ///
  /// In en, this message translates to:
  /// **'How long did this period last?'**
  String get how_long_did_this_period_last;

  /// No description provided for @choose_the_days_you_bled.
  ///
  /// In en, this message translates to:
  /// **'Choose how many days you bled. Most periods last 2 to 7 days.'**
  String get choose_the_days_you_bled;

  /// No description provided for @your_usual_length.
  ///
  /// In en, this message translates to:
  /// **'Your usual'**
  String get your_usual_length;

  /// No description provided for @hi_i_am_probahini_your_menstrual_companion_ask_me_anything.
  ///
  /// In en, this message translates to:
  /// **'Hi, I am Probahini, your menstrual companion. Ask me anything.'**
  String get hi_i_am_probahini_your_menstrual_companion_ask_me_anything;

  /// No description provided for @begin_chat.
  ///
  /// In en, this message translates to:
  /// **'BEGIN CHAT'**
  String get begin_chat;

  /// No description provided for @get_to_know_your_body_better.
  ///
  /// In en, this message translates to:
  /// **'GET TO KNOW YOUR \nBODY BETTER'**
  String get get_to_know_your_body_better;

  /// No description provided for @go_to_nexus.
  ///
  /// In en, this message translates to:
  /// **'Knowledge hub'**
  String get go_to_nexus;

  /// No description provided for @shop.
  ///
  /// In en, this message translates to:
  /// **'SHOP'**
  String get shop;

  /// No description provided for @for_menstrual_health_products.
  ///
  /// In en, this message translates to:
  /// **'FOR MENSTRUAL HEALTH PRODUCTS'**
  String get for_menstrual_health_products;

  /// No description provided for @view_product.
  ///
  /// In en, this message translates to:
  /// **'VIEW PRODUCT'**
  String get view_product;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help number list'**
  String get help;

  /// No description provided for @call_emergency_helpline.
  ///
  /// In en, this message translates to:
  /// **'CALL EMERGENCY HELPLINE'**
  String get call_emergency_helpline;

  /// No description provided for @call_now.
  ///
  /// In en, this message translates to:
  /// **'CALL NOW'**
  String get call_now;

  /// No description provided for @period_in.
  ///
  /// In en, this message translates to:
  /// **'PERIOD IN\n'**
  String get period_in;

  /// No description provided for @prediction_of_next_cycle.
  ///
  /// In en, this message translates to:
  /// **'Prediction of next cycle'**
  String get prediction_of_next_cycle;

  /// No description provided for @menstrual_health_status.
  ///
  /// In en, this message translates to:
  /// **'Menstrual health status'**
  String get menstrual_health_status;

  /// No description provided for @menstruation.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get menstruation;

  /// No description provided for @ovulation.
  ///
  /// In en, this message translates to:
  /// **'Ovulation'**
  String get ovulation;

  /// No description provided for @update_my_cycle_details.
  ///
  /// In en, this message translates to:
  /// **'Update my cycle details'**
  String get update_my_cycle_details;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @login_with_your_mobile_number_and_password.
  ///
  /// In en, this message translates to:
  /// **'Login with your mobile number and password'**
  String get login_with_your_mobile_number_and_password;

  /// No description provided for @dont_have_an_account_create_a_new_account.
  ///
  /// In en, this message translates to:
  /// **'Do not have an account? Create a new account.'**
  String get dont_have_an_account_create_a_new_account;

  /// No description provided for @forget_password_set_a_new_password.
  ///
  /// In en, this message translates to:
  /// **'Forget password? Set a new password.'**
  String get forget_password_set_a_new_password;

  /// No description provided for @phone_number.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phone_number;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @invalid_bangladeshi_phone_number.
  ///
  /// In en, this message translates to:
  /// **'Invalid Bangladeshi phone number'**
  String get invalid_bangladeshi_phone_number;

  /// No description provided for @password_is_too_short.
  ///
  /// In en, this message translates to:
  /// **'Password is too short'**
  String get password_is_too_short;

  /// No description provided for @date_of_birth.
  ///
  /// In en, this message translates to:
  /// **'Year of birth'**
  String get date_of_birth;

  /// No description provided for @create_a_new_account.
  ///
  /// In en, this message translates to:
  /// **'Create a new account'**
  String get create_a_new_account;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @district.
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get district;

  /// No description provided for @project.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get project;

  /// No description provided for @create_new_account.
  ///
  /// In en, this message translates to:
  /// **'Create New Account'**
  String get create_new_account;

  /// No description provided for @already_have_an_account_click_here_for_login.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Click here for login'**
  String get already_have_an_account_click_here_for_login;

  /// No description provided for @choose_a.
  ///
  /// In en, this message translates to:
  /// **'Choose '**
  String get choose_a;

  /// No description provided for @period_start_today.
  ///
  /// In en, this message translates to:
  /// **'period_start_today'**
  String get period_start_today;

  /// No description provided for @your_period_starts_today_please_confirm.
  ///
  /// In en, this message translates to:
  /// **'Your period starts today. Please confirm.'**
  String get your_period_starts_today_please_confirm;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @postpone.
  ///
  /// In en, this message translates to:
  /// **'Postpone'**
  String get postpone;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @cohort_period_history.
  ///
  /// In en, this message translates to:
  /// **'COHORT PERIOD HISTORY'**
  String get cohort_period_history;

  /// No description provided for @request_data_purge.
  ///
  /// In en, this message translates to:
  /// **'Request Data Purge'**
  String get request_data_purge;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @your_period_history.
  ///
  /// In en, this message translates to:
  /// **'YOUR PERIOD HISTORY'**
  String get your_period_history;

  /// No description provided for @purge_request_successful.
  ///
  /// In en, this message translates to:
  /// **'Purge request successful'**
  String get purge_request_successful;

  /// No description provided for @purge_request_failed.
  ///
  /// In en, this message translates to:
  /// **'Purge Request Failed'**
  String get purge_request_failed;

  /// No description provided for @confirm_purge_title.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get confirm_purge_title;

  /// No description provided for @confirm_purge_message.
  ///
  /// In en, this message translates to:
  /// **'Your all the history will be disappeared'**
  String get confirm_purge_message;

  /// No description provided for @user_type.
  ///
  /// In en, this message translates to:
  /// **'User Type'**
  String get user_type;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @dont_know.
  ///
  /// In en, this message translates to:
  /// **'I do not know'**
  String get dont_know;

  /// No description provided for @regular.
  ///
  /// In en, this message translates to:
  /// **'regular'**
  String get regular;

  /// No description provided for @are_your_periods.
  ///
  /// In en, this message translates to:
  /// **'Are your periods '**
  String get are_your_periods;

  /// No description provided for @regular_means_that_the_gap_between_your_periods_is_around_the_same_number_of_days_each_month.
  ///
  /// In en, this message translates to:
  /// **'Regular means that the gap between your periods is around the same number of days each month'**
  String
      get regular_means_that_the_gap_between_your_periods_is_around_the_same_number_of_days_each_month;

  /// No description provided for @what_is_the.
  ///
  /// In en, this message translates to:
  /// **'What is the\n'**
  String get what_is_the;

  /// No description provided for @number_of_days.
  ///
  /// In en, this message translates to:
  /// **'number of days\n'**
  String get number_of_days;

  /// No description provided for @between_your_periods_and.
  ///
  /// In en, this message translates to:
  /// **'between your periods and \n'**
  String get between_your_periods_and;

  /// No description provided for @how_long.
  ///
  /// In en, this message translates to:
  /// **'how long '**
  String get how_long;

  /// No description provided for @does_it_last.
  ///
  /// In en, this message translates to:
  /// **'do they last?'**
  String get does_it_last;

  /// No description provided for @generally_periods_occur_every_21_to_35_days_and_last_2_to_7_days.
  ///
  /// In en, this message translates to:
  /// **'Generally, periods occur every 21 to 35 days and last 2 to 7 days.'**
  String get generally_periods_occur_every_21_to_35_days_and_last_2_to_7_days;

  /// No description provided for @number_of_days_between_period_eg_27_days.
  ///
  /// In en, this message translates to:
  /// **'Number of days between period (e.g. 27 days).'**
  String get number_of_days_between_period_eg_27_days;

  /// No description provided for @length_of_your_period_eg_6_days.
  ///
  /// In en, this message translates to:
  /// **'Length of your period (e.g. 6 days)'**
  String get length_of_your_period_eg_6_days;

  /// No description provided for @log_your_periods_to_get.
  ///
  /// In en, this message translates to:
  /// **'Log your periods to get '**
  String get log_your_periods_to_get;

  /// No description provided for @accurate_predictions.
  ///
  /// In en, this message translates to:
  /// **'right predictions'**
  String get accurate_predictions;

  /// No description provided for @logging_your_period_when_it_happens_in_the_ananya_app_will_get_you_accurate_predictions_of_your_next_period_cycle.
  ///
  /// In en, this message translates to:
  /// **'Logging your period when it happens in the Ananya App will get you right predictions of your next period cycle.'**
  String
      get logging_your_period_when_it_happens_in_the_ananya_app_will_get_you_accurate_predictions_of_your_next_period_cycle;

  /// No description provided for @when_did_your.
  ///
  /// In en, this message translates to:
  /// **'When did your \n'**
  String get when_did_your;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @last_period.
  ///
  /// In en, this message translates to:
  /// **'last period '**
  String get last_period;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'start?'**
  String get start;

  /// No description provided for @do_you_take.
  ///
  /// In en, this message translates to:
  /// **'Do you take \n'**
  String get do_you_take;

  /// No description provided for @birth_control.
  ///
  /// In en, this message translates to:
  /// **'birth control '**
  String get birth_control;

  /// No description provided for @measures.
  ///
  /// In en, this message translates to:
  /// **'measures?'**
  String get measures;

  /// No description provided for @we_are_asking_because_some_type_of_birth_control_measures_can_potentially_impact_your_menstrual_cycle.
  ///
  /// In en, this message translates to:
  /// **'We are asking because some type of birth control measures can potentially affect your menstrual cycle.'**
  String
      get we_are_asking_because_some_type_of_birth_control_measures_can_potentially_impact_your_menstrual_cycle;

  /// No description provided for @do_you_have_any_of_these.
  ///
  /// In en, this message translates to:
  /// **'Do you have any of these '**
  String get do_you_have_any_of_these;

  /// No description provided for @health_conditions.
  ///
  /// In en, this message translates to:
  /// **'health conditions'**
  String get health_conditions;

  /// No description provided for @choose_all_that_apply.
  ///
  /// In en, this message translates to:
  /// **'Choose all that apply.'**
  String get choose_all_that_apply;

  /// No description provided for @yeast_infection.
  ///
  /// In en, this message translates to:
  /// **'Yeast infection'**
  String get yeast_infection;

  /// No description provided for @urinary_track_infections.
  ///
  /// In en, this message translates to:
  /// **'Urinary tract infections'**
  String get urinary_track_infections;

  /// No description provided for @bacterial_vaginosis.
  ///
  /// In en, this message translates to:
  /// **'Bacterial Vaginosis'**
  String get bacterial_vaginosis;

  /// No description provided for @polycystic_ovary_syndrome.
  ///
  /// In en, this message translates to:
  /// **'Polycystic Ovary Syndrome'**
  String get polycystic_ovary_syndrome;

  /// No description provided for @endometriosis.
  ///
  /// In en, this message translates to:
  /// **'Endometriosis'**
  String get endometriosis;

  /// No description provided for @fibroids.
  ///
  /// In en, this message translates to:
  /// **'Fibroids'**
  String get fibroids;

  /// No description provided for @i_m_not_sure.
  ///
  /// In en, this message translates to:
  /// **'I’m not sure'**
  String get i_m_not_sure;

  /// No description provided for @no_health_issues.
  ///
  /// In en, this message translates to:
  /// **'No health issues'**
  String get no_health_issues;

  /// No description provided for @i_dont_know.
  ///
  /// In en, this message translates to:
  /// **'I do not know'**
  String get i_dont_know;

  /// No description provided for @continues.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continues;

  /// No description provided for @question_1.
  ///
  /// In en, this message translates to:
  /// **'What is menstruation?'**
  String get question_1;

  /// No description provided for @first_description_1.
  ///
  /// In en, this message translates to:
  /// **'Menstruation is a natural biological process experienced by millions of women worldwide. Despite how common it is, significant stigma and misinformation regarding menstrual health still exist. This guide covers the essentials of menstrual hygiene and offers practical tips for maintaining healthy habits.'**
  String get first_description_1;

  /// No description provided for @second_description_1.
  ///
  /// In en, this message translates to:
  /// **'Menstrual hygiene refers to the specific steps taken to stay clean and healthy during your period. This includes using reliable products – such as pads, tampons, menstrual cups, or period panties – and keeping the genital area clean and dry. Practising good hygiene is essential to prevent infections, reduce discomfort, and promote your overall well-being.'**
  String get second_description_1;

  /// No description provided for @third_description_1.
  ///
  /// In en, this message translates to:
  /// **'Menstruation usually begins during puberty, a time of major physical and hormonal shifts. While it typically starts between the ages of 10 and 16, every individual is different. This first period is known as menarche. Remember, every body develops at its own pace; if you haven’t started yet, there is no need to worry, it will happen when your body is ready.\n \nMenstruation eventually stops at menopause, which usually occurs in a woman’s late 40s or early 50s, marking the end of the reproductive years. During this time, the ovaries stop releasing eggs and hormone levels shift. The transition period leading up to this is called perimenopause, which often involves irregular periods or changes in your cycle\'s intensity.\n \nMenstruation is a normal, healthy sign that your body is functioning properly and preparing for potential pregnancy. By speaking openly about it, we can break down taboos and create a supportive environment where everyone feels empowered to manage their menstrual health with dignity.'**
  String get third_description_1;

  /// No description provided for @question_2.
  ///
  /// In en, this message translates to:
  /// **'What is Menstruation Cycle?'**
  String get question_2;

  /// No description provided for @first_description_2.
  ///
  /// In en, this message translates to:
  /// **'Menstruation plays a vital role in maintaining the reproductive health of girls and women, a process managed through the menstrual cycle. This cycle is defined as the entire period from the first day of one menstruation to the first day of the next. The entire process is regulated by various hormones. While a standard menstrual cycle is typically 28 days long, this duration can naturally vary from person to person and from month to month.'**
  String get first_description_2;

  /// No description provided for @second_description_2.
  ///
  /// In en, this message translates to:
  /// **'Now we know that the menstrual cycle plays an important role in a girls healthy reproductive health, but now we dont see how it happens.'**
  String get second_description_2;

  /// No description provided for @question_3.
  ///
  /// In en, this message translates to:
  /// **'Learn about the common symptoms of Menstruation'**
  String get question_3;

  /// No description provided for @first_description_3.
  ///
  /// In en, this message translates to:
  /// **'During menstruation, it is common to experience a range of symptoms that vary from person to person. These are caused by natural hormonal changes in the body and are typically no cause for concern. It is important to remember that menstruation is a healthy process, and there is no reason to feel anxious or afraid.'**
  String get first_description_3;

  /// No description provided for @second_description_3.
  ///
  /// In en, this message translates to:
  /// **'Common symptoms include:\n \n•\tAbdominal cramps: Many women experience mild to moderate cramping in the lower abdomen. This occurs as the uterus contracts to shed its lining.\n \n•\tBloating: Hormonal fluctuations can cause water retention, leading to a feeling of fullness or swelling in the abdomen. \n \n•\tBreast tenderness: You may notice sensitivity or tenderness in your breasts, which is another result of shifting hormone levels.\n \n•\tMood swings: Hormones can affect neurotransmitters in the brain, making it common to feel more irritable, emotional, or sensitive during your period.\n \n•\tFatigue: Feeling particularly tired or fatigued is common, as the body’s energy demands increase during this time.\n \n•\tHeadaches: Some individuals may experience headaches or migraines before or during their periods due to changes in hormones and blood flow.\n \nWhile these symptoms can be uncomfortable, they are generally temporary and manageable. Maintaining a healthy lifestyle – including regular exercise, a balanced diet, and stress management – can help relieve many of these discomforts.'**
  String get second_description_3;

  /// No description provided for @third_description_3.
  ///
  /// In en, this message translates to:
  /// **'When to seek advice?\n \nIt is important to note that symptoms vary in intensity for everyone. However, if you experience severe pain, excessively heavy bleeding, or symptoms that significantly disrupt your daily life, it is advisable to seek medical advice. These could be signs of underlying conditions, such as endometriosis or hormonal imbalances, which can be effectively managed with professional medical care.'**
  String get third_description_3;

  /// No description provided for @question_4.
  ///
  /// In en, this message translates to:
  /// **'What are the steps of Menstruation Cycle?'**
  String get question_4;

  /// No description provided for @first_description_4.
  ///
  /// In en, this message translates to:
  /// **'Understanding the menstrual cycle is essential for every teenage girl. It is a natural, recurring process in the reproductive system designed to prepare the body for a potential pregnancy. By learning the different stages and their symptoms, you can track your health more effectively and understand your body’s unique patterns.'**
  String get first_description_4;

  /// No description provided for @second_description_4.
  ///
  /// In en, this message translates to:
  /// **'The four stages of the menstrual Cycle\nThe follicular phase: Following your period, your body enters the follicular phase. Hormones stimulate the growth of follicles in the ovaries, each containing an egg. As the lining of the uterus begins to thicken, you may notice increased energy levels and a general sense of well-being.\nOvulation: This occurs around the midpoint of your cycle. A mature egg is released from the ovary into the fallopian tube. During this time, some girls may experience a mild twinge or slight pain in the lower abdomen.\nThe luteal phase: After ovulation, the body enters the luteal phase. The empty follicle transforms into the ‘corpus luteum’, which produces hormones to prepare the uterus for pregnancy. If fertilisation does not occur, the uterine lining begins to break down.\nMenstruation: The cycle begins with menstruation, commonly known as a period. During this stage, the uterus sheds its lining, resulting in bleeding that typically lasts between 3 and 7 days. Common symptoms during this phase include abdominal cramps, bloating, and fatigue.\n'**
  String get second_description_4;

  /// No description provided for @third_description_4.
  ///
  /// In en, this message translates to:
  /// **'Tracking these stages provides valuable insights into your hormonal health, fertility, and overall well-being. By recognising how each phase impacts your body, you can better prepare for your period and identify when something feels ‘off’.\nRemember, knowledge is power. Understanding your cycle allows you to take control of your menstrual health and seek medical advice with confidence if you ever notice any abnormalities.\n'**
  String get third_description_4;

  /// No description provided for @question_5.
  ///
  /// In en, this message translates to:
  /// **'What is abnormal Menstruation?'**
  String get question_5;

  /// No description provided for @first_description_5.
  ///
  /// In en, this message translates to:
  /// **'Abnormal menstruation refers to any significant deviation from what is considered a regular menstrual cycle. While it is true that every person’s period is unique, certain signs can indicate an underlying issue. For teenage girls, learning to recognise these signs is an essential part of monitoring their health effectively.'**
  String get first_description_5;

  /// No description provided for @second_description_5.
  ///
  /// In en, this message translates to:
  /// **'Signs of abnormal menstruation:\n•\tIrregular periods: Cycles that occur less than 21 days apart or more than 35 days apart are generally considered irregular.\n•\tExcessive bleeding: This refers to heavy or prolonged bleeding, such as needing to change a pad or tampon every hour for several hours in a row.\n•\tAbsent or missed periods: If your period does not occur for three or more consecutive months, it is classified as a missed period.\n•\tSevere menstrual pain: This includes debilitating cramps that interfere with your daily activities and require medication for relief.\n•\tUnusual menstrual flow: This may involve passing large blood clots or, conversely, experiencing an unusually light or scanty flow.\n'**
  String get second_description_5;

  /// No description provided for @third_description_5.
  ///
  /// In en, this message translates to:
  /// **'It is important to stay aware of these signs and track your cycle regularly. If you experience any of these symptoms, we recommend seeking medical advice. Understanding what is abnormal for your body allows you to take charge of your menstrual health, ensuring you receive the appropriate care to maintain your overall well-being.'**
  String get third_description_5;

  /// No description provided for @question_6.
  ///
  /// In en, this message translates to:
  /// **'What are the common misconceptions about menstruation?'**
  String get question_6;

  /// No description provided for @first_description_6.
  ///
  /// In en, this message translates to:
  /// **'First and foremost, it must be noted that our society harbours many misconceptions about menstruation, largely due to a lack of science-based information regarding why it occurs. These myths include:\n1.\tThe belief that menstrual blood is ‘contaminated’ or impure.\n2.\tThe misconception that the body is purging toxins because the blood is inherently ‘dirty’.\n3.\tThe framing of menstruation as a shameful secret that must be hidden from public discourse.\n4.\tThe taboo surrounding menstrual hygiene products, suggesting that cloths or pads must be concealed and never left to dry in open air or sunlight.\n5.\tTraditional restrictions often suggest that during menstruation, individuals should avoid eating fish or meat and refrain from attending school or participating in sports. Furthermore, some beliefs dictate that one should stay indoors throughout the duration of their period – especially after evening – under the superstitious pretence that going out might attract ghosts or malevolent spirits.\nThese myths don\'t just spread shame; they lead to serious health risks by discouraging safe hygiene and restricting your daily freedom.\n'**
  String get first_description_6;

  /// No description provided for @question_7.
  ///
  /// In en, this message translates to:
  /// **'What is PMS or premenstrual syndrome?'**
  String get question_7;

  /// No description provided for @first_description_7.
  ///
  /// In en, this message translates to:
  /// **'As the name suggests, premenstrual syndrome (PMS) occurs in the days leading up to menstruation. PMS is a combination of physical and psychological symptoms, which may include headaches, breast tenderness, fatigue, irritability, bloating, or feelings of anxiety and low mood. It is common for individuals to experience a blend of both physical and emotional changes.\nWhile PMS symptoms can sometimes be disruptive to your daily routine, they are generally not a cause for concern. These symptoms typically resolve on their own once your period begins or concludes.\n'**
  String get first_description_7;

  /// No description provided for @question_8.
  ///
  /// In en, this message translates to:
  /// **'When should a doctor be consulted?'**
  String get question_8;

  /// No description provided for @first_description_8.
  ///
  /// In en, this message translates to:
  /// **'It is a common misconception that menstrual problems should be ignored or kept secret. However, if you notice any signs of an abnormal menstrual cycle, it is important to speak with your parents or a guardian and seek professional medical advice.\nIn addition to the signs of abnormal cycles, you should consult a doctor if you experience any of the following:\n•\tVaginal itching\n•\tCurd-like white discharge\n•\tThick or foul-smelling vaginal discharge\n•\tPersistent or severe abdominal pain\n•\tSymptoms of toxic shock syndrome (TSS): While rare, this is a life-threatening illness caused by specific bacteria and requires immediate medical attention.\nMaintaining good hygiene and using sanitary methods during your period are vital for your long-term reproductive and sexual health. Using unhygienic materials, such as unclean cloths, can cause infections and inflammation. If left untreated, these infections can spread to the upper reproductive organs. For example, inflammation of the fallopian tubes can lead to blockages, which may prevent eggs or sperm from passing through, potentially resulting in future infertility.\nTaking care of your menstrual health today is a key step in protecting your health for the future.\n'**
  String get first_description_8;

  /// No description provided for @question_9.
  ///
  /// In en, this message translates to:
  /// **'What is the recommended diet during menstruation?'**
  String get question_9;

  /// No description provided for @first_description_9.
  ///
  /// In en, this message translates to:
  /// **'During every menstrual cycle, the body loses blood. This loss can be replenished through a proper, nutrient-rich diet. Because blood contains iron, a lack of nutritional support can lead to a monthly iron deficiency in menstruating girls.\nIt is essential to address this through your diet, as iron performs several vital functions in the body that are necessary for healthy growth and development. By choosing the right foods, you can help your body recover and maintain its energy levels throughout your cycle.\n'**
  String get first_description_9;

  /// No description provided for @question_10.
  ///
  /// In en, this message translates to:
  /// **'Why is iron important for girls?'**
  String get question_10;

  /// No description provided for @first_description_10.
  ///
  /// In en, this message translates to:
  /// **'Iron is essential because it helps the body produce haemoglobin, the component in our blood responsible for carrying oxygen to all our organs and tissues. When oxygen levels are insufficient, the energy required to keep the body functioning properly is disrupted.\nThis is why an iron deficiency (often called anaemia) can lead to various symptoms, such as fatigue, headaches, nausea, and heart palpitations. Furthermore, a lack of iron can cause the skin, hair, and nails to become dry and lose their vitality. To prevent this, it is vital to replenish your iron levels by taking iron supplements if recommended or by regularly eating iron-rich, nutritious foods such as leafy green vegetables, nuts, and liver.\n'**
  String get first_description_10;

  /// No description provided for @question_11.
  ///
  /// In en, this message translates to:
  /// **'Necessary hygiene measures during menstruation'**
  String get question_11;

  /// No description provided for @first_description_11.
  ///
  /// In en, this message translates to:
  /// **'Practising good menstrual hygiene is essential for your comfort and long-term health. Following these research-backed steps can help prevent infections, such as urinary tract infections (UTIs) and bacterial vaginosis, while ensuring you feel fresh and confident throughout your cycle.'**
  String get first_description_11;

  /// No description provided for @second_description_11.
  ///
  /// In en, this message translates to:
  /// **'1.\tChange your menstrual products regularly\n•\tDisposable Pads: Change your pad every 4 to 6 hours, regardless of how light your flow is. Leaving a pad on for too long can encourage bacterial growth and cause skin irritation.\n•\tTampons: Change these every 4 to 8 hours. Never wear a single tampon for more than 8 hours, as this increases the risk of Toxic Shock Syndrome (TSS).\n•\tMenstrual cups: Empty and rinse your cup every 4 to 12 hours depending on your flow.\n2.\tWash your hands frequently\nAlways wash your hands with soap and clean water both before and after changing your menstrual product. This prevents you from transferring bacteria from your hands to your genital area and vice-versa.\n3.\tProper cleaning of the genital area\nWash your external genital area (the vulva) at least once or twice a day with plain, warm water.\n•\tAvoid scented products: Do not use scented soaps or ‘feminine hygiene’ sprays. These can disrupt the natural pH balance of your vagina and lead to infections.\n•\tWipe correctly: When using the toilet, always wipe from front to back to prevent bacteria from the anal area from reaching the vagina.\n4.\tCare for reusable materials\nIf you use reusable cloth pads or cloths, they must be cleaned thoroughly to remain safe:\n•\tWash: Use soap and clean water. Research shows that washing with detergent and a disinfectant is the most effective way to remove bacteria.\n•\tDry in sunlight: Always dry your cloths in direct sunlight. The sun\'s UV rays act as a natural disinfectant. Never dry them in damp, unventilated spaces.\n•\tIroning: If possible, iron your dry cloths to kill any remaining microorganisms.\n5.\tSafe disposal\nDispose of used pads and tampons by wrapping them in paper and placing them in a bin. Never flush them down the toilet, as this causes blockages and environmental pollution.\n'**
  String get second_description_11;

  /// No description provided for @third_description_11.
  ///
  /// In en, this message translates to:
  /// **'If you suspect you may be pregnant, it\'s important to confirm it with a pregnancy test and to consult a healthcare provider. They can provide further guidance and prenatal care to ensure a healthy pregnancy.'**
  String get third_description_11;

  /// No description provided for @question_12.
  ///
  /// In en, this message translates to:
  /// **'What are the pillars of menstrual health and menstrual hygiene management?'**
  String get question_12;

  /// No description provided for @first_description_12.
  ///
  /// In en, this message translates to:
  /// **'Menstrual health and hygiene management are built upon four essential pillars that ensure dignity, safety, and health for all:\na) Education and attitude: Gaining accurate, science-based knowledge about menstruation is the first step toward developing healthy hygiene practices and fostering a positive, shame-free attitude.\nb) Access to menstrual materials: It is vital to ensure that affordable and convenient menstrual products are readily available. These include:\n-\tSanitary pads, tampons, and menstrual cups.\n-\tReusable cloth pads or period pants.\n-\tClean, thin cloths (which must be washed thoroughly).\n-\tEssential supplies such as soap, clean water, and appropriate underwear.\nc) Supporting facilities: Access to safe and private spaces is necessary at home and in schools, including:\n-\tClean toilets with a constant supply of soap and water.\n-\tCovered bins for the discreet disposal of used materials.\n-\tPrivate areas specifically designed for girls to change their menstrual products.\n-\tSafe places for washing used menstrual cloths and drying them in direct sunlight.\n-\tProper disposal systems to ensure used products do not pollute the environment.\nd) Institutional policies and planning: Creating a supportive environment through formal measures, such as:\n-\tImplementing period-friendly policies within institutions.\n-\tAllocating dedicated budgets and annual plans for menstrual health.\n-\tEstablishing regular monitoring systems to ensure these policies are carried out effectively.\n'**
  String get first_description_12;

  /// No description provided for @question_13.
  ///
  /// In en, this message translates to:
  /// **'What items are needed during menstruation?'**
  String get question_13;

  /// No description provided for @first_description_13.
  ///
  /// In en, this message translates to:
  /// **'The materials used to manage menstruation can be divided into two main categories: single-use and reusable products.\na) Single-use products\n-\tDisposable pads: These are designed for one-time use and are widely available.\n-\tTampons: These are inserted into the vagina to absorb menstrual blood. They are an excellent option for those who are physically active, such as those involved in sports or dance, as they allow for greater freedom of movement.\nb) Reusable products\n-\tClean, washable cloths: A traditional and sustainable option if managed correctly.\n-\tWashable cloth pads: These function like disposable pads but can be laundered and reused.\n-\tMenstrual cups: These are flexible cups made of medical-grade silicone that collect rather than absorb blood.\n-\tPeriod panties: Specialised underwear designed with built-in absorbent layers.\nEssential facilities for cleanliness\nBeyond menstrual products, the following are required to maintain proper hygiene:\n-\tSupply of clean water: Essential for washing both the body and reusable materials.\n-\tSoap: Necessary for maintaining personal hygiene and cleaning reusable cloths or pads.\n-\tA safe toilet/washroom: A private and secure space for changing and washing.\n-\tA covered bin or basket: For the discreet and hygienic disposal of used pads or cloths.\n'**
  String get first_description_13;

  /// No description provided for @question_14.
  ///
  /// In en, this message translates to:
  /// **'Why is there so much stigma surrounding menstruation?'**
  String get question_14;

  /// No description provided for @first_description_14.
  ///
  /// In en, this message translates to:
  /// **'Misconceptions, shame, fear, and secrecy regarding menstruation are deeply rooted in socio-cultural history. Across various religions and mythologies, menstrual blood has often been incorrectly labelled as ‘impure’. In some regions, these beliefs are so extreme that menstrual cloths are burned to ward off perceived ‘evil spirits’.\nThese rituals persist and become socially established primarily due to a lack of science-based education and open public discourse. Breaking these cycles of misinformation is essential to ensuring that menstruation is viewed not as a source of shame, but as a natural biological process and a fundamental health right.\n'**
  String get first_description_14;

  /// No description provided for @question_15.
  ///
  /// In en, this message translates to:
  /// **'What could cause a late or missed period?'**
  String get question_15;

  /// No description provided for @first_description_15.
  ///
  /// In en, this message translates to:
  /// **'Late or missed periods can often be a source of concern for teenage girls. It is important to understand that several factors can contribute to this. By recognising the possible causes and symptoms, you can gain better insight into your menstrual health and alleviate unnecessary worry.'**
  String get first_description_15;

  /// No description provided for @second_description_15.
  ///
  /// In en, this message translates to:
  /// **'Common reasons for late or missed periods could be:\n•\tHormonal imbalance: Fluctuations in hormone levels, particularly during adolescence, often cause irregular cycles. Factors such as stress, excessive exercise, significant weight changes, and certain medical conditions can disrupt this hormonal balance.\n•\tPolycystic Ovary Syndrome (PCOS): PCOS is a common hormonal disorder affecting the ovaries. It can result in irregular periods, prolonged cycles, or missed periods entirely. Other symptoms may include acne, weight gain, and excessive hair growth.\n•\tPregnancy: A missed period can be a sign of pregnancy. If you are sexually active and experiencing other symptoms such as breast tenderness, nausea, or fatigue, it is important to take a pregnancy test or consult a healthcare provider.\n•\tMedications and medical conditions: Certain medications, including hormonal contraceptives or those that affect hormone levels, can impact cycle regularity. Additionally, medical conditions such as thyroid disorders or abnormalities in the reproductive system may contribute to irregularities.\n'**
  String get second_description_15;

  /// No description provided for @third_description_15.
  ///
  /// In en, this message translates to:
  /// **'While occasional irregularities are normal, especially in the first few years of menstruating, it is crucial to seek medical advice if missed periods become a persistent issue or are accompanied by concerning symptoms. By maintaining a healthy lifestyle, managing stress, and staying in tune with your body, you can better support your menstrual health. Remember, open communication with a trusted adult or healthcare provider is key to ensuring your overall well-being.'**
  String get third_description_15;

  /// No description provided for @question_16.
  ///
  /// In en, this message translates to:
  /// **'Why is it important to learn about periods before they start?'**
  String get question_16;

  /// No description provided for @first_description_16.
  ///
  /// In en, this message translates to:
  /// **'During puberty, girls begin to notice significant physical and emotional changes. Without access to accurate information, these shifts can feel overwhelming and confusing. Because our society still harbours various superstitions and restrictions surrounding menstruation, girls often rely on prevalent misinformation rather than seeking scientific knowledge.'**
  String get first_description_16;

  /// No description provided for @second_description_16.
  ///
  /// In en, this message translates to:
  /// **'Without early education, many girls develop a mental \"preparedness\" based on shame, fear, and anxiety, believing that menstruation is a secret to be hidden. These harmful misconceptions can have a lasting impact.\nWhen girls are deprived of the correct information, they miss the opportunity to develop the healthy habits they need from the very beginning. Furthermore, a lack of knowledge makes it difficult for them to understand or challenge social prejudices and taboos. Early education empowers girls to navigate these changes with confidence and dignity.\n'**
  String get second_description_16;

  /// No description provided for @question_17.
  ///
  /// In en, this message translates to:
  /// **'What to do when you get your first period?'**
  String get question_17;

  /// No description provided for @first_description_17.
  ///
  /// In en, this message translates to:
  /// **'Experiencing your first menstruation, also known as menarche, is a significant and exciting milestone. While it may feel unfamiliar, approaching this new phase with the right knowledge will help you navigate it with ease. This guide provides a step-by-step approach to managing your first period with confidence.'**
  String get first_description_17;

  /// No description provided for @second_description_17.
  ///
  /// In en, this message translates to:
  /// **'•\tStay calm: First and foremost, remember that menstruation is a normal and healthy part of life. Take a deep breath and know that millions of girls are going through this same experience.\n•\tFind support: Talk to a trusted adult, such as your mother, an older sister, or a female guardian. They can offer practical advice and the emotional support you need during this time.\n•\tBe prepared: It is helpful to have supplies ready before your period arrives. Keep a few sanitary pads or tampons in your bag so you aren\'t caught off guard. If you aren\'t sure which product to use, ask an adult for a recommendation.\n•\tTrack your cycle: Start noting the first day of your period on a calendar or in this app. This will help you anticipate your next period and understand your body’s unique patterns.\n•\tPractise good hygiene: Change your pad or tampon regularly—typically every 4 to 6 hours. Wash your genital area gently with warm water and mild soap, and always wash your hands before and after changing your menstrual products.\n•\tManage discomfort: If you experience cramps, a heating pad or a warm water bottle can help. With a doctor’s guidance, you may also take over-the-counter pain relief. Light exercises like walking or stretching can also ease discomfort.\n•\tPrioritise self-care: Listen to your body. Ensure you get enough rest, eat nutritious meals, and stay well-hydrated. Give yourself the space to feel relaxed and comfortable.\n•\tAsk questions: Never hesitate to ask about your body or any concerns you have. Open communication with friends, family, or healthcare professionals helps dispel myths and provides you with the facts.\n'**
  String get second_description_17;

  /// No description provided for @third_description_17.
  ///
  /// In en, this message translates to:
  /// **'Your first period is the start of a natural bodily process. It may take a little time to adjust, but with the right support, you will soon feel confident managing your menstrual health.'**
  String get third_description_17;

  /// No description provided for @question_18.
  ///
  /// In en, this message translates to:
  /// **'What preparations can be made to ensure menstruation does not interfere with daily life?'**
  String get question_18;

  /// No description provided for @first_description_18.
  ///
  /// In en, this message translates to:
  /// **'Effective preparation is key to ensuring that menstruation does not disrupt daily routines. By planning ahead, users can manage their cycles with confidence, whether they are at school, at work, or away from home.\n•\tTrack the cycle: Keep a clear idea of when your next period is due. You can easily predict your start date by using the period tracker in the Ananya app.\n•\tPlan ahead: If you know your period is approaching, think about your schedule. If you will be at school or travelling, make sure you have your supplies ready in advance.\n•\tCarry a period kit: Prepare a small, discreet bag to keep in a school bag or handbag. This kit should include:\n\tPreferred sanitary pads, tampons, or menstrual cups.\n\tClean tissues or wet wipes.\n\tA small bar of soap.\n\tA small bottle of clean water for washing, if possible.\nBy staying prepared, you can go about your daily activities comfortably and without worry.\n'**
  String get first_description_18;

  /// No description provided for @question_1_1.
  ///
  /// In en, this message translates to:
  /// **'What are the early signs of pregnancy?'**
  String get question_1_1;

  /// No description provided for @first_description_1_1.
  ///
  /// In en, this message translates to:
  /// **'While a pregnancy test is the only way to be certain, you may notice physical changes even before a missed period. The most common early signs and symptoms of pregnancy include:\n•\tMissed period: This is often the most obvious and earliest indicator of pregnancy.\n•\tNausea: Nausea and vomiting, frequently referred to as \"morning sickness\", are common symptoms during the early stages.\n•\tBreast changes: Hormonal shifts can cause your breasts to feel tender, sensitive, or noticeably enlarged.\n•\tFatigue: Feeling unusually tired or exhausted is common due to the significant hormonal changes taking place.\n•\tMood swings: Pregnancy can affect your emotions, leading to increased irritability or sudden changes in mood.\n•\tSpotting: You may experience very light bleeding (spotting) or mild cramping as the fertilised egg implants itself in the uterus.\n•\tIncreased urination: The production of the hormone hCG during pregnancy often leads to a more frequent need to urinate.\nIf you suspect you may be pregnant, it\'s important to confirm it with a pregnancy test and to consult a healthcare provider. They can provide further guidance and prenatal care to ensure a healthy pregnancy.\n'**
  String get first_description_1_1;

  /// No description provided for @question_1_2.
  ///
  /// In en, this message translates to:
  /// **'How to identify the fertile window?'**
  String get question_1_2;

  /// No description provided for @first_description_1_2.
  ///
  /// In en, this message translates to:
  /// **'Whether you are planning to conceive or seeking to avoid pregnancy, understanding your fertility is an essential part of reproductive health. Knowing when you are most fertile allows you to understand your body’s cycle more clearly. The following guide covers the basics of fertility and the common methods used to determine when you are most likely to conceive.'**
  String get first_description_1_2;

  /// No description provided for @second_description_1_2.
  ///
  /// In en, this message translates to:
  /// **'•\tOvulation: Ovulation is the process where an egg is released from the ovary, making it available for fertilisation. Identifying your ovulation cycle is the key to determining your ‘fertile window’.\n•\tBasal body temperature: Monitoring your basal body temperature, your temperature while at rest, can help track ovulation. A slight, consistent rise in temperature often indicates that ovulation has occurred.\n•\tOvulation predictor kits: These kits measure the levels of luteinising hormone (LH) in your urine. A surge in LH levels typically happens just before ovulation, signifying your most fertile period.\n•\tThe fertile window: If your menstrual cycle lasts 28 days and is regular, ovulation usually occurs around day 14 (the midpoint of your cycle). In this scenario, your fertile window typically begins on day 10. For those seeking to conceive, the likelihood of pregnancy is higher when having intercourse at least every other day between days 10 and 14.\n'**
  String get second_description_1_2;

  /// No description provided for @third_description_1_2.
  ///
  /// In en, this message translates to:
  /// **'Remember that fertility can vary from one cycle to the next and is influenced by factors such as age, weight, stress, and overall health. If you have any concerns regarding your fertility or cycle regularity, it is always best to consult a healthcare provider.'**
  String get third_description_1_2;

  /// No description provided for @question_1_3.
  ///
  /// In en, this message translates to:
  /// **'Spotting vs Period vs Bleeding'**
  String get question_1_3;

  /// No description provided for @first_description_1_3.
  ///
  /// In en, this message translates to:
  /// **'Menstruation (your regular period): Menstruation is your body\'s completely natural and healthy monthly cycle. It usually lasts between three to seven days. During this time, you might need to change your pad or clean cloth two to three times a day. This is an absolutely normal sign of a healthy body!\nSpotting (light drops): Spotting happens when you see tiny drops of blood between your regular periods. The flow is usually so light that you do not need a full pad; a panty liner is often enough. The colour might look light pink or brown. This can occur due to hormone changes or certain medicines, and it is usually nothing to worry about.\nHeavy bleeding (warning sign): This occurs when your bleeding is unusually heavy or lasts for more than eight days. If you find yourself soaking through a pad every one to two hours or passing large blood clots, it is a warning sign. Heavy bleeding can make you very weak and cause anaemia, so it is important to consult a doctor if you experience these symptoms.\n'**
  String get first_description_1_3;

  /// No description provided for @help_number_16263.
  ///
  /// In en, this message translates to:
  /// **'16263'**
  String get help_number_16263;

  /// No description provided for @help_description_16263.
  ///
  /// In en, this message translates to:
  /// **'Shasthaya Batayan Health Care Centre. Get help from doctors all over 24 hours by dialling this number.'**
  String get help_description_16263;

  /// No description provided for @help_number_109.
  ///
  /// In en, this message translates to:
  /// **'109'**
  String get help_number_109;

  /// No description provided for @help_description_109.
  ///
  /// In en, this message translates to:
  /// **'Government helpline number for violence against women/ prevention of child marriage'**
  String get help_description_109;

  /// No description provided for @help_number_10921.
  ///
  /// In en, this message translates to:
  /// **'10921'**
  String get help_number_10921;

  /// No description provided for @help_description_10921.
  ///
  /// In en, this message translates to:
  /// **'National helpline centre for violence against women. Immediate service to victims and links up to relevant agencies: doctors, counsellors, lawyers, DNA experts, police officers'**
  String get help_description_10921;

  /// No description provided for @help_number_333.
  ///
  /// In en, this message translates to:
  /// **'333'**
  String get help_number_333;

  /// No description provided for @help_description_333.
  ///
  /// In en, this message translates to:
  /// **'National Hotline Number. Immediate reports/help for any social problems from enquiring after COVID 19 to child marriage and sexual harassment cases.'**
  String get help_description_333;

  /// No description provided for @help_number_01779554391_01779554392.
  ///
  /// In en, this message translates to:
  /// **'01779554391'**
  String get help_number_01779554391_01779554392;

  /// No description provided for @help_description_01779554391_01779554392.
  ///
  /// In en, this message translates to:
  /// **'Kaan Pete Roi: an emotional support and suicide prevention helpline, staffed by trained volunteers, which people can call to receive immediate support.'**
  String get help_description_01779554391_01779554392;

  /// No description provided for @help_number_01776632344.
  ///
  /// In en, this message translates to:
  /// **'01776632344'**
  String get help_number_01776632344;

  /// No description provided for @help_description_01776632344.
  ///
  /// In en, this message translates to:
  /// **'Moner Bondhu: with a dynamic and skilled team of counsellors and experts, Moner Bondhu is a platform to provide care for mental health and well-being services.'**
  String get help_description_01776632344;

  /// No description provided for @help_number_09678771511.
  ///
  /// In en, this message translates to:
  /// **'09678771511'**
  String get help_number_09678771511;

  /// No description provided for @help_description_09678771511.
  ///
  /// In en, this message translates to:
  /// **'SAJIDA Foundation’s one-stop hotline number caters to the healthcare needs of all. Access consultation on COVID, general health, receive mental health and emotional support and in-home care for the elderly and chronically ill, alongside psychiatric and psychological care.'**
  String get help_description_09678771511;

  /// No description provided for @help_number_09612600600.
  ///
  /// In en, this message translates to:
  /// **'09612600600'**
  String get help_number_09612600600;

  /// No description provided for @help_description_09612600600.
  ///
  /// In en, this message translates to:
  /// **'Dosh Unisher Mor Helpline: A helpline to answer sexual health related queries, quell the curiosities of adolescent minds and provide them with information to seek help if needed.'**
  String get help_description_09612600600;

  /// No description provided for @help_number_list.
  ///
  /// In en, this message translates to:
  /// **'  '**
  String get help_number_list;

  /// No description provided for @common_asked_question_on_menstruation.
  ///
  /// In en, this message translates to:
  /// **'Common asked question on Menstruation'**
  String get common_asked_question_on_menstruation;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @do_you_know_we_have_governmental_regulation_about_menstrual.
  ///
  /// In en, this message translates to:
  /// **'Do you know we have governmental regulation about menstrual?'**
  String get do_you_know_we_have_governmental_regulation_about_menstrual;

  /// No description provided for @national_mhm_strategies.
  ///
  /// In en, this message translates to:
  /// **'National MHM Strategies'**
  String get national_mhm_strategies;

  /// No description provided for @call_to_learn_more.
  ///
  /// In en, this message translates to:
  /// **'Call to Learn More'**
  String get call_to_learn_more;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @click.
  ///
  /// In en, this message translates to:
  /// **'Click'**
  String get click;

  /// No description provided for @recomended_reading_for_you.
  ///
  /// In en, this message translates to:
  /// **'RECOMMENDED READINGS FOR YOU'**
  String get recomended_reading_for_you;

  /// No description provided for @irregular.
  ///
  /// In en, this message translates to:
  /// **'Irregular'**
  String get irregular;

  /// No description provided for @invalid_credentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid Credentials'**
  String get invalid_credentials;

  /// No description provided for @is_required.
  ///
  /// In en, this message translates to:
  /// **'is required'**
  String get is_required;

  /// No description provided for @dhaka.
  ///
  /// In en, this message translates to:
  /// **'Dhaka'**
  String get dhaka;

  /// No description provided for @sylhet.
  ///
  /// In en, this message translates to:
  /// **'Sylhet'**
  String get sylhet;

  /// No description provided for @khulna.
  ///
  /// In en, this message translates to:
  /// **'Khulna'**
  String get khulna;

  /// No description provided for @cumilla.
  ///
  /// In en, this message translates to:
  /// **'Cumilla'**
  String get cumilla;

  /// No description provided for @feni.
  ///
  /// In en, this message translates to:
  /// **'Feni'**
  String get feni;

  /// No description provided for @brahmanbaria.
  ///
  /// In en, this message translates to:
  /// **'Brahmanbaria'**
  String get brahmanbaria;

  /// No description provided for @rangamati.
  ///
  /// In en, this message translates to:
  /// **'Rangamati'**
  String get rangamati;

  /// No description provided for @noakhali.
  ///
  /// In en, this message translates to:
  /// **'Noakhali'**
  String get noakhali;

  /// No description provided for @chandpur.
  ///
  /// In en, this message translates to:
  /// **'Chandpur'**
  String get chandpur;

  /// No description provided for @lakshmipur.
  ///
  /// In en, this message translates to:
  /// **'Lakshmipur'**
  String get lakshmipur;

  /// No description provided for @chattogram.
  ///
  /// In en, this message translates to:
  /// **'Chattogram'**
  String get chattogram;

  /// No description provided for @coxsbazar.
  ///
  /// In en, this message translates to:
  /// **'Cox\'s Bazar'**
  String get coxsbazar;

  /// No description provided for @khagrachhari.
  ///
  /// In en, this message translates to:
  /// **'Khagrachhari'**
  String get khagrachhari;

  /// No description provided for @bandarban.
  ///
  /// In en, this message translates to:
  /// **'Bandarban'**
  String get bandarban;

  /// No description provided for @sirajganj.
  ///
  /// In en, this message translates to:
  /// **'Sirajganj'**
  String get sirajganj;

  /// No description provided for @pabna.
  ///
  /// In en, this message translates to:
  /// **'Pabna'**
  String get pabna;

  /// No description provided for @bogura.
  ///
  /// In en, this message translates to:
  /// **'Bogura'**
  String get bogura;

  /// No description provided for @rajshahi.
  ///
  /// In en, this message translates to:
  /// **'Rajshahi'**
  String get rajshahi;

  /// No description provided for @natore.
  ///
  /// In en, this message translates to:
  /// **'Natore'**
  String get natore;

  /// No description provided for @joypurhat.
  ///
  /// In en, this message translates to:
  /// **'Joypurhat'**
  String get joypurhat;

  /// No description provided for @chapainawabganj.
  ///
  /// In en, this message translates to:
  /// **'Chapainawabganj'**
  String get chapainawabganj;

  /// No description provided for @naogaon.
  ///
  /// In en, this message translates to:
  /// **'Naogaon'**
  String get naogaon;

  /// No description provided for @jashore.
  ///
  /// In en, this message translates to:
  /// **'Jashore'**
  String get jashore;

  /// No description provided for @satkhira.
  ///
  /// In en, this message translates to:
  /// **'Satkhira'**
  String get satkhira;

  /// No description provided for @meherpur.
  ///
  /// In en, this message translates to:
  /// **'Meherpur'**
  String get meherpur;

  /// No description provided for @narail.
  ///
  /// In en, this message translates to:
  /// **'Narail'**
  String get narail;

  /// No description provided for @chuadanga.
  ///
  /// In en, this message translates to:
  /// **'Chuadanga'**
  String get chuadanga;

  /// No description provided for @kushtia.
  ///
  /// In en, this message translates to:
  /// **'Kushtia'**
  String get kushtia;

  /// No description provided for @magura.
  ///
  /// In en, this message translates to:
  /// **'Magura'**
  String get magura;

  /// No description provided for @bagerhat.
  ///
  /// In en, this message translates to:
  /// **'Bagerhat'**
  String get bagerhat;

  /// No description provided for @jhenaidah.
  ///
  /// In en, this message translates to:
  /// **'Jhenaidah'**
  String get jhenaidah;

  /// No description provided for @jhalakathi.
  ///
  /// In en, this message translates to:
  /// **'Jhalakathi'**
  String get jhalakathi;

  /// No description provided for @patuakhali.
  ///
  /// In en, this message translates to:
  /// **'Patuakhali'**
  String get patuakhali;

  /// No description provided for @pirojpur.
  ///
  /// In en, this message translates to:
  /// **'Pirojpur'**
  String get pirojpur;

  /// No description provided for @barishal.
  ///
  /// In en, this message translates to:
  /// **'Barishal'**
  String get barishal;

  /// No description provided for @bhola.
  ///
  /// In en, this message translates to:
  /// **'Bhola'**
  String get bhola;

  /// No description provided for @barguna.
  ///
  /// In en, this message translates to:
  /// **'Barguna'**
  String get barguna;

  /// No description provided for @moulvibazar.
  ///
  /// In en, this message translates to:
  /// **'Moulvibazar'**
  String get moulvibazar;

  /// No description provided for @habiganj.
  ///
  /// In en, this message translates to:
  /// **'Habiganj'**
  String get habiganj;

  /// No description provided for @sunamganj.
  ///
  /// In en, this message translates to:
  /// **'Sunamganj'**
  String get sunamganj;

  /// No description provided for @narsingdi.
  ///
  /// In en, this message translates to:
  /// **'Narsingdi'**
  String get narsingdi;

  /// No description provided for @gazipur.
  ///
  /// In en, this message translates to:
  /// **'Gazipur'**
  String get gazipur;

  /// No description provided for @shariatpur.
  ///
  /// In en, this message translates to:
  /// **'Shariatpur'**
  String get shariatpur;

  /// No description provided for @narayanganj.
  ///
  /// In en, this message translates to:
  /// **'Narayanganj'**
  String get narayanganj;

  /// No description provided for @tangail.
  ///
  /// In en, this message translates to:
  /// **'Tangail'**
  String get tangail;

  /// No description provided for @kishoreganj.
  ///
  /// In en, this message translates to:
  /// **'Kishoreganj'**
  String get kishoreganj;

  /// No description provided for @manikganj.
  ///
  /// In en, this message translates to:
  /// **'Manikganj'**
  String get manikganj;

  /// No description provided for @munshiganj.
  ///
  /// In en, this message translates to:
  /// **'Munshiganj'**
  String get munshiganj;

  /// No description provided for @rajbari.
  ///
  /// In en, this message translates to:
  /// **'Rajbari'**
  String get rajbari;

  /// No description provided for @madaripur.
  ///
  /// In en, this message translates to:
  /// **'Madaripur'**
  String get madaripur;

  /// No description provided for @gopalganj.
  ///
  /// In en, this message translates to:
  /// **'Gopalganj'**
  String get gopalganj;

  /// No description provided for @faridpur.
  ///
  /// In en, this message translates to:
  /// **'Faridpur'**
  String get faridpur;

  /// No description provided for @panchagarh.
  ///
  /// In en, this message translates to:
  /// **'Panchagarh'**
  String get panchagarh;

  /// No description provided for @dinajpur.
  ///
  /// In en, this message translates to:
  /// **'Dinajpur'**
  String get dinajpur;

  /// No description provided for @lalmonirhat.
  ///
  /// In en, this message translates to:
  /// **'Lalmonirhat'**
  String get lalmonirhat;

  /// No description provided for @nilphamari.
  ///
  /// In en, this message translates to:
  /// **'Nilphamari'**
  String get nilphamari;

  /// No description provided for @gaibandha.
  ///
  /// In en, this message translates to:
  /// **'Gaibandha'**
  String get gaibandha;

  /// No description provided for @thakurgaon.
  ///
  /// In en, this message translates to:
  /// **'Thakurgaon'**
  String get thakurgaon;

  /// No description provided for @rangpur.
  ///
  /// In en, this message translates to:
  /// **'Rangpur'**
  String get rangpur;

  /// No description provided for @kurigram.
  ///
  /// In en, this message translates to:
  /// **'Kurigram'**
  String get kurigram;

  /// No description provided for @sherpur.
  ///
  /// In en, this message translates to:
  /// **'Sherpur'**
  String get sherpur;

  /// No description provided for @mymensingh.
  ///
  /// In en, this message translates to:
  /// **'Mymensingh'**
  String get mymensingh;

  /// No description provided for @jamalpur.
  ///
  /// In en, this message translates to:
  /// **'Jamalpur'**
  String get jamalpur;

  /// No description provided for @netrokona.
  ///
  /// In en, this message translates to:
  /// **'Netrokona'**
  String get netrokona;

  /// No description provided for @wateraid.
  ///
  /// In en, this message translates to:
  /// **'WaterAid'**
  String get wateraid;

  /// No description provided for @brac.
  ///
  /// In en, this message translates to:
  /// **'Brac'**
  String get brac;

  /// No description provided for @user.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get user;

  /// No description provided for @superuser.
  ///
  /// In en, this message translates to:
  /// **'Superuser'**
  String get superuser;

  /// No description provided for @no_anomalies.
  ///
  /// In en, this message translates to:
  /// **'No anomalies'**
  String get no_anomalies;

  /// No description provided for @some_anomalies.
  ///
  /// In en, this message translates to:
  /// **'Some anomalies'**
  String get some_anomalies;

  /// No description provided for @days_cycle.
  ///
  /// In en, this message translates to:
  /// **'days cycle'**
  String get days_cycle;

  /// No description provided for @your_period_starts_in.
  ///
  /// In en, this message translates to:
  /// **'Your period starts in'**
  String get your_period_starts_in;

  /// No description provided for @period_reminder.
  ///
  /// In en, this message translates to:
  /// **'Period Reminder'**
  String get period_reminder;

  /// No description provided for @no_history_available.
  ///
  /// In en, this message translates to:
  /// **'No history available'**
  String get no_history_available;

  /// No description provided for @error_loading_data.
  ///
  /// In en, this message translates to:
  /// **'Error loading data'**
  String get error_loading_data;

  /// No description provided for @no_user_selected.
  ///
  /// In en, this message translates to:
  /// **'No user selected'**
  String get no_user_selected;

  /// No description provided for @calculating.
  ///
  /// In en, this message translates to:
  /// **'Calculating'**
  String get calculating;

  /// No description provided for @your_cycle_prediction.
  ///
  /// In en, this message translates to:
  /// **'your cycle prediction'**
  String get your_cycle_prediction;

  /// No description provided for @your_next_period_will_start_around.
  ///
  /// In en, this message translates to:
  /// **'Your next period will start around'**
  String get your_next_period_will_start_around;

  /// No description provided for @pdf_downloaded.
  ///
  /// In en, this message translates to:
  /// **'PDF Downloaded'**
  String get pdf_downloaded;

  /// No description provided for @permission_denied.
  ///
  /// In en, this message translates to:
  /// **'Permission denied'**
  String get permission_denied;

  /// No description provided for @forget_password.
  ///
  /// In en, this message translates to:
  /// **'Forget password'**
  String get forget_password;

  /// No description provided for @reset_your_account_password.
  ///
  /// In en, this message translates to:
  /// **'Reset your account password'**
  String get reset_your_account_password;

  /// No description provided for @new_password.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get new_password;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @no_data_available.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get no_data_available;

  /// No description provided for @which_user_do_you_want_to.
  ///
  /// In en, this message translates to:
  /// **'Which user do you want to'**
  String get which_user_do_you_want_to;

  /// No description provided for @log_period_of.
  ///
  /// In en, this message translates to:
  /// **'log period of'**
  String get log_period_of;

  /// No description provided for @probahini.
  ///
  /// In en, this message translates to:
  /// **'Probahini'**
  String get probahini;

  /// No description provided for @others.
  ///
  /// In en, this message translates to:
  /// **'WaterAid project'**
  String get others;

  /// No description provided for @sts_project.
  ///
  /// In en, this message translates to:
  /// **'BRAC project'**
  String get sts_project;

  /// No description provided for @account_created_successfully.
  ///
  /// In en, this message translates to:
  /// **'Account created successfully'**
  String get account_created_successfully;

  /// No description provided for @hospital_and_pharmacy.
  ///
  /// In en, this message translates to:
  /// **'Hospital and \nPharmacy'**
  String get hospital_and_pharmacy;

  /// No description provided for @find_a_pharmacy_or_hospital_near_you.
  ///
  /// In en, this message translates to:
  /// **'Find a pharmacy or \nhospital near you'**
  String get find_a_pharmacy_or_hospital_near_you;

  /// No description provided for @see_address.
  ///
  /// In en, this message translates to:
  /// **'SEE ADDRESS'**
  String get see_address;

  /// No description provided for @password_changed_successfully.
  ///
  /// In en, this message translates to:
  /// **'Password Changed successfully'**
  String get password_changed_successfully;

  /// No description provided for @no_users_found.
  ///
  /// In en, this message translates to:
  /// **'No users found'**
  String get no_users_found;

  /// No description provided for @user_period_logged_tracking_in_progress.
  ///
  /// In en, this message translates to:
  /// **'User period logged, tracking in progress'**
  String get user_period_logged_tracking_in_progress;

  /// No description provided for @emergency_numbers.
  ///
  /// In en, this message translates to:
  /// **'Emergency numbers'**
  String get emergency_numbers;

  /// No description provided for @please_login_to_continue.
  ///
  /// In en, this message translates to:
  /// **'Please sign up or log in to continue'**
  String get please_login_to_continue;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @sign_up.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get sign_up;

  /// No description provided for @log_symptoms.
  ///
  /// In en, this message translates to:
  /// **'Log symptoms'**
  String get log_symptoms;

  /// No description provided for @log_description.
  ///
  /// In en, this message translates to:
  /// **'Track symptoms and wellbeing to understand your body'**
  String get log_description;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @emergency_description.
  ///
  /// In en, this message translates to:
  /// **'Find reliable emergency and health helplines'**
  String get emergency_description;

  /// No description provided for @view_numbers.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get view_numbers;

  /// No description provided for @find_nearby_care.
  ///
  /// In en, this message translates to:
  /// **'Find nearby care'**
  String get find_nearby_care;

  /// No description provided for @map_description.
  ///
  /// In en, this message translates to:
  /// **'Find hospitals and pharmacies near you when needed'**
  String get map_description;

  /// No description provided for @view_map.
  ///
  /// In en, this message translates to:
  /// **'View map'**
  String get view_map;

  /// No description provided for @track_your_cycle.
  ///
  /// In en, this message translates to:
  /// **'Track your cycle'**
  String get track_your_cycle;

  /// No description provided for @calendar_description.
  ///
  /// In en, this message translates to:
  /// **'Add your cycle details to personalise your period calendar'**
  String get calendar_description;

  /// No description provided for @set_your_calendar.
  ///
  /// In en, this message translates to:
  /// **'Track your period cycle'**
  String get set_your_calendar;

  /// No description provided for @view_all.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get view_all;

  /// No description provided for @knowledge_hub.
  ///
  /// In en, this message translates to:
  /// **'Knowledge hub'**
  String get knowledge_hub;

  /// No description provided for @view_detail.
  ///
  /// In en, this message translates to:
  /// **'View detail'**
  String get view_detail;

  /// No description provided for @question_19.
  ///
  /// In en, this message translates to:
  /// **'Why is menstrual hygiene management a human right?'**
  String get question_19;

  /// No description provided for @first_description_19.
  ///
  /// In en, this message translates to:
  /// **'Menstrual hygiene management (MHM) is a fundamental human right, as it is vital for ensuring health, dignity, and gender equality. When it is neglected, individuals face increased risks of reproductive health issues, while stigma, shame, and limited access to education or work reinforce inequality and restrict bodily autonomy.'**
  String get first_description_19;

  /// No description provided for @question_20.
  ///
  /// In en, this message translates to:
  /// **'Respecting bodily autonomy'**
  String get question_20;

  /// No description provided for @first_description_20.
  ///
  /// In en, this message translates to:
  /// **'Having the ability to manage one\'s menstruation with access to proper products, private facilities, and information is a matter of self-determination and freedom from discrimination.\nLack of access can lead to physical and mental health problems, shame, and social inequalities, directly undermining an individual\'s right to care for their own body with dignity. \nEnsuring access to menstrual hygiene products and private facilities affirms the right to bodily autonomy – the right to make informed choices about one’s own body and to manage one’s health with dignity.\n'**
  String get first_description_20;

  /// No description provided for @question_21.
  ///
  /// In en, this message translates to:
  /// **'How to reduce equity gap at household, school and workspaces?'**
  String get question_21;

  /// No description provided for @first_description_21.
  ///
  /// In en, this message translates to:
  /// **'To reduce the equity gap at home, in schools, and in workplaces, it is essential to ensure that menstrual hygiene management (MHM) is supported through access to private, safe, and culturally appropriate facilities for changing, washing, and disposing of menstrual materials. MHM is integral to the human rights to water and sanitation. Barriers such as limited access to clean menstrual materials, lack of privacy to change as often as needed, inadequate water and soap for personal hygiene, and poorly maintained or unsafe disposal facilities reinforce gender inequality. These challenges restrict girls’ and women’s participation in education, employment, and social life.\nIn addition to improving infrastructure and access, it is equally important to challenge and reduce patriarchal norms and stigma surrounding menstruation, both in domestic settings and in public spaces. Promoting awareness, open dialogue, and gender-sensitive education can help dismantle harmful taboos, foster respect for bodily autonomy, and create equitable environments where women and girls can manage menstruation with confidence and dignity. \n'**
  String get first_description_21;

  /// No description provided for @question_22.
  ///
  /// In en, this message translates to:
  /// **'What are the common myths about menstruation?'**
  String get question_22;

  /// No description provided for @first_description_22.
  ///
  /// In en, this message translates to:
  /// **'Many girls and women in South Asia - young and old, educated and uneducated, rural and urban, rich and poor - feel ashamed talking about their periods. Talking about periods is still treated as a taboo in many societies. In many communities, people believe that girls and women should avoid eating certain foods during their periods, like eggs, red spinach, sour, cold, or easily spoiled foods. But there’s no medical reason to avoid these foods. In fact, following such food restrictions can be harmful, because it may stop girls from getting the nutrients their bodies need to stay healthy during menstruation.'**
  String get first_description_22;

  /// No description provided for @question_23.
  ///
  /// In en, this message translates to:
  /// **'How do menstrual myths originate and spread?'**
  String get question_23;

  /// No description provided for @first_description_23.
  ///
  /// In en, this message translates to:
  /// **'Many menstrual myths started long ago because people didn’t have scientific knowledge. They made guesses based on what they saw, like blood flowing from the vagina or pain from stomach cramps during periods. In some ancient societies, menstrual blood was seen as a sign of life and fertility, while in others it was seen as something dangerous that needed to be avoided.\nBecause these old beliefs were passed down without proper scientific understanding, many myths about periods still exist today. In many communities, people still don’t talk openly about menstruation, and there isn’t enough correct information. As a result, these myths continue from one generation to the next instead of being questioned or corrected. \n'**
  String get first_description_23;

  /// No description provided for @faqs.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get faqs;

  /// No description provided for @faq_q1.
  ///
  /// In en, this message translates to:
  /// **'What is the menstrual cycle?'**
  String get faq_q1;

  /// No description provided for @faq_a1.
  ///
  /// In en, this message translates to:
  /// **'The menstrual cycle is a natural process that prepares the body for pregnancy every month. It is controlled by hormones that tell the ovaries to release an egg and help the uterus get ready in case pregnancy happens. The cycle begins when a girl reaches puberty and continues until menopause.'**
  String get faq_a1;

  /// No description provided for @faq_q2.
  ///
  /// In en, this message translates to:
  /// **'What is the menstrual cycle and how long does it last?'**
  String get faq_q2;

  /// No description provided for @faq_a2.
  ///
  /// In en, this message translates to:
  /// **'The menstrual cycle is the time from the first day of one period to the day before the next one starts. For most people, a full cycle lasts 21 to 35 days. The bleeding part (menstruation) is just one part of the cycle and usually lasts about three to seven days.'**
  String get faq_a2;

  /// No description provided for @faq_q3.
  ///
  /// In en, this message translates to:
  /// **'What is menstruation or a “period”?'**
  String get faq_q3;

  /// No description provided for @faq_a3.
  ///
  /// In en, this message translates to:
  /// **'Menstruation (often called a “period”) is when a girl or woman bleeds from the vagina for a few days, usually three to seven days, every month. The blood isn’t harmful; it’s a mix of blood, tissue from the uterus lining, and natural vaginal fluids. Once menstruation starts, it means pregnancy is possible if an egg is fertilised.'**
  String get faq_a3;

  /// No description provided for @faq_q4.
  ///
  /// In en, this message translates to:
  /// **'How can I prepare for my first period?'**
  String get faq_q4;

  /// No description provided for @faq_a4.
  ///
  /// In en, this message translates to:
  /// **'Your first period might happen at school, during an outing, or somewhere unexpected – and that’s okay. It’s normal to feel nervous. You can stay prepared by carrying a small pouch with pads and an extra pair of underwear, so that if your period starts suddenly, you’ll feel ready and confident. Talking to your mother or another trusted adult can also help you learn how to manage your period.'**
  String get faq_a4;

  /// No description provided for @faq_q5.
  ///
  /// In en, this message translates to:
  /// **'How do I know when my next period will start?'**
  String get faq_q5;

  /// No description provided for @faq_a5.
  ///
  /// In en, this message translates to:
  /// **'Most people have their period every 21 to 35 days, but cycles can vary. After puberty, it might take a few months to figure out your own pattern. Try tracking the first day of each period in a calendar or an app. Over time, you’ll see how long your cycle usually is and when your next period might begin. It’s normal if it sometimes comes a few days earlier or later than expected.'**
  String get faq_a5;

  /// No description provided for @faq_q6.
  ///
  /// In en, this message translates to:
  /// **'Why are periods sometimes painful?'**
  String get faq_q6;

  /// No description provided for @faq_a6.
  ///
  /// In en, this message translates to:
  /// **'Period pain happens because the uterus squeezes to help push the blood out. This squeezing is caused by hormones and certain natural chemicals. Some people only feel mild cramps; others feel stronger pain in the lower belly, back, or thighs. Pain can last a few hours to a few days. If it’s very strong, talk to a doctor before taking any medicine. Always use painkillers safely; overusing them can cause other problems.'**
  String get faq_a6;

  /// No description provided for @faq_q7.
  ///
  /// In en, this message translates to:
  /// **'Why do I get mood swings before my period?'**
  String get faq_q7;

  /// No description provided for @faq_a7.
  ///
  /// In en, this message translates to:
  /// **'Before a period starts, hormone levels change and can affect brain chemicals that control mood. This may cause sadness, anxiety, irritability, trouble sleeping, or food cravings. You might also feel bloated or notice breast tenderness. These are common signs of premenstrual syndrome (PMS), though not everyone experiences them.'**
  String get faq_a7;

  /// No description provided for @faq_q8.
  ///
  /// In en, this message translates to:
  /// **'How do I use sanitary pads correctly?'**
  String get faq_q8;

  /// No description provided for @faq_a8.
  ///
  /// In en, this message translates to:
  /// **'Keeping yourself clean during your period is very important. Always wash your hands well before putting on a new pad. Change your pad every four to six hours so the blood doesn’t build up, as this can cause bad odours, fungal infections, or urinary and vaginal infections. When you remove a used pad, wrap it tightly (you can use the wrapper of the new pad if you have one) and throw it in a trashcan to keep smells and germs contained. After disposing of the pad, wash your hands thoroughly with soap and water.'**
  String get faq_a8;

  /// No description provided for @faq_q9.
  ///
  /// In en, this message translates to:
  /// **'Can I take a shower during my period?'**
  String get faq_q9;

  /// No description provided for @faq_a9.
  ///
  /// In en, this message translates to:
  /// **'Yes, you absolutely can! In fact, showering can help you feel fresh, clean, and more comfortable. Hormonal changes may make you feel sweaty or warm, especially at night. Just use water or a mild cleanser for the sensitive area and avoid harsh soaps.'**
  String get faq_a9;

  /// No description provided for @faq_q10.
  ///
  /// In en, this message translates to:
  /// **'Can I exercise during my period?'**
  String get faq_q10;

  /// No description provided for @faq_a10.
  ///
  /// In en, this message translates to:
  /// **'Yes, you can exercise during your period if you feel well enough. Gentle movement like walking, stretching, or light jogging can help relieve cramps and improve mood. Listen to your body, if the pain feels too strong, it’s okay to rest.'**
  String get faq_a10;

  /// No description provided for @faq_q11.
  ///
  /// In en, this message translates to:
  /// **'What should I eat and drink during my period?'**
  String get faq_q11;

  /// No description provided for @faq_a11.
  ///
  /// In en, this message translates to:
  /// **'Eating well can help you feel better. Try to include iron-rich foods like eggs, meat, and leafy greens to replace iron lost during bleeding. Drink plenty of water (six to eight glasses a day). Warm drinks can help with bloating and cramps. Try not to drink tea or coffee right with meals, as they can reduce iron absorption. Craving snacks is normal, but choose healthy options like fruits, nuts, and vegetables when you can.'**
  String get faq_a11;

  /// No description provided for @faq_q12.
  ///
  /// In en, this message translates to:
  /// **'When should I see a doctor about my periods?'**
  String get faq_q12;

  /// No description provided for @faq_a12.
  ///
  /// In en, this message translates to:
  /// **'It’s a good idea to see a doctor if your periods seem unusual or are causing problems. You should get medical advice if your periods last a very long time or come irregularly, if they start before the age of eight or haven’t started by age 16, or if you have severe or unusual pain at any time during your cycle. A doctor can help find the cause and suggest the right treatment or support.'**
  String get faq_a12;

  /// No description provided for @faqs_description.
  ///
  /// In en, this message translates to:
  /// **'Find clear and reliable answers to common questions about menstruation'**
  String get faqs_description;

  /// No description provided for @choose_nearby_care.
  ///
  /// In en, this message translates to:
  /// **'Choose nearby care'**
  String get choose_nearby_care;

  /// No description provided for @select_what_you_are_looking_for.
  ///
  /// In en, this message translates to:
  /// **'Select what you are looking for'**
  String get select_what_you_are_looking_for;

  /// No description provided for @nearby_hospital.
  ///
  /// In en, this message translates to:
  /// **'Nearby Hospital'**
  String get nearby_hospital;

  /// No description provided for @nearby_pharmacy.
  ///
  /// In en, this message translates to:
  /// **'Nearby Pharmacy'**
  String get nearby_pharmacy;

  /// No description provided for @open_in_map.
  ///
  /// In en, this message translates to:
  /// **'Open in Map'**
  String get open_in_map;

  /// No description provided for @password_instruction.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get password_instruction;

  /// No description provided for @app_version.
  ///
  /// In en, this message translates to:
  /// **'App version 2.0'**
  String get app_version;

  /// No description provided for @select_your_area.
  ///
  /// In en, this message translates to:
  /// **'Select your area'**
  String get select_your_area;

  /// No description provided for @tanore.
  ///
  /// In en, this message translates to:
  /// **'Tanore'**
  String get tanore;

  /// No description provided for @naogaon_sadar.
  ///
  /// In en, this message translates to:
  /// **'Naogaon Sadar'**
  String get naogaon_sadar;

  /// No description provided for @atrai.
  ///
  /// In en, this message translates to:
  /// **'Atrai'**
  String get atrai;

  /// No description provided for @manda.
  ///
  /// In en, this message translates to:
  /// **'Manda'**
  String get manda;

  /// No description provided for @mohadevpur.
  ///
  /// In en, this message translates to:
  /// **'Mohadevpur'**
  String get mohadevpur;

  /// No description provided for @badalgachi.
  ///
  /// In en, this message translates to:
  /// **'Badalgachi'**
  String get badalgachi;

  /// No description provided for @patnitala.
  ///
  /// In en, this message translates to:
  /// **'Patnitala'**
  String get patnitala;

  /// No description provided for @sapahar.
  ///
  /// In en, this message translates to:
  /// **'Sapahar'**
  String get sapahar;

  /// No description provided for @raninagar.
  ///
  /// In en, this message translates to:
  /// **'Raninagar'**
  String get raninagar;

  /// No description provided for @dhamoirhat.
  ///
  /// In en, this message translates to:
  /// **'Dhamoirhat'**
  String get dhamoirhat;

  /// No description provided for @barguna_sadar.
  ///
  /// In en, this message translates to:
  /// **'Barguna Sadar'**
  String get barguna_sadar;

  /// No description provided for @patharghata.
  ///
  /// In en, this message translates to:
  /// **'Patharghata'**
  String get patharghata;

  /// No description provided for @amtali.
  ///
  /// In en, this message translates to:
  /// **'Amtali'**
  String get amtali;

  /// No description provided for @betagi.
  ///
  /// In en, this message translates to:
  /// **'Betagi'**
  String get betagi;

  /// No description provided for @bamna.
  ///
  /// In en, this message translates to:
  /// **'Bamna'**
  String get bamna;

  /// No description provided for @kalapara.
  ///
  /// In en, this message translates to:
  /// **'Kalapara'**
  String get kalapara;

  /// No description provided for @golachipa.
  ///
  /// In en, this message translates to:
  /// **'Golachipa'**
  String get golachipa;

  /// No description provided for @bauphal.
  ///
  /// In en, this message translates to:
  /// **'Bauphal'**
  String get bauphal;

  /// No description provided for @patuakhali_sadar.
  ///
  /// In en, this message translates to:
  /// **'Patuakhali Sadar'**
  String get patuakhali_sadar;

  /// No description provided for @dashmina.
  ///
  /// In en, this message translates to:
  /// **'Dashmina'**
  String get dashmina;

  /// No description provided for @dumki.
  ///
  /// In en, this message translates to:
  /// **'Dumki'**
  String get dumki;

  /// No description provided for @mirzaganj.
  ///
  /// In en, this message translates to:
  /// **'Mirzaganj'**
  String get mirzaganj;

  /// No description provided for @dhaka_north_city_corporation.
  ///
  /// In en, this message translates to:
  /// **'Dhaka North City-Corporation'**
  String get dhaka_north_city_corporation;

  /// No description provided for @dhaka_south_city_corporation.
  ///
  /// In en, this message translates to:
  /// **'Dhaka South City-Corporation'**
  String get dhaka_south_city_corporation;

  /// No description provided for @khulna_city_corporation.
  ///
  /// In en, this message translates to:
  /// **'Khulna City-Corporation'**
  String get khulna_city_corporation;

  /// No description provided for @chattogram_city_corporation.
  ///
  /// In en, this message translates to:
  /// **'Chattogram City-Corporation'**
  String get chattogram_city_corporation;

  /// No description provided for @paikgacha_municipality.
  ///
  /// In en, this message translates to:
  /// **'Paikgacha Municipality'**
  String get paikgacha_municipality;

  /// No description provided for @savar.
  ///
  /// In en, this message translates to:
  /// **'Savar'**
  String get savar;

  /// No description provided for @help_name_109.
  ///
  /// In en, this message translates to:
  /// **'Violence against women & child marriage'**
  String get help_name_109;

  /// No description provided for @help_name_333.
  ///
  /// In en, this message translates to:
  /// **'National Hotline'**
  String get help_name_333;

  /// No description provided for @help_name_10921.
  ///
  /// In en, this message translates to:
  /// **'National Helpline for Violence Against Women'**
  String get help_name_10921;

  /// No description provided for @help_name_16263.
  ///
  /// In en, this message translates to:
  /// **'Shasthaya Batayan Health Care Centre'**
  String get help_name_16263;

  /// No description provided for @help_name_01779554391_01779554392.
  ///
  /// In en, this message translates to:
  /// **'Kaan Pete Roi'**
  String get help_name_01779554391_01779554392;

  /// No description provided for @help_name_01776632344.
  ///
  /// In en, this message translates to:
  /// **'Moner Bondhu'**
  String get help_name_01776632344;

  /// No description provided for @help_name_09678771511.
  ///
  /// In en, this message translates to:
  /// **'SAJIDA Foundation Hotline'**
  String get help_name_09678771511;

  /// No description provided for @help_name_09612600600.
  ///
  /// In en, this message translates to:
  /// **'Dosh Unisher Mor'**
  String get help_name_09612600600;

  /// No description provided for @myth_quiz_title.
  ///
  /// In en, this message translates to:
  /// **'True or false?'**
  String get myth_quiz_title;

  /// No description provided for @myth_quiz_intro.
  ///
  /// In en, this message translates to:
  /// **'Six things people say about periods. How many can you get right?'**
  String get myth_quiz_intro;

  /// No description provided for @myth_quiz_start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get myth_quiz_start;

  /// No description provided for @myth_true.
  ///
  /// In en, this message translates to:
  /// **'True'**
  String get myth_true;

  /// No description provided for @myth_false.
  ///
  /// In en, this message translates to:
  /// **'False'**
  String get myth_false;

  /// No description provided for @myth_correct.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get myth_correct;

  /// No description provided for @myth_incorrect.
  ///
  /// In en, this message translates to:
  /// **'Not quite'**
  String get myth_incorrect;

  /// No description provided for @myth_next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get myth_next;

  /// No description provided for @myth_see_result.
  ///
  /// In en, this message translates to:
  /// **'See result'**
  String get myth_see_result;

  /// No description provided for @myth_progress.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String myth_progress(String current, String total);

  /// No description provided for @myth_score.
  ///
  /// In en, this message translates to:
  /// **'{correct} out of {total} correct'**
  String myth_score(String correct, String total);

  /// No description provided for @myth_result_strong.
  ///
  /// In en, this message translates to:
  /// **'You know your facts. Tell a friend.'**
  String get myth_result_strong;

  /// No description provided for @myth_result_mixed.
  ///
  /// In en, this message translates to:
  /// **'A good start — a few myths still caught you out.'**
  String get myth_result_mixed;

  /// No description provided for @myth_result_low.
  ///
  /// In en, this message translates to:
  /// **'Worth another go. These myths fool a lot of people.'**
  String get myth_result_low;

  /// No description provided for @myth_try_again.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get myth_try_again;

  /// No description provided for @myth_read_more.
  ///
  /// In en, this message translates to:
  /// **'Read the full topic'**
  String get myth_read_more;

  /// NEEDS HEALTH REVIEW. Condensed from first_description_6 (myth 5).
  ///
  /// In en, this message translates to:
  /// **'You should not eat fish or meat during your period.'**
  String get myth_1_statement;

  /// NEEDS HEALTH REVIEW. Condensed from first_description_22.
  ///
  /// In en, this message translates to:
  /// **'There is no medical reason to avoid these foods. Restricting them can be harmful, because it may stop you getting the nutrients your body needs during menstruation.'**
  String get myth_1_answer;

  /// NEEDS HEALTH REVIEW. Condensed from first_description_6 (myth 1).
  ///
  /// In en, this message translates to:
  /// **'Menstrual blood is dirty or impure.'**
  String get myth_2_statement;

  /// NEEDS HEALTH REVIEW. Condensed from faq_a3.
  ///
  /// In en, this message translates to:
  /// **'The blood is not harmful. It is a mix of blood, tissue from the lining of the uterus, and natural fluids.'**
  String get myth_2_answer;

  /// NEEDS HEALTH REVIEW. Condensed from first_description_6 (myth 4).
  ///
  /// In en, this message translates to:
  /// **'Used cloths should be hidden away and never dried in the sun.'**
  String get myth_3_statement;

  /// NEEDS HEALTH REVIEW. Condensed from second_description_11.
  ///
  /// In en, this message translates to:
  /// **'The opposite is true. Cloths should always be dried in direct sunlight, because the sun’s UV rays are a natural disinfectant.'**
  String get myth_3_answer;

  /// NEEDS HEALTH REVIEW. Condensed from first_description_6 (myth 5).
  ///
  /// In en, this message translates to:
  /// **'You should stay home from school and avoid sport during your period.'**
  String get myth_4_statement;

  /// NEEDS HEALTH REVIEW. Condensed from second_description_17.
  ///
  /// In en, this message translates to:
  /// **'A period is not a reason to stop your normal life. Light exercise such as walking or stretching can actually ease the discomfort.'**
  String get myth_4_answer;

  /// No description provided for @myth_5_statement.
  ///
  /// In en, this message translates to:
  /// **'A normal menstrual cycle can be anywhere from 21 to 35 days.'**
  String get myth_5_statement;

  /// NEEDS HEALTH REVIEW. Condensed from faq_a2.
  ///
  /// In en, this message translates to:
  /// **'True. The cycle is counted from the first day of one period to the day before the next one starts, and for most people that is 21 to 35 days.'**
  String get myth_5_answer;

  /// No description provided for @myth_6_statement.
  ///
  /// In en, this message translates to:
  /// **'Bleeding usually lasts about three to seven days.'**
  String get myth_6_statement;

  /// NEEDS HEALTH REVIEW. Condensed from faq_a2.
  ///
  /// In en, this message translates to:
  /// **'True. The bleeding is just one part of the cycle, and it usually lasts about three to seven days.'**
  String get myth_6_answer;

  /// NEEDS HEALTH REVIEW. Condensed from first_description_6 (myth 2).
  ///
  /// In en, this message translates to:
  /// **'Your body is pushing out toxins through menstrual blood.'**
  String get myth_7_statement;

  /// NEEDS HEALTH REVIEW. Condensed from faq_a3.
  ///
  /// In en, this message translates to:
  /// **'The blood carries no toxins and is not harmful. It is a mix of blood, tissue from the lining of the uterus, and natural fluids.'**
  String get myth_7_answer;

  /// NEEDS HEALTH REVIEW. Condensed from first_description_6 (myth 3).
  ///
  /// In en, this message translates to:
  /// **'A period is shameful and should not be talked about openly.'**
  String get myth_8_statement;

  /// NEEDS HEALTH REVIEW. Condensed from second_description_17.
  ///
  /// In en, this message translates to:
  /// **'Menstruation is a normal and healthy part of life. Being able to talk about it openly is what makes it easier to look after yourself.'**
  String get myth_8_answer;

  /// NEEDS HEALTH REVIEW. Condensed from first_description_6 (myth 5, evening restriction).
  ///
  /// In en, this message translates to:
  /// **'You should not go outside after dark while you are on your period.'**
  String get myth_9_statement;

  /// NEEDS HEALTH REVIEW. Condensed from first_description_6 (closing paragraph).
  ///
  /// In en, this message translates to:
  /// **'This is a superstition with no basis. Restrictions like it take away your daily freedom and make safe hygiene harder to manage.'**
  String get myth_9_answer;

  /// NEEDS HEALTH REVIEW. Condensed from first_description_22.
  ///
  /// In en, this message translates to:
  /// **'You should avoid eggs, red spinach and sour foods during your period.'**
  String get myth_10_statement;

  /// NEEDS HEALTH REVIEW. Condensed from first_description_22.
  ///
  /// In en, this message translates to:
  /// **'There is no medical reason to avoid these foods. Restricting them can stop you getting the nutrients your body needs.'**
  String get myth_10_answer;

  /// NEEDS HEALTH REVIEW. Condensed from first_description_7.
  ///
  /// In en, this message translates to:
  /// **'Feeling low or irritable in the days before a period is not normal.'**
  String get myth_11_statement;

  /// NEEDS HEALTH REVIEW. Condensed from first_description_7.
  ///
  /// In en, this message translates to:
  /// **'These are common signs of PMS, along with headaches, tiredness and bloating. They usually settle on their own once the period begins.'**
  String get myth_11_answer;

  /// NEEDS HEALTH REVIEW. Condensed from second_description_11.
  ///
  /// In en, this message translates to:
  /// **'A pad should be changed every 4 to 6 hours, even when the flow is light.'**
  String get myth_12_statement;

  /// NEEDS HEALTH REVIEW. Condensed from second_description_11.
  ///
  /// In en, this message translates to:
  /// **'True. Leaving a pad on too long encourages bacteria to grow and can irritate the skin.'**
  String get myth_12_answer;

  /// NEEDS HEALTH REVIEW. Condensed from third_description_1.
  ///
  /// In en, this message translates to:
  /// **'A first period usually happens between the ages of 10 and 16.'**
  String get myth_15_statement;

  /// NEEDS HEALTH REVIEW. Condensed from third_description_1.
  ///
  /// In en, this message translates to:
  /// **'True, though every body develops at its own pace. If yours has not started yet, there is no need to worry.'**
  String get myth_15_answer;

  /// NEEDS HEALTH REVIEW. Condensed from second_description_5.
  ///
  /// In en, this message translates to:
  /// **'Going three months or more with no period is worth paying attention to.'**
  String get myth_16_statement;

  /// NEEDS HEALTH REVIEW. Condensed from second_description_5.
  ///
  /// In en, this message translates to:
  /// **'True. That is counted as a missed period, and it is worth talking to a health worker about it.'**
  String get myth_16_answer;

  /// NEEDS HEALTH REVIEW. Source: third_description_3 + second_description_5.
  ///
  /// In en, this message translates to:
  /// **'Severe period pain that stops you doing your daily activities is just something to put up with.'**
  String get myth_17_statement;

  /// NEEDS HEALTH REVIEW. Source: third_description_3 + second_description_5.
  ///
  /// In en, this message translates to:
  /// **'Pain that disrupts your daily life is not something to endure quietly. It is one of the signs worth seeking medical advice about.'**
  String get myth_17_answer;

  /// NEEDS HEALTH REVIEW. Source: second_description_3.
  ///
  /// In en, this message translates to:
  /// **'Cramps happen because the uterus is contracting to shed its lining.'**
  String get myth_18_statement;

  /// NEEDS HEALTH REVIEW. Source: second_description_3.
  ///
  /// In en, this message translates to:
  /// **'True. The lower-abdomen cramping many people feel is the uterus contracting as it sheds its lining.'**
  String get myth_18_answer;

  /// NEEDS HEALTH REVIEW. Source: second_description_3. POST-REVIEW CORRECTION: The reviewer removed "Bloating and" from the English but not from the Bangla, so the two languages asked different questions. Bangla brought into line, and the English number agreement fixed — with bloating gone, "tenderness ... are caused" and "Both are" no longer agree with a single subject.
  ///
  /// In en, this message translates to:
  /// **'Breast tenderness around a period is caused by hormonal changes.'**
  String get myth_19_statement;

  /// NEEDS HEALTH REVIEW. Source: second_description_3. POST-REVIEW CORRECTION: The reviewer removed "Bloating and" from the English but not from the Bangla, so the two languages asked different questions. Bangla brought into line, and the English number agreement fixed — with bloating gone, "tenderness ... are caused" and "Both are" no longer agree with a single subject.
  ///
  /// In en, this message translates to:
  /// **'True. Hormonal shifts cause breast sensitivity. This is normal and usually settles on its own.'**
  String get myth_19_answer;

  /// NEEDS HEALTH REVIEW. Source: first_description_8.
  ///
  /// In en, this message translates to:
  /// **'Period problems should be kept secret and not discussed with anyone.'**
  String get myth_20_statement;

  /// NEEDS HEALTH REVIEW. Source: first_description_8.
  ///
  /// In en, this message translates to:
  /// **'This is a common misconception. If you notice signs of an abnormal cycle, speak to a parent, guardian or health worker.'**
  String get myth_20_answer;

  /// NEEDS HEALTH REVIEW. Source: first_description_9.
  ///
  /// In en, this message translates to:
  /// **'Losing blood every month can lead to iron deficiency, so iron-rich food matters.'**
  String get myth_21_statement;

  /// NEEDS HEALTH REVIEW. Source: first_description_9.
  ///
  /// In en, this message translates to:
  /// **'True. Blood contains iron, so without nutritional support a monthly loss can lead to deficiency. Diet is how that is replaced.'**
  String get myth_21_answer;

  /// NEEDS HEALTH REVIEW. Source: first_description_10. POST-REVIEW CORRECTION: Spelling: "weekness" corrected to "weakness". The trailing item was also folded into the list in both languages ("nausea and palpitations, weakness" reads as an afterthought); no meaning changed, and no item was added or removed.
  ///
  /// In en, this message translates to:
  /// **'Iron deficiency can cause tiredness, headaches and a racing heartbeat.'**
  String get myth_22_statement;

  /// NEEDS HEALTH REVIEW. Source: first_description_10. POST-REVIEW CORRECTION: Spelling: "weekness" corrected to "weakness". The trailing item was also folded into the list in both languages ("nausea and palpitations, weakness" reads as an afterthought); no meaning changed, and no item was added or removed.
  ///
  /// In en, this message translates to:
  /// **'True. Iron helps the body make haemoglobin. Too little causes fatigue, headaches, nausea, palpitations and weakness.'**
  String get myth_22_answer;

  /// NEEDS HEALTH REVIEW. Source: second_description_15.
  ///
  /// In en, this message translates to:
  /// **'Stress, big weight changes or too much exercise can delay a period.'**
  String get myth_23_statement;

  /// NEEDS HEALTH REVIEW. Source: second_description_15.
  ///
  /// In en, this message translates to:
  /// **'True. All of these can disrupt the hormone balance that controls the cycle.'**
  String get myth_23_answer;

  /// NEEDS HEALTH REVIEW. Source: second_description_15.
  ///
  /// In en, this message translates to:
  /// **'PCOS is a hormonal condition that can cause irregular periods.'**
  String get myth_24_statement;

  /// NEEDS HEALTH REVIEW. Source: second_description_15.
  ///
  /// In en, this message translates to:
  /// **'True. Polycystic Ovary Syndrome is a common hormonal disorder affecting the ovaries, and irregular cycles are one of its effects.'**
  String get myth_24_answer;

  /// NEEDS HEALTH REVIEW. Source: third_description_15.
  ///
  /// In en, this message translates to:
  /// **'Irregular periods in the first few years after they start are common.'**
  String get myth_25_statement;

  /// NEEDS HEALTH REVIEW. Source: third_description_15.
  ///
  /// In en, this message translates to:
  /// **'True. Occasional irregularity is normal early on. It is worth advice if it becomes persistent or comes with worrying symptoms.'**
  String get myth_25_answer;

  /// NEEDS HEALTH REVIEW. Source: first_description_13.
  ///
  /// In en, this message translates to:
  /// **'A menstrual cup collects blood rather than absorbing it.'**
  String get myth_27_statement;

  /// NEEDS HEALTH REVIEW. Source: first_description_13.
  ///
  /// In en, this message translates to:
  /// **'True. Cups are flexible medical-grade silicone and collect the blood, unlike pads and tampons which absorb it.'**
  String get myth_27_answer;

  /// NEEDS HEALTH REVIEW. Source: second_description_1_2.
  ///
  /// In en, this message translates to:
  /// **'Ovulation is when an egg is released from the ovary.'**
  String get myth_28_statement;

  /// NEEDS HEALTH REVIEW. Source: second_description_1_2.
  ///
  /// In en, this message translates to:
  /// **'True. Knowing roughly when it happens is how the fertile window is worked out.'**
  String get myth_28_answer;

  /// NEEDS HEALTH REVIEW. Source: first_description_8.
  ///
  /// In en, this message translates to:
  /// **'Vaginal itching or thick, foul-smelling discharge is a reason to see a doctor.'**
  String get myth_31_statement;

  /// NEEDS HEALTH REVIEW. Source: first_description_8.
  ///
  /// In en, this message translates to:
  /// **'True. Along with curd-like white discharge, these are listed as signs to seek medical advice about.'**
  String get myth_31_answer;

  /// NEEDS HEALTH REVIEW. Source: faq_a5.
  ///
  /// In en, this message translates to:
  /// **'Writing down the first day of each period helps you learn your own pattern.'**
  String get myth_32_statement;

  /// NEEDS HEALTH REVIEW. Source: faq_a5.
  ///
  /// In en, this message translates to:
  /// **'True. Over time, tracking shows how long your cycle usually is and roughly when the next period is due.'**
  String get myth_32_answer;

  /// NEEDS HEALTH REVIEW. Source: EXTERNAL: NHS periods page; UNICEF Pakistan myth list.
  ///
  /// In en, this message translates to:
  /// **'You should not bathe or wash during your period.'**
  String get myth_35_statement;

  /// NEEDS HEALTH REVIEW. Source: EXTERNAL: NHS periods page; UNICEF Pakistan myth list.
  ///
  /// In en, this message translates to:
  /// **'Washing is safe and important during a period. A warm bath can relax the body and ease discomfort.'**
  String get myth_35_answer;

  /// NEEDS HEALTH REVIEW. Source: EXTERNAL: NHS periods page.
  ///
  /// In en, this message translates to:
  /// **'You should not wash your hair during your period.'**
  String get myth_36_statement;

  /// NEEDS HEALTH REVIEW. Source: EXTERNAL: NHS periods page.
  ///
  /// In en, this message translates to:
  /// **'There is no reason to avoid washing your hair. This is one of several restrictions with no basis behind them.'**
  String get myth_36_answer;

  /// NEEDS HEALTH REVIEW. Source: EXTERNAL: UNICEF Pakistan myth list; cf. first_description_22.
  ///
  /// In en, this message translates to:
  /// **'You should not drink cold water during your period.'**
  String get myth_37_statement;

  /// NEEDS HEALTH REVIEW. Source: EXTERNAL: UNICEF Pakistan myth list; cf. first_description_22.
  ///
  /// In en, this message translates to:
  /// **'There is no medical reason to avoid cold water. Staying hydrated matters more.'**
  String get myth_37_answer;

  /// NEEDS HEALTH REVIEW. Source: EXTERNAL: NHS periods page; cf. second_description_5.
  ///
  /// In en, this message translates to:
  /// **'Periods are supposed to be very painful, so severe pain is normal.'**
  String get myth_38_statement;

  /// NEEDS HEALTH REVIEW. Source: EXTERNAL: NHS periods page; cf. second_description_5.
  ///
  /// In en, this message translates to:
  /// **'Mild to moderate cramping is common, but severe pain is not normal and should not be ignored.'**
  String get myth_38_answer;

  /// NEEDS HEALTH REVIEW. Source: EXTERNAL: NHS periods page; cf. faq_a2.
  ///
  /// In en, this message translates to:
  /// **'Bleeding for anywhere between 2 and 7 days is within the normal range.'**
  String get myth_39_statement;

  /// NEEDS HEALTH REVIEW. Source: EXTERNAL: NHS periods page; cf. faq_a2.
  ///
  /// In en, this message translates to:
  /// **'True. Most people bleed for two to seven days, and cycles of 21 to 35 days are considered regular.'**
  String get myth_39_answer;

  /// NEEDS HEALTH REVIEW. Source: EXTERNAL: NHS periods page.
  ///
  /// In en, this message translates to:
  /// **'A whole period loses only about 1 to 5 tablespoons of blood in total.'**
  String get myth_40_statement;

  /// NEEDS HEALTH REVIEW. Source: EXTERNAL: NHS periods page.
  ///
  /// In en, this message translates to:
  /// **'True. It often looks like far more, but a typical period is about 20 to 90 ml across all the days together.'**
  String get myth_40_answer;

  /// No description provided for @myth_continue.
  ///
  /// In en, this message translates to:
  /// **'Keep going'**
  String get myth_continue;

  /// No description provided for @myth_continue_prompt.
  ///
  /// In en, this message translates to:
  /// **'{remaining} more statements to try'**
  String myth_continue_prompt(String remaining);

  /// No description provided for @myth_done_title.
  ///
  /// In en, this message translates to:
  /// **'You have seen them all'**
  String get myth_done_title;

  /// No description provided for @myth_done_body.
  ///
  /// In en, this message translates to:
  /// **'You have worked through every statement. Start again from the beginning whenever you like.'**
  String get myth_done_body;

  /// No description provided for @myth_start_over.
  ///
  /// In en, this message translates to:
  /// **'Start from the beginning'**
  String get myth_start_over;

  /// No description provided for @myth_round_done.
  ///
  /// In en, this message translates to:
  /// **'Round complete'**
  String get myth_round_done;

  /// No description provided for @myth_eyebrow.
  ///
  /// In en, this message translates to:
  /// **'MYTH BUSTER'**
  String get myth_eyebrow;

  /// No description provided for @myth_cat_cycle.
  ///
  /// In en, this message translates to:
  /// **'The cycle'**
  String get myth_cat_cycle;

  /// No description provided for @myth_cat_hygiene.
  ///
  /// In en, this message translates to:
  /// **'Hygiene and care'**
  String get myth_cat_hygiene;

  /// No description provided for @myth_cat_food.
  ///
  /// In en, this message translates to:
  /// **'Food and nutrition'**
  String get myth_cat_food;

  /// No description provided for @myth_cat_stigma.
  ///
  /// In en, this message translates to:
  /// **'Stigma and superstition'**
  String get myth_cat_stigma;

  /// No description provided for @myth_cat_health.
  ///
  /// In en, this message translates to:
  /// **'Health signs'**
  String get myth_cat_health;

  /// No description provided for @myth_cat_products.
  ///
  /// In en, this message translates to:
  /// **'Period products'**
  String get myth_cat_products;

  /// No description provided for @myth_cat_fertility.
  ///
  /// In en, this message translates to:
  /// **'Fertility'**
  String get myth_cat_fertility;

  /// No description provided for @myth_your_answers.
  ///
  /// In en, this message translates to:
  /// **'Your answers'**
  String get myth_your_answers;

  /// No description provided for @myth_correct_answer.
  ///
  /// In en, this message translates to:
  /// **'Correct answer'**
  String get myth_correct_answer;

  /// NEEDS HEALTH REVIEW. Source: second_description_11. Approved in the reviewer's second pass.
  ///
  /// In en, this message translates to:
  /// **'You should wash your hands with soap before and after changing a pad.'**
  String get myth_14_statement;

  /// NEEDS HEALTH REVIEW. Source: second_description_11. Approved in the reviewer's second pass.
  ///
  /// In en, this message translates to:
  /// **'True. It stops bacteria passing between your hands and your genital area.'**
  String get myth_14_answer;

  /// NEEDS HEALTH REVIEW. Source: first_description_1_3. Approved in the reviewer's second pass.
  ///
  /// In en, this message translates to:
  /// **'A few drops of blood between periods is called spotting.'**
  String get myth_30_statement;

  /// NEEDS HEALTH REVIEW. Source: first_description_1_3. Approved in the reviewer's second pass.
  ///
  /// In en, this message translates to:
  /// **'True. Spotting is light bleeding between regular periods, much lighter than a period itself.'**
  String get myth_30_answer;

  /// No description provided for @logged_periods.
  ///
  /// In en, this message translates to:
  /// **'Logged periods'**
  String get logged_periods;

  /// No description provided for @no_periods_logged_yet.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged yet.'**
  String get no_periods_logged_yet;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @remove_period_title.
  ///
  /// In en, this message translates to:
  /// **'Remove this period?'**
  String get remove_period_title;

  /// No description provided for @remove_period_message.
  ///
  /// In en, this message translates to:
  /// **'The period logged on {date} will be removed and your predictions recalculated. This cannot be undone.'**
  String remove_period_message(String date);

  /// No description provided for @period_removed.
  ///
  /// In en, this message translates to:
  /// **'Period removed'**
  String get period_removed;

  /// No description provided for @period_remove_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not remove the period. Please try again.'**
  String get period_remove_failed;

  /// No description provided for @bleed_days_label.
  ///
  /// In en, this message translates to:
  /// **'{days} days of bleeding'**
  String bleed_days_label(String days);

  /// No description provided for @delete_my_data.
  ///
  /// In en, this message translates to:
  /// **'Delete my data'**
  String get delete_my_data;

  /// No description provided for @delete_data_heading.
  ///
  /// In en, this message translates to:
  /// **'This removes everything, permanently'**
  String get delete_data_heading;

  /// No description provided for @delete_removes_periods.
  ///
  /// In en, this message translates to:
  /// **'Every period you have logged, and your calendar history'**
  String get delete_removes_periods;

  /// No description provided for @delete_removes_settings.
  ///
  /// In en, this message translates to:
  /// **'Your cycle settings, predictions and reminders'**
  String get delete_removes_settings;

  /// No description provided for @delete_removes_profile.
  ///
  /// In en, this message translates to:
  /// **'Your name, phone number, date of birth and location'**
  String get delete_removes_profile;

  /// No description provided for @delete_removes_account.
  ///
  /// In en, this message translates to:
  /// **'Your account itself — you will not be able to log in again'**
  String get delete_removes_account;

  /// No description provided for @delete_cannot_be_undone.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone. To use Ananya again you would have to create a new account and start your cycle history from the beginning.'**
  String get delete_cannot_be_undone;

  /// No description provided for @delete_confirm_with_password.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to confirm it is you.'**
  String get delete_confirm_with_password;

  /// No description provided for @delete_needs_connection.
  ///
  /// In en, this message translates to:
  /// **'You need an internet connection to do this.'**
  String get delete_needs_connection;

  /// No description provided for @delete_button.
  ///
  /// In en, this message translates to:
  /// **'Delete everything'**
  String get delete_button;

  /// No description provided for @delete_in_progress.
  ///
  /// In en, this message translates to:
  /// **'Deleting your data...'**
  String get delete_in_progress;

  /// No description provided for @delete_success.
  ///
  /// In en, this message translates to:
  /// **'Your data has been deleted.'**
  String get delete_success;

  /// No description provided for @delete_wrong_password.
  ///
  /// In en, this message translates to:
  /// **'That password is not correct.'**
  String get delete_wrong_password;

  /// No description provided for @delete_no_connection.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. Nothing was deleted. Check your internet and try again.'**
  String get delete_no_connection;

  /// No description provided for @delete_too_many_attempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a few minutes and try again.'**
  String get delete_too_many_attempts;

  /// No description provided for @delete_failed.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Your data has not been deleted.'**
  String get delete_failed;

  /// No description provided for @delete_partial_warning.
  ///
  /// In en, this message translates to:
  /// **'Your data was removed but the account could not be closed. Please try again when you have a better connection.'**
  String get delete_partial_warning;

  /// No description provided for @greeting_hello.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String greeting_hello(String name);

  /// No description provided for @watch_on_youtube.
  ///
  /// In en, this message translates to:
  /// **'Watch on YouTube'**
  String get watch_on_youtube;

  /// No description provided for @video_could_not_load.
  ///
  /// In en, this message translates to:
  /// **'The video could not be played here.'**
  String get video_could_not_load;

  /// No description provided for @estimate_accuracy_title.
  ///
  /// In en, this message translates to:
  /// **'How reliable is this prediction?'**
  String get estimate_accuracy_title;

  /// No description provided for @no_period_data_yet.
  ///
  /// In en, this message translates to:
  /// **'No period information added yet'**
  String get no_period_data_yet;

  /// No description provided for @periods_added_of_total.
  ///
  /// In en, this message translates to:
  /// **'{added} of {total} periods added'**
  String periods_added_of_total(String added, String total);

  /// No description provided for @add_earlier_period_hint.
  ///
  /// In en, this message translates to:
  /// **'If you remember an earlier period date, you can add it now.'**
  String get add_earlier_period_hint;

  /// No description provided for @estimate_based_on_cycles.
  ///
  /// In en, this message translates to:
  /// **'Based on {count} cycles'**
  String estimate_based_on_cycles(String count);

  /// No description provided for @estimate_variation.
  ///
  /// In en, this message translates to:
  /// **'approximately ±{days} days'**
  String estimate_variation(String days);

  /// No description provided for @probahini_privacy_note.
  ///
  /// In en, this message translates to:
  /// **'Your questions are saved without your name, to help us improve Probahini.'**
  String get probahini_privacy_note;

  /// No description provided for @hint_your_name.
  ///
  /// In en, this message translates to:
  /// **'Write your name'**
  String get hint_your_name;

  /// No description provided for @hint_phone_or_email.
  ///
  /// In en, this message translates to:
  /// **'01XXXXXXXXX or your email'**
  String get hint_phone_or_email;

  /// No description provided for @hint_phone.
  ///
  /// In en, this message translates to:
  /// **'01XXXXXXXXX'**
  String get hint_phone;

  /// No description provided for @hint_email.
  ///
  /// In en, this message translates to:
  /// **'name@example.com'**
  String get hint_email;

  /// No description provided for @hint_password.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get hint_password;

  /// No description provided for @hint_new_password.
  ///
  /// In en, this message translates to:
  /// **'Enter a new password'**
  String get hint_new_password;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
