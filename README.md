# FPS Survivor Prototype — Godot 4.7 (GDScript)

État : **jalon 3** (ennemis qui poursuivent le joueur, dégâts de contact, PV, XP, crédits, soin, défaite).

## Lancer
Ouvrir Godot 4.7 → Importer → `project.godot`, laisser l'import se terminer, puis F5.

## Contrôles (clavier AZERTY, touches physiques)
| Action | Touche |
|---|---|
| Avancer / Reculer / Gauche / Droite | Z / S / Q / D |
| Sauter / Sprinter | Espace / Shift gauche |
| Tirer | Clic gauche |
| Recharger | R |
| Arme principale 1 / 2 / pistolet | 1 / 2 / 3 |
| Arme précédente / suivante | Molette |
| Pause (libère la souris) | Échap |
| Overlay de diagnostic | F3 |
| Test : +25 ennemis | F4 |
| Test : séparation des ennemis on/off | F6 |

## Tests automatisés
```
godot --headless --path . --import
godot --headless --path . res://tests/milestone1_test.tscn
godot --headless --path . res://tests/milestone2_test.tscn
godot --headless --path . res://tests/milestone3_test.tscn
```
Code de sortie 0 = tous les tests passent.

## Réglages (sans toucher au code)
- Déplacement, saut, sensibilité, FOV : `data/player/player_movement_config.tres`
- Chance et multiplicateur critiques de base : `data/player/player_stats_data.tres`
- Pistolet (dégâts, cadence, chargeur, rechargement, dispersion, recul, sons) : `data/weapons/pistol.tres`
- PV et réapparition des mannequins : `targets/training_dummy.tscn`
- Ennemi standard (PV, vitesse, dégâts et intervalle de contact, XP, crédits, chance de soin) : `data/enemies/standard_enemy.tres`
- PV max et invulnérabilité du joueur : nœud `PlayerHealth` de `player/player.tscn`
- Pool, séparation (rayon, force) et nombre max de soins au sol : nœud `Enemies` de `game/game.tscn`
- Générateur de test (population maintenue, salve F4, distances) : nœud `DebugSpawner` de `game/game.tscn`
- Montant de soin et durée de vie du soin : `pickups/heal_pickup.gd`
- Arène (100 × 100 m, obstacles, buttes et crêtes praticables) : `arena/arena.tscn` ; dimensions d'un relief = propriétés `base_size`, `top_size`, `height` des nœuds sous `Relief` (pentes < 40°)
