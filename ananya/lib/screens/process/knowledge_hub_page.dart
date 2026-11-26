import 'dart:io';
import 'package:ananya/widgets/app_loader.dart';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ananya/l10n/app_localizations.dart';
import 'package:ananya/models/knowledge_nexus_data.dart';
import 'package:ananya/utils/constants.dart';
import 'package:ananya/utils/app_dialog.dart';

// =======================================================
// ============= TEXTBOOK / COVER DATA ===================
// =======================================================
// Each textbook holds a Bangla and an English variant (cover + pdf). The
// slider below picks the variant that matches the app's current language.
// To add more later, just append another _Textbook entry here.
class _Textbook {
  final String titleEn;
  final String titleBn;
  final String coverEn;
  final String coverBn;
  final String pdfEn;
  final String pdfBn;

  const _Textbook({
    required this.titleEn,
    required this.titleBn,
    required this.coverEn,
    required this.coverBn,
    required this.pdfEn,
    required this.pdfBn,
  });

  String title(bool isBangla) => isBangla ? titleBn : titleEn;
  String cover(bool isBangla) => isBangla ? coverBn : coverEn;
  String pdf(bool isBangla) => isBangla ? pdfBn : pdfEn;
}

const List<_Textbook> _textbooks = [
  _Textbook(
    titleEn: 'Class 5 - Elementary Science',
    titleBn: 'পঞ্চম শ্রেণি - প্রাথমিক বিজ্ঞান',
    coverEn: 'assets/images/Cover page_Class 5_Elementary Science_EM.jpg',
    coverBn: 'assets/images/Cover page_Class 5_Elementary Science_BM.jpg',
    pdfEn: 'assets/pdf/Class 5_Elementary Science_EM.pdf',
    pdfBn: 'assets/pdf/Class 5_Elementary Science_BM.pdf',
  ),
  _Textbook(
    titleEn: 'Class 6 - Home Science',
    titleBn: 'ষষ্ঠ শ্রেণি - গার্হস্থ্য বিজ্ঞান',
    coverEn: 'assets/images/Cover page_Class 6_Home Science_EV.jpg',
    coverBn: 'assets/images/Cover page_Class 6_Home Science_BV.jpg',
    pdfEn: 'assets/pdf/Class 6_Home Science_EV.pdf',
    pdfBn: 'assets/pdf/Class 6_Home Science_BV.pdf',
  ),
  _Textbook(
    titleEn: 'Class 6 - Physical Education and Health',
    titleBn: 'ষষ্ঠ শ্রেণি - শারীরিক শিক্ষা ও স্বাস্থ্য',
    coverEn:
        'assets/images/Cover page_Class 6_Physical Education and Health_EV.jpg',
    coverBn:
        'assets/images/Cover page_Class 6_Physical Education and Health_BV.jpg',
    pdfEn: 'assets/pdf/Class 6_Physical Education and Health_EV.pdf',
    pdfBn: 'assets/pdf/Class 6_Physical Education and Health_BV.pdf',
  ),
  _Textbook(
    titleEn: 'Class 8 - Home Science',
    titleBn: 'অষ্টম শ্রেণি - গার্হস্থ্য বিজ্ঞান',
    coverEn: 'assets/images/Cover page_Class 8_Home Science_EV.jpg',
    coverBn: 'assets/images/Cover page_Class 8_Home Science_BV.jpg',
    pdfEn: 'assets/pdf/Class 8_Home Science_EV.pdf',
    pdfBn: 'assets/pdf/Class 8_Home Science_BV.pdf',
  ),
  _Textbook(
    titleEn: 'Class 9-10 - Physical Education',
    titleBn: 'নবম-দশম শ্রেণি - শারীরিক শিক্ষা',
    // Note: the Bangla cover has no _BV suffix, and the English PDF has a
    // lowercase "education" plus a space before "EV" — matched exactly.
    coverEn: 'assets/images/Cover page_Class 9-10_Physical Education_EV.jpg',
    coverBn: 'assets/images/Cover page_Class 9-10_Physical Education.jpg',
    pdfEn: 'assets/pdf/Class 9-10_Physical education_ EV.pdf',
    pdfBn: 'assets/pdf/Class 9-10_Physical Education_BV.pdf',
  ),
  _Textbook(
    titleEn: 'Class 9-10 - Science',
    titleBn: 'নবম-দশম শ্রেণি - বিজ্ঞান',
    coverEn: 'assets/images/Cover page_Class 9-10_Science_EM.jpg',
    coverBn: 'assets/images/Cover page_Class 9-10_Science_BM.jpg',
    pdfEn: 'assets/pdf/Class 9-10_Science_EV.pdf',
    pdfBn: 'assets/pdf/Class 9-10_Science_BV.pdf',
  ),
];

class KnowledgeHubPage extends StatefulWidget {
  const KnowledgeHubPage({super.key});

  @override
  State<KnowledgeHubPage> createState() => _KnowledgeHubPageState();
}

class _KnowledgeHubPageState extends State<KnowledgeHubPage> {
  int _selectedIndex = 1; // Default: Knowledge Hub

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
        break; // already on Knowledge Hub
      case 2:
        Navigator.pushReplacementNamed(context, '/faq');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = KnowledgeItemProvider.getKnowledgeItems(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F0E4), // Same as LandingPage
      body: CustomScrollView(
        slivers: [
          // ================= COLLAPSING BANNER =================
          // The illustration shrinks as the user scrolls and then scrolls
          // fully away with the content. The title + back button stay pinned
          // so navigation is always available.
          SliverAppBar(
            pinned: true,
            expandedHeight: 340,
            backgroundColor: const Color(0xFFF8F0E4),
            surfaceTintColor: const Color(0xFFF8F0E4),
            elevation: 0,
            iconTheme: const IconThemeData(color: Color(0xFF151435)),
            title: Text(
              AppLocalizations.of(context)!.knowledge_hub,
              style: const TextStyle(color: Color(0xFF151435)),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Padding(
                // Push the image below the pinned title bar (status bar +
                // toolbar) so the "Knowledge hub" title sits on the cream
                // background with a clear margin, never on top of the image.
                padding: EdgeInsets.only(
                  top: kToolbarHeight + MediaQuery.of(context).padding.top,
                ),
                child: Image.asset(
                  'assets/images/knowledgehub.png',
                  width: double.infinity,
                  // Show the whole banner illustration (nothing cropped).
                  fit: BoxFit.contain,
                  cacheWidth: 1080,
                ),
              ),
            ),
          ),

          // ================= TEXTBOOK COVER SLIDER =================
          const SliverToBoxAdapter(
            child: TextbookSlider(),
          ),

          // ================= MYTH QUIZ =================
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: _MythQuizCard(),
            ),
          ),

          // ================= LIST / Knowledge Hub =================
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => KnowledgeHubItemCard(item: items[index]),
                childCount: items.length,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color(0xFFEA2249),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: ""),
          BottomNavigationBarItem(icon: Icon(Icons.language), label: ""),
          BottomNavigationBarItem(icon: Icon(Icons.help_outline), label: ""),
        ],
      ),
    );
  }
}

// =======================================================
// ================= ITEM CARD ============================
// =======================================================

class KnowledgeHubItemCard extends StatelessWidget {
  final Map<String, String> item;

  const KnowledgeHubItemCard({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final isBangla = Localizations.localeOf(context).languageCode == 'bn';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF151435).withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      // The whole card opens the article — a question with a picture reads as
      // tappable, so requiring a separate button was needless friction.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Navigator.pushNamed(
            context,
            '/knowledge-nexus-info',
            arguments: [item['id'], item],
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
            return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _thumbnail(context, item['hero_image']!, constraints.maxWidth),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item['question']!,
                      // No maxLines: questions were being cut off mid-word,
                      // which is the one thing a question must not do.
                      style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF151435),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Same "Read →" as the home-screen cards. The filled red
                    // disc that used to sit here said nothing about what the
                    // card did and took 40px from the question, which is the
                    // one part that must never be cut short.
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isBangla ? 'পড়ুন' : 'Read',
                          style: const TextStyle(
                            color: PRIMARY_COLOR,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward,
                          size: 13,
                          color: PRIMARY_COLOR,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
            },
          ),
        ),
      ),
    );
  }

  /// The illustration beside a question.
  ///
  /// Two things were wrong with the fixed `Image.asset(width: 132, height: 118,
  /// cacheWidth: 264, cacheHeight: 236)` this replaces.
  ///
  /// Setting BOTH cacheWidth and cacheHeight decodes the file to exactly those
  /// pixels and stretches it to fit them — aspect ratio is not preserved. The
  /// 29 hero images run from 0.93 to 3.81 in aspect against a forced 1.119, so
  /// they reached the painter already distorted: 33.png stretched 21% wider,
  /// 28.png squashed to 29% of its shape. BoxFit.cover then cropped a bitmap
  /// that was already the wrong shape, which is why the artwork looked
  /// squeezed. Only cacheWidth is set now, and the decoder scales height to
  /// match.
  ///
  /// And 264 assumed a 2x screen. Most phones here are 3x, where a 132pt box
  /// is 396 device pixels — so every illustration was decoded below the size
  /// it was drawn at and upscaled. The width now comes from the real device
  /// pixel ratio.
  static Widget _thumbnail(
      BuildContext context, String asset, double available) {
    // A third of the card rather than a fixed 132: that was 41% of the row on
    // a 320px phone and a stamp on a tablet. Clamped so the question keeps
    // room to breathe at either extreme.
    final width = (available * 0.34).clamp(104.0, 168.0);
    final height = width / (132 / 118);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: width,
        height: height,
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          cacheWidth: (width * MediaQuery.devicePixelRatioOf(context)).round(),
        ),
      ),
    );
  }
}


// =======================================================
// ============= TEXTBOOK COVER SLIDER ===================
// =======================================================
// A horizontal, language-aware slider of textbook covers. Each cover is a
// tappable card (cover image + title). Tapping flips + zooms the card into a
// full-screen PDF module (see _pdfFlipRoute / TextbookPdfViewer).

/// Invitation into the true-or-false quiz, sitting where she is already
/// deciding what to read.
///
/// Given the weight of a real card rather than a banner strip: it is the only
/// thing on this screen that is answered rather than read, and it competes for
/// attention with a row of textbook covers directly above it.
class _MythQuizCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/myth-buster'),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: PRIMARY_COLOR.withValues(alpha: 0.16)),
        ),
        child: Stack(
          children: [
            // Oversized quote mark bleeding off the corner — the same device
            // the question screen opens with, so the card previews what is
            // behind it.
            Positioned(
              right: -14,
              top: -34,
              child: Text(
                '“',
                style: TextStyle(
                  fontSize: 150,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: PRIMARY_COLOR.withValues(alpha: 0.07),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: PRIMARY_COLOR.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          loc.myth_true,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: PRIMARY_COLOR,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: ACCENT.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          loc.myth_false,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: ACCENT.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    loc.myth_quiz_title,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                      color: ACCENT,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    loc.myth_quiz_intro,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: ACCENT.withValues(alpha: 0.62),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 11),
                        decoration: BoxDecoration(
                          color: PRIMARY_COLOR,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              loc.myth_quiz_start,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward,
                                size: 15, color: Colors.white),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TextbookSlider extends StatefulWidget {
  const TextbookSlider({super.key});

  @override
  State<TextbookSlider> createState() => _TextbookSliderState();
}

class _TextbookSliderState extends State<TextbookSlider> {
  final ScrollController _controller = ScrollController();
  static const double _scrollAmount = 164.0; // card width (150) + spacing (14)

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scrollBy(double delta) {
    if (!_controller.hasClients) return;
    _controller.animateTo(
      _controller.offset + delta,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBangla = Localizations.localeOf(context).languageCode == 'bn';
    final sectionTitle =
        isBangla ? 'পাঠ্যপুস্তক কি বলছে?' : 'What do the text books say?';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            sectionTitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF151435),
            ),
          ),
        ),
        SizedBox(
          height: 252,
          child: Stack(
            children: [
              ListView.separated(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 40),
                itemCount: _textbooks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) => _TextbookCard(
                  book: _textbooks[index],
                  isBangla: isBangla,
                ),
              ),
              // Left arrow (centered over the cover, above the title).
              Positioned(
                left: 0,
                top: 0,
                bottom: 52,
                child: Container(
                  width: 40,
                  alignment: Alignment.center,
                  color: Colors.transparent,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios),
                    onPressed: () => _scrollBy(-_scrollAmount),
                  ),
                ),
              ),
              // Right arrow.
              Positioned(
                right: 0,
                top: 0,
                bottom: 52,
                child: Container(
                  width: 40,
                  alignment: Alignment.center,
                  color: Colors.transparent,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_forward_ios),
                    onPressed: () => _scrollBy(_scrollAmount),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Textbook content is for signed-in users only. Mirrors the gate used by the
/// period-tracking feature (see _safeGetUserStatus in landing.dart): a user is
/// signed in when both a userId and a token are stored. The check is kept
/// local — opening a PDF should not depend on the backend being reachable.
Future<bool> _isSignedIn() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    final token = prefs.getString('token');
    return userId != null && token != null;
  } catch (e) {
    debugPrint('Sign-in check failed: $e');
    return false;
  }
}

void _showLoginPrompt(BuildContext context) {
  final loc = AppLocalizations.of(context);
  showAppDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        loc?.please_login_to_continue ?? 'Please sign up or log in to continue',
        style: const TextStyle(
            fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF151435)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(loc?.cancel ?? 'Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEA2249),
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
            minimumSize: const Size(120, 40),
          ),
          onPressed: () {
            Navigator.pop(ctx);
            Navigator.pushNamed(context, '/signup');
          },
          child: Text(
            loc?.sign_up ?? 'Sign up',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}

class _TextbookCard extends StatelessWidget {
  final _Textbook book;
  final bool isBangla;

  const _TextbookCard({required this.book, required this.isBangla});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (!await _isSignedIn()) {
          if (context.mounted) _showLoginPrompt(context);
          return;
        }
        if (context.mounted) {
          Navigator.of(context).push(_pdfFlipRoute(book, isBangla));
        }
      },
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The textbook covers have a thin printed frame around their edge.
            // Overscan the image slightly (scale > 1) and clip to the rounded
            // card so that frame is cropped off — leaving a clean borderless
            // look. Content (title/pictures) sits inside, so nothing important
            // is lost.
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 150,
                height: 200,
                child: Transform.scale(
                  scale: 1.06,
                  child: Image.asset(
                    book.cover(isBangla),
                    width: 150,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              book.title(isBangla),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF151435),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// A custom route that flips (Y-axis) and zooms the tapped card into the
// full-screen PDF module, and reverses the same animation on close.
Route<void> _pdfFlipRoute(_Textbook book, bool isBangla) {
  return PageRouteBuilder<void>(
    opaque: false, // keep the app page visible (blurred) behind the module
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 550),
    reverseTransitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (_, __, ___) => TextbookPdfViewer(
      title: book.title(isBangla),
      pdfAsset: book.pdf(isBangla),
    ),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return Stack(
        children: [
          // Blur + dim the app background so focus stays on the PDF.
          // Tapping outside the module closes it.
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: AnimatedBuilder(
                animation: curved,
                builder: (context, _) {
                  final v = curved.value.clamp(0.0, 1.0);
                  return BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6 * v, sigmaY: 6 * v),
                    child: Container(
                      color: Color.fromRGBO(0, 0, 0, 0.25 * v),
                    ),
                  );
                },
              ),
            ),
          ),
          // The module flips (Y-axis) and zooms in.
          AnimatedBuilder(
            animation: curved,
            child: child,
            builder: (context, child) {
              final v = curved.value;
              final flip = (1 - v) * (math.pi / 2); // 90° -> 0°
              final scale = 0.7 + 0.3 * v; // zoom in
              return Opacity(
                opacity: v.clamp(0.0, 1.0),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0015) // perspective
                    ..rotateY(flip)
                    ..scaleByDouble(scale, scale, 1.0, 1.0),
                  child: child,
                ),
              );
            },
          ),
        ],
      );
    },
  );
}

// =======================================================
// ================= PDF MODULE ==========================
// =======================================================
// flutter_pdfview needs a real file path, so the bundled asset PDF is copied
// to a temp file first, then rendered. Includes a close (X) button.

class TextbookPdfViewer extends StatefulWidget {
  final String title;
  final String pdfAsset;

  const TextbookPdfViewer({
    super.key,
    required this.title,
    required this.pdfAsset,
  });

  @override
  State<TextbookPdfViewer> createState() => _TextbookPdfViewerState();
}

class _TextbookPdfViewerState extends State<TextbookPdfViewer> {
  String? _localPath;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _preparePdf();
  }

  Future<void> _preparePdf() async {
    try {
      final data = await rootBundle.load(widget.pdfAsset);
      final dir = await getTemporaryDirectory();
      final fileName = widget.pdfAsset.split('/').last;
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      if (!mounted) return;
      setState(() => _localPath = file.path);
    } catch (e) {
      debugPrint('PDF load error: $e');
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Transparent scaffold so the blurred app background shows around the
    // module. The module itself is inset from the screen edges.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 30),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                color: const Color(0xFFF8F0E4),
                child: Column(
                  children: [
                    // Header: title + close (X)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF151435),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close,
                                color: Color(0xFF151435)),
                            tooltip: MaterialLocalizations.of(context)
                                .closeButtonTooltip,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: _buildContent()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_failed) {
      final isBangla = Localizations.localeOf(context).languageCode == 'bn';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            isBangla ? 'পিডিএফ খোলা যায়নি।' : 'Could not open the PDF.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF151435)),
          ),
        ),
      );
    }
    if (_localPath == null) {
      return const Center(
        child: AppLoader(),
      );
    }
    return PDFView(
      filePath: _localPath!,
      swipeHorizontal: false, // vertical scroll
      pageSnap: false, // don't snap to each page
      pageFling: false, // free, continuous flinging
      autoSpacing: false, // pages flow continuously with no gaps
    );
  }
}
