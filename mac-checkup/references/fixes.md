# Correctifs mac-checkup

Deux colonnes : **Ce que Claude applique** (côté utilisateur, sans `sudo`, après accord) et **Ce que l'utilisateur fait** (procédures à guider). Chaque fiche porte son piège connu. Les menus cités sont ceux de macOS 13 et suivants (« Réglages Système ») ; sur macOS 12 et avant, c'est « Préférences Système ».

---

## Ce que Claude applique

### Mettre à la Corbeille (réversible) — méthode commune
Déplacer via le Finder garde l'option « Remettre » :
```bash
osascript -e 'tell application "Finder" to delete POSIX file "/chemin/complet"'
```
La première fois, macOS demande d'autoriser le Terminal (ou l'appli de Claude Code) à contrôler le Finder : l'utilisateur clique sur OK. S'il refuse, repli : `mv "/chemin" ~/.Trash/`. Toujours montrer le chemin exact et la taille avant, et vérifier après que l'élément a disparu.

### Homebrew
```bash
brew update && brew upgrade          # mises à jour
brew autoremove                      # dépendances devenues inutiles
brew cleanup --prune=all             # anciennes versions et cache de téléchargement
```
Mesure l'espace avant/après (`du -sh "$(brew --cache)"`). Un `brew upgrade` peut redémarrer un service (`brew services list`) : le signaler.

### Applis du Mac App Store (si `mas` est installé)
```bash
mas upgrade
```
Sans `mas` : guider vers App Store > Mises à jour.

### Caches d'outils de développement (se reconstruisent)
```bash
npm cache clean --force
pip cache purge                       # ou: python3 -m pip cache purge
xcrun simctl delete unavailable       # simulateurs iOS obsolètes
```
- **Xcode DerivedData** (`~/Library/Developer/Xcode/DerivedData`) : à la Corbeille, Xcode le reconstruit au prochain build (premier build plus long).
- **iOS DeviceSupport** : garder les dossiers des versions iOS des appareils encore utilisés, mettre les anciens à la Corbeille.
- **Docker** : `docker system df` pour montrer ce qui prend de la place, puis `docker system prune` **seulement après avoir listé ce qui sera supprimé** (images et conteneurs arrêtés). Jamais `--volumes` sans accord explicite : ce sont des données.

### Tâche de fond orpheline dans `~/Library/LaunchAgents`
Uniquement celles signalées « programme absent » par l'audit :
```bash
launchctl bootout gui/$(id -u) "$HOME/Library/LaunchAgents/<fichier>.plist" 2>/dev/null
```
puis mettre le `.plist` à la Corbeille. Celles de `/Library/LaunchAgents` ou `/Library/LaunchDaemons` demandent un mot de passe admin : procédure guidée (voir plus bas).

### Doublon d'appli dans `~/Applications`
Quand la même appli existe dans `/Applications` et `~/Applications` : vérifier laquelle tourne (`ps -axo comm | grep -F "Nom.app"`) et laquelle est la plus récente, garder celle-là, mettre l'autre à la Corbeille.

### Gros fichiers ou doublons choisis par l'utilisateur
Montrer les chemins, l'utilisateur désigne la copie à retirer, Claude la met à la Corbeille. Jamais de choix automatique.

---

## Ce que l'utilisateur fait (procédures à guider)

### Mises à jour Apple
- Réglages Système > Général > **Mise à jour de logiciels** → installer. Le Mac redémarre : enregistrer son travail avant.
- Mise à jour majeure (nouvelle version de macOS) : vérifier la compatibilité du modèle sur le site d'Apple, faire une sauvegarde Time Machine avant.
- Dans le même écran, bouton **(i)** à côté de « Mises à jour automatiques » : activer au minimum « Installer les réponses de sécurité et fichiers système ».

### Éléments ouverts à la connexion et en arrière-plan
Réglages Système > Général > **Ouverture** :
- « Ouvrir lors de la connexion » : retirer (−) ce qui n'a pas besoin de démarrer avec le Mac.
- « Autoriser en arrière-plan » : désactiver les éléments d'applis désinstallées ou inutiles.
Tâche orpheline dans `/Library/LaunchAgents` ou `/Library/LaunchDaemons` : Finder → Aller → **Aller au dossier…** → coller le dossier → glisser le `.plist` signalé dans la Corbeille (mot de passe demandé) → redémarrer.

### Désinstaller une appli proprement
1. Quitter l'appli, puis la glisser de **Applications** vers la Corbeille (ou Launchpad : appui long → ×).
2. Si l'éditeur fournit un désinstalleur (Adobe, Microsoft, antivirus, pilotes), **l'utiliser en priorité** : il retire aussi ses tâches de fond.
3. Restes éventuels (Finder → Aller au dossier) : `~/Library/Application Support/<Appli>`, `~/Library/Caches/<identifiant>`, `~/Library/Preferences/<identifiant>.plist`, `~/Library/Containers/<identifiant>`. Ne retirer que ce qui porte clairement le nom de l'appli désinstallée.

### Adware et faux nettoyeurs (MacKeeper, Advanced Mac Cleaner…)
1. Quitter l'appli (Moniteur d'activité si besoin), la mettre à la Corbeille avec son désinstalleur s'il existe.
2. Réglages Système > Général > Ouverture : retirer ses éléments.
3. Réglages Système > Confidentialité et sécurité > **Profils** (s'il apparaît) : supprimer tout profil inconnu.
4. Navigateurs : retirer les extensions inconnues, remettre la page d'accueil et le moteur de recherche.
5. Optionnel : analyse gratuite avec Malwarebytes for Mac, puis désinstallation.

### Applis Intel (Rosetta) sur puce Apple
Télécharger la version « Apple Silicon » ou « Universal » sur le site de l'éditeur (ou mettre à jour l'appli). Si l'éditeur n'en propose pas, chercher une alternative native. Vérifier ensuite : Moniteur d'activité → colonne « Type » = Apple.

### Libérer de l'espace (outils Apple)
- Réglages Système > Général > **Stockage** : suivre les recommandations (Stocker dans iCloud, Optimiser le stockage, Vider la Corbeille automatiquement).
- **Sauvegardes iPhone/iPad** : Finder → l'appareil → Gérer les sauvegardes → supprimer les anciennes (garder la plus récente de chaque appareil).
- **Photos** : Photos > Réglages > iCloud → « Optimiser le stockage du Mac » (si Photos iCloud est utilisé).
- **Docker Desktop** : Settings > Resources → réduire la taille du disque virtuel.
- **Vider la Corbeille** : Finder → Cmd+Maj+Suppr, après avoir vérifié son contenu (définitif).

### Mémoire saturée / swap
Moniteur d'activité → onglet Mémoire → trier par mémoire ; fermer les onglets et applis gourmands, désactiver ceux qui démarrent seuls. Sur Apple Silicon, la RAM ne s'ajoute pas : si le swap reste élevé en usage normal, c'est le signe que le Mac est sous-dimensionné pour cet usage.

### Batterie (portables)
Réglages Système > Batterie > **État de la batterie** : activer la recharge optimisée. Sous 80 % de capacité ou « Service recommandé » : remplacement en Apple Store ou centre agréé.

### Sécurité
- **FileVault** : Réglages Système > Confidentialité et sécurité > FileVault → Activer ; noter la clé de secours ou la lier au compte iCloud. Indispensable sur un portable.
- **Pare-feu** : Réglages Système > Réseau > Pare-feu → Activer.
- **Gatekeeper / SIP désactivés** : souvent volontaire chez les développeurs ; sinon, réactiver SIP demande le mode de récupération (`csrutil enable`) : à guider seulement si l'utilisateur le souhaite.
- Un antivirus tiers n'est pas nécessaire sur macOS pour un usage courant : XProtect et Gatekeeper sont intégrés.

### Sauvegarde Time Machine
Brancher un disque externe (au moins 2× la taille des données) → Réglages Système > Général > **Time Machine** → Ajouter un disque de sauvegarde → chiffrer la sauvegarde.

### Écrans
Réglages Système > **Moniteurs** → sélectionner l'écran → Taux de rafraîchissement → valeur maximale (120/144/165 Hz). Si elle n'apparaît pas : câble USB-C/Thunderbolt ou DisplayPort, HDMI 2.0+ minimum, et adaptateur compatible.

### Fluidité de l'interface (Mac modestes ou anciens)
Réglages Système > Accessibilité > **Affichage** → « Réduire la transparence » et « Réduire les animations ». Écrire ces réglages par la ligne de commande échoue sur les macOS récents : passer par les Réglages.

### Spotlight qui tourne en boucle
Réglages Système > Siri et Spotlight > Confidentialité de Spotlight → exclure les dossiers lourds (machines virtuelles, `node_modules`, gros projets, disques externes de sauvegarde).

### Réseau
- Wi-Fi faible (signal < −70 dBm) : se rapprocher de la box, bande 5 GHz, ou câble Ethernet via un adaptateur.
- Ping élevé / pertes : redémarrer la box, tester en filaire.
- DNS : Réglages Système > Réseau → la connexion → Détails → DNS → ajouter 1.1.1.1 et 1.0.0.1.

### Plantages et kernel panics
1. Mettre macOS et les applis concernées à jour.
2. Kernel panics : retirer les extensions système et pilotes tiers inutiles (Réglages Système > Général > Ouverture > Extensions), débrancher les accessoires USB, puis tester.
3. Utilitaire de disque → **S.O.S.** sur « Macintosh HD ».
4. Mode sans échec pour isoler : Apple Silicon = maintenir le bouton d'allumage → choisir le disque en maintenant Maj ; Intel = maintenir Maj au démarrage.
5. Test matériel : **Diagnostics Apple** (Apple Silicon : maintenir le bouton d'allumage → Cmd+D ; Intel : maintenir D au démarrage).
6. Réinitialiser NVRAM/SMC : **Intel uniquement** (sur Apple Silicon, un redémarrage suffit).

### Audit plus complet (optionnel)
Certains points (date de la dernière sauvegarde Time Machine, Corbeille, conteneurs) demandent l'**Accès complet au disque** pour l'application qui lance l'audit : Réglages Système > Confidentialité et sécurité > Accès complet au disque → ajouter Terminal (ou l'appli Claude). À retirer après l'audit si l'utilisateur préfère.

### Entretien régulier
Une fois par mois : relancer le checkup (mises à jour, Homebrew, espace disque, éléments de connexion). Tous les 6 mois : vérifier la batterie, les sauvegardes Time Machine et l'espace libre (> 15 %).
