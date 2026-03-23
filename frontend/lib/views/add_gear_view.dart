import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/halide_scaffold.dart';
import 'package:frontend/features/gear/presentation/widgets/add_gear_form.dart';

class AddGearView extends StatelessWidget {
  const AddGearView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return HalideScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: const SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: AddGearForm(),
      ),
    );
  }
}
