# Optimisation PC — skill `pc-checkup` pour Claude Code

Un **check complet et une optimisation de PC Windows 10/11**, menés par [Claude Code](https://claude.com/claude-code) : pilotes, mises à jour, applis en double, fichiers inutiles, RAM, écrans, réglages graphiques et de jeu, pubs Windows, réseau, stabilité…

Claude audite le PC **en lecture seule**, présente un rapport classé du plus gros gain au plus petit, applique **avec ton accord** les correctifs sans risque, te guide pas à pas pour le reste (BIOS, XMP, pilotes…), puis refait le check pour te montrer l'avant/après.

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
   ```powershell
   git clone https://github.com/HugoSevelin/Optimisation-PC.git
   ```
3. Copie le dossier **`pc-checkup`** dans ton dossier de skills Claude :
   ```powershell
   Copy-Item -Recurse .\Optimisation-PC\pc-checkup "$env:USERPROFILE\.claude\skills\"
   ```
   Tu dois obtenir `C:\Users\<toi>\.claude\skills\pc-checkup\SKILL.md`.
4. Redémarre Claude Code.

## Utilisation

Dans Claude Code, écris simplement :

> Fais un check complet de mon PC, je veux qu'il soit le plus optimisé possible.

Tu peux aussi taper `/pc-checkup`. Après tes changements (redémarrage, BIOS, XMP…), écris « refais le check » : Claude compare avec le rapport précédent.

Les rapports et tes décisions (ce que tu as accepté ou refusé) sont gardés dans `Documents\pc-checkup\`. Claude ne te repropose pas ce que tu as déjà refusé.

## Ce que le check couvre (14 sections)

1. **Matériel et système** : âge du BIOS, uptime, activation, fin de support de Windows 10
2. **Mémoire** : vitesse réelle comparée à la vitesse prévue par chaque barrette (XMP/EXPO), dual channel, barrettes mélangées
3. **GPU et écrans** : pilote, température, lignes PCIe, fréquence de chaque écran comparée à son maximum
4. **Pilotes** : périphériques en erreur, pilotes anciens, port réseau 2,5G inutilisé
5. **Mises à jour** : Windows Update et logiciels (winget)
6. **Applications** : doublons, même appli installée deux fois, restes de logiciels désinstallés, composants cachés
7. **Démarrage** : programmes lancés plusieurs fois, raccourcis morts, tâches planifiées orphelines, processus gourmands
8. **Disques et fichiers** : santé, TRIM, corbeille, caches, gros fichiers en double
9. **Réglages** : plan d'alimentation, mode Jeu, capture en arrière-plan, accélération souris…
10. **Sécurité** : antivirus, points de restauration
11. **Stabilité** : écrans bleus, erreurs matérielles, plantages, résultat du test mémoire
12. **Réseau** : câble ou Wi-Fi, DNS, latence, pertes
13. **Windows désencombré** : pubs, suggestions, Bing dans le menu Démarrer, applis préinstallées
14. **Jeux** : jeux sur disque dur lent, overlays en double

## Sécurité

- L'audit (`pc-checkup/scripts/audit.ps1`) est **en lecture seule** et fonctionne **sans droits admin**. Tu peux le lire avant de l'utiliser, ou le lancer seul :
  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\pc-checkup\scripts\audit.ps1"
  ```
- Claude ne modifie **rien sans ton accord explicite**, point par point.
- Il n'applique lui-même que des réglages côté utilisateur, réversibles. **BIOS, XMP, réglages système et de sécurité, pilotes** : il te guide et c'est toi qui le fais.
- Les suppressions passent **par la corbeille** quand c'est possible, après avoir vérifié que rien n'utilise les fichiers.
- Le rapport contient les noms de tes logiciels et tes chemins de dossiers : relis-le avant de le partager.

## Structure

```
pc-checkup/
├── SKILL.md              # la méthode suivie par Claude (audit → diagnostic → rapport → correctifs → contre-visite)
├── README.md             # notice du skill
├── references/fixes.md   # tous les correctifs : ce que Claude applique, ce que tu fais (procédures par marque)
└── scripts/audit.ps1     # l'audit en lecture seule (PowerShell 5.1+, Windows 10/11)
```

Testé sur Windows 11 (Ryzen 5 5600X, RTX 2060, carte MSI B550). Les retours d'autres configurations (Intel, carte graphique AMD, PC portable, Wi-Fi) sont les bienvenus via les *Issues*.
