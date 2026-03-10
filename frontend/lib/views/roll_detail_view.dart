import 'package:flutter/material.dart';

class RollDetailView extends StatelessWidget {
  final String rollId;

  const RollDetailView({Key? key, required this.rollId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Roll Detail - $rollId'),
      ),
      body: const Center(
        child: Text('Roll Detail View Empty State'),
      ),
    );
  }
}
