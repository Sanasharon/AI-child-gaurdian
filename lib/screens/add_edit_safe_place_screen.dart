// ============================================================
// add_edit_safe_place_screen.dart
// ------------------------------------------------------------
// Screen for creating or modifying a Safe Place.
// Steps / Sections:
//   1. Location Selection (Google Map with fixed center pin)
//      - "[ Use Current Location ]" button
//      - "[ Confirm Location ]" action
//   2. Safe Place Details
//      - Place name with quick presets (Home, Office, School, Hospital, Gym, Custom)
//      - Optional place type
//   3. Geofence Radius
//      - Interactive slider (50m to 1000m)
//      - Circular geofence updates dynamically on the map
//   4. Schedule Configuration
//      - Always active vs Custom schedule
//      - Multi-day selection (Mon - Sun)
//      - Start & End time pickers
//   5. Review & Save to Firestore
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/user_model.dart';
import '../models/safe_place_model.dart';
import '../models/place_suggestion_model.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../services/places_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_card.dart';
import '../widgets/custom_button.dart';

class AddEditSafePlaceScreen extends StatefulWidget {
  final AppUser user;
  final SafePlace? existingPlace;

  const AddEditSafePlaceScreen({
    super.key,
    required this.user,
    this.existingPlace,
  });

  @override
  State<AddEditSafePlaceScreen> createState() => _AddEditSafePlaceScreenState();
}

class _AddEditSafePlaceScreenState extends State<AddEditSafePlaceScreen> {
  final _firestoreService = FirestoreService();
  final _locationService = LocationService();
  final _placesService = PlacesService();
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  GoogleMapController? _mapController;

  // Selected center coordinates
  late double _latitude;
  late double _longitude;
  bool _hasInitialPosition = false;

  // Place Search & Autocomplete state
  Timer? _debounceTimer;
  bool _isSearching = false;
  List<PlaceSuggestion> _placeSuggestions = [];
  String? _searchErrorMessage;
  bool _showSuggestions = false;

  // Geofence Radius
  double _radius = 150.0; // default 150 meters

  // Place Type & Presets
  String _placeType = 'Home';
  final List<String> _presets = ['Home', 'Office', 'School', 'Hospital', 'Gym', 'Custom'];

  // Schedule
  bool _alwaysActive = true;
  List<int> _activeDays = [1, 2, 3, 4, 5, 6, 7];
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);

  bool _isSaving = false;
  bool _isLocatingCurrent = false;

  final List<String> _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    if (widget.existingPlace != null) {
      final p = widget.existingPlace!;
      _latitude = p.latitude;
      _longitude = p.longitude;
      _radius = p.radius;
      _nameController.text = p.name;
      _placeType = p.placeType;
      _alwaysActive = p.alwaysActive;
      _activeDays = List<int>.from(p.activeDays);
      if (p.startTime != null) {
        final parts = p.startTime!.split(':');
        if (parts.length >= 2) {
          _startTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        }
      }
      if (p.endTime != null) {
        final parts = p.endTime!.split(':');
        if (parts.length >= 2) {
          _endTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        }
      }
      _hasInitialPosition = true;
    } else {
      // Default placeholder before current GPS or user pan
      _latitude = 37.4220;
      _longitude = -122.0841;
      _fetchInitialCurrentLocation();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _nameController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      setState(() {
        _isSearching = false;
        _placeSuggestions = [];
        _searchErrorMessage = null;
        _showSuggestions = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      setState(() {
        _isSearching = true;
        _searchErrorMessage = null;
        _showSuggestions = true;
      });

      try {
        final suggestions = await _placesService.searchPlaces(trimmed);
        if (mounted) {
          setState(() {
            _placeSuggestions = suggestions;
            _isSearching = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _placeSuggestions = [];
            _isSearching = false;
            _searchErrorMessage = e.toString();
          });
        }
      }
    });
  }

  Future<void> _selectPlaceSuggestion(PlaceSuggestion suggestion) async {
    _searchFocusNode.unfocus();
    setState(() {
      _showSuggestions = false;
      _searchController.text = suggestion.mainText;
      _isSearching = true;
      _searchErrorMessage = null;
    });

    try {
      final detailedPlace = await _placesService.getPlaceDetails(suggestion);
      if (mounted && detailedPlace.latitude != null && detailedPlace.longitude != null) {
        final lat = detailedPlace.latitude!;
        final lng = detailedPlace.longitude!;

        setState(() {
          _latitude = lat;
          _longitude = lng;
          _hasInitialPosition = true;
          _isSearching = false;

          // If the name field is currently default or empty, prefill with place name
          if (_nameController.text.trim().isEmpty || _nameController.text.trim() == _placeType) {
            _nameController.text = suggestion.mainText;
          }
        });

        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchErrorMessage = 'Could not get place coordinates: $e';
        });
      }
    }
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _placeSuggestions = [];
      _isSearching = false;
      _searchErrorMessage = null;
      _showSuggestions = false;
    });
  }

  Future<void> _fetchInitialCurrentLocation() async {
    try {
      final pos = await _locationService.getCurrentPosition();
      if (mounted) {
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
          _hasInitialPosition = true;
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(LatLng(_latitude, _longitude)),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _hasInitialPosition = true);
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocatingCurrent = true);
    try {
      final pos = await _locationService.getCurrentPosition();
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _hasInitialPosition = true;
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(_latitude, _longitude), 16),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not get current location: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLocatingCurrent = false);
      }
    }
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final h = tod.hour.toString().padLeft(2, '0');
    final m = tod.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryDark,
              onPrimary: Colors.white,
              surface: AppColors.background,
              onSurface: AppColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _saveSafePlace() async {
    final name = _nameController.text.trim().isEmpty ? _placeType : _nameController.text.trim();

    setState(() => _isSaving = true);
    try {
      final placeId = widget.existingPlace?.id ??
          'sp_${DateTime.now().millisecondsSinceEpoch}_${widget.user.uid.substring(0, 4)}';

      final place = SafePlace(
        id: placeId,
        guardianUid: widget.user.uid,
        monitoredUid: widget.user.linkedUid,
        name: name,
        placeType: _placeType,
        latitude: _latitude,
        longitude: _longitude,
        radius: _radius,
        isActive: widget.existingPlace?.isActive ?? true,
        alwaysActive: _alwaysActive,
        activeDays: _alwaysActive ? const [1, 2, 3, 4, 5, 6, 7] : _activeDays,
        startTime: _alwaysActive ? null : _formatTimeOfDay(_startTime),
        endTime: _alwaysActive ? null : _formatTimeOfDay(_endTime),
        createdAt: widget.existingPlace?.createdAt ?? DateTime.now(),
      );

      await _firestoreService.saveSafePlace(place);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Safe Place "$name" saved successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save Safe Place: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingPlace != null;

    final circles = <Circle>{
      Circle(
        circleId: const CircleId('geofence_preview'),
        center: LatLng(_latitude, _longitude),
        radius: _radius,
        strokeColor: AppColors.primaryDark,
        strokeWidth: 2,
        fillColor: AppColors.primary.withValues(alpha: 0.22),
      ),
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Safe Place' : 'Add Safe Place'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------------- SEARCH FOR A PLACE ----------------
              Container(
                decoration: AppDecorations.neumorphicCard(radius: 16),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: _onSearchChanged,
                  style: AppTextStyles.body.copyWith(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search for a place...',
                    hintStyle: AppTextStyles.subheading.copyWith(fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryDark, size: 22),
                    suffixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textLight),
                                onPressed: _clearSearch,
                              )
                            : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),

              // Search error message or status banner (e.g. if API is restricted/disabled)
              if (_searchErrorMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.danger),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _searchErrorMessage!,
                          style: const TextStyle(color: AppColors.danger, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Autocomplete suggestions dropdown list
              if (_showSuggestions && _placeSuggestions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: AppDecorations.neumorphicCard(radius: 16),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _placeSuggestions.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: AppColors.accent.withValues(alpha: 0.2),
                    ),
                    itemBuilder: (context, index) {
                      final item = _placeSuggestions[index];
                      return ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.location_on_outlined,
                          color: AppColors.primaryDark,
                          size: 20,
                        ),
                        title: Text(
                          item.mainText,
                          style: AppTextStyles.heading.copyWith(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: item.secondaryText.isNotEmpty
                            ? Text(
                                item.secondaryText,
                                style: AppTextStyles.subheading.copyWith(fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        onTap: () => _selectPlaceSuggestion(item),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // ---------------- MAP LOCATION PICKER ----------------
              Container(
                height: 260,
                clipBehavior: Clip.antiAlias,
                decoration: AppDecorations.neumorphicCard(radius: 20),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_hasInitialPosition)
                      GoogleMap(
                        style: AppDecorations.darkNavyMapStyle,
                        initialCameraPosition: CameraPosition(
                          target: LatLng(_latitude, _longitude),
                          zoom: 15,
                        ),
                        onMapCreated: (ctrl) => _mapController = ctrl,
                        onCameraMove: (pos) {
                          setState(() {
                            _latitude = pos.target.latitude;
                            _longitude = pos.target.longitude;
                          });
                        },
                        circles: circles,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                      )
                    else
                      const Center(child: CircularProgressIndicator()),

                    // Fixed center crosshair / pin marker
                    IgnorePointer(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.primaryDark,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black38,
                                  blurRadius: 6,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          Container(
                            width: 3,
                            height: 6,
                            color: AppColors.primaryDark,
                          ),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // "Use Current Location" button overlay
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: _isLocatingCurrent ? null : _useCurrentLocation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.background.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isLocatingCurrent)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              else
                                const Icon(Icons.my_location_rounded, size: 16, color: AppColors.primaryDark),
                              const SizedBox(width: 6),
                              Text(
                                'Use Current Location',
                                style: AppTextStyles.subheading.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Coordinates subtitle indicator at bottom
                    Positioned(
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Center: ${_latitude.toStringAsFixed(4)}, ${_longitude.toStringAsFixed(4)}',
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ---------------- GEOFENCE RADIUS SLIDER ----------------
              CustomCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Geofence Radius', style: AppTextStyles.heading.copyWith(fontSize: 15)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_radius.round()} m',
                            style: const TextStyle(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.primaryDark,
                        inactiveTrackColor: AppColors.accent.withValues(alpha: 0.3),
                        thumbColor: AppColors.primaryDark,
                        overlayColor: AppColors.primary.withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: _radius,
                        min: 50.0,
                        max: 1000.0,
                        divisions: 19,
                        label: '${_radius.round()} m',
                        onChanged: (val) {
                          setState(() => _radius = val);
                        },
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('50 m (Compact)', style: AppTextStyles.subheading.copyWith(fontSize: 11)),
                        Text('1000 m (Expansive)', style: AppTextStyles.subheading.copyWith(fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ---------------- PLACE DETAILS ----------------
              CustomCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Place Details', style: AppTextStyles.heading.copyWith(fontSize: 15)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Place Name (e.g. Home, Office, Gym)',
                        labelStyle: AppTextStyles.subheading.copyWith(fontSize: 13),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Place Type Presets:', style: AppTextStyles.subheading.copyWith(fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _presets.map((preset) {
                        final isSelected = _placeType == preset;
                        return ChoiceChip(
                          label: Text(preset),
                          selected: isSelected,
                          selectedColor: AppColors.primaryDark,
                          backgroundColor: AppColors.background,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textDark,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _placeType = preset;
                                if (_nameController.text.isEmpty && preset != 'Custom') {
                                  _nameController.text = preset;
                                }
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ---------------- SCHEDULE ----------------
              CustomCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Active Schedule', style: AppTextStyles.heading.copyWith(fontSize: 15)),
                    const SizedBox(height: 8),
                    RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      value: true,
                      groupValue: _alwaysActive,
                      activeColor: AppColors.primaryDark,
                      title: Text('Always active', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                      subtitle: Text('Geofence monitored 24/7 continuously', style: AppTextStyles.subheading.copyWith(fontSize: 12)),
                      onChanged: (val) => setState(() => _alwaysActive = val ?? true),
                    ),
                    RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      value: false,
                      groupValue: _alwaysActive,
                      activeColor: AppColors.primaryDark,
                      title: Text('Custom schedule', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                      subtitle: Text('Define specific days and hours', style: AppTextStyles.subheading.copyWith(fontSize: 12)),
                      onChanged: (val) => setState(() => _alwaysActive = !(val ?? false)),
                    ),
                    if (!_alwaysActive) ...[
                      const Divider(height: 20),
                      Text('Active Days:', style: AppTextStyles.subheading.copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: List.generate(7, (i) {
                          final dayNumber = i + 1;
                          final isSelected = _activeDays.contains(dayNumber);
                          return FilterChip(
                            label: Text(_dayLabels[i]),
                            selected: isSelected,
                            selectedColor: AppColors.primaryDark,
                            checkmarkColor: Colors.white,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textDark,
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _activeDays.add(dayNumber);
                                  _activeDays.sort();
                                } else {
                                  if (_activeDays.length > 1) {
                                    _activeDays.remove(dayNumber);
                                  }
                                }
                              });
                            },
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _pickTime(isStart: true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.accent),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Start Time', style: AppTextStyles.subheading.copyWith(fontSize: 11)),
                                    const SizedBox(height: 4),
                                    Text(_formatTimeOfDay(_startTime), style: AppTextStyles.heading.copyWith(fontSize: 14)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _pickTime(isStart: false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.accent),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('End Time', style: AppTextStyles.subheading.copyWith(fontSize: 11)),
                                    const SizedBox(height: 4),
                                    Text(_formatTimeOfDay(_endTime), style: AppTextStyles.heading.copyWith(fontSize: 14)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ---------------- REVIEW & SAVE ----------------
              CustomCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Summary Review', style: AppTextStyles.heading.copyWith(fontSize: 15)),
                    const SizedBox(height: 8),
                    _buildSummaryRow(
                      'Name',
                      _nameController.text.trim().isEmpty ? _placeType : _nameController.text.trim(),
                    ),
                    _buildSummaryRow('Type', _placeType),
                    _buildSummaryRow('Radius', '${_radius.round()} meters'),
                    _buildSummaryRow(
                      'Schedule',
                      _alwaysActive
                          ? 'Always active (24/7)'
                          : '${_activeDays.length} days • ${_formatTimeOfDay(_startTime)} - ${_formatTimeOfDay(_endTime)}',
                    ),
                    _buildSummaryRow('Status', 'Active'),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              CustomButton(
                label: isEditing ? 'Save Changes' : 'Save Safe Place',
                icon: Icons.check_circle_outline_rounded,
                isLoading: _isSaving,
                onPressed: _saveSafePlace,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.subheading.copyWith(fontSize: 12)),
          Text(
            value,
            style: AppTextStyles.body.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
