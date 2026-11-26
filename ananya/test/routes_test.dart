import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Named routes are strings, so nothing checks them.
///
/// `Navigator.pushNamed(context, '/userhome')` compiles cleanly whether or not
/// `/userhome` exists. When it does not, the button simply does nothing — no
/// crash, no log, no hint. Exactly that shipped: two navigation buttons in the
/// knowledge hub were dead for weeks because the route was `/home`, and it was
/// only found by reading every route by hand.
///
/// These tests are that reading, automated. They parse the source rather than
/// running the app, because the bug is in code paths a widget test would have
/// to reach by tapping — and the ones that were broken are the ones nobody
/// tapped.
void main() {
  final registered = _registeredRoutes();
  final navigations = _navigations();

  test('every named route the app navigates to is registered', () {
    final dead = navigations
        .where((n) => !registered.contains(n.route))
        .map((n) => '  ${n.file}:${n.line}  ->  ${n.route}')
        .toList()
      ..sort();

    expect(
      dead,
      isEmpty,
      reason: 'These navigate to routes that are not registered in '
          'lib/main.dart, so they silently do nothing when tapped:\n'
          '${dead.join('\n')}',
    );
  });

  test('every registered route is reachable', () {
    // Routes reached without a pushNamed call: the app opens on SplashScreen,
    // which decides between these two.
    const entryPoints = {'/home', '/signin'};

    // Known-unreachable, deliberately still in the build.
    //
    // These two screens are the Django-backed history views, superseded for
    // the girl's own history by the Firestore path in user_home. They are not
    // dead code: they hold `request-data-purge`, which is the only way to
    // delete an account's data from inside the app, and the cohort view is the
    // only history a field worker can see. Nothing links to either, so both
    // are currently unusable — a missing link, not surplus code.
    //
    // /forget-password is parked on purpose, not forgotten. Its link on the
    // sign-in screen is hidden because nothing behind it can work: it posts to
    // Django's reset endpoint, which is switched off — the original set a new
    // password from a phone number alone, so anyone who knew a girl's number
    // could take her account. Even switched on it would write to Postgres,
    // while sign-in now goes through Firebase, so it would change nothing she
    // logs in with.
    //
    // The screen stays for the phone-OTP reset being built next release.
    //
    // Wire them up or delete them, then take them off this list. Anything not
    // named here fails the test, so this cannot grow by accident.
    const knownUnreachable = {
      '/history/individual',
      '/history/cohort',
      '/forget-password',
    };

    final targeted = navigations.map((n) => n.route).toSet();
    final orphans = registered
        .where((r) =>
            !targeted.contains(r) &&
            !entryPoints.contains(r) &&
            !knownUnreachable.contains(r))
        .toList()
      ..sort();

    expect(
      orphans,
      isEmpty,
      reason: 'These routes are registered but nothing navigates to them, so '
          'the screens behind them are dead weight in the build:\n'
          '${orphans.map((r) => '  $r').join('\n')}',
    );
  });

  test('the route table was actually found', () {
    // Guards the tests above: if main.dart is reformatted so the patterns stop
    // matching, both would pass on an empty set and quietly stop checking.
    expect(registered.length, greaterThan(10));
    expect(navigations.length, greaterThan(10));
  });
}

Set<String> _registeredRoutes() {
  final main = File('lib/main.dart').readAsStringSync();
  final table = RegExp(r"routes:\s*\{").firstMatch(main);
  if (table == null) return {};
  return RegExp("^\\s*'(/[^']*)':", multiLine: true)
      .allMatches(main.substring(table.end))
      .map((m) => m.group(1)!)
      .toSet();
}

class _Nav {
  final String file;
  final int line;
  final String route;
  _Nav(this.file, this.line, this.route);
}

/// Both call styles: `pushNamed(context, '/x')` and `.of(context).pushNamed('/x')`.
///
/// Matched against whole file contents, not line by line — these calls are
/// routinely wrapped across four lines by the formatter, and a per-line scan
/// silently sees none of them.
///
/// Only literal routes are checked. A route held in a variable (see
/// `skipRoute` in custom_app_bar_with_progress.dart) cannot be resolved by
/// reading the source, so those are neither verified nor reported here.
final _navPatterns = [
  RegExp(r"push(?:Named|ReplacementNamed|NamedAndRemoveUntil)\(\s*context\s*,"
      r"\s*'(/[^']*)'"),
  RegExp(r"push(?:Named|ReplacementNamed|NamedAndRemoveUntil)\(\s*'(/[^']*)'"),
];

List<_Nav> _navigations() {
  final found = <_Nav>[];
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final rel = entity.path.replaceAll(r'\', '/');
    final source = entity.readAsStringSync();
    for (final pattern in _navPatterns) {
      for (final m in pattern.allMatches(source)) {
        final line = '\n'.allMatches(source.substring(0, m.start)).length + 1;
        found.add(_Nav(rel, line, m.group(1)!));
      }
    }
  }
  return found;
}
