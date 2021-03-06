import 'dart:math' as math;

import 'package:piecemeal/piecemeal.dart';

import '../core/combat.dart';
import '../core/energy.dart';
import '../core/game.dart';
import '../core/log.dart';
import '../core/option.dart';
import '../hero/hero.dart';
import '../items/item.dart';
import '../stage/tile.dart';
import 'monster.dart';
import 'move.dart';

/// A single kind of [Monster] in the game.
class Breed {
  final Pronoun pronoun;
  String get name => Log.singular(_name);

  /// Untyped so the engine isn't coupled to how monsters appear.
  final appearance;

  /// The breeds's depth.
  ///
  /// Higher depth breeds are found later in the game.
  final int depth;

  final List<Attack> attacks;
  final List<Move> moves;

  final int maxHealth;

  /// How well the monster can navigate the stage to reach its target.
  ///
  /// Used to determine maximum pathfinding distance.
  final int tracking;

  /// How many tiles away the monster can see the hero.
  final int vision;

  /// How many tiles away (as sound flows) the monster can hear the hero.
  final int hearing;

  /// How much randomness the monster has when walking towards its target.
  final int meander;

  /// The breed's speed, relative to normal. Ranges from `-6` (slowest) to `6`
  /// (fastest) where `0` is normal speed.
  final int speed;

  /// The [Item]s this monster may drop when killed.
  final Drop drop;

  final SpawnLocation location;

  final MotilitySet motilities;

  final Set<String> flags;

  /// Base chance for this breed to dodge an attack.
  final int dodge;

  /// Additional defenses this breed has.
  final List<Defense> defenses = [];

  /// The minimum number of this breed that are spawned when it is placed in
  /// the dungeon.
  final int countMin;

  /// The minimum number of this breed that are spawned when it is placed in
  /// the dungeon.
  final int countMax;

  /// Additional monsters that should be spawned when this one is spawned.
  final List<Minion> minions = [];

  /// The name of the breed. If the breed's name has irregular pluralization
  /// like "bunn[y|ies]", this will be the original unparsed string.
  final String _name;

  /// If this breed should stain some of the nearby floor tiles when spawned,
  /// this is the type is should stain them with. Otherwise null.
  final TileType stain;

  Breed(this._name, this.pronoun, this.appearance, this.attacks, this.moves,
      this.drop, this.location, this.motilities,
      {this.depth,
      this.maxHealth,
      this.tracking,
      int vision,
      int hearing,
      this.meander,
      int speed,
      int dodge,
      this.countMin,
      this.countMax,
      this.stain,
      this.flags})
      : vision = vision ?? 16,
        hearing = hearing ?? 16,
        speed = speed ?? 0,
        dodge = dodge ?? 20;

  /// How much experience a level one [Hero] gains for killing a [Monster] of
  /// this breed.
  int get experienceCents {
    // The more health it has, the longer it can hurt the hero.
    var exp = maxHealth.toDouble();

    // The more it can dodge, the longer it lives.
    var totalDodge = dodge;
    for (var defense in defenses) {
      totalDodge += defense.amount;
    }

    exp *= 1.0 + totalDodge / 100.0;

    // Faster monsters are worth more.
    exp *= Energy.gains[Energy.normalSpeed + speed];

    // Average the attacks (since they are selected randomly) and factor them
    // in.
    var attackTotal = 0.0;
    for (var attack in attacks) {
      // TODO: Take range into account?
      attackTotal += attack.damage * attack.element.experience;
    }

    attackTotal /= attacks.length;

    var moveTotal = 0.0;
    var moveRateTotal = 0.0;
    for (var move in moves) {
      // Scale by the move rate. The less frequently a move can be performed,
      // the less it affects experience.
      moveTotal += move.experience / move.rate;

      // Magify the rate to roughly account for the fact that a move may not be
      // applicable all the time.
      moveRateTotal += 1 / (move.rate * 2);
    }

    // A monster can only do one thing each turn, so even if the move rates
    // are better than than, limit it.
    moveRateTotal = math.min(1.0, moveRateTotal);

    // Time spent using moves is not time spent attacking.
    attackTotal *= (1.0 - moveRateTotal);

    // Add in moves and attacks.
    exp *= attackTotal + moveTotal;

    // Take into account flags.
    for (var flag in flags) {
      exp *= Option.expFlag[flag];
    }

    // TODO: Modify by motility?

    // Meandering monsters are worth less.
    exp *= (Option.expMeander - meander) / Option.expMeander;

    return exp.toInt();
  }

  Monster spawn(Game game, Vec pos, [Monster parent]) {
    var generation = 1;
    if (parent != null) generation = parent.generation + 1;

    return new Monster(game, this, pos.x, pos.y, maxHealth, generation);
  }

  /// Generate the list of breeds spawned by this breed.
  ///
  /// Each item in the list represents a breed that should spawn a single
  /// monster. Takes into account this breed's count and minions.
  List<Breed> spawnAll() {
    var breeds = <Breed>[];

    // This breed.
    var count = rng.inclusive(countMin, countMax);
    for (var i = 0; i < count; i++) {
      breeds.add(this);
    }

    for (var minion in minions) {
      count = rng.inclusive(minion.countMin, minion.countMax);
      for (var i = 0; i < count; i++) {
        breeds.add(minion.breed);
      }
    }

    return breeds;
  }
}

// TODO: Should this affect how the monster moves during the game too?
/// Where in the dungeon the breed prefers to spawn.
enum SpawnLocation {
  anywhere,

  /// Away from walls.
  open,

  /// Adjacent to a wall.
  wall,

  /// Adjacent to multiple walls.
  corner,
}

class Minion {
  final Breed breed;
  final int countMin;
  final int countMax;

  Minion(this.breed, this.countMin, this.countMax);
}
