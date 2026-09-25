import '../models/inventory_item.dart';

/// Pure inventory helpers (no widgets, no I/O) so the workflow rules are
/// unit-testable and shared between screens.
///
/// - Quantities are never negative: stepping/clamping floors at 0, matching
///   the backend rule `quantity >= 0` (inventory.controller.js).
/// - Search filters the already-loaded list locally (no backend endpoint).
/// - Stock totals are grouped per unit: mixed units (bags, kg, pieces)
///   cannot be summed into one number, so they are displayed separately
///   rather than compared against godown capacity.

/// Floors [value] at zero.
double clampQuantity(double value) => value < 0 ? 0 : value;

/// Steps [current] by [step] (use negative step to decrement), never below 0.
double stepQuantity(double current, double step) => clampQuantity(current + step);

/// Formats a quantity without a trailing `.0` for whole numbers.
String formatQuantity(double value) {
  if (value % 1 == 0) return value.toInt().toString();
  return value.toString();
}

/// Case-insensitive substring filter on item name over the loaded list.
/// Empty/blank query returns the full list.
List<InventoryItem> filterInventoryByName(List<InventoryItem> items, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return List<InventoryItem>.from(items);
  return items.where((i) => i.itemName.toLowerCase().contains(q)).toList();
}

/// Sums quantities grouped by unit, e.g. `{bags: 500, kg: 20}`.
Map<String, double> totalsByUnit(List<InventoryItem> items) {
  final totals = <String, double>{};
  for (final item in items) {
    totals.update(item.unit, (v) => v + item.quantity,
        ifAbsent: () => item.quantity);
  }
  return totals;
}

/// Human-readable stock summary, e.g. `500 bags · 20 kg`, or `—` when empty.
String stockSummary(List<InventoryItem> items) {
  final totals = totalsByUnit(items);
  if (totals.isEmpty) return '—';
  return totals.entries.map((e) => '${formatQuantity(e.value)} ${e.key}').join(' · ');
}
