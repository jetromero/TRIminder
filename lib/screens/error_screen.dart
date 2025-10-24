import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/responsive_utils.dart';
import '../utils/device_info_helper.dart';

class ErrorScreen extends StatefulWidget {
  final String error;
  final String stackTrace;
  final bool isCritical;
  final VoidCallback? onRetry;

  const ErrorScreen({
    super.key,
    required this.error,
    required this.stackTrace,
    this.isCritical = false,
    this.onRetry,
  });

  @override
  State<ErrorScreen> createState() => _ErrorScreenState();
}

class _ErrorScreenState extends State<ErrorScreen> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.errorContainer,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: ResponsiveUtils.getMaxContentWidth(context),
            ),
            child: Padding(
              padding: ResponsiveUtils.getScreenPadding(context),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Error Icon
                  Icon(
                    widget.isCritical ? Icons.error_outline : Icons.warning_amber_outlined,
                    size: 80,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Error Title
                  Text(
                    widget.isCritical ? 'Critical Error' : 'Something Went Wrong',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Error Message
                  Text(
                    widget.isCritical 
                        ? 'The app encountered a critical error and couldn\'t start properly.'
                        : 'TRIminder encountered an unexpected error.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Action Buttons
                  Column(
                    children: [
                      // Retry Button
                      if (widget.onRetry != null) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: widget.onRetry,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try Again'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      
                      // Reset App Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _resetApp,
                          icon: const Icon(Icons.restart_alt),
                          label: const Text('Reset App'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.onErrorContainer,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Settings Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _openSettings,
                          icon: const Icon(Icons.settings),
                          label: const Text('Check Settings'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.onErrorContainer,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Technical Details Toggle
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showDetails = !_showDetails;
                      });
                    },
                    child: Text(
                      _showDetails ? 'Hide Technical Details' : 'Show Technical Details',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer.withOpacity(0.7),
                      ),
                    ),
                  ),
                  
                  // Technical Details
                  if (_showDetails) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.onErrorContainer.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Error Details:',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onErrorContainer,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.error,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onErrorContainer.withOpacity(0.8),
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton.icon(
                                  onPressed: _copyErrorDetails,
                                  icon: const Icon(Icons.copy, size: 16),
                                  label: const Text('Copy Details'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Help Text
                  Text(
                    'If this problem persists, please contact support with the error details above.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _resetApp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset App'),
        content: const Text(
          'This will clear all app data and settings. You will need to sign in again. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement app reset functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('App reset functionality coming soon'),
                ),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _openSettings() {
    // TODO: Navigate to app settings or system settings
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings navigation coming soon'),
      ),
    );
  }

  void _copyErrorDetails() async {
    try {
      final deviceInfo = await DeviceInfoHelper.getDebugInfo();
      final details = '''
Error: ${widget.error}

Stack Trace:
${widget.stackTrace}

Device Information:
- Platform: ${deviceInfo['platform']}
- Manufacturer: ${deviceInfo['manufacturer']}
- Model: ${deviceInfo['model']}
- Android Version: ${deviceInfo['androidVersion']}
- SDK: ${deviceInfo['sdkInt']}
- Is Tecno: ${deviceInfo['isTecno']}
- Is Physical Device: ${deviceInfo['isPhysicalDevice']}

Timestamp: ${DateTime.now().toIso8601String()}
    ''';
      
      Clipboard.setData(ClipboardData(text: details));
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error details copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Fallback to basic error details if device info fails
      final details = '''
Error: ${widget.error}

Stack Trace:
${widget.stackTrace}

Timestamp: ${DateTime.now().toIso8601String()}
    ''';
      
      Clipboard.setData(ClipboardData(text: details));
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error details copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
