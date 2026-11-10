# pc-checkup — skill Claude Code

Check complet et optimisation d'un PC Windows 10/11, guidé par Claude.

## Ce qu'il vérifie
- **Matériel** : processeur, carte mère, âge du BIOS, uptime, activation Windows, fin de support de Windows 10
- **RAM** : vitesse réelle comparée à la vitesse prévue par la référence de chaque barrette (XMP/EXPO activé ou non), dual channel, barrettes mélangées
- **GPU et écrans** : version du pilote, température, lignes PCIe (carte en x8 au lieu de x16), fréquence de chaque écran comparée à son maximum (ex. un écran 180 Hz réglé à 60 Hz)
- **Pilotes** : périphériques en erreur, pilotes de plus de 2 ans, anciennes versions conservées, port réseau 2,5G inutilisé
- **Mises à jour** : Windows Update et tous les logiciels (winget)
- **Applications** : versions en double, même appli installée deux fois, restes de logiciels désinstallés (Avast, Adobe, McAfee…)
- **Démarrage** : programmes lancés au démarrage, raccourcis morts, tâches planifiées orphelines, services tiers, processus gourmands
- **Disques** : santé, espace libre, TRIM et optimisation planifiée, corbeille, caches et fichiers inutiles en Go, gros fichiers en double dans tes dossiers perso
- **Réglages** : plan d'alimentation, mode Jeu, capture en arrière-plan, accélération souris, HAGS, démarrage rapide, assistant de stockage
- **Windows désencombré** : pubs et suggestions, applis sponsorisées installées automatiquement, résultats Bing dans le menu Démarrer, applis préinstallées inutiles
- **Réseau** : connexion active, DNS, Wi-Fi ou câble, latence et pertes de paquets
- **Jeux** : jeux Steam/Epic installés sur un disque dur lent, plusieurs overlays actifs en même temps
- **Sécurité** : antivirus et date de la dernière analyse, VBS, points de restauration
- **Stabilité** : écrans bleus, arrêts brutaux, erreurs matérielles WHEA, plantages d'applications sur 30 jours

## Ce qu'il fait (et ne fait pas)
1. Il lance un audit **en lecture seule** (le script `scripts/audit.ps1`, environ 1 à 3 minutes, sans droits admin). Le rapport est gardé dans `Documents\pc-checkup\` pour comparer plus tard.
2. Il présente un rapport classé du plus gros gain au plus petit.
3. Il applique **seulement après ton accord** les correctifs sans risque : mises à jour des logiciels, nettoyage des fichiers temporaires, mode Jeu, capture en arrière-plan, accélération souris, pubs et suggestions Windows, applis préinstallées que tu as validées une par une, corbeille.
4. Pour tout ce qui est sensible (BIOS, XMP, plan d'alimentation, pilotes, désinstallations), il te **guide pas à pas** et c'est toi qui le fais.
5. Il refait le check après tes changements et te montre un tableau avant/après.

## Installation
1. Installe [Claude Code](https://claude.com/claude-code) (terminal, appli de bureau ou extension VS Code).
2. Dézippe le dossier `pc-checkup` dans :
   ```
   %USERPROFILE%\.claude\skills\
   ```
   Tu dois obtenir `C:\Users\<toi>\.claude\skills\pc-checkup\SKILL.md`.
3. Redémarre Claude Code.

## Utilisation
Écris simplement « fais un check complet de mon PC » ou « optimise mon PC », ou tape `/pc-checkup`.

Tu peux aussi lancer l'audit seul, sans Claude :
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\skills\pc-checkup\scripts\audit.ps1"
```
Ajoute `-Quick` pour sauter la mesure de la taille des dossiers. Les lignes `[!]` sont les points à regarder.

## Bon à savoir
- Lancé sans droits admin, certains points s'affichent « ADMIN REQUIS » (usure du SSD, Secure Boot, liste exacte des points de restauration). C'est normal.
- Le rapport contient les noms de tes logiciels et tes chemins de dossiers. Relis-le avant de le partager.
