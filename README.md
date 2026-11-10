# FPS Survivor Prototype — Godot 4.7 (GDScript)

État : **jalon 2** (pistolet, tir hitscan, chargeur, rechargement, critiques, recul, impacts, mannequins).

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

## Tests automatisés
```
godot --headless --path . --import
godot --headless --path . res://tests/milestone1_test.tscn
godot --headless --path . res://tests/milestone2_test.tscn
```
Code de sortie 0 = tous les tests passent.

## Réglages (sans toucher au code)
- Déplacement, saut, sensibilité, FOV : `data/player/player_movement_config.tres`
- Chance et multiplicateur critiques de base : `data/player/player_stats_data.tres`
- Pistolet (dégâts, cadence, chargeur, rechargement, dispersion, recul, sons) : `data/weapons/pistol.tres`
- PV et réapparition des mannequins : `targets/training_dummy.tscn`
