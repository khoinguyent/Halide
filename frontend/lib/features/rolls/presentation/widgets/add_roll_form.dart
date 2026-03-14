import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:frontend/models/film_stock.dart';
import 'package:frontend/models/camera.dart';
import 'package:frontend/features/rolls/data/rolls_repository.dart';

class AddRollForm extends StatefulWidget {
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

class _AddRollFormState extends State<AddRollForm> {
  final _formKey = GlobalKey<FormState>();
  
  FilmStock? _selectedStock;
  Camera? _selectedCamera;
  int? _shotAtIso;
  int? _expiredYear;
  int _maxFrames = 36;

  List<FilmStock> _stocks = [];
  List<Camera> _cameras = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
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
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'ADD NEW ROLL',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 2
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildSearchableStockPicker(),
                            const SizedBox(height: 16),
                            _buildSearchableCameraPicker(),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(child: _buildNumberField('ISO', (val) => _shotAtIso = val)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildNumberField('EXPIRED YEAR', (val) => _expiredYear = val)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildNumberField('TOTAL FRAMES (e.g. 36)', (val) => _maxFrames = val ?? 36),
                            const SizedBox(height: 32),
                            ElevatedButton(
                              onPressed: _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('INITIALIZE ROLL'),
                            ),
                          ],
                        ),
                      ),
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchableStockPicker() {
    return Autocomplete<FilmStock>(
      displayStringForOption: (stock) => '${stock.brand} ${stock.name}',
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) return const Iterable<FilmStock>.empty();
        return _stocks.where((stock) => 
          stock.name.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
          stock.brand.toLowerCase().contains(textEditingValue.text.toLowerCase())
        );
      },
      onSelected: (stock) => setState(() => _selectedStock = stock),
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('SEARCH FILM STOCK'),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width - 96,
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final stock = options.elementAt(index);
                  return ListTile(
                    title: Text('${stock.brand} ${stock.name}', style: const TextStyle(color: Colors.white)),
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
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) return const Iterable<Camera>.empty();
        return _cameras.where((camera) => 
          camera.displayName.toLowerCase().contains(textEditingValue.text.toLowerCase())
        );
      },
      onSelected: (camera) => setState(() => _selectedCamera = camera),
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('SEARCH CAMERA'),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width - 96,
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final camera = options.elementAt(index);
                  return ListTile(
                    title: Text(camera.displayName, style: const TextStyle(color: Colors.white)),
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

  Widget _buildNumberField(String label, Function(int?) onSaved) {
    return TextField(
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      onChanged: (val) => onSaved(int.tryParse(val)),
      decoration: _inputDecoration(label),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
    );
  }

  void _submit() async {
    if (_selectedStock == null || _selectedCamera == null) return;
    
    await widget.repository.createRoll(
      filmStockId: _selectedStock!.id,
      userCameraId: _selectedCamera!.id,
      shotAtIso: _shotAtIso,
      expiredYear: _expiredYear,
      maxFrames: _maxFrames,
    );
    widget.onRollAdded();
    Navigator.of(context).pop();
  }
}
