import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/film_stock.dart';
import 'package:frontend/models/camera.dart';
import 'package:frontend/models/roll_status.dart';
import 'package:frontend/features/rolls/data/rolls_repository.dart';
import 'package:frontend/features/rolls/presentation/bloc/rolls_bloc.dart';
import 'package:frontend/core/widgets/halide_dialog.dart';
import 'package:frontend/core/providers/notification_provider.dart';
import 'package:frontend/core/models/notification_model.dart';
import 'package:frontend/providers/guidance_pending_provider.dart';
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

  /// Strip zero-width chars used only to trigger [Autocomplete] option refresh on focus.
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

  Widget _buildStatusSelector() {
    return DropdownButtonFormField<RollStatus>(
      value: _formData.status,
      dropdownColor: const Color(0xFF1A1C29),
      icon: const Icon(
        Icons.keyboard_arrow_down,
        color: Colors.white24,
        size: 18,
      ),
      decoration: InputDecoration(
        labelText: 'STATUS',
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.35),
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white, width: 1.2),
        ),
      ),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        letterSpacing: 0.5,
      ),
      items: const [
        DropdownMenuItem(value: RollStatus.shooting, child: Text('Shooting')),
        DropdownMenuItem(value: RollStatus.lab, child: Text('At Lab')),
        DropdownMenuItem(value: RollStatus.scanned, child: Text('Scanned')),
      ],
      onChanged: (status) {
        if (status != null) {
          setState(() {
            _formData.status = status;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
          ref
              .read(notificationProvider.notifier)
              .show(
                'YOUR NEW ROLL IS READY TO SHOOT!',
                type: NotificationType.success,
              );

          if (id != null && driveUrl != null && driveUrl.isNotEmpty) {
            // Trigger fetch scans helper, no await so it runs after modal closes
            FetchScansHelper.handleFetchScans(
              context: context,
              ref: ref,
              rollId: id,
              driveUrl: driveUrl,
            );
          }

          Navigator.of(context).pop();
        } else if (state is RollsError) {
          ref
              .read(notificationProvider.notifier)
              .show(state.message, type: NotificationType.error);
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
                      'ADD NEW ROLL'.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildStatusSelector(),
                    const SizedBox(height: 16),
                    HalideTextField(
                      label: 'TITLE',
                      initialValue: _formData.title,
                      onChanged: (val) => _formData.title = val,
                    ),
                    const SizedBox(height: 16),
                    HalideTextField(
                      label: 'DESCRIPTION',
                      initialValue: _formData.description,
                      onChanged: (val) => _formData.description = val,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 16),
                    _buildSearchableStockPicker(),
                    const SizedBox(height: 16),
                    _buildSearchableCameraPicker(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: HalideTextField(
                            label: 'ISO',
                            initialValue: _formData.shotAtIso?.toString(),
                            keyboardType: TextInputType.number,
                            onChanged: (val) =>
                                _formData.shotAtIso = int.tryParse(val),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: HalideTextField(
                            label: 'EXPIRED YEAR',
                            initialValue: _formData.expiredYear?.toString(),
                            keyboardType: TextInputType.number,
                            onChanged: (val) =>
                                _formData.expiredYear = int.tryParse(val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    HalideTextField(
                      label: 'TOTAL FRAMES (E.G. 36)',
                      initialValue: _formData.maxFrames.toString(),
                      keyboardType: TextInputType.number,
                      onChanged: (val) =>
                          _formData.maxFrames = int.tryParse(val) ?? 36,
                    ),
                    const SizedBox(height: 16),
                    HalideTextField(
                      label: 'DRIVE URL (OPTIONAL)',
                      initialValue: _formData.driveUrl,
                      onChanged: (val) {
                        _formData.driveUrl = val;
                        if (val.trim().isNotEmpty) {
                          setState(() {
                            _formData.status = RollStatus.scanned;
                          });
                        } else {
                          setState(() {
                            _formData.status = RollStatus.shooting;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 48),
                    HalideActionButton(
                      text: 'INITIALIZE ROLL',
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSearchableStockPicker() {
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
          label: 'FILM STOCK (*)',
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
                color: const Color(0xFF1A1C29),
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

  Widget _buildSearchableCameraPicker() {
    return Autocomplete<Camera>(
      displayStringForOption: (camera) => camera.displayName,
      optionsBuilder: (textEditingValue) =>
          _cameraOptionsForQuery(textEditingValue.text),
      onSelected: (camera) => setState(() => _formData.selectedCamera = camera),
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return HalideTextField(
          controller: controller,
          focusNode: focusNode,
          label: 'GEAR',
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
                color: const Color(0xFF1A1C29),
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
      setState(() => _showValidationError = true);
      return;
    }

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
        driveUrl: _formData.driveUrl,
      ),
    );
  }
}
