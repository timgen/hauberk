import 'package:piecemeal/piecemeal.dart';

import '../engine.dart';
import 'drops.dart';
import 'dungeon/dungeon.dart';
import 'monsters.dart';
import 'tiles.dart';

typedef Vec ChooseLocation(Dungeon dungeon);

final _spawnPattern = new RegExp(r"(.*) (\d+)-(\d+)");

int _depth = 1;

class Encounters {
  static final ResourceSet<Encounter> _encounters = new ResourceSet();

  static void initialize() {
    _encounters.defineTags("encounter");

    _depth = 1;
    _encounter(["green jelly 0-5"],
        locate: _hugWalls, decorate: _stain(Tiles.greenJellyStain, 5));

    _encounter(["brown spider 0-2"],
        locate: _preferCorridor, decorate: _stain(Tiles.spiderweb, 3));

    _encounter(["giant cockroach 2-5"], locate: _hugWalls);

    // TODO: Tune this?
    _encounter([],
        locate: _hugWalls,
        drops: [
          percentDrop(60, "Skull", 1),
          percentDrop(30, "weapon", 1),
          percentDrop(30, "armor", 1),
          percentDrop(40, "magic", 1)
        ]);

    _depth = 2;
    _single("stray cat");

    _depth = 3;
    _encounter(["gray spider 0-1"],
        locate: _preferCorridor, decorate: _stain(Tiles.spiderweb, 4));
  }

  static _Decorator _stain(TileType tile, int distance) =>
      new _StainDecorator(tile, distance);

  static void _single(String breed, {int rarity = 1}) {
    _encounter([breed], rarity: rarity);
  }

  static void _encounter(List<String> spawns,
      {ChooseLocation locate,
      _Decorator decorate,
      int rarity = 1,
      List<Drop> drops = const []}) {
    var spawnObjects = <_Spawn>[];
    for (var spawn in spawns) {
      var match = _spawnPattern.firstMatch(spawn);

      String breed;
      int min;
      int max;
      if (match != null) {
        breed = match[1];
        min = int.parse(match[2]);
        max = int.parse(match[3]);
      } else {
        breed = spawn;
        min = 1;
        max = 1;
      }

      spawnObjects.add(new _Spawn(Monsters.breeds.find(breed), min, max));
    }

    if (locate == null) locate = _anywhere;
    _encounters.addUnnamed(new Encounter(locate, decorate, spawnObjects, drops),
        _depth, rarity, "encounter");
  }

  static Encounter choose(int depth) =>
      _encounters.tryChoose(depth, "encounter");
}

class Encounter {
  final ChooseLocation _location;
  final _Decorator _decorator;
  final List<_Spawn> _spawns;
  final List<Drop> _drops;

  Encounter(this._location, this._decorator, this._spawns, this._drops);

  void spawn(Dungeon dungeon) {
    var encounterPos = _location(dungeon);

    var monsterCount = 0;
    var flow = new Flow(dungeon.stage, encounterPos);

    for (var spawn in _spawns) {
      var count = rng.inclusive(spawn.min, spawn.max);
      if (count == 0) continue;

      for (var i = 0; i < count; i++) {
        var monsterPos = encounterPos;
        if (dungeon.stage.actorAt(monsterPos) != null) {
          monsterPos =
              flow.nearestWhere((pos) => dungeon.stage.actorAt(pos) == null);
        }
        if (monsterPos == null) break;

        dungeon.spawnMonster(spawn.breed, monsterPos);
        monsterCount++;
      }
    }

    if (_decorator != null) {
      _decorator.decorate(dungeon, encounterPos, monsterCount);
    }

    for (var drop in _drops) {
      // TODO: Mostly copied from Monster.onDied(). Refactor.
      // Try to keep dropped items from overlapping.
      var flow = new Flow(dungeon.stage, encounterPos,
          canOpenDoors: false, ignoreActors: true);

      drop.spawnDrop((item) {
        var itemPos = encounterPos;
        if (dungeon.stage.isItemAt(itemPos)) {
          itemPos = flow.nearestWhere((pos) {
            if (rng.oneIn(5)) return true;
            return !dungeon.stage.isItemAt(pos);
          });

          if (itemPos == null) itemPos = encounterPos;
        }

        dungeon.stage.addItem(item, itemPos);
      });
    }
  }
}

Vec _anywhere(Dungeon dungeon) => dungeon.stage.findOpenTile();

Vec _hugWalls(Dungeon dungeon) => _preferWalls(dungeon, 20, 4);

Vec _preferCorridor(Dungeon dungeon) {
  // Don't *always* go in corridors.
  if (rng.oneIn(6)) return _hugWalls(dungeon);

  return dungeon.findOpenCorridor();
}

Vec _preferWalls(Dungeon dungeon, int tries, int idealWalls) {
  var bestWalls = -1;
  Vec best;
  for (var i = 0; i < tries; i++) {
    var pos = dungeon.stage.findOpenTile();
    var walls = Direction.all.where((dir) {
      return !dungeon.getTileAt(pos + dir).isTraversable;
    }).length;

    // Don't try to crowd corridors.
    if (walls >= 6 && !rng.oneIn(3)) continue;

    // Early out as soon as we find a good enough spot.
    if (walls >= idealWalls) return pos;

    if (walls > bestWalls) {
      best = pos;
      bestWalls = walls;
    }
  }

  // Otherwise, take the best we could find.
  return best;
}

class _Spawn {
  final Breed breed;
  final int min;
  final int max;

  _Spawn(this.breed, this.min, this.max);
}

abstract class _Decorator {
  void decorate(Dungeon dungeon, Vec pos, int mounterCount);
}

class _StainDecorator extends _Decorator {
  final TileType _tile;
  final int _distance;

  _StainDecorator(this._tile, this._distance);

  void decorate(Dungeon dungeon, Vec start, int monsterCount) {
    // Make a bunch of wandering paths from the starting point, leaving stains
    // as they go.
    for (var i = 0; i < 1 + monsterCount * 2; i++) {
      var pos = start;
      for (var j = 0; j < _distance; j++) {
        if (rng.percent(60) && dungeon.getTileAt(pos) == Tiles.floor) {
          dungeon.setTileAt(pos, _tile);
        }

        var dirs = Direction.all.where((dir) {
          return dungeon.getTileAt(pos + dir).isTraversable;
        }).toList();
        pos += rng.item(dirs);
      }
    }
  }
}
