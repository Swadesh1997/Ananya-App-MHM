import 'package:flutter_test/flutter_test.dart';

import 'package:ananya/widgets/rich_description.dart';

void main() {
  group('structure detection', () {
    test('a "Label: body" line becomes an openable row', () {
      final n = DescriptionParser.parse(
          'The follicular phase: Following your period, your body enters the '
          'follicular phase and hormones stimulate the growth of follicles.');
      expect(n.length, 1);
      expect(n.first.isExpandable, isTrue);
      expect(n.first.text, 'The follicular phase');
      expect(n.first.body, startsWith('Following your period'));
    });

    test('bullet markers and tabs are stripped', () {
      final n = DescriptionParser.parse(
          '•\tIrregular periods: Cycles that occur less than 21 days apart or '
          'more than 35 days apart are considered irregular.');
      expect(n.length, 1);
      expect(n.first.isExpandable, isTrue);
      expect(n.first.text, 'Irregular periods');
    });

    test('Bangla "label (english): body" bullets parse the same way', () {
      final n = DescriptionParser.parse(
          '•\tফলিকুলার ধাপ (the follicular phase): পিরিয়ড শেষ হওয়ার পরপরই '
          'আপনার শরীর ফলিকুলার ধাপে প্রবেশ করে এবং হরমোন কাজ শুরু করে।');
      expect(n.length, 1);
      expect(n.first.isExpandable, isTrue);
      expect(n.first.text, 'ফলিকুলার ধাপ (the follicular phase)');
    });

    test('a colon inside a real sentence is NOT treated as a heading', () {
      const line =
          'The materials used to manage menstruation can be divided into two '
          'main categories: single-use and reusable products.';
      final n = DescriptionParser.parse(line);
      expect(n.length, 1);
      expect(n.first.isExpandable, isFalse,
          reason: 'the label would be 80 characters — too long to be a heading');
      expect(n.first.text, line);
    });

    test('a short line with no closing punctuation is a subheading', () {
      final n =
          DescriptionParser.parse('The four stages of the menstrual Cycle');
      expect(n.first.isSubheading, isTrue);
    });

    test('a trailing colon heading keeps its text but drops the colon', () {
      final n = DescriptionParser.parse('Signs of abnormal menstruation:');
      expect(n.first.isSubheading, isTrue);
      expect(n.first.text, 'Signs of abnormal menstruation');
    });

    test('an ordinary paragraph stays a paragraph', () {
      const p = 'Menstruation is a natural biological process experienced by '
          'millions of women worldwide.';
      final n = DescriptionParser.parse(p);
      expect(n.first.isParagraph, isTrue);
      expect(n.first.text, p);
    });

    test('a label with too short a body is left inline, not hidden', () {
      final n = DescriptionParser.parse('Note: see below');
      expect(n.first.isExpandable, isFalse,
          reason: 'hiding four words behind a tap is worse than showing them');
    });

    test('blank lines are dropped', () {
      final n = DescriptionParser.parse('First para.\n\n\nSecond para.');
      expect(n.length, 2);
    });
  });

  group('real content shapes', () {
    test('the four-stage block yields four openable rows', () {
      const block = 'The four stages of the menstrual Cycle\n'
          'The follicular phase: Following your period, your body enters the '
          'follicular phase as hormones stimulate follicle growth.\n'
          'Ovulation: This occurs around the midpoint of your cycle when a '
          'mature egg is released from the ovary.\n'
          'The luteal phase: After ovulation the empty follicle becomes the '
          'corpus luteum and prepares the uterus.\n'
          'Menstruation: The cycle begins with menstruation, during which the '
          'uterus sheds its lining over three to seven days.';
      final n = DescriptionParser.parse(block);
      expect(n.first.isSubheading, isTrue);
      expect(n.where((e) => e.isExpandable).length, 4,
          reason: 'one scannable heading per stage');
    });

    test('a mixed block keeps bullets that have no label', () {
      const block = 'Essential facilities for cleanliness\n'
          '-\tSupply of clean water\n'
          '-\tSoap: necessary for maintaining personal hygiene and for '
          'cleaning reusable cloths or pads.';
      final n = DescriptionParser.parse(block);
      expect(n[0].isSubheading, isTrue);
      expect(n[1].isBullet, isTrue);
      expect(n[1].text, 'Supply of clean water');
      expect(n[2].isExpandable, isTrue);
    });

    test('numbered myth lists survive as readable bullets', () {
      const block = '1.\tThe belief that menstrual blood is impure and unclean '
          'in some way.\n'
          '2.\tThe misconception that the body is purging toxins because the '
          'blood is dirty.';
      final n = DescriptionParser.parse(block);
      expect(n.length, 2);
      expect(n.every((e) => e.isBullet), isTrue);
      expect(n.first.text, startsWith('The belief'));
    });
  });
}
