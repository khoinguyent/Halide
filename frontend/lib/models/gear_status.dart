enum GearStatus {
  active('Active'),
  repair('In Repair'),
  sold('Sold'),
  archived('Archived');

  final String label;
  const GearStatus(this.label);
}

GearStatus gearStatusFromString(String status) {
  return GearStatus.values.firstWhere(
    (e) => e.name == status.toLowerCase() || e.label.toLowerCase() == status.toLowerCase(),
    orElse: () => GearStatus.active,
  );
}
