// lib/data/models/energy_valence.dart
// ORDER IS FIXED — stored as int index in Goal.energyValenceIndex.
// neutral = 0 so goals persisted without this field read as neutral.
// Never reorder these values.
enum EnergyValence { neutral, gives, costs }
