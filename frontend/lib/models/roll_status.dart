enum RollStatus {
  shooting('Shooting'),
  finished('Finished'),
  atLab('At Lab'),
  developed('Developed');

  final String label;
  const RollStatus(this.label);
}
