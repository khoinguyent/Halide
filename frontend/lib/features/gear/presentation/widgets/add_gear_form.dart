import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/constants/free_tier_limits.dart';
import 'package:frontend/core/widgets/halide_dialog.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/gear_provider.dart';
import '../../../../core/providers/notification_provider.dart';
import '../../../../core/models/notification_model.dart';

class AddGearForm extends ConsumerStatefulWidget {
  final VoidCallback? onGearAdded;

  const AddGearForm({Key? key, this.onGearAdded}) : super(key: key);

  @override
  ConsumerState<AddGearForm> createState() => _AddGearFormState();
}

class _AddGearFormState extends ConsumerState<AddGearForm> {
  final _formKey = GlobalKey<FormState>();
  String _gearType = 'Camera';
  final _nicknameController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _serialController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _serialController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(userProvider);
      if (user == null) throw Exception('USER_NOT_LOGGED_IN');
      
      final token = await user.getIdToken();
      if (token == null) throw Exception('FETCH_TOKEN_FAILED');

      final gearService = ref.read(gearServiceProvider);
      final data = {
        'gear_nickname': _nicknameController.text.trim(),
        'brand': _brandController.text.trim(),
        'model': _modelController.text.trim(),
        'serial_number': _serialController.text.trim(),
      };

      if (_gearType == 'Camera') {
        final block = ref.read(userGearProvider.notifier).blockReasonForNewCamera();
        if (block != null) {
          ref.read(notificationProvider.notifier).show(
                block,
                type: NotificationType.warning,
              );
          return;
        }
        await gearService.addUserCamera(token, data);
      } else {
        if (isFreeArchivePlan(ref.read(userPlanProvider))) {
          ref.read(notificationProvider.notifier).show(
                freeTierStandaloneLensMessage(),
                type: NotificationType.warning,
              );
          return;
        }
        await gearService.addUserLens(token, data);
      }

      // Refresh the gear list
      ref.invalidate(userGearProvider);

      if (mounted) {
        if (widget.onGearAdded != null) {
          widget.onGearAdded!();
        }
        Navigator.of(context).pop();
        ref.read(notificationProvider.notifier).show(
          'YOUR ${_gearType.toUpperCase()} IS READY!',
          type: NotificationType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        ref.read(notificationProvider.notifier).show(
          'WE COULDN\'T ADD YOUR ${_gearType.toUpperCase()}. PLEASE TRY AGAIN.',
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onTypeChanged(String type) {
    if (_gearType == type) return;
    setState(() {
      _gearType = type;
    });
    _nicknameController.clear();
    _brandController.clear();
    _modelController.clear();
    _serialController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return HalideModalContainer(
      padding: const EdgeInsets.all(32),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'ADD ${_gearType.toUpperCase()}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildGearTypeSelector(),
                  const SizedBox(height: 32),
                  HalideTextField(
                    controller: _nicknameController,
                    label: 'NICKNAME',
                  ),
                  const SizedBox(height: 16),
                  HalideTextField(
                    controller: _brandController,
                    label: 'MANUFACTURER',
                  ),
                  const SizedBox(height: 16),
                  HalideTextField(
                    controller: _modelController,
                    label: 'MODEL',
                  ),
                  const SizedBox(height: 16),
                  HalideTextField(
                    controller: _serialController,
                    label: 'SERIAL NUMBER',
                  ),
                  const SizedBox(height: 48),
                  HalideActionButton(
                    text: 'SAVE ${_gearType.toUpperCase()}',
                    isLoading: _isLoading,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildGearTypeSelector() {
    final plan = ref.watch(userPlanProvider);
    final showLensTab = !isFreeArchivePlan(plan);

    if (!showLensTab && _gearType == 'Lens') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _gearType = 'Camera');
      });
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(child: _buildTypeButton('Camera')),
          if (showLensTab) Expanded(child: _buildTypeButton('Lens')),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String type) {
    final isSelected = _gearType == type;
    return GestureDetector(
      onTap: () => _onTypeChanged(type),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: Colors.white.withOpacity(0.1)) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          type.toUpperCase(),
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white24,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
