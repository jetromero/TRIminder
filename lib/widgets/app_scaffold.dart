import 'package:flutter/material.dart';

/// App-wide Scaffold wrapper with optimized drawer configuration
/// Provides consistent drawer swipe gesture handling across all screens
class AppScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? drawer;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final List<Widget>? persistentFooterButtons;
  final DrawerCallback? onDrawerChanged;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;
  final bool extendBody;
  final bool extendBodyBehindAppBar;
  final double? drawerWidth;

  const AppScaffold({
    super.key,
    this.appBar,
    this.body,
    this.drawer,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.persistentFooterButtons,
    this.onDrawerChanged,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.drawerWidth,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Configure drawer settings for optimal swipe gesture
    final edgeDragWidth = screenWidth * 0.20; // 15% of screen width for edge detection

    return Scaffold(
      appBar: appBar,
      body: body,
      drawer: drawer,
      drawerEdgeDragWidth: edgeDragWidth,
      drawerEnableOpenDragGesture: true,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      persistentFooterButtons: persistentFooterButtons,
      onDrawerChanged: onDrawerChanged,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
    );
  }
}

