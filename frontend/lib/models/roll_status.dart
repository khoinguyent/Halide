enum RollStatus {
  shooting('Shooting'),
  lab('At Lab'),
  scanned('Scanned'),
  archived('Archived');

  final String label;
  const RollStatus(this.label);
}

RollStatus statusFromString(String status) {
  return RollStatus.values.firstWhere(
    (e) => e.name == status.toLowerCase() || e.label.toLowerCase() == status.toLowerCase(),
    orElse: () => RollStatus.shooting,
  );
}
