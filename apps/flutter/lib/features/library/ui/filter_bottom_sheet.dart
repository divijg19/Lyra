import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../library_notifier.dart';
import '../models/track_filters.dart';

class FilterBottomSheet extends ConsumerStatefulWidget {
  const FilterBottomSheet({super.key, required this.initialFilters});

  final TrackFilters initialFilters;

  @override
  ConsumerState<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<FilterBottomSheet> {
  static const RangeValues _bpmBounds = RangeValues(50, 200);
  static const RangeValues _unitBounds = RangeValues(0, 1);

  late RangeValues _bpmRange;
  late RangeValues _energyRange;
  late RangeValues _valenceRange;

  @override
  void initState() {
    super.initState();
    _bpmRange = RangeValues(
      widget.initialFilters.minBpm ?? _bpmBounds.start,
      widget.initialFilters.maxBpm ?? _bpmBounds.end,
    );
    _energyRange = RangeValues(
      widget.initialFilters.minEnergy ?? _unitBounds.start,
      widget.initialFilters.maxEnergy ?? _unitBounds.end,
    );
    _valenceRange = RangeValues(
      widget.initialFilters.minValence ?? _unitBounds.start,
      widget.initialFilters.maxValence ?? _unitBounds.end,
    );
  }

  bool _isFullRange(RangeValues values, RangeValues bounds) {
    return values.start == bounds.start && values.end == bounds.end;
  }

  Future<void> _apply() async {
    final filters = TrackFilters(
      minBpm: _isFullRange(_bpmRange, _bpmBounds) ? null : _bpmRange.start,
      maxBpm: _isFullRange(_bpmRange, _bpmBounds) ? null : _bpmRange.end,
      minEnergy: _isFullRange(_energyRange, _unitBounds)
          ? null
          : _energyRange.start,
      maxEnergy: _isFullRange(_energyRange, _unitBounds)
          ? null
          : _energyRange.end,
      minValence: _isFullRange(_valenceRange, _unitBounds)
          ? null
          : _valenceRange.start,
      maxValence: _isFullRange(_valenceRange, _unitBounds)
          ? null
          : _valenceRange.end,
    );

    await ref.read(tracksNotifierProvider.notifier).applyFilters(filters);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _clear() async {
    setState(() {
      _bpmRange = _bpmBounds;
      _energyRange = _unitBounds;
      _valenceRange = _unitBounds;
    });

    await ref
        .read(tracksNotifierProvider.notifier)
        .applyFilters(TrackFilters.empty);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter Tracks',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text(
              'BPM (${_bpmRange.start.round()} - ${_bpmRange.end.round()})',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            RangeSlider(
              min: 50,
              max: 200,
              divisions: 150,
              values: _bpmRange,
              labels: RangeLabels(
                _bpmRange.start.round().toString(),
                _bpmRange.end.round().toString(),
              ),
              onChanged: (values) => setState(() => _bpmRange = values),
            ),
            Text(
              'Energy (${_energyRange.start.toStringAsFixed(2)} - ${_energyRange.end.toStringAsFixed(2)})',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            RangeSlider(
              min: 0,
              max: 1,
              divisions: 100,
              values: _energyRange,
              labels: RangeLabels(
                _energyRange.start.toStringAsFixed(2),
                _energyRange.end.toStringAsFixed(2),
              ),
              onChanged: (values) => setState(() => _energyRange = values),
            ),
            Text(
              'Valence (${_valenceRange.start.toStringAsFixed(2)} - ${_valenceRange.end.toStringAsFixed(2)})',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            RangeSlider(
              min: 0,
              max: 1,
              divisions: 100,
              values: _valenceRange,
              labels: RangeLabels(
                _valenceRange.start.toStringAsFixed(2),
                _valenceRange.end.toStringAsFixed(2),
              ),
              onChanged: (values) => setState(() => _valenceRange = values),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _clear,
                  child: const Text('Clear Filters'),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _apply, child: const Text('Apply')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
