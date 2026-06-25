import 'package:flutter/material.dart';

import '../models/guest_onboarding_draft.dart';
import '../models/persona_copy.dart';
import '../models/wedding_location_draft.dart';
import '../widgets/guest_onboarding_step_scaffold.dart';
import '../widgets/location_picker_section.dart';

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
    _districtController = TextEditingController(
      text: widget.draft.district ?? widget.draft.neighborhood,
    );
    _neighborhoodController = TextEditingController();
    _streetController = TextEditingController(text: widget.draft.street);
    _addressNoteController = TextEditingController(
      text: widget.draft.addressNote,
    );
    _governorateController.addListener(_handleLocationChanged);
    _cityController.addListener(_handleLocationChanged);
  }

  @override
  void dispose() {
    _governorateController.removeListener(_handleLocationChanged);
    _cityController.removeListener(_handleLocationChanged);
    _governorateController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _neighborhoodController.dispose();
    _streetController.dispose();
    _addressNoteController.dispose();
    super.dispose();
  }

  void _handleLocationChanged() {
    setState(() {});
  }

  bool get _canContinue {
    return WeddingLocationDraft.fromLegacyFields(
      governorate: _governorateController.text,
      city: _cityController.text,
      district: _districtController.text,
      neighborhood: _neighborhoodController.text,
      street: _streetController.text,
      addressNote: _addressNoteController.text,
    ).hasRequiredLocation;
  }

  @override
  Widget build(BuildContext context) {
    final copy = personaCopyForGuest(widget.draft.persona);

    return GuestOnboardingStepScaffold(
      stepNumber: 3,
      title: copy.locationTitle,
      description:
          'حدد موقع الزفاف خطوة بخطوة. لا نطلب GPS أو خرائط في هذه المرحلة.',
      continueLabel: 'حفظ الموقع',
      onContinue: _canContinue
          ? () => widget.onSaveLocation?.call(
              governorate: _governorateController.text,
              city: _cityController.text,
              district: _districtController.text,
              neighborhood: _neighborhoodController.text,
              street: _streetController.text,
              addressNote: _addressNoteController.text,
            )
          : null,
      onBack: widget.onBack,
      child: LocationPickerSection(
        governorateController: _governorateController,
        cityOrDistrictController: _cityController,
        areaOrNeighborhoodController: _districtController,
        streetController: _streetController,
        detailedAddressController: _addressNoteController,
        onChanged: _handleLocationChanged,
      ),
    );
  }
}
