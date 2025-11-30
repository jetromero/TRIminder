import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/permission_status_widget.dart';
import '../../utils/responsive_utils.dart';
import '../../utils/input_validator.dart';
import '../../services/supabase_service.dart';
import '../../services/user_session_manager.dart';
import '../../services/database_service.dart';
import '../../models/user_models.dart';
import '../../widgets/profile/avatar_widget.dart';
import '../auth/login_screen.dart';
import '../profile/student_profile_screen.dart';
import '../../config/app_config.dart';
import '../../widgets/app_scaffold.dart';
import '../../services/screen_time_notification_service.dart';

class SettingsScreen extends StatefulWidget {
  final ValueChanged<int>? onSelectTab;
  final GlobalKey<ScaffoldState>? scaffoldKey;
  
  const SettingsScreen({super.key, this.onSelectTab, this.scaffoldKey});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;
  bool _isDeletingAccount = false;
  bool _isEditingAccountInfo = false;
  bool _isSaving = false;
  bool _isAccountExpanded = true; // Account section expanded by default
  bool _isStatusBarHidden = false;
  UserProfile? _userProfile;
  
  // Form controllers and state for editing
  final _studentIdController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  String? _selectedGender;
  String? _selectedYearLevel;
  DateTime? _selectedDateOfBirth;
  
  // Gender and Year Level options
  final List<String> _genders = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];
  
  final List<String> _yearLevels = [
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
  ];
  
  // Screen time reminder configuration
  List<int> _sessionMilestones = [];
  List<int> _dailyMilestones = [];
  
  // Reminder notification preferences
  bool _reminderSoundEnabled = true;
  bool _reminderVibrationEnabled = false; // Default: disabled

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadMilestones();
    _loadReminderPreferences();
  }
  
  @override
  void dispose() {
    if (_isStatusBarHidden) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _studentIdController.dispose();
    _dateOfBirthController.dispose();
    super.dispose();
  }

  void _handleScroll(ScrollNotification notification) {
    if (notification.depth != 0) return;
    if (notification is ScrollUpdateNotification) {
      final currentOffset = notification.metrics.pixels;
      if (currentOffset >= kToolbarHeight && !_isStatusBarHidden) {
        _isStatusBarHidden = true;
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else if (currentOffset < 1 && _isStatusBarHidden) {
        _isStatusBarHidden = false;
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    }
  }

  Future<void> _loadUserData() async {
    try {
      final userId = SupabaseService().currentUserId;
      if (userId != null) {
        final profile = await SupabaseService().getUserProfile(userId);
        if (mounted) {
          setState(() {
            _userProfile = profile;
            _isLoading = false;
            // Initialize form fields with current values
            if (profile != null) {
              _studentIdController.text = profile.studentId ?? '';
              _selectedGender = profile.gender;
              _selectedYearLevel = profile.yearLevel;
              _selectedDateOfBirth = profile.dateOfBirth;
              if (profile.dateOfBirth != null) {
                final months = ['January', 'February', 'March', 'April', 'May', 'June',
                  'July', 'August', 'September', 'October', 'November', 'December'];
                final dob = profile.dateOfBirth!;
                _dateOfBirthController.text = '${months[dob.month - 1]} ${dob.day}, ${dob.year}';
              }
            }
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadMilestones() async {
    try {
      final sessionMilestones = await AppConfig.getSessionMilestones();
      final dailyMilestones = await AppConfig.getDailyTotalMilestones();
      if (mounted) {
        setState(() {
          _sessionMilestones = List.from(sessionMilestones);
          _dailyMilestones = List.from(dailyMilestones);
        });
      }
    } catch (e) {
      print('Error loading milestones: $e');
    }
  }

  Future<void> _loadReminderPreferences() async {
    try {
      final soundEnabled = await ScreenTimeNotificationService.getSoundEnabled();
      final vibrationEnabled = await ScreenTimeNotificationService.getVibrationEnabled();
      if (mounted) {
        setState(() {
          _reminderSoundEnabled = soundEnabled;
          _reminderVibrationEnabled = vibrationEnabled;
        });
      }
    } catch (e) {
      print('Error loading reminder preferences: $e');
    }
  }
  
  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 100)),
      lastDate: DateTime.now(),
      helpText: 'Select Date of Birth',
    );
    
    if (picked != null) {
      setState(() {
        _selectedDateOfBirth = picked;
        final months = ['January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December'];
        _dateOfBirthController.text = '${months[picked.month - 1]} ${picked.day}, ${picked.year}';
      });
    }
  }
  
  Future<void> _saveAccountInfo() async {
    if (_userProfile == null) return;
    
    // Validate inputs
    if (_studentIdController.text.trim().isNotEmpty) {
      final studentIdError = InputValidator.validateStudentId(_studentIdController.text.trim());
      if (studentIdError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(studentIdError),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    
    if (_selectedDateOfBirth != null) {
      final dobError = InputValidator.validateDateOfBirth(_selectedDateOfBirth);
      if (dobError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(dobError),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      // Update profile with new values
      final updatedProfile = _userProfile!.copyWith(
        studentId: _studentIdController.text.trim().isEmpty ? null : InputValidator.sanitizeStudentId(_studentIdController.text.trim()),
        gender: _selectedGender,
        yearLevel: _selectedYearLevel,
        dateOfBirth: _selectedDateOfBirth,
      );
      
      // Update in Supabase
      final supabaseService = SupabaseService();
      final result = await supabaseService.updateUserProfile(updatedProfile);
      
      if (result != null) {
        // Update local database
        await DatabaseService().updateUserProfile(updatedProfile);
        
        if (mounted) {
          setState(() {
            _userProfile = result;
            _isEditingAccountInfo = false;
            _isSaving = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account information updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to update profile');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating account information: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  void _cancelEditing() {
    // Reset form fields to current profile values
    if (_userProfile != null) {
      setState(() {
        _studentIdController.text = _userProfile!.studentId ?? '';
        _selectedGender = _userProfile!.gender;
        _selectedYearLevel = _userProfile!.yearLevel;
        _selectedDateOfBirth = _userProfile!.dateOfBirth;
        if (_userProfile!.dateOfBirth != null) {
          final months = ['January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December'];
          final dob = _userProfile!.dateOfBirth!;
          _dateOfBirthController.text = '${months[dob.month - 1]} ${dob.day}, ${dob.year}';
        } else {
          _dateOfBirthController.clear();
        }
        _isEditingAccountInfo = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await SupabaseService().signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      drawerGestureEnabled: false,
      extendBodyBehindAppBar: true,
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          _handleScroll(notification);
          return false;
        },
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              elevation: 0,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              floating: true,
              snap: true,
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => widget.scaffoldKey?.currentState?.openDrawer(),
              ),
              title: Text(
                'Settings',
                style: TextStyle(
                  fontSize: 20 * ResponsiveUtils.getFontScale(context),
                ),
              ),
              centerTitle: true,
            ),
          ],
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: ResponsiveUtils.getMaxContentWidth(context),
                    ),
                    child: ListView(
                      physics: const ClampingScrollPhysics(),
                      padding: ResponsiveUtils.getScreenPadding(context),
                      children: [
                        const SizedBox(height: 16),
                        
                        // User Profile Section
                        _buildUserProfileSection(),
                        
                        const SizedBox(height: 24),
                        
                        // Permissions Section
                        _buildPermissionsSection(),
                        
                        const SizedBox(height: 24),
                        
                        // App Settings Section
                        _buildAppSettingsSection(),
                        
                        const SizedBox(height: 24),
                        
                        // Data Management Section
                        _buildDataManagementSection(),
                        
                        const SizedBox(height: 24),
                        
                        // App Information Section
                        _buildAppInformationSection(),
                        
                        const SizedBox(height: 24),
                        
                        // Sign Out Section
                        _buildSignOutSection(),
                        
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildUserProfileSection() {
    const accentColor = Color(0xFFa92d35);
    
    return Card(
      child: Column(
        children: [
          // Expandable header
          InkWell(
            onTap: () {
              setState(() {
                _isAccountExpanded = !_isAccountExpanded;
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    Icons.person,
                    color: accentColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Account',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!_isEditingAccountInfo && _userProfile != null)
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        setState(() {
                          _isEditingAccountInfo = true;
                          _isAccountExpanded = true;
                        });
                      },
                      tooltip: 'Edit Account Information',
                    ),
                  Icon(
                    _isAccountExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          // Collapsible content
          AnimatedCrossFade(
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_userProfile != null) ..._buildAccountContent()
                  else const Text('Unable to load profile information'),
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _isAccountExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAccountContent() {
    if (_userProfile == null) return [];
    
    return [
              _buildInfoRow('Name', _userProfile!.fullName),
              _buildInfoRow('Email', _userProfile!.email),
              if (_userProfile!.userTag != null)
                _buildInfoRow('User Tag', '@${_userProfile!.userTag}'),
              
              // Editable fields
              if (_isEditingAccountInfo) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  'Edit Account Information',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Student ID Field
                TextFormField(
                  controller: _studentIdController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d-]')),
                    LengthLimitingTextInputFormatter(10),
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
                      final limitedDigits = digitsOnly.length > 9 
                          ? digitsOnly.substring(0, 9) 
                          : digitsOnly;
                      if (limitedDigits.length <= 4) {
                        return TextEditingValue(
                          text: limitedDigits,
                          selection: TextSelection.collapsed(offset: limitedDigits.length),
                        );
                      } else {
                        final formatted = '${limitedDigits.substring(0, 4)}-${limitedDigits.substring(4)}';
                        return TextEditingValue(
                          text: formatted,
                          selection: TextSelection.collapsed(offset: formatted.length),
                        );
                      }
                    }),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Student ID',
                    hintText: '2020-30041',
                    helperText: 'Format: YYYY-XXXXX (e.g., 2020-30041)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      return InputValidator.validateStudentId(value.trim());
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Gender Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    border: OutlineInputBorder(),
                  ),
                  items: _genders.map((String gender) {
                    return DropdownMenuItem<String>(
                      value: gender,
                      child: Text(gender),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedGender = newValue;
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                // Year Level Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedYearLevel,
                  decoration: const InputDecoration(
                    labelText: 'Year Level',
                    border: OutlineInputBorder(),
                  ),
                  items: _yearLevels.map((String year) {
                    return DropdownMenuItem<String>(
                      value: year,
                      child: Text(year),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedYearLevel = newValue;
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                // Date of Birth Field
                TextFormField(
                  controller: _dateOfBirthController,
                  readOnly: true,
                  onTap: _selectDateOfBirth,
                  decoration: const InputDecoration(
                    labelText: 'Date of Birth',
                    hintText: 'Tap to select',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Save and Cancel buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : _cancelEditing,
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveAccountInfo,
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ],
                ),
              ] else ...[
            // Read-only display
            if (_userProfile!.studentId != null && _userProfile!.studentId!.isNotEmpty)
              _buildInfoRow('Student ID', _userProfile!.studentId!),
            if (_userProfile!.gender != null && _userProfile!.gender!.isNotEmpty)
              _buildInfoRow('Gender', _userProfile!.gender!),
            if (_userProfile!.yearLevel != null && _userProfile!.yearLevel!.isNotEmpty)
              _buildInfoRow('Year Level', _userProfile!.yearLevel!),
            if (_userProfile!.dateOfBirth != null)
              _buildInfoRow('Date of Birth', _formatDateOfBirth(_userProfile!.dateOfBirth!)),
          ],
    ];
  }

  Widget _buildPermissionsSection() {
    const accentColor = Color(0xFFa92d35);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.security,
              color: accentColor,
            ),
            const SizedBox(width: 8),
            Text(
              'Permissions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const PermissionStatusWidget(),
      ],
    );
  }

  Widget _buildAppSettingsSection() {
    const accentColor = Color(0xFFa92d35);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings,
                  color: accentColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'App Settings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSettingsItem(
              icon: Icons.notifications,
              title: 'Screen Time Reminders',
              subtitle: 'Configure reminder milestones',
              onTap: () {
                _showReminderSettingsDialog();
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              secondary: const Icon(Icons.volume_up),
              title: const Text('Reminder Sound'),
              subtitle: const Text('Play sound for reminder notifications'),
              value: _reminderSoundEnabled,
              onChanged: (value) async {
                await ScreenTimeNotificationService.setSoundEnabled(value);
                if (mounted) {
                  setState(() {
                    _reminderSoundEnabled = value;
                  });
                }
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.vibration),
              title: const Text('Reminder Vibration'),
              subtitle: const Text('Vibrate for reminder notifications'),
              value: _reminderVibrationEnabled,
              onChanged: (value) async {
                await ScreenTimeNotificationService.setVibrationEnabled(value);
                if (mounted) {
                  setState(() {
                    _reminderVibrationEnabled = value;
                  });
                }
              },
            ),
            _buildSettingsItem(
              icon: Icons.dark_mode,
              title: 'Theme',
              subtitle: 'Light, Dark, or System',
              onTap: () {
                // TODO: Implement theme settings
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Theme settings coming soon')),
                );
              },
            ),
            _buildSettingsItem(
              icon: Icons.sync,
              title: 'Auto Sync',
              subtitle: 'Automatically sync data',
              onTap: () {
                // TODO: Implement sync settings
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sync settings coming soon')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataManagementSection() {
    const accentColor = Color(0xFFa92d35);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.storage,
                  color: accentColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Data Management',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSettingsItem(
              icon: Icons.cloud_sync,
              title: 'Sync Data',
              subtitle: 'Manually sync with cloud',
              onTap: () {
                // TODO: Implement manual sync
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Manual sync coming soon')),
                );
              },
            ),
            _buildSettingsItem(
              icon: Icons.download,
              title: 'Export Data',
              subtitle: 'Download your data',
              onTap: () {
                // TODO: Implement data export
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Data export coming soon')),
                );
              },
            ),
            _buildSettingsItem(
              icon: Icons.delete_sweep,
              title: 'Clear Cache',
              subtitle: 'Free up storage space',
              onTap: () {
                // TODO: Implement cache clearing
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cache clearing coming soon')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppInformationSection() {
    const accentColor = Color(0xFFa92d35);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info,
                  color: accentColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'App Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Version', AppConfig.appVersion),
            _buildInfoRow('Build', '1'),
            _buildInfoRow('Platform', 'Android'),
            const SizedBox(height: 8),
            _buildSettingsItem(
              icon: Icons.help,
              title: 'Help & Support',
              subtitle: 'Get help and contact support',
              onTap: () {
                // TODO: Implement help section
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Help section coming soon')),
                );
              },
            ),
            _buildSettingsItem(
              icon: Icons.privacy_tip,
              title: 'Privacy Policy',
              subtitle: 'Read our privacy policy',
              onTap: () {
                // TODO: Implement privacy policy viewer
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Privacy policy viewer coming soon')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showReminderSettingsDialog() async {
    // Load current milestones
    await _loadMilestones();
    
    // Create editable lists
    List<int> sessionMilestones = List.from(_sessionMilestones);
    List<int> dailyMilestones = List.from(_dailyMilestones);
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Screen Time Reminders'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Session Reminders',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Get notified after continuous screen time (in minutes)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...sessionMilestones.map((milestone) => Chip(
                      label: Text('$milestone min'),
                      onDeleted: () {
                        setDialogState(() {
                          sessionMilestones.remove(milestone);
                        });
                      },
                    )),
                    ActionChip(
                      label: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 16),
                          SizedBox(width: 4),
                          Text('Add'),
                        ],
                      ),
                      onPressed: () => _showAddMilestoneDialog(
                        context,
                        setDialogState,
                        sessionMilestones,
                        'Session',
                        (value) {
                          setDialogState(() {
                            if (!sessionMilestones.contains(value)) {
                              sessionMilestones.add(value);
                              sessionMilestones.sort();
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Daily Total Reminders',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Get notified when daily screen time reaches (in minutes)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...dailyMilestones.map((milestone) => Chip(
                      label: Text('${milestone ~/ 60}h ${milestone % 60}m'),
                      onDeleted: () {
                        setDialogState(() {
                          dailyMilestones.remove(milestone);
                        });
                      },
                    )),
                    ActionChip(
                      label: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 16),
                          SizedBox(width: 4),
                          Text('Add'),
                        ],
                      ),
                      onPressed: () => _showAddMilestoneDialog(
                        context,
                        setDialogState,
                        dailyMilestones,
                        'Daily',
                        (value) {
                          setDialogState(() {
                            if (!dailyMilestones.contains(value)) {
                              dailyMilestones.add(value);
                              dailyMilestones.sort();
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
                if (sessionMilestones.isEmpty || dailyMilestones.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      '⚠️ At least one milestone is required for each type',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.orange,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                // Reset to defaults
                await AppConfig.resetMilestonesToDefaults();
                await _loadMilestones();
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reset to default milestones')),
                  );
                }
              },
              child: const Text('Reset to Defaults'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: sessionMilestones.isEmpty || dailyMilestones.isEmpty
                  ? null
                  : () async {
                      print('💾 Saving milestones - Session: $sessionMilestones, Daily: $dailyMilestones');
                      final sessionSuccess = await AppConfig.setSessionMilestones(sessionMilestones);
                      final dailySuccess = await AppConfig.setDailyTotalMilestones(dailyMilestones);
                      
                      print('💾 Save results - Session: $sessionSuccess, Daily: $dailySuccess');
                      
                      // Verify the save worked
                      final verifySession = await AppConfig.getSessionMilestones();
                      final verifyDaily = await AppConfig.getDailyTotalMilestones();
                      print('🔍 Verification after save - Session: $verifySession, Daily: $verifyDaily');
                      
                      if (mounted) {
                        Navigator.of(context).pop();
                        if (sessionSuccess && dailySuccess) {
                          await _loadMilestones();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Reminder settings saved\nSession: $verifySession\nDaily: $verifyDaily'),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to save settings\nSession success: $sessionSuccess\nDaily success: $dailySuccess'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMilestoneDialog(
    BuildContext context,
    StateSetter setDialogState,
    List<int> currentMilestones,
    String type,
    Function(int) onAdd,
  ) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add $type Milestone'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Minutes',
            hintText: type == 'Session' ? 'e.g., 30' : 'e.g., 120 (2 hours)',
            helperText: type == 'Session'
                ? 'Minutes of continuous use'
                : 'Total minutes for the day',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value > 0) {
                if (currentMilestones.contains(value)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$value minutes is already added')),
                  );
                } else {
                  onAdd(value);
                  Navigator.of(context).pop();
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid number')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildSignOutSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.logout,
                  color: Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  'Account',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isDeletingAccount ? null : _signOut,
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isDeletingAccount ? null : _showDeleteAccountConfirmation,
                icon: const Icon(Icons.delete_forever),
                label: _isDeletingAccount 
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Delete Account'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.red.withOpacity(0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteAccountConfirmation() async {
    // First confirmation dialog
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Account?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.\n\n'
          'All your data including:\n'
          '• Screen time history\n'
          '• XP and achievements\n'
          '• Friends and social connections\n'
          '• All account information\n\n'
          'will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (firstConfirm != true || !mounted) return;

    // Second confirmation dialog with text input
    final textController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text('Final Confirmation'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This is your last chance to cancel. Type "DELETE" in the box below to confirm account deletion.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                decoration: const InputDecoration(
                  labelText: 'Type DELETE to confirm',
                  border: OutlineInputBorder(),
                  errorText: null,
                ),
                onChanged: (value) {
                  setDialogState(() {});
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: textController.text.trim() == 'DELETE'
                  ? () => Navigator.of(context).pop(true)
                  : null,
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete Account'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    // Proceed with account deletion
    await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    if (!mounted) return;

    setState(() {
      _isDeletingAccount = true;
    });

    try {
      final sessionManager = UserSessionManager();
      final success = await sessionManager.deleteAccount();

      if (!mounted) return;

      if (success) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate to login screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account deletion failed. Please try again or contact support if the problem persists.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error deleting account: ${e.toString()}\n\n'
            'Your local data has been deleted. If you were offline, cloud data deletion may be pending.',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 6),
        ),
      );

      // Still navigate to login screen even on error
      // since local data is likely deleted
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingAccount = false;
        });
      }
    }
  }

  String _formatDateOfBirth(DateTime dateOfBirth) {
    final months = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[dateOfBirth.month - 1]} ${dateOfBirth.day}, ${dateOfBirth.year}';
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    const accentColor = Color(0xFFa92d35);
    
    return ListTile(
      leading: Icon(icon, color: accentColor),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// App-wide navigation drawer used in Settings screen
class _AppDrawer extends StatelessWidget {
  final ValueChanged<int> onSelectTab;
  final int currentScreenIndex;
  
  const _AppDrawer({
    required this.onSelectTab,
    this.currentScreenIndex = 200, // Default to Settings
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth * 0.75; // 75% of screen width
    
    return Drawer(
      width: drawerWidth,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile header section (matching home screen drawer)
            _buildProfileHeader(context),
            _buildNavItem(
              context: context,
              icon: Icons.dashboard,
              title: 'Dashboard',
              index: 0,
              onTap: () {
                Navigator.of(context).pop();
                onSelectTab(0);
              },
            ),
            _buildNavItem(
              context: context,
              icon: Icons.leaderboard,
              title: 'Rankings',
              index: 1,
              onTap: () {
                Navigator.of(context).pop();
                onSelectTab(1);
              },
            ),
            _buildNavItem(
              context: context,
              icon: Icons.group,
              title: 'Friends',
              index: 100,
              onTap: () {
                Navigator.of(context).pop();
                onSelectTab(100);
              },
            ),
            _buildNavItem(
              context: context,
              icon: Icons.settings,
              title: 'Account Settings',
              index: 200,
              onTap: () {
                Navigator.of(context).pop();
                onSelectTab(200);
              },
            ),
            const Spacer(),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  useRootNavigator: true,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  if (!context.mounted) return;
                  showDialog(
                    context: context,
                    useRootNavigator: true,
                    barrierDismissible: false,
                    builder: (context) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                  try {
                    await UserSessionManager().logoutCurrentUser();
                    if (context.mounted) {
                      Navigator.of(context, rootNavigator: true).pop(); // close loading
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                        (route) => false,
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.of(context, rootNavigator: true).pop(); // close loading
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Logout error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                        (route) => false,
                      );
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Build profile header at top of drawer
  /// Shows local profile immediately, then updates from cloud if avatar missing
  Widget _buildProfileHeader(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: _loadCurrentUserProfileOptimized(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        
        // Calculate XP progress
        int? level;
        double? progress;
        Map<String, int>? levelProgress;
        
        if (profile != null) {
          level = profile.level;
          progress = profile.progressToNextLevel;
          levelProgress = profile.currentLevelProgress;
        }
        
        final currentLevel = level ?? 1;
        final currentProgress = (progress ?? 0.0).clamp(0.0, 1.0);
        final xpInCurrentLevel = levelProgress?['currentLevelXP'] ?? 0;
        final xpNeededForNextLevel = levelProgress?['requiredForNextLevel'] ?? 100;
        
        return InkWell(
          onTap: () {
            Navigator.of(context).pop();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const StudentProfileScreen(),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AvatarWidget.medium(
                      avatarUrl: profile?.avatarUrl,
                      fullName: profile?.fullName,
                      size: 56.0,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            profile?.fullName ?? 'Loading...',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (profile?.userTag != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '@${profile!.userTag}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // XP Progress Bar
                Row(
                  children: [
                    const Icon(
                      Icons.star,
                      size: 16,
                      color: Color(0xFFa92d35),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Level $currentLevel',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFa92d35),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$xpInCurrentLevel / $xpNeededForNextLevel XP',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: currentProgress,
                  backgroundColor: const Color(0xFFfec443),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFa92d35),
                  ),
                  minHeight: 6,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Load current user profile for drawer header (optimized version)
  Future<UserProfile?> _loadCurrentUserProfileOptimized() async {
    try {
      final userId = SupabaseService().currentUserId;
      if (userId == null) return null;
      
      final db = DatabaseService();
      
      // STEP 1: Load from local DB first (fast, instant, works offline)
      final localProfile = await db.getUserProfile(userId);
      
      // STEP 2: If online and avatarUrl is missing/null/empty, fetch from cloud in background
      final supabaseService = SupabaseService();
      final isConnected = await supabaseService.isConnected();
      
      if (isConnected && (localProfile == null || localProfile.avatarUrl == null || localProfile.avatarUrl!.isEmpty)) {
        // Fetch from cloud in background (non-blocking)
        try {
          final cloudProfile = await supabaseService.getUserProfile(userId);
          if (cloudProfile != null) {
            // Cache cloud profile locally for offline access
            await db.insertUserProfile(cloudProfile);
            return cloudProfile; // Return updated profile with avatar
          }
        } catch (e) {
          print('Supabase profile fetch failed, using local: $e');
          // Continue with local profile if cloud fetch fails
        }
      }
      
      // Return local profile (either found in step 1, or cloud fetch failed/not needed)
      return localProfile;
    } catch (e) {
      print('Error loading current user profile: $e');
      // Last resort: try local DB even if there was an error
      try {
        final userId = SupabaseService().currentUserId;
        if (userId != null) {
          return await DatabaseService().getUserProfile(userId);
        }
      } catch (_) {
        // Ignore errors in fallback
      }
      return null;
    }
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required int index,
    required VoidCallback onTap,
  }) {
    final isSelected = currentScreenIndex == index;
    const accentColor = Color(0xFFa92d35);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isSelected 
          ? accentColor.withOpacity(0.15)
          : Colors.transparent,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected 
            ? accentColor
            : Theme.of(context).colorScheme.onSurface,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected 
              ? accentColor
              : Theme.of(context).colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        selectedTileColor: Colors.transparent,
        onTap: onTap,
      ),
    );
  }
}
