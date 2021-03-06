import '../monster/breed.dart';
import '../monster/monster.dart';

/// The history of interesting events the hero has experienced.
class Lore {
  /// The number of monsters of each breed the hero has detected.
  ///
  /// (Or, more specifically, that have died.)
  final Map<Breed, int> _seen;

  /// The number of monsters of each breed the hero has killed.
  ///
  /// (Or, more specifically, that have died.)
  final Map<Breed, int> _slain;

  Lore() : this.from({}, {});

  Lore.from(this._seen, this._slain);

  void see(Monster monster) {
    _seen.putIfAbsent(monster.breed, () => 0);
    _seen[monster.breed]++;
  }

  void slay(Monster monster) {
    _slain.putIfAbsent(monster.breed, () => 0);
    _slain[monster.breed]++;
  }

  /// The number of monsters of [breed] that the hero has detected.
  int seen(Breed breed) => _seen[breed] ?? 0;

  /// The number of monsters of [breed] that the hero has killed.
  int slain(Breed breed) => _slain[breed] ?? 0;

  Lore clone() => new Lore.from(
      new Map<Breed, int>.from(_seen), new Map<Breed, int>.from(_slain));
}
