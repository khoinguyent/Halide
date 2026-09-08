import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/l10n/enum_l10n.dart';
import 'package:frontend/core/l10n/l10n_extension.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/models/film_stock.dart';
import 'package:frontend/models/camera.dart';
import 'package:frontend/models/roll_status.dart';
import 'package:frontend/features/rolls/data/rolls_repository.dart';
import 'package:frontend/features/rolls/presentation/bloc/rolls_bloc.dart';
import 'package:frontend/core/widgets/halide_dialog.dart';
import 'package:frontend/core/theme/halide_colors.dart';
import 'package:frontend/core/providers/notification_provider.dart';
import 'package:frontend/core/models/notification_model.dart';
import 'package:frontend/providers/guidance_pending_provider.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/services/fetch_scans_helper.dart';

class AddRollFormData {
  FilmStock? selectedStock;
  Camera? selectedCamera;
  String? title;
  String? description;
  int? shotAtIso;
  int? expiredYear;
  int maxFrames = 36;
  RollStatus status = RollStatus.shooting;
  String? driveUrl;

  void clear() {
    selectedStock = null;
    selectedCamera = null;
    title = null;
    description = null;
    shotAtIso = null;
    expiredYear = null;
    maxFrames = 36;
    status = RollStatus.shooting;
    driveUrl = null;
  }
}

final addRollFormDataProvider = Provider<AddRollFormData>(
  (ref) => AddRollFormData(),
);

class AddRollForm extends ConsumerStatefulWidget {
  final RollsRepository repository;
  final Function() onRollAdded;

  const AddRollForm({
    Key? key,
    required this.repository,
    required this.onRollAdded,
  }) : super(key: key);

  @override
  _AddRollFormState createState() => _AddRollFormState();
}

class _AddRollFormState extends ConsumerState<AddRollForm> {
  final _formKey = GlobalKey<FormState>();

  late final AddRollFormData _formData;

  List<FilmStock> _stocks = [];
  List<Camera> _cameras = [];
  bool _isLoading = true;
  bool _showValidationError = false;
  bool _showFramesError = false;
  int _step = 0;

  final _stockController = TextEditingController();
  final _cameraController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _formData = ref.read(addRollFormDataProvider);

    if (_formData.selectedStock != null) {
      _stockController.text =
          '${_formData.selectedStock!.brand} ${_formData.selectedStock!.name} (${_formData.selectedStock!.format})';
    }
    if (_formData.selectedCamera != null) {
      _cameraController.text = _formData.selectedCamera!.displayName;
    }

    _loadData();
  }

  @override
  void dispose() {
    _stockController.dispose();
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final stocks = await widget.repository.getFilmStocks();
      final cameras = await widget.repository.getCameras();
      setState(() {
        _stocks = stocks;
        _cameras = cameras;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static String _normalizeAutocompleteQuery(String s) {
    return s.replaceAll('\u200b', '').trim();
  }

  Iterable<FilmStock> _filmStockOptionsForQuery(String query) {
    final q = _normalizeAutocompleteQuery(query).toLowerCase();
    if (q.isEmpty) return _stocks;
    return _stocks.where(
      (stock) =>
          stock.name.toLowerCase().contains(q) ||
          stock.brand.toLowerCase().contains(q),
    );
  }

  Iterable<Camera> _cameraOptionsForQuery(String query) {
    final q = _normalizeAutocompleteQuery(query).toLowerCase();
    if (q.isEmpty) return _cameras;
    return _cameras.where(
      (camera) => camera.displayName.toLowerCase().contains(q),
    );
  }

  void _kickAutocompleteOptions(TextEditingController controller) {
    if (controller.text.isNotEmpty) return;
    controller.value = const TextEditingValue(
      text: '\u200b',
      selection: TextSelection.collapsed(offset: 1),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (controller.text == '\u200b') {
        controller.value = const TextEditingValue(
          text: '',
          selection: TextSelection.collapsed(offset: 0),
        );
      }
    });
  }

  bool get _showDriveUrlField {
    final isPro = ref.watch(userPlanProvider).isPro;
    if (!isPro) return false;
    return _formData.status == RollStatus.lab ||
        _formData.status == RollStatus.scanned;
  }

  Widget _buildStepIndicator(AppLocalizations l10n) {
    return Row(
      children: [
        _StepDot(label: '1', title: l10n.addRollStep1, active: _step == 0, done: _step > 0),
        Expanded(
          child: Container(
            height: 2,
            margin: const EdgeInsets.only(bottom: 18),
            color: _step > 0
                ? HalideColors.of(context).slateTeal.withValues(alpha: 0.5)
                : HalideColors.of(context).glassBorder(0.2),
          ),
        ),
        _StepDot(label: '2', title: l10n.addRollStep2, active: _step == 1, done: false),
      ],
    );
  }

  Widget _buildFrameInput(AppLocalizations l10n) {
    return HalideTextField(
      label: halideCaps(l10n.totalFrames),
      initialValue: _formData.maxFrames.toString(),
      keyboardType: TextInputType.number,
      errorText: _showFramesError
          ? 'ENTER A VALID FRAME COUNT (1 OR MORE)'
          : null,
      onChanged: (val) {
        final trimmed = val.trim();
        if (trimmed.isEmpty) {
          _formData.maxFrames = 0;
          return;
        }
        final parsed = int.tryParse(trimmed);
        if (parsed != null && parsed > 0) {
          _formData.maxFrames = parsed;
          if (_showFramesError) {
            setState(() => _showFramesError = false);
          }
        } else {
          _formData.maxFrames = 0;
        }
      },
    );
  }

  Widget _buildStatusSelector(AppLocalizations l10n) {
    return DropdownButtonFormField<RollStatus>(
      value: _formData.status,
      dropdownColor: HalideColors.of(context).surfaceSheet,
      icon: Icon(
        Icons.keyboard_arrow_down,
        color: Colors.white24,
        size: 18,
      ),
      decoration: InputDecoration(
        labelText: halideCaps(l10n.status),
        labelStyle: TextStyle(
          color: HalideColors.of(context).steel.withValues(alpha: 0.85),
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: HalideColors.of(context).borderSubtle),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: HalideColors.of(context).slateTeal, width: 1.2),
        ),
      ),
      style: TextStyle(
        color: HalideColors.of(context).textPrimary,
        fontSize: 15,
        letterSpacing: 0.5,
      ),
      items: [
        DropdownMenuItem(value: RollStatus.shooting, child: Text(RollStatus.shooting.localizedLabel(l10n))),
        DropdownMenuItem(value: RollStatus.lab, child: Text(RollStatus.lab.localizedLabel(l10n))),
        DropdownMenuItem(value: RollStatus.scanned, child: Text(RollStatus.scanned.localizedLabel(l10n))),
      ],
      onChanged: (status) {
        if (status != null) {
          setState(() {
            _formData.status = status;
            if (!_showDriveUrlField) {
              _formData.driveUrl = null;
            }
          });
        }
      },
    );
  }

  Widget _buildStepOne(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSearchableStockPicker(l10n),
        const SizedBox(height: 16),
        _buildSearchableCameraPicker(l10n),
        const SizedBox(height: 16),
        _buildFrameInput(l10n),
      ],
    );
  }

  Widget _buildStepTwo(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HalideTextField(
          label: halideCaps(l10n.title),
          initialValue: _formData.title,
          onChanged: (val) => _formData.title = val,
        ),
        const SizedBox(height: 16),
        HalideTextField(
          label: halideCaps(l10n.description),
          initialValue: _formData.description,
          onChanged: (val) => _formData.description = val,
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: HalideTextField(
                label: halideCaps(l10n.iso),
                initialValue: _formData.shotAtIso?.toString(),
                keyboardType: TextInputType.number,
                onChanged: (val) => _formData.shotAtIso = int.tryParse(val),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: HalideTextField(
                label: halideCaps(l10n.expiredYear),
                initialValue: _formData.expiredYear?.toString(),
                keyboardType: TextInputType.number,
                onChanged: (val) => _formData.expiredYear = int.tryParse(val),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildStatusSelector(l10n),
        if (_showDriveUrlField) ...[
          const SizedBox(height: 16),
          HalideTextField(
            label: halideCaps(l10n.driveUrlOptional),
            initialValue: _formData.driveUrl,
            onChanged: (val) => _formData.driveUrl = val,
          ),
        ],
      ],
    );
  }

  void _goNext() {
    if (_formData.selectedStock == null) {
      setState(() {
        _showValidationError = true;
        _showFramesError = false;
      });
      return;
    }
    if (_formData.maxFrames < 1) {
      setState(() {
        _showFramesError = true;
        _showValidationError = false;
      });
      return;
    }
    setState(() {
      _showValidationError = false;
      _showFramesError = false;
      _step = 1;
    });
  }

  Widget _buildStepTwoActions(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HalideActionButton(
          text: halideCaps(l10n.startRoll),
          onPressed: _submit,
        ),
        SizedBox(height: 4),
        TextButton(
          onPressed: () => setState(() => _step = 0),
          style: TextButton.styleFrom(
            foregroundColor: HalideColors.of(context).textSecondary,
            minimumSize: const Size(double.infinity, 44),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            halideCaps(l10n.back),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocListener<RollsBloc, RollsState>(
      listener: (context, state) async {
        if (state is RollActionSuccess) {
          ref.read(addRollFormDataProvider).clear();
          final id = state.createdRollId;
          final driveUrl = state.driveUrlToSync;

          if (id != null) {
            ref.read(newRollGuidanceRollIdProvider.notifier).setPending(id);
          }
          widget.onRollAdded();
          ref.read(notificationProvider.notifier).show(
            'YOUR NEW ROLL IS READY TO SHOOT!',
            type: NotificationType.success,
          );

          if (id != null && driveUrl != null && driveUrl.isNotEmpty) {
            FetchScansHelper.handleFetchScans(
              context: context,
              ref: ref,
              rollId: id,
              driveUrl: driveUrl,
            );
          }

          Navigator.of(context).pop();
        } else if (state is RollsError) {
          ref.read(notificationProvider.notifier).show(
            state.message,
            type: NotificationType.error,
          );
        }
      },
      child: HalideModalContainer(
        padding: const EdgeInsets.all(32),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      halideCaps(l10n.openNewRoll),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: HalideColors.of(context).textPrimary,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildStepIndicator(l10n),
                    const SizedBox(height: 24),
                    if (_step == 0) _buildStepOne(l10n) else _buildStepTwo(l10n),
                    const SizedBox(height: 32),
                    if (_step == 0)
                      HalideActionButton(
                        text: halideCaps(l10n.next),
                        onPressed: _goNext,
                      )
                    else
                      _buildStepTwoActions(l10n),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSearchableStockPicker(AppLocalizations l10n) {
    return Autocomplete<FilmStock>(
      displayStringForOption: (stock) =>
          '${stock.brand} ${stock.name} (${stock.format})',
      optionsBuilder: (textEditingValue) =>
          _filmStockOptionsForQuery(textEditingValue.text),
      onSelected: (stock) => setState(() {
        _formData.selectedStock = stock;
        _showValidationError = false;
      }),
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return HalideTextField(
          controller: controller,
          focusNode: focusNode,
          label: halideCaps(l10n.filmStock),
          errorText: (_showValidationError && _formData.selectedStock == null)
              ? 'PLEASE SELECT A FILM STOCK'
              : null,
          onTap: () => _kickAutocompleteOptions(controller),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              constraints: const BoxConstraints(maxHeight: 250),
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF314F6E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final stock = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(
                      '${stock.brand} ${stock.name} (${stock.format})',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    onTap: () => onSelected(stock),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchableCameraPicker(AppLocalizations l10n) {
    return Autocomplete<Camera>(
      displayStringForOption: (camera) => camera.displayName,
      optionsBuilder: (textEditingValue) =>
          _cameraOptionsForQuery(textEditingValue.text),
      onSelected: (camera) => setState(() => _formData.selectedCamera = camera),
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return HalideTextField(
          controller: controller,
          focusNode: focusNode,
          label: halideCaps(l10n.gear),
          onTap: () => _kickAutocompleteOptions(controller),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              constraints: const BoxConstraints(maxHeight: 250),
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF314F6E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final camera = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(
                      camera.displayName,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    onTap: () => onSelected(camera),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _submit() {
    if (_formData.selectedStock == null) {
      setState(() {
        _showValidationError = true;
        _step = 0;
      });
      return;
    }
    if (_formData.maxFrames < 1) {
      setState(() {
        _showFramesError = true;
        _step = 0;
      });
      return;
    }

    final isPro = ref.read(userPlanProvider).isPro;
    context.read<RollsBloc>().add(
      AddRollEvent(
        filmStockId: _formData.selectedStock!.id,
        userCameraId: _formData.selectedCamera?.id,
        title: _formData.title,
        description: _formData.description,
        shotAtIso: _formData.shotAtIso,
        expiredYear: _formData.expiredYear,
        maxFrames: _formData.maxFrames,
        status: _formData.status.name,
        driveUrl: isPro ? _formData.driveUrl : null,
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final String label;
  final String title;
  final bool active;
  final bool done;

  const _StepDot({
    required this.label,
    required this.title,
    required this.active,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final color = active || done ? HalideColors.of(context).slateTeal : HalideColors.of(context).steel;
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? HalideColors.of(context).slateTeal.withValues(alpha: 0.2) : HalideColors.of(context).glassFill(0.06),
            border: Border.all(color: color, width: active ? 2 : 1),
          ),
          child: Center(
            child: done
                ? Icon(Icons.check, size: 14, color: HalideColors.of(context).slateTeal)
                : Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 9,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: color,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}
