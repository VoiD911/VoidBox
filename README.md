# VoidBox

Raid frames minimalistes pour healers avec click-casting — Style Cell/VuhDo.

Compatible **WoW 12.0 Midnight** (secret values, nouvelles APIs).

## Fonctionnalités

- **Raid frames compacts** avec barres de vie et mana
- **Click-casting** via SecureUnitButtonTemplate (fonctionne en combat)
- **Pourcentage de vie** affiché via `UnitHealthPercent` + `C_CurveUtil` (contourne les secret values 12.0)
- **Bindings par classe** — tous vos prêtres partagent les mêmes bindings
- **Drag & drop** depuis le grimoire pour assigner les sorts
- **Indicateurs** :
  - Rôle (tank/heal/dps) — carré coloré en haut à gauche
  - HOTs/boucliers actifs — carré vert en bas à droite
  - Debuffs dispellables — icônes en bas à gauche (max 3)
  - Menace (bordure rouge/jaune)
  - Portée (opacité réduite hors portée)
  - Mort / Déconnecté / Résurrection en cours
  - Ready check
- **Tri par rôle** : Tank > DPS > Healer
- **Configuration UI** : taille des frames, couleurs de classe, verrouillage
- **Couleur thème** : violet (`#9966FF`)

## Commandes

| Commande | Description |
|----------|-------------|
| `/vb` | Affiche l'aide |
| `/vb config` | Ouvre la configuration |
| `/vb lock` | Verrouille les frames |
| `/vb unlock` | Déverrouille les frames |
| `/vb reset` | Réinitialise la position |
| `/vb debug` | Toggle le mode debug |
| `/vb debughealth` | Debug des valeurs de vie (secret values) |

## Utilisation

1. Le petit carré violet à gauche des frames permet de **glisser** pour déplacer
2. **Clic droit** sur le carré violet pour ouvrir la **configuration**
3. Dans la config, onglet **Click-Castings** : glissez un sort depuis le grimoire sur un slot
4. Les bindings sont sauvegardés **par classe** (pas par personnage)

## Installation

1. Téléchargez la dernière release
2. Extrayez le dossier `VoidBox/` dans `World of Warcraft/_retail_/Interface/AddOns/`
3. Relancez WoW ou faites `/reload`

## Secret Values (WoW 12.0)

Cet addon implémente une solution pour le problème des "secret values" introduit en 12.0 Midnight.
Les valeurs de vie retournées par `UnitHealth()` sont protégées et aucune opération mathématique n'est possible dessus.

La solution utilise `UnitHealthPercent()` combiné avec `C_CurveUtil.CreateCurve()` pour obtenir
le pourcentage de vie affichable via `string.format()`.

## Licence

MIT License — voir [LICENSE](LICENSE)
