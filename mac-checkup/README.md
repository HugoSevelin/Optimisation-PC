# mac-checkup — skill Claude Code

Check complet et optimisation d'un Mac (macOS 12 et suivants, Apple Silicon et Intel), guidé par Claude.

## Ce qu'il vérifie (10 sections)
1. **Matériel et système** : modèle, puce, RAM, version de macOS, uptime, pression mémoire et swap, santé de la batterie
2. **Stockage** : espace libre, santé SMART, instantanés Time Machine, volumes externes
3. **Mises à jour** : macOS et logiciels Apple, mises à jour automatiques, Homebrew, App Store
4. **Applications** : applis Intel sous Rosetta, même appli installée deux fois, applis non ouvertes depuis 6 mois, adware et faux nettoyeurs, antivirus redondants, restes d'applis désinstallées
5. **Démarrage et arrière-plan** : tâches de fond (LaunchAgents/Daemons) dont le programme a disparu, processus les plus gourmands
6. **Espace récupérable** : caches, Corbeille, Téléchargements, Xcode, simulateurs, sauvegardes iPhone, caches Homebrew/npm/pip, gros fichiers en double
7. **Réglages** : mode économie d'énergie, veille, Spotlight, transparence et animations, fréquence des écrans, souris
8. **Sécurité et sauvegarde** : FileVault, pare-feu, Gatekeeper, SIP, Time Machine
9. **Stabilité** : kernel panics, manque de mémoire, plantages d'applis sur 30 jours
10. **Réseau** : Wi-Fi ou câble, qualité du signal, DNS, latence et pertes

## Ce qu'il fait (et ne fait pas)
1. Il lance un audit **en lecture seule** (`scripts/audit.sh`, 1 à 4 minutes, **jamais de sudo**). Le rapport est gardé dans `~/mac-checkup/`.
2. Il présente un rapport classé du plus gros gain au plus petit.
3. Il applique **seulement après ton accord** les correctifs sans risque : mises à jour Homebrew et App Store, nettoyage des caches de développement, tâches de fond orphelines, doublons choisis. Tout ce qu'il supprime passe **par la Corbeille**.
4. Pour le reste (mises à jour de macOS, FileVault, Time Machine, éléments de connexion, désinstallations), il te **guide pas à pas**.
5. Il refait le check après tes changements et montre un tableau avant/après.

## Installation
1. Installe [Claude Code](https://claude.com/claude-code).
2. Copie le dossier `mac-checkup` dans `~/.claude/skills/` :
   ```bash
   mkdir -p ~/.claude/skills && cp -R mac-checkup ~/.claude/skills/
   ```
3. Redémarre Claude Code.

## Utilisation
Écris « fais un check complet de mon Mac » ou tape `/mac-checkup`.

Tu peux aussi lancer l'audit seul, sans Claude :
```bash
bash ~/.claude/skills/mac-checkup/scripts/audit.sh
```
Ajoute `--quick` pour un audit rapide. Les lignes `[!]` sont les points à regarder.

## Bon à savoir
- macOS peut te demander d'autoriser l'accès à Bureau, Documents ou Téléchargements pendant l'audit. Accepter rend le check complet, refuser n'empêche pas le reste.
- Quelques points (date de la dernière sauvegarde Time Machine, contenu de la Corbeille) demandent l'« Accès complet au disque ». Sans lui, ils s'affichent « ACCÈS REQUIS ».
- Le rapport contient les noms de tes applis et de tes dossiers : relis-le avant de le partager.
- **Version jamais lancée sur un vrai Mac à ce jour** : seule la syntaxe a été vérifiée. Merci de signaler tout problème dans les *Issues* du dépôt.
