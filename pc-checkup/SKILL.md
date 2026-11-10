---
name: pc-checkup
description: Audit complet et optimisation d'un PC Windows — matériel, RAM/XMP, BIOS, pilotes, mises à jour, applis en double ou résidus, démarrage, fichiers inutiles, réglages alimentation/graphiques/jeu, pubs Windows, réseau, stabilité. Utiliser quand l'utilisateur veut checker, optimiser, nettoyer ou accélérer son PC, ou revérifier après des changements.
---

# pc-checkup

Un _checkup_ en cinq temps : **audit → diagnostic → rapport → correctifs → contre-visite**. Rien n'est modifié avant le rapport et l'accord explicite de l'utilisateur. Réponds dans la langue de l'utilisateur, en termes simples : il n'est pas forcément technicien.

## Garde-fous

- **Lecture seule jusqu'à l'accord.** Le script d'audit ne modifie rien ; chaque correctif attend un « oui » qui le couvre nommément.
- **Deux colonnes de correctifs.** Tu appliques toi-même uniquement les correctifs **côté utilisateur** listés dans [`references/fixes.md`](references/fixes.md) (section « Ce que Claude applique »). Tout ce qui touche au BIOS/UEFI, aux réglages système ou de sécurité (plan d'alimentation, protection système, Defender, VBS, Secure Boot, services, registre HKLM, DNS), aux pilotes et aux logiciels de bureau à désinstaller, tu le **guides pas à pas** et l'utilisateur le fait lui-même, même s'il te demande de « prendre le contrôle ».
- **Suppression = périmètre fermé.** Tu supprimes seulement : fichiers de `%TEMP%` de plus d'un jour, installateurs résiduels winget, logs de jeux, raccourcis de démarrage dont la cible n'existe plus, applis Store validées nom par nom, la corbeille après confirmation de son contenu, et — sur demande explicite de l'utilisateur — une copie d'appli en double ou un dossier résiduel, **envoyés à la corbeille** après avoir prouvé qu'aucun processus ne les utilise (pour une appli en double : la copie qui tourne est celle qu'on garde). Les caches de shaders (NVIDIA/AMD/DirectX) se gardent : les vider provoque des saccades en jeu.
- **Un résultat sans droits n'est pas un zéro.** Une commande qui renvoie « Accès refusé » ou vide faute d'admin s'écrit `ADMIN REQUIS`, jamais « 0 » ni « absent ». Vérifie par une source alternative (journal d'événements) avant de conclure.

## 1. Audit

Les rapports se gardent dans `%USERPROFILE%\Documents\pc-checkup\` pour pouvoir comparer d'une session à l'autre :

```powershell
$d = "$env:USERPROFILE\Documents\pc-checkup"; New-Item $d -ItemType Directory -Force | Out-Null
powershell -NoProfile -ExecutionPolicy Bypass -File "<dossier du skill>\scripts\audit.ps1" *> "$d\rapport-$(Get-Date -Format yyyyMMdd-HHmm).txt"
```

Durée : 1 à 3 minutes (`-Quick` saute les tailles de dossiers et la recherche de doublons). Lance-le en arrière-plan si l'outil le permet et préviens l'utilisateur en une ligne. Pour les points `ADMIN REQUIS`, propose la variante admin décrite dans fixes.md.

**Terminé quand** le fichier se termine par `# Fin du rapport` et qu'aucune section n'est marquée « interrompue » (sinon complète-la à la main avec des commandes ciblées).

## 2. Diagnostic

Le script repère l'objectif ; certaines choses demandent ton jugement. Commence par lire `Documents\pc-checkup\decisions.txt` s'il existe : un point que l'utilisateur a déjà refusé se mentionne en une ligne (« déjà refusé le … »), sans le reproposer. Pour chaque ligne `[!]`, décide : vrai problème, faux positif, ou info ; quand le doute est permis, vérifie par une commande ciblée plutôt que de supposer (ex. quelle copie d'une appli tourne vraiment, quel Python est dans le PATH, ce que contient un vieux dossier). Puis complète ce que le script ne peut pas voir :

- **Doublons par fonction** : relis la liste d'applis et de démarrage pour repérer deux logiciels qui font la même chose sous des noms différents (deux outils de dictée, deux lanceurs, deux antivirus, deux nettoyeurs, deux clients de stockage cloud).
- **Applis préinstallées** : la liste de la section 13 est une liste de candidats ; garde celles que l'utilisateur pourrait utiliser comme questions, pas comme verdicts.
- **Versions de référence** : si la recherche web est disponible, vérifie la dernière version du BIOS pour la carte mère exacte et des pilotes réseau/chipset ; sinon donne la page support du fabricant.
- **Gros consommateurs** : rapproche les processus gourmands de la liste de démarrage.
- **Profil d'usage** : joueur, bureautique, portable sur batterie. Un PC portable ne passe pas en Haute performance ; un PC sans jeux n'a pas besoin des conseils de la section 14.

**Terminé quand** chaque ligne `[!]` a un verdict et chaque vrai problème a un correctif choisi dans `references/fixes.md`.

## 3. Rapport

Structure, du plus gros gain au plus petit :

1. **🔴 Gros gains** (performances réelles : XMP désactivé, single channel, GPU en x8/x4, écran sous sa fréquence, jeux sur HDD, BIOS très ancien, uptime de plusieurs semaines).
2. **🟠 Pilotes et mises à jour.**
3. **🟡 Applis en double, résidus, démarrage, applis préinstallées.**
4. **🟡 Fichiers en trop** (chiffrés en Go, en signalant ce qui est à garder).
5. **🟡 Réglages** : tableau « Actuel / Recommandé » (performance, jeu, pubs et suggestions Windows).
6. **🟡 Réseau** si latence, pertes ou Wi-Fi.
7. **✅ Ce qui est sain** en une ligne (disques, stabilité, sécurité).

Termine par deux listes : **« Je peux appliquer maintenant »** (correctifs côté utilisateur) et **« À faire de ton côté »** (dans l'ordre conseillé), puis demande l'accord.

**Terminé quand** chaque vrai problème apparaît une fois, dans une des deux listes.

## 4. Correctifs

Applique uniquement ce que l'utilisateur a accepté, avec les commandes de [`references/fixes.md`](references/fixes.md). Après chaque correctif, relis la valeur et rapporte-la. Un échec se diagnostique avant de réessayer (ex. installeur winget « fichiers utilisés » → trouve le processus qui verrouille, voir fixes.md). Pour les étapes guidées, donne une procédure numérotée adaptée au matériel détecté (marque de carte mère, GPU) et propose de vérifier après.

Consigne chaque décision dans `Documents\pc-checkup\decisions.txt`, une ligne par point : `AAAA-MM-JJ | accepté/refusé/fait par l'utilisateur | point`.

**Terminé quand** chaque correctif accepté est vérifié ou expliqué en échec avec sa cause, et chaque décision est consignée.

## 5. Contre-visite

Quand l'utilisateur revient (après redémarrage, BIOS, XMP…, même dans une nouvelle conversation), relance l'audit et compare au rapport précédent le plus récent de `Documents\pc-checkup\` : tableau **Avant / Maintenant** sur les points du rapport initial, puis ce qui reste à faire. Après un XMP ou un changement de BIOS, rappelle qu'un PC démarré depuis quelques minutes ne prouve pas sa stabilité : propose `mdsched` ou quelques jours d'usage avec surveillance de la section 11. Termine en proposant l'entretien régulier décrit dans fixes.md.
