# Optimisation PC & Mac — skills `pc-checkup` et `mac-checkup` pour Claude Code

Un **check complet et une optimisation de ton ordinateur**, menés par [Claude Code](https://claude.com/claude-code) : pilotes et mises à jour, applis en double ou inutiles, fichiers en trop, mémoire, écrans, réglages, sécurité, réseau, stabilité…

| Ton ordinateur | Skill | État |
|---|---|---|
| **PC Windows 10/11** | [`pc-checkup`](pc-checkup/) | Testé de bout en bout sur un vrai PC |
| **Mac (macOS 12+)** | [`mac-checkup`](mac-checkup/) | Nouveau : syntaxe vérifiée, **pas encore lancé sur un vrai Mac**, retours bienvenus |

Le principe est le même pour les deux : Claude audite l'ordinateur **en lecture seule**, présente un rapport classé du plus gros gain au plus petit, applique **avec ton accord** les correctifs sans risque, te guide pas à pas pour le reste (BIOS, réglages système, désinstallations…), puis refait le check pour te montrer l'avant/après.

## Ce que ça a donné sur le PC de test

| Problème trouvé | Résultat |
|---|---|
| RAM 3200 MHz bridée à 2400 MHz (XMP désactivé) | Repassée à 3200 MHz |
| Un écran 180 Hz réglé à 59 Hz | Repassé à 180 Hz |
| Fortnite (35 Go) installé sur le disque dur | Déplacé sur le SSD NVMe |
| Pilotes réseau de 2021 | Mis à jour (version 2025) |
| Logiciel de dictée installé deux fois (3,7 Go) et lancé deux fois au démarrage | Doublon retiré, la copie utilisée est conservée |
| Restes d'Adobe et d'Avast, dont un composant Adobe caché qui se relançait à chaque connexion | Désinstallés proprement |
| 10 réglages de pubs et suggestions Windows, applis sponsorisées installées automatiquement | Désactivés |
| Mode Jeu désactivé, capture vidéo en arrière-plan, accélération souris | Corrigés |
| 11 logiciels pas à jour | Mis à jour |

## Installation (2 minutes)

1. Installe [Claude Code](https://claude.com/claude-code) : appli de bureau, terminal ou extension VS Code.
2. Récupère ce dépôt. Le plus simple : bouton vert **Code → Download ZIP**, puis dézippe. Avec git, tu peux aussi faire :
   ```
   git clone https://github.com/HugoSevelin/Optimisation-PC.git
   ```
3. Copie **le dossier correspondant à ton système** dans ton dossier de skills Claude :
   - **Windows** (PowerShell) :
     ```powershell
     Copy-Item -Recurse .\Optimisation-PC\pc-checkup "$env:USERPROFILE\.claude\skills\"
     ```
   - **Mac** (Terminal) :
     ```bash
     mkdir -p ~/.claude/skills && cp -R Optimisation-PC/mac-checkup ~/.claude/skills/
     ```
4. Redémarre Claude Code.

## Utilisation

Dans Claude Code, écris simplement :

> Fais un check complet de mon PC (ou de mon Mac), je veux qu'il soit le plus optimisé possible.

Tu peux aussi taper `/pc-checkup` ou `/mac-checkup`. Après tes changements, écris « refais le check » : Claude compare avec le rapport précédent.

Les rapports et tes décisions (ce que tu as accepté ou refusé) sont gardés dans `Documents\pc-checkup\` sous Windows et dans `~/mac-checkup/` sur Mac. Claude ne te repropose pas ce que tu as déjà refusé.

## Ce que le check couvre

**Windows (14 sections)** : matériel et BIOS, RAM et XMP/EXPO, GPU et écrans, pilotes, mises à jour, applications et doublons, démarrage, disques et fichiers inutiles, réglages performance et jeu, sécurité et points de restauration, stabilité, réseau, pubs Windows et applis préinstallées, jeux sur disque dur et overlays. [Détails](pc-checkup/README.md)

**Mac (10 sections)** : matériel, mémoire et batterie, stockage, mises à jour Apple/Homebrew/App Store, applis (Rosetta, doublons, inutilisées, adware), tâches de fond orphelines, espace récupérable (caches, Xcode, sauvegardes iPhone…), réglages, sécurité et Time Machine, stabilité, réseau. [Détails](mac-checkup/README.md)

## Sécurité

- Les audits sont **en lecture seule** et fonctionnent **sans droits admin** (jamais de `sudo` sur Mac). Tu peux lire les scripts avant de les utiliser, ou les lancer seuls :
  - Windows : `powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\pc-checkup\scripts\audit.ps1"`
  - Mac : `bash ~/.claude/skills/mac-checkup/scripts/audit.sh`
- Claude ne modifie **rien sans ton accord explicite**, point par point.
- Il n'applique lui-même que des réglages côté utilisateur, réversibles. **BIOS, réglages système et de sécurité, pilotes, mises à jour système** : il te guide et c'est toi qui le fais.
- Les suppressions passent **par la corbeille** quand c'est possible, après avoir vérifié que rien n'utilise les fichiers.
- Le rapport contient les noms de tes logiciels et tes chemins de dossiers : relis-le avant de le partager.

## Structure

```
pc-checkup/                    # Windows
├── SKILL.md                   # la méthode suivie par Claude
├── README.md
├── references/fixes.md        # correctifs : ce que Claude applique, ce que tu fais
└── scripts/audit.ps1          # audit en lecture seule (PowerShell 5.1+)
mac-checkup/                   # macOS
├── SKILL.md
├── README.md
├── references/fixes.md
└── scripts/audit.sh           # audit en lecture seule (bash 3.2+, celui de macOS)
```

`pc-checkup` a été testé sous Windows 11 (Ryzen 5 5600X, RTX 2060, carte MSI B550). Les retours d'autres configurations sont les bienvenus via les *Issues* : Intel, carte graphique AMD, PC portable, Wi-Fi, et **tout retour sur Mac**.
