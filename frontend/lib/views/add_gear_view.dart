import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/widgets/halide_scaffold.dart';
import '../core/widgets/glass_panel.dart';
import '../providers/auth_provider.dart';
import '../providers/gear_provider.dart';

class AddGearView extends ConsumerStatefulWidget {
  const AddGearView({Key? key}) : super(key: key);

  @override
  ConsumerState<AddGearView> createState() => _AddGearViewState();
}

class _AddGearViewState extends ConsumerState<AddGearView> {
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
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_gearType} added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add gear: $e'),
            backgroundColor: Colors.orangeAccent,
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
    return HalideScaffold(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            expandedHeight: 100,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'ADD GEAR',
                style: TextStyle(
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              centerTitle: true,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            sliver: SliverToBoxAdapter(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildGearTypeSelector(),
                    const SizedBox(height: 32),
                    GlassPanel(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTextField(_nicknameController, 'NICKNAME', 'e.g., Daily Driver'),
                          const SizedBox(height: 24),
                          _buildTextField(_brandController, 'MANUFACTURER', 'e.g., Leica, Nikon'),
                          const SizedBox(height: 24),
                          _buildTextField(_modelController, 'MODEL', 'e.g., M6, F3'),
                          const SizedBox(height: 24),
                          _buildTextField(_serialController, 'SERIAL NUMBER', 'Optional'),
                          const SizedBox(height: 40),
                          _buildSubmitButton(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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

  Widget _buildTextField(TextEditingController controller, String label, String hint) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.15)),
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
        errorStyle: const TextStyle(color: Colors.orangeAccent),
        errorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.orangeAccent)),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
      ),
      validator: (value) {
        if (label != 'SERIAL NUMBER' && (value == null || value.trim().isEmpty)) {
          return 'Required';
        }
        return null;
      },
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _submit,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
            )
          : Text(
              'SAVE ${_gearType.toUpperCase()}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 2,
              ),
            ),
    );
  }
}
