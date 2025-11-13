import 'package:flutter/material.dart';

/// Responsive breakpoints for different screen sizes
class ResponsiveBreakpoints {
  /// Mobile: < 600px width
  static const double mobile = 600;

  /// Tablet: >= 600px and < 1024px width
  static const double tablet = 1024;

  /// Desktop: >= 1024px width
  static const double desktop = 1024;
}

/// Extension to check device type based on screen width
extension ResponsiveContext on BuildContext {
  /// Returns true if screen width is less than 600px (mobile)
  bool get isMobile => MediaQuery.of(this).size.width < ResponsiveBreakpoints.mobile;

  /// Returns true if screen width is between 600px and 1024px (tablet)
  bool get isTablet =>
      MediaQuery.of(this).size.width >= ResponsiveBreakpoints.mobile &&
      MediaQuery.of(this).size.width < ResponsiveBreakpoints.tablet;

  /// Returns true if screen width is >= 1024px (desktop)
  bool get isDesktop => MediaQuery.of(this).size.width >= ResponsiveBreakpoints.desktop;

  /// Returns true if screen width is >= 600px (tablet or desktop)
  bool get isTabletOrDesktop => MediaQuery.of(this).size.width >= ResponsiveBreakpoints.mobile;
}

/// Widget that adapts its layout based on screen size
class ResponsiveLayout extends StatelessWidget {
  /// Widget to show on mobile screens
  final Widget mobile;

  /// Widget to show on tablet screens (optional, defaults to mobile)
  final Widget? tablet;

  /// Widget to show on desktop screens (optional, defaults to tablet or mobile)
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= ResponsiveBreakpoints.desktop) {
          return desktop ?? tablet ?? mobile;
        } else if (constraints.maxWidth >= ResponsiveBreakpoints.mobile) {
          return tablet ?? mobile;
        } else {
          return mobile;
        }
      },
    );
  }
}

/// Widget that constrains its child to a maximum width on larger screens
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 1200,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: padding,
        child: child,
      ),
    );
  }
}
