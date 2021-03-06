import 'package:piecemeal/piecemeal.dart';

import 'engine.dart';

import 'content/affixes.dart';
import 'content/dungeon/dungeon.dart';
import 'content/elements.dart';
import 'content/floor_drops.dart';
import 'content/items.dart';
import 'content/monsters.dart';
import 'content/old/recipes.dart';
import 'content/old/shops.dart';
import 'content/skills.dart';
import 'content/tiles.dart';

Content createContent() {
  // Note: The order is significant here. For example, monster drops will
  // reference items, which need to have already been created.
  Tiles.initialize();
  Items.initialize();
  Monsters.initialize();
  Recipes.initialize();
  Affixes.initialize();
  Shops.initialize();
  FloorDrops.initialize();

  return new GameContent();
}

class GameContent implements Content {
  Iterable<String> buildStage(Stage stage, int depth, Function(Vec) placeHero) {
    return new Dungeon(stage, depth).generate(placeHero);
  }

  Affix findAffix(String name) => Affixes.find(name);
  Breed findBreed(String name) => Monsters.breeds.find(name);
  ItemType tryFindItem(String name) => Items.types.tryFind(name);
  Skill findSkill(String name) => Skills.find(name);

  Iterable<Breed> get breeds => Monsters.breeds.all;
  Iterable<Element> get elements => Elements.all;
  Iterable<Skill> get skills => Skills.all;
  Iterable<Recipe> get recipes => Recipes.all;
  Iterable<Shop> get shops => Shops.all;

  HeroSave createHero(String name) {
    var hero = new HeroSave(name);

    var initialItems = {
      "Mending Salve": 3,
      "Scroll of Sidestepping": 2,
      "Tallow Candle": 4
    };

    initialItems.forEach((type, amount) {
      hero.inventory.tryAdd(new Item(Items.types.find(type), amount));
    });

    return hero;
  }
}
