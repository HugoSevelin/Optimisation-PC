---
name: mac-checkup
description: Audit complet et optimisation d'un Mac (macOS) — stockage, mémoire, batterie, mises à jour Apple/Homebrew, applis en double, inutilisées, Intel sous Rosetta ou indésirables, tâches de fond orphelines, fichiers inutiles, réglages, sécurité, sauvegardes, stabilité, réseau. Utiliser quand l'utilisateur veut checker, optimiser, nettoyer ou accélérer son Mac, ou revérifier après des changements.
---

# mac-checkup

Un _checkup_ en cinq temps : **audit → diagnostic → rapport → correctifs → contre-visite**. Rien n'est modifié avant le rapport et l'accord explicite de l'utilisateur. Réponds dans la langue de l'utilisateur, en termes simples : il n'est pas forcément technicien. Sur un PC Windows, c'est le skill `pc-checkup` qui s'applique.

## Garde-fous

- **Lecture seule jusqu'à l'accord.** Le script d'audit ne modifie rien ; chaque correctif attend un « oui » qui le couvre nommément.
- **Jamais de `sudo`.** Tu n'exécutes aucune commande avec `sudo` et ne demandes jamais le mot de passe de l'utilisateur. Ce qui exige des droits administrateur, tu le **guides** et l'utilisateur le fait lui-même.
- **Deux colonnes de correctifs.** Tu appliques toi-même uniquement les correctifs **côté utilisateur** listés dans [`references/fixes.md`](references/fixes.md) (section « Ce que Claude applique »). Mises à jour de macOS, FileVault, pare-feu, Gatekeeper, SIP, Time Machine, éléments de connexion, réglages Système et désinstallation d'applis : tu **guides pas à pas**, même si l'utilisateur te demande de « prendre le contrôle ».
- **Suppression = périmètre fermé, et par la Corbeille.** Tu ne supprimes que ce que fixes.md liste comme nettoyable, en déplaçant vers `~/.Trash` (réversible) plutôt qu'avec `rm`, sauf pour les caches d'outils qui ont leur propre commande de nettoyage (`brew cleanup`, `npm cache clean`…). Vider la Corbeille se fait après confirmation de son contenu. Ne touche jamais à `~/Library/Caches` en bloc, à `~/Library/Containers`, aux sauvegardes iPhone ni à la photothèque.
- **Un résultat sans droits n'est pas un zéro.** Une commande qui échoue faute de permission (Accès complet au disque, admin, autorisation de dossier refusée) s'écrit `ACCÈS REQUIS`, jamais « 0 » ni « absent ».

## 1. Audit

Les rapports se gardent dans `~/mac-checkup/` (hors des dossiers protégés de macOS) pour comparer d'une session à l'autre :

```bash
mkdir -p ~/mac-checkup
bash "<dossier du skill>/scripts/audit.sh" > ~/mac-checkup/rapport-$(date +%Y%m%d-%H%M).txt 2>&1
```

Durée : 1 à 4 minutes (`--quick` saute tailles, doublons et mises à jour Apple). Lance-le en arrière-plan si l'outil le permet et préviens l'utilisateur en une ligne : **macOS peut afficher des demandes d'accès** à Bureau, Documents ou Téléchargements ; accepter rend l'audit complet, refuser n'empêche pas le reste.

**Terminé quand** le fichier se termine par `# Fin du rapport` et que les 10 sections sont présentes (une section vide ou en erreur se complète à la main avec des commandes ciblées).

## 2. Diagnostic

Commence par lire `~/mac-checkup/decisions.txt` s'il existe : un point déjà refusé se mentionne en une ligne (« déjà refusé le … »), sans le reproposer. Pour chaque ligne `[!]`, décide : vrai problème, faux positif, ou info ; quand le doute est permis, vérifie par une commande ciblée plutôt que de supposer. Puis complète ce que le script ne peut pas voir :

- **Doublons par fonction** : relis la liste d'applis pour repérer deux logiciels qui font la même chose (deux nettoyeurs, deux clients cloud, deux navigateurs inutilisés, un antivirus tiers en plus de XProtect).
- **Applis non ouvertes depuis 6 mois** : ce sont des questions, pas des verdicts (une appli rare mais utile se garde).
- **Conteneurs orphelins** : la liste est heuristique ; un nom qui correspond à une appli encore utilisée (extension, appli du Mac App Store installée ailleurs) est un faux positif.
- **Éléments de connexion** : demande à l'utilisateur d'ouvrir Réglages Système > Général > Ouverture et de te lire la liste, ou guide-le pour désactiver ce qui ne sert pas.
- **Versions de référence** : si la recherche web est disponible, vérifie la dernière version de macOS compatible avec le modèle exact et, pour les applis Intel, l'existence d'une version Apple Silicon.
- **Profil d'usage** : portable sur batterie (autonomie, santé de batterie), Mac de bureau, développeur (Xcode, Docker, Homebrew), créatif (photothèque, gros projets).

**Terminé quand** chaque ligne `[!]` a un verdict et chaque vrai problème a un correctif choisi dans `references/fixes.md`.

## 3. Rapport

Structure, du plus gros gain au plus petit :

1. **🔴 Gros gains** : disque presque plein, mémoire saturée / swap, adware ou faux nettoyeur, applis Intel sous Rosetta, macOS très ancien, batterie usée.
2. **🟠 Mises à jour** (macOS, Homebrew, App Store).
3. **🟡 Applis** : doublons, inutilisées, redondantes, restes et tâches de fond orphelines.
4. **🟡 Espace récupérable** (chiffré en Go, en signalant ce qui se reconstruit et ce qu'il faut garder).
5. **🟡 Réglages** : tableau « Actuel / Recommandé ».
6. **🟡 Réseau** si Wi-Fi faible, latence ou pertes.
7. **🟠 Sécurité et sauvegarde** si FileVault, pare-feu ou Time Machine manquent.
8. **✅ Ce qui est sain** en une ligne.

Termine par deux listes : **« Je peux appliquer maintenant »** et **« À faire de ton côté »** (dans l'ordre conseillé), puis demande l'accord.

**Terminé quand** chaque vrai problème apparaît une fois, dans une des deux listes.

## 4. Correctifs

Applique uniquement ce que l'utilisateur a accepté, avec les commandes de [`references/fixes.md`](references/fixes.md). Après chaque correctif, revérifie (taille libérée, version, présence du fichier) et rapporte le résultat réel. Un échec se diagnostique avant de réessayer. Pour les étapes guidées, donne une procédure numérotée adaptée au modèle (Apple Silicon ou Intel, portable ou bureau) et propose de vérifier après.

Consigne chaque décision dans `~/mac-checkup/decisions.txt`, une ligne par point : `AAAA-MM-JJ | accepté/refusé/fait par l'utilisateur | point`.

**Terminé quand** chaque correctif accepté est vérifié ou expliqué en échec avec sa cause, et chaque décision est consignée.

## 5. Contre-visite

Quand l'utilisateur revient (même dans une nouvelle conversation), relance l'audit et compare au rapport le plus récent de `~/mac-checkup/` : tableau **Avant / Maintenant** sur les points du rapport initial, puis ce qui reste à faire. Termine en proposant l'entretien régulier décrit dans fixes.md.
