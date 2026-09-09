// ============================================================
// safe_places_screen.dart
// ------------------------------------------------------------
// Screen displaying all saved Safe Places configured by the
// guardian. Provides options to:
//   - View active/inactive status and radius
//   - Enable/disable a Safe Place
//   - Add a new Safe Place
//   - Edit an existing Safe Place
//   - Delete a Safe Place
// Accessible via Profile -> Safe Places.
// ============================================================

import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/safe_place_model.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_card.dart';
import '../widgets/custom_button.dart';
import 'add_edit_safe_place_screen.dart';

class SafePlacesScreen extends StatefulWidget {
  final AppUser user;
  const SafePlacesScreen({super.key, required this.user});

  @override
  State<SafePlacesScreen> createState() => _SafePlacesScreenState();
}

class _SafePlacesScreenState extends State<SafePlacesScreen> {
  final _firestoreService = FirestoreService();

  IconData _iconForPlaceType(String type) {
    switch (type.toLowerCase()) {
      case 'home':
        return Icons.home_rounded;
      case 'office':
      case 'work':
        return Icons.business_rounded;
      case 'school':
      case 'college':
        return Icons.school_rounded;
      case 'hospital':
      case 'clinic':
        return Icons.local_hospital_rounded;
      case 'gym':
      case 'fitness':
        return Icons.fitness_center_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  Future<void> _toggleActive(SafePlace place) async {
    final updated = place.copyWith(isActive: !place.isActive);
    await _firestoreService.saveSafePlace(updated);
  }

  Future<void> _confirmDelete(SafePlace place) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.background,
        title: Text('Delete Safe Place', style: AppTextStyles.heading.copyWith(fontSize: 18)),
        content: Text(
          'Are you sure you want to delete "${place.name}"? Geofencing alerts for this location will be discontinued.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: AppTextStyles.subheading.copyWith(fontSize: 14)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await _firestoreService.deleteSafePlace(place.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "${place.name}"'),
            backgroundColor: AppColors.textDark,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Safe Places'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<SafePlace>>(
                stream: _firestoreService.streamGuardianSafePlaces(widget.user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final places = snapshot.data ?? [];
                  if (places.isEmpty) {
                    return Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: CustomCard(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.shield_outlined, size: 48, color: AppColors.primary),
                              const SizedBox(height: 16),
                              Text('No Safe Places Saved', style: AppTextStyles.heading.copyWith(fontSize: 18)),
                              const SizedBox(height: 8),
                              Text(
                                'Create a Safe Place such as Home, Office, or School to get automated geofence entry and exit alerts.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.body,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: places.length,
                    itemBuilder: (context, index) {
                      final place = places[index];
                      final isCurrentActive = place.isActive;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: CustomCard(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: (isCurrentActive ? AppColors.primary : AppColors.textLight).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  _iconForPlaceType(place.placeType),
                                  color: isCurrentActive ? AppColors.primaryDark : AppColors.textLight,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            place.name,
                                            style: AppTextStyles.heading.copyWith(fontSize: 15),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isCurrentActive ? AppColors.success : AppColors.textLight,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isCurrentActive ? 'Active' : 'Inactive',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: isCurrentActive ? AppColors.success : AppColors.textLight,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${place.radius.round()} m radius • ${place.alwaysActive ? "Always active" : "Scheduled"}',
                                      style: AppTextStyles.subheading.copyWith(fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded, color: AppColors.textDark, size: 20),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                onSelected: (action) {
                                  if (action == 'toggle') {
                                    _toggleActive(place);
                                  } else if (action == 'edit') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AddEditSafePlaceScreen(
                                          user: widget.user,
                                          existingPlace: place,
                                        ),
                                      ),
                                    );
                                  } else if (action == 'delete') {
                                    _confirmDelete(place);
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'toggle',
                                    child: Row(
                                      children: [
                                        Icon(
                                          isCurrentActive ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                                          size: 18,
                                          color: AppColors.textDark,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(isCurrentActive ? 'Disable' : 'Enable'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 18, color: AppColors.textDark),
                                        SizedBox(width: 10),
                                        Text('Edit'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                                        SizedBox(width: 10),
                                        Text('Delete', style: TextStyle(color: AppColors.danger)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: CustomButton(
                label: '+ Add Safe Place',
                icon: Icons.add_location_alt_rounded,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddEditSafePlaceScreen(user: widget.user),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
