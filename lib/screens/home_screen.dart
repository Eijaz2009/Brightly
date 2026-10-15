import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/scholarship_provider.dart';
import '../services/app_style.dart';
import '../services/app_translations.dart';
import '../services/auth_service.dart';
import '../widgets/scholarship_card.dart';
import '../widgets/shimmer_loading.dart';
import 'ai_chat_screen.dart';
import 'detail_screen.dart';
import 'explore_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'saved_screen.dart';

/// Nav entries. The nav bar renders selection with the single brand blue, so
/// `color` is only a fallback tint and stays muted on purpose — four saturated
/// tab colours made the bar look like a toy.
const List<NavItem> kHomeNav = <NavItem>[
  NavItem(
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    label: 'Home',
    color: AppStyle.spark,
  ),
  NavItem(
    icon: Icons.search_rounded,
    activeIcon: Icons.search_rounded,
    label: 'Explore',
    color: AppStyle.spark,
  ),
  NavItem(
    icon: Icons.bookmark_border_rounded,
    activeIcon: Icons.bookmark_rounded,
    label: 'Saved',
    color: AppStyle.spark,
  ),
  NavItem(
    icon: Icons.person_outline_rounded,
    activeIcon: Icons.person_rounded,
    label: 'Profil',
    color: AppStyle.spark,
  ),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapUser());
  }

  Future<void> _bootstrapUser() async {
    try {
      await context.read<ScholarshipProvider>().loadSession();
    } catch (e) {
      debugPrint('Error bootstrapping user session: $e');
    }
  }

  void _openAIChat() {
    final provider = context.read<ScholarshipProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AIChatScreen(
          scholarships: provider.scholarships,
          userName: AuthService.displayName(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.getBackgroundColor(context),
      body: AppStyle.background(
        context: context,
        child: Stack(
          children: [
            IndexedStack(
              index: _selectedIndex,
              children: const [
                _DashboardTab(),
                ExploreScreen(),
                SavedScreen(),
                ProfileScreen(),
              ],
            ),
            AppStyle.darkNavBar(
              context: context,
              index: _selectedIndex,
              items: kHomeNav,
              onTap: (i) => setState(() => _selectedIndex = i),
            ),
            _AiFab(onTap: _openAIChat),
          ],
        ),
      ),
    );
  }
}

/// Friendly name for the signed-in user, falling back to the email prefix.
String displayNameOf(User? user) => AuthService.displayName(user);


// ═══════════════════════════════════════════════════════════════════
// AI FAB
// ═══════════════════════════════════════════════════════════════════
class _AiFab extends StatelessWidget {
  final VoidCallback onTap;

  const _AiFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 20,
      bottom: 115,
      child: Semantics(
        button: true,
        label: 'Tanya Brightly AI',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppStyle.rMd),
            child: Ink(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppStyle.ink,
                borderRadius: BorderRadius.circular(AppStyle.rMd),
                boxShadow: AppStyle.liftShadow(context, tint: AppStyle.ink),
              ),
              child: const Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: AppStyle.lime,
                    size: 23,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Dashboard
// ═══════════════════════════════════════════════════════════════════
class _DashboardTab extends StatefulWidget {
  const _DashboardTab();

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  final _searchController = TextEditingController();
  int _carouselPage = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) return 'Selamat pagi';
    if (hour >= 11 && hour < 15) return 'Selamat siang';
    if (hour >= 15 && hour < 19) return 'Selamat sore';
    return 'Selamat malam';
  }

  void _openDetail(Map<String, dynamic> data, String heroPrefix) {
    final card = ScholarshipCard(
      scholarship: data,
      isBookmarked: false,
      onBookmarkTap: () {},
      heroPrefix: heroPrefix,
    );
    final provider = context.read<ScholarshipProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailScreen(
          flag: card.flag,
          title: card.title,
          country: card.country,
          level: card.level,
          funding: card.funding,
          deadline: card.deadline,
          officialUrl: card.url,
          isBookmarked: provider.isBookmarked(card.title),
          heroTag: card.heroTag,
          onBookmarkTap: () => provider.toggleBookmark(card.title),
        ),
      ),
    );
  }

  void _openAIChat() {
    final provider = context.read<ScholarshipProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AIChatScreen(
          scholarships: provider.scholarships,
          userName: AuthService.displayName(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScholarshipProvider>();
    final featured = provider.featuredScholarships;
    final list = provider.filteredScholarships;
    final counts = provider.levelCounts;

    return CustomScrollView(
      slivers: [
        // ── Greeting header ──
        SliverToBoxAdapter(
          child: AppHeaders.greeting(
            context: context,
            name: displayNameOf(AuthService.safeCurrentUser()),
            subtitle: _greeting(),
            bellSlot: const _BellButton(),
            searchController: _searchController,
            onSearchChanged: provider.setSearchQuery,
            onSearchCleared: provider.clearSearch,
            searchHint: AppTranslations.get('search_scholarships'),
          ),
        ),

        // ── Stat bubbles ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: _Stat(
                    icon: Icons.school_rounded,
                    value: '${counts['S1'] ?? 0}',
                    label: 'S1',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Stat(
                    icon: Icons.workspace_premium_rounded,
                    value: '${counts['S2'] ?? 0}',
                    label: 'S2',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Stat(
                    icon: Icons.auto_stories_rounded,
                    value: '${counts['S3'] ?? 0}',
                    label: 'S3',
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── AI banner ──
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        SliverToBoxAdapter(child: _AiBanner(onTap: _openAIChat)),

        // ── Featured carousel ──
        if (featured.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SizedBox(height: 26)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppStyle.sectionTitle(
                context,
                title: AppTranslations.get('featured'),
                trailingWidget: AppStyle.sparkles(size: 11, count: 3),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 14)),
          SliverToBoxAdapter(
            child: _FeaturedCarousel(
              items: featured,
              page: _carouselPage,
              onPageChanged: (p) => setState(() => _carouselPage = p),
              onItemTap: (s) => _openDetail(s, 'featured'),
            ),
          ),
        ],

        // ── List header ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
            child: AppStyle.sectionTitle(
              context,
              title: provider.searchQuery.isEmpty
                  ? 'Beasiswa terbaru'
                  : 'Hasil pencarian',
              trailing: '${list.length} ditemukan',
            ),
          ),
        ),

        // ── List body ──
        if (provider.isLoading)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.builder(
              itemCount: 4,
              itemBuilder: (context, index) => const ShimmerLoadingCard(),
            ),
          )
        else if (list.isEmpty)
          SliverToBoxAdapter(
            child: AppStyle.emptyState(
              context: context,
              icon: Icons.search_off_rounded,
              title: provider.searchQuery.isEmpty
                  ? 'Belum ada beasiswa'
                  : 'Tidak ada hasil untuk "${provider.searchQuery}"',
              subtitle: 'Coba kata kunci lain atau jelajahi kategori.',
              color: AppStyle.periwinkle,
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              AppStyle.bottomInset(context) + 84,
            ),
            sliver: SliverList.builder(
              itemCount: list.length,
              itemBuilder: (context, index) {
                final s = list[index];
                final title = ScholarshipCard.titleOf(s);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ScholarshipCard(
                    scholarship: s,
                    heroPrefix: 'latest',
                    isBookmarked: provider.isBookmarked(title),
                    onBookmarkTap: () => provider.toggleBookmark(title),
                    onTap: () => _openDetail(s, 'latest'),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Dashboard sub-widgets
// ═══════════════════════════════════════════════════════════════════

/// Stat tile: white card, hairline border, big numeral.
///
/// Coloured translucent tiles per stat is what made the old dashboard feel like
/// a toy; the reference separates cards with borders and lets the number carry
/// the weight.
class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _Stat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppStyle.getCardColor(context),
        borderRadius: BorderRadius.circular(AppStyle.rLg),
        border: Border.all(color: AppStyle.getBorderColor(context), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: AppStyle.spark),
          const SizedBox(height: 10),
          Text(value, style: AppStyle.numeral(context, size: 24)),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppStyle.font(
              context,
              size: 11,
              weight: FontWeight.w600,
              color: AppStyle.getSubtitleColor(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton();

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.safeCurrentUser()?.uid;
    if (uid == null) {
      return AppStyle.circleButton(
        context: context,
        icon: Icons.notifications_none_rounded,
        size: 42,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Object?>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        final unread = snapshot.hasData &&
            (snapshot.data?.docs.isNotEmpty ?? false);

        return AppStyle.bellButton(
          context: context,
          hasUnread: unread,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
        );
      },
    );
  }
}

class _AiBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _AiBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppStyle.rLg),
          child: Ink(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppStyle.ink,
              borderRadius: BorderRadius.circular(AppStyle.rLg),
              boxShadow: AppStyle.liftShadow(context, tint: AppStyle.ink),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppStyle.lime,
                    borderRadius: BorderRadius.circular(AppStyle.rSm),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppStyle.ink,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Tanya Brightly AI',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Rekomendasi beasiswa yang dipersonalisasi',
                        maxLines: 2,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 17,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturedCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final int page;
  final ValueChanged<int> onPageChanged;
  final void Function(Map<String, dynamic>) onItemTap;

  const _FeaturedCarousel({
    required this.items,
    required this.page,
    required this.onPageChanged,
    required this.onItemTap,
  });

  @override
  State<_FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<_FeaturedCarousel> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.88);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 208,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: widget.onPageChanged,
            itemCount: widget.items.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _FeaturedCard(
                data: widget.items[index],
                color: AppStyle
                    .blockColors[index % AppStyle.blockColors.length],
                onTap: () => widget.onItemTap(widget.items[index]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.items.length, (index) {
            final active = widget.page == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 7,
              width: active ? 24 : 7,
              decoration: BoxDecoration(
                color: active
                    ? AppStyle.ink
                    : AppStyle.ink.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color color;
  final VoidCallback onTap;

  const _FeaturedCard({
    required this.data,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = ScholarshipCard(
      scholarship: data,
      isBookmarked: false,
      onBookmarkTap: () {},
      heroPrefix: 'featured',
    );
    final onLight = color.computeLuminance() > 0.55;
    final fg = onLight ? AppStyle.ink : Colors.white;
    final fgSoft = fg.withValues(alpha: 0.78);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppStyle.rLg),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppStyle.rLg),
            boxShadow: AppStyle.liftShadow(context, tint: color),
          ),
          child: Stack(
            children: [
              // Decorative sparkle, top-right. Hero-only, never in lists.
              Positioned(
                top: -4,
                right: -2,
                child: IgnorePointer(
                  child: AppStyle.sparkles(
                    size: 16,
                    color: fg,
                    count: 2,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Hero(
                        tag: card.heroTag,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: fg.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            card.flag,
                            style: const TextStyle(fontSize: 23),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              card.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: fg,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.place_rounded,
                                    size: 12, color: fgSoft),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    '${card.country} · ${card.level}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: fgSoft,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _Pill(
                        icon: Icons.event_rounded,
                        label: card.deadline,
                        fg: fg,
                        fgSoft: fgSoft,
                      ),
                      const SizedBox(width: 8),
                      _Pill(
                        icon: Icons.payments_rounded,
                        label: card.funding,
                        fg: fg,
                        fgSoft: fgSoft,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Lihat detail',
                        style: GoogleFonts.plusJakartaSans(
                          color: fg,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(Icons.arrow_forward_rounded,
                          size: 17, color: fg.withValues(alpha: 0.7)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color fg;
  final Color fgSoft;

  const _Pill({
    required this.icon,
    required this.label,
    required this.fg,
    required this.fgSoft,
  });

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: fg.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppStyle.rPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: fg,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
