import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/film_stock.dart';
import 'package:frontend/models/camera.dart';
import 'package:frontend/features/rolls/data/rolls_repository.dart';
import 'package:frontend/features/rolls/presentation/bloc/rolls_bloc.dart';
import 'package:frontend/core/widgets/halide_dialog.dart';
import 'package:frontend/core/providers/notification_provider.dart';
import 'package:frontend/core/models/notification_model.dart';
import 'package:frontend/providers/guidance_pending_provider.dart';

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
  
  FilmStock? _selectedStock;
  Camera? _selectedCamera;
  String? _title;
  String? _description;
  int? _shotAtIso;
  int? _expiredYear;
  int _maxFrames = 36;

  List<FilmStock> _stocks = [];
  List<Camera> _cameras = [];
  bool _isLoading = true;
  bool _showValidationError = false;

  final _stockController = TextEditingController();
  final _cameraController = TextEditingController();

  @override
  void initState() {
    super.initState();
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
      (stock) => stock.name.toLowerCase().contains(q) || stock.brand.toLowerCase().contains(q),
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

  @override
  Widget build(BuildContext context) {
    return BlocListener<RollsBloc, RollsState>(
      listener: (context, state) {
        if (state is RollActionSuccess) {
          final id = state.createdRollId;
          if (id != null) {
            ref.read(newRollGuidanceRollIdProvider.notifier).setPending(id);
          }
          widget.onRollAdded();
          ref.read(notificationProvider.notifier).show(
            'YOUR NEW ROLL IS READY TO SHOOT!',
            type: NotificationType.success,
          );
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
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
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
                    HalideTextField(
                      label: 'TITLE',
                      onChanged: (val) => _title = val,
                    ),
                    const SizedBox(height: 16),
                    HalideTextField(
                      label: 'DESCRIPTION',
                      onChanged: (val) => _description = val,
                      maxLines: 2,
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
                            keyboardType: TextInputType.number,
                            onChanged: (val) => _shotAtIso = int.tryParse(val),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: HalideTextField(
                            label: 'EXPIRED YEAR',
                            keyboardType: TextInputType.number,
                            onChanged: (val) => _expiredYear = int.tryParse(val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    HalideTextField(
                      label: 'TOTAL FRAMES (E.G. 36)',
                      keyboardType: TextInputType.number,
                      onChanged: (val) => _maxFrames = int.tryParse(val) ?? 36,
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
      displayStringForOption: (stock) => '${stock.brand} ${stock.name} (${stock.format})',
      optionsBuilder: (textEditingValue) => _filmStockOptionsForQuery(textEditingValue.text),
      onSelected: (stock) => setState(() {
        _selectedStock = stock;
        _showValidationError = false;
      }),
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return HalideTextField(
          controller: controller,
          focusNode: focusNode,
          label: 'FILM STOCK (*)', 
          errorText: (_showValidationError && _selectedStock == null) ? 'PLEASE SELECT A FILM STOCK' : null,
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
                    title: Text('${stock.brand} ${stock.name} (${stock.format})', style: const TextStyle(color: Colors.white, fontSize: 13)),
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
      optionsBuilder: (textEditingValue) => _cameraOptionsForQuery(textEditingValue.text),
      onSelected: (camera) => setState(() => _selectedCamera = camera),
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
                    title: Text(camera.displayName, style: const TextStyle(color: Colors.white, fontSize: 13)),
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
    if (_selectedStock == null) {
      setState(() => _showValidationError = true);
      return;
    }
    
    context.read<RollsBloc>().add(AddRollEvent(
      filmStockId: _selectedStock!.id,
      userCameraId: _selectedCamera?.id,
      title: _title,
      description: _description,
      shotAtIso: _shotAtIso,
      expiredYear: _expiredYear,
      maxFrames: _maxFrames,
    ));
  }
}
