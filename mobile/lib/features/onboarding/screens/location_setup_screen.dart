import 'package:flutter/material.dart';

import '../models/guest_onboarding_draft.dart';
import '../widgets/guest_onboarding_step_scaffold.dart';

class LocationSetupScreen extends StatefulWidget {
  const LocationSetupScreen({
    this.draft = const GuestOnboardingDraft.empty(),
    this.onSaveLocation,
    this.onBack,
    super.key,
  });

  final GuestOnboardingDraft draft;
  final Future<void> Function({
    String? governorate,
    String? city,
    String? district,
    String? neighborhood,
    String? street,
    String? addressNote,
  })?
  onSaveLocation;
  final VoidCallback? onBack;

  @override
  State<LocationSetupScreen> createState() => _LocationSetupScreenState();
}

class _LocationSetupScreenState extends State<LocationSetupScreen> {
  late final TextEditingController _governorateController;
  late final TextEditingController _cityController;
  late final TextEditingController _districtController;
  late final TextEditingController _neighborhoodController;
  late final TextEditingController _streetController;
  late final TextEditingController _addressNoteController;

  @override
  void initState() {
    super.initState();
    _governorateController = TextEditingController(
      text: widget.draft.governorate,
    );
    _cityController = TextEditingController(text: widget.draft.city);
    _districtController = TextEditingController(text: widget.draft.district);
    _neighborhoodController = TextEditingController(
      text: widget.draft.neighborhood,
    );
    _streetController = TextEditingController(text: widget.draft.street);
    _addressNoteController = TextEditingController(
      text: widget.draft.addressNote,
    );
  }

  @override
  void dispose() {
    _governorateController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _neighborhoodController.dispose();
    _streetController.dispose();
    _addressNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GuestOnboardingStepScaffold(
      stepNumber: 3,
      title: 'أين سيكون الزفاف؟',
      description: 'أدخل الموقع يدويًا. لا يتم طلب إذن الموقع في هذه المرحلة.',
      continueLabel: 'حفظ الموقع',
      onContinue: () => widget.onSaveLocation?.call(
        governorate: _governorateController.text,
        city: _cityController.text,
        district: _districtController.text,
        neighborhood: _neighborhoodController.text,
        street: _streetController.text,
        addressNote: _addressNoteController.text,
      ),
      onBack: widget.onBack,
      child: Column(
        children: [
          _LocationField(controller: _governorateController, label: 'المحافظة'),
          const SizedBox(height: 12),
          _LocationField(
            controller: _cityController,
            label: 'المدينة أو المديرية',
          ),
          const SizedBox(height: 12),
          _LocationField(controller: _districtController, label: 'الحي'),
          const SizedBox(height: 12),
          _LocationField(controller: _neighborhoodController, label: 'المنطقة'),
          const SizedBox(height: 12),
          _LocationField(controller: _streetController, label: 'الشارع'),
          const SizedBox(height: 12),
          _LocationField(
            controller: _addressNoteController,
            label: 'ملاحظة على العنوان',
          ),
        ],
      ),
    );
  }
}

class _LocationField extends StatelessWidget {
  const _LocationField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textAlign: TextAlign.right,
      decoration: InputDecoration(labelText: label),
    );
  }
}
