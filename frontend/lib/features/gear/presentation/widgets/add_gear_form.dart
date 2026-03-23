import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/widgets/halide_dialog.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/gear_provider.dart';

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
        await gearService.addUserCamera(token, data);
      } else {
        await gearService.addUserLens(token, data);
      }

      // Refresh the gear list
      ref.invalidate(userGearProvider);

      if (mounted) {
        if (widget.onGearAdded != null) {
          widget.onGearAdded!();
        }
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_gearType} added successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add gear: $e'),
            backgroundColor: Colors.orangeAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildGearTypeSelector(),
                  const SizedBox(height: 32),
                  HalideTextField(
                    controller: _nicknameController,
                    label: 'NICKNAME',
                    prefixIcon: Icons.label_outline,
                  ),
                  const SizedBox(height: 16),
                  HalideTextField(
                    controller: _brandController,
                    label: 'MANUFACTURER',
                    prefixIcon: Icons.business_outlined,
                  ),
                  const SizedBox(height: 16),
                  HalideTextField(
                    controller: _modelController,
                    label: 'MODEL',
                    prefixIcon: Icons.camera_alt_outlined,
                  ),
                  const SizedBox(height: 16),
                  HalideTextField(
                    controller: _serialController,
                    label: 'SERIAL NUMBER',
                    prefixIcon: Icons.tag,
                  ),
                  const SizedBox(height: 40),
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
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(child: _buildTypeButton('Camera')),
          Expanded(child: _buildTypeButton('Lens')),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String type) {
    final isSelected = _gearType == type;
    return GestureDetector(
      onTap: () => setState(() => _gearType = type),
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
            color: isSelected ? Colors.white : Colors.white38,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
