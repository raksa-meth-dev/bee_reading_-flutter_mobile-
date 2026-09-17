import 'package:flutter/material.dart';

import 'package:bee_reading/screens/home_screen.dart';
import 'package:bee_reading/theme/app_theme.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_FeatureInfo> _features = const [
    _FeatureInfo(
      icon: Icons.auto_stories_rounded,
      tag: "SMART READER",
      title: "Distraction-Free Reading",
      description:
          "Customize fonts, margins, line-spacing, and switch between Sepia, Paper, and Dark modes for optimal eye comfort.",
      badge: "EPUB & PDF Supported",
    ),
    _FeatureInfo(
      icon: Icons.headphones_rounded,
      tag: "AUDIO SYNC",
      title: "Listen & Read Simultaneously",
      description:
          "Seamlessly switch between text and high-quality voice narration with word-by-word synchronized highlighting.",
      badge: "Hands-Free Mode",
    ),
    _FeatureInfo(
      icon: Icons.cloud_download_rounded,
      tag: "OFFLINE LIBRARY",
      title: "Read Anywhere, Offline",
      description:
          "Download entire books to your personal bookshelf and enjoy reading uninterrupted without internet connection.",
      badge: "Zero Data Required",
    ),
    _FeatureInfo(
      icon: Icons.edit_note_rounded,
      tag: "SMART NOTES",
      title: "Highlights & Smart Bookmarks",
      description:
          "Highlight memorable quotes in multiple colors, take margin notes, and export your key insights to Notion or PDF.",
      badge: "1-Click Export",
    ),
  ];

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Logo & Skip Action
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.accentLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('🐝', style: TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Bee Reading',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _navigateToHome,
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Feature Carousel
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _features.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final feature = _features[index];
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 8),
                        // Decorative Illustrated Card
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxHeight: 200),
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppTheme.accentLight,
                                Colors.white,
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.15),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.10),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primary.withValues(alpha: 0.30),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  feature.icon,
                                  size: 38,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppTheme.primary.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Text(
                                  feature.badge,
                                  style: const TextStyle(
                                    color: AppTheme.primaryDark,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Tag
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            feature.tag,
                            style: const TextStyle(
                              color: AppTheme.primaryDark,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Title
                        Text(
                          feature.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Description
                        Text(
                          feature.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textMuted,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Indicator Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_features.length, (index) {
                final isSelected = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isSelected ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary : AppTheme.surfaceMuted,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            // Bottom Actions Section
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage < _features.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          _navigateToHome();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shadowColor: AppTheme.primary.withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentPage == _features.length - 1
                                ? "Get Started"
                                : "Next Feature",
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _navigateToHome,
                    child: const Text(
                      "Explore Library Directly",
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

class _FeatureInfo {
  final IconData icon;
  final String tag;
  final String title;
  final String description;
  final String badge;

  const _FeatureInfo({
    required this.icon,
    required this.tag,
    required this.title,
    required this.description,
    required this.badge,
  });
}
