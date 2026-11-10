# FPS Survivor Prototype — Godot 4.3+ (GDScript)

État : **jalon 1** (arène, contrôleur FPS, HUD de diagnostic, pause).

## Lancer
1. Ouvrir Godot 4.3 ou plus récent → Importer → sélectionner `project.godot`.
2. Laisser l'éditeur terminer l'import, puis F5.

## Contrôles (clavier AZERTY, touches physiques)
| Action | Touche |
|---|---|
| Avancer / Reculer | Z / S |
| Gauche / Droite | Q / D |
| Sauter | Espace |
| Sprinter | Shift gauche |
| Caméra | Souris |
| Pause (libère la souris) | Échap |
| Overlay de diagnostic | F3 |
| Tirer, recharger, armes 1-2-3, molette | déclarés dans l'Input Map, utilisés à partir du jalon 2 |

## Test automatisé du jalon 1
```
godot --headless --path . --import
godot --headless --path . res://tests/milestone1_test.tscn
```
Code de sortie 0 = tous les tests passent.

## Réglages
Déplacement, saut, gravité, sensibilité, FOV : `data/player/player_movement_config.tres`.
