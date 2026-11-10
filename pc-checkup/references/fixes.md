# Correctifs pc-checkup

Deux colonnes : **Ce que Claude applique** (côté utilisateur, sans admin, après accord) et **Ce que l'utilisateur fait** (procédures à guider). Chaque fiche porte son piège connu.

---

## Ce que Claude applique

### Mises à jour logicielles (winget)
```powershell
winget upgrade --all --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
```
- Certains installeurs déclenchent une fenêtre UAC : préviens l'utilisateur de la valider.
- **Échec « fichiers utilisés par une autre application » (code 6)** : trouve qui verrouille au lieu de réessayer à l'aveugle :
  ```powershell
  Get-Process | % { $p=$_; try { $p.Modules | ? FileName -like '*<dossier de l app>*' | % { "$($p.ProcessName) ($($p.Id)) -> $($_.FileName)" } } catch {} } | sort -Unique
  ```
  Cas typique : **OBS** — sa caméra virtuelle (`obs-virtualcam-module64.dll`) est chargée par tout programme qui a listé les webcams (navigateurs, Discord, Teams, l'appli Claude elle-même). Solution : l'utilisateur ferme ces programmes puis lance `winget upgrade --id OBSProject.OBSStudio` depuis un terminal Windows.
- Après coup, supprime les installateurs résiduels : `Remove-Item "$env:TEMP\WinGet\*" -Recurse -Force`.

### Fichiers temporaires
```powershell
Get-ChildItem $env:TEMP -Force | ? { $_.LastWriteTime -lt (Get-Date).AddDays(-1) } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
```
- Mesure avant/après et rapporte le gain réel. Les fichiers verrouillés restent : normal.
- Logs de jeux (ex. `%LOCALAPPDATA%\FortniteGame\Saved\Logs`) : supprime les fichiers via `Get-ChildItem <chemin> -File | Remove-Item` avec le chemin développé (certains garde-fous bloquent `Remove-Item` sur une variable d'environnement brute).
- **Ne touche pas** aux caches de shaders (`NVIDIA\DXCache`, `AMD\DxCache`, `D3DSCache`) ni à la corbeille sans accord explicite.

### Mode Jeu activé, capture en arrière-plan coupée
```powershell
New-Item 'HKCU:\Software\Microsoft\GameBar' -Force | Out-Null
Set-ItemProperty 'HKCU:\Software\Microsoft\GameBar' AutoGameModeEnabled 1 -Type DWord
Set-ItemProperty 'HKCU:\Software\Microsoft\GameBar' AllowAutoGameMode 1 -Type DWord
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' AppCaptureEnabled 0 -Type DWord
Set-ItemProperty 'HKCU:\System\GameConfigStore' GameDVR_Enabled 0 -Type DWord
```
Couper la capture en arrière-plan n'empêche pas d'enregistrer avec OBS, ShadowPlay ou Win+Alt+R.

### Accélération souris désactivée (effet immédiat)
```powershell
Set-ItemProperty 'HKCU:\Control Panel\Mouse' MouseSpeed '0'
Set-ItemProperty 'HKCU:\Control Panel\Mouse' MouseThreshold1 '0'
Set-ItemProperty 'HKCU:\Control Panel\Mouse' MouseThreshold2 '0'
Add-Type 'using System;using System.Runtime.InteropServices;public class SPI{[DllImport("user32.dll")]public static extern bool SystemParametersInfo(uint a,uint b,int[] c,uint d);}'
[SPI]::SystemParametersInfo(0x0004,0,[int[]](0,0,0),3)
```
Préviens : la souris paraîtra différente quelques jours ; c'est voulu (mouvement 1:1, utile en jeu).

### Raccourci de démarrage mort
Supprime uniquement le `.lnk` signalé `cible absente` par l'audit, après avoir montré son chemin à l'utilisateur.

### Pubs, suggestions et applis sponsorisées (section 13)
Réglages côté utilisateur, réversibles (remettre 1). N'applique que les lignes acceptées :
```powershell
$cdm='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
'SilentInstalledAppsEnabled','SystemPaneSuggestionsEnabled','SubscribedContent-338389Enabled','SubscribedContent-338393Enabled','SubscribedContent-310093Enabled' |
  % { Set-ItemProperty $cdm $_ 0 -Type DWord }
$adv='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Set-ItemProperty $adv Start_IrisRecommendations 0 -Type DWord
Set-ItemProperty $adv ShowSyncProviderNotifications 0 -Type DWord
New-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' -Force | Out-Null
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' ScoobeSystemSettingEnabled 0 -Type DWord
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' Enabled 0 -Type DWord
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' TailoredExperiencesWithDiagnosticDataEnabled 0 -Type DWord
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' BingSearchEnabled 0 -Type DWord   # recherche Démarrer sans Bing
```
Bing : la clé `HKCU\Software\Policies\...` est protégée (Accès refusé sans admin) ; `BingSearchEnabled` est le réglage côté utilisateur, mais les versions récentes de Windows 11 peuvent l'ignorer. Si des résultats web apparaissent encore après redémarrage de l'Explorateur, c'est une étape guidée : Terminal (admin) →
`reg add HKCU\Software\Policies\Microsoft\Windows\Explorer /v DisableSearchBoxSuggestions /t REG_DWORD /d 1 /f`
Le menu Démarrer et la recherche prennent effet après redémarrage de l'Explorateur : propose `Stop-Process -Name explorer` (la barre des tâches clignote 2 secondes) ou une déconnexion.

### Applis préinstallées inutiles (Store)
Uniquement la liste **exacte** que l'utilisateur a validée, nom par nom. Désinstallation pour l'utilisateur courant, réinstallable depuis le Microsoft Store :
```powershell
'Microsoft.GetHelp','Clipchamp.Clipchamp' | % { Get-AppxPackage -Name $_ | Remove-AppxPackage }
```
Ne propose jamais : Store, Photos, Calculatrice, Bloc-notes, Terminal, extensions vidéo/image (HEVC, AV1, WebP…), Xbox/Gaming Services si l'utilisateur joue, SecHealthUI.

### Corbeille (> 1 Go)
Suppression **définitive** : annonce le nombre d'éléments et la taille, demande confirmation explicite, puis :
```powershell
Clear-RecycleBin -Force
```

---

## Ce que l'utilisateur fait — ajouts

### Gros fichiers en double (section 8)
Montre les chemins par paire et laisse l'utilisateur choisir quelle copie garder. Il supprime lui-même (ou Claude envoie la copie choisie à la corbeille sur demande explicite, chemin par chemin).

### Nettoyage système en profondeur (admin)
1. Démarrer → **Nettoyage de disque** → C: → **Nettoyer les fichiers système** → cocher *Nettoyage de Windows Update*, *Fichiers d'optimisation de la distribution*, *Anciennes installations de Windows* (si présent) → OK. Gain fréquent : 2 à 20 Go.
2. Optionnel, Terminal (admin) : `DISM /Online /Cleanup-Image /StartComponentCleanup` (5-15 min, réduit le dossier WinSxS).
3. Santé des fichiers système si plantages inexpliqués : `sfc /scannow` puis `DISM /Online /Cleanup-Image /RestoreHealth`.

### Anciens pilotes (DriverStore)
Gain faible (quelques centaines de Mo). Seulement si l'utilisateur veut aller au bout : outil open source **DriverStore Explorer (RAPR)** en admin → *Select Old Driver(s)* → *Delete Driver(s)*.

### Jeux sur disque dur (section 14)
Steam : Paramètres → **Stockage** → sélectionner le jeu → **Déplacer** vers une bibliothèque sur le SSD (en créer une si besoin). Epic : pas de déplacement intégré ; désinstaller puis réinstaller sur le SSD, ou déplacer le dossier puis « Vérifier » depuis le launcher. Prioriser les jeux joués souvent ; les vieux jeux peuvent rester sur le HDD.

### Un seul overlay (section 14)
Garder celui qu'on utilise vraiment. Désactiver les autres : NVIDIA App → Paramètres → Superposition ; Discord → Paramètres → Superposition du jeu ; Steam → Paramètres → En jeu ; Xbox Game Bar → Paramètres → Jeux → Xbox Game Bar.

### GPU en x8/x4 au lieu de x16 (section 3)
PC éteint et débranché : vérifier que la carte est dans le **premier slot PCIe x16** (le plus proche du processeur), bien enfoncée avec le clip verrouillé. Consulter le manuel : certains slots M.2 partagent des lignes avec le slot graphique.

### RAM en single channel (section 2)
Manuel de la carte mère → section mémoire : avec 2 barrettes, les slots conseillés sont presque toujours **A2 et B2** (2e et 4e en partant du processeur). PC débranché, déplacer les barrettes.

### Resizable BAR (bonus jeu)
Uniquement GPU récents (NVIDIA RTX 30/40/50, AMD RX 6000+, Intel Arc) et processeurs compatibles (Ryzen 3000+, Intel 10e gén.+). BIOS → activer **Above 4G Decoding** puis **Re-Size BAR Support** ; nécessite le démarrage UEFI (CSM désactivé). Vérifier ensuite : Panneau NVIDIA → Informations système → Resizable BAR : Oui.

### Réseau lent ou instable (section 12)
- Wi-Fi : privilégier le câble ; sinon bande 5 GHz/6 GHz, rapprocher la box.
- Ping > 60 ms ou pertes en filaire : redémarrer la box, changer le câble, tester un autre port.
- DNS lents (ceux de la box) : Paramètres → Réseau → la connexion → Attribution du serveur DNS → Manuel → 1.1.1.1 / 1.0.0.1 (Cloudflare) ou 8.8.8.8 / 8.8.4.4 (Google). Gain : navigation un peu plus réactive, aucun effet sur le ping en jeu.

### Navigateur
Dans le navigateur : désactiver les extensions inutilisées ; Edge → Paramètres → Système et performances → désactiver *Accélération du démarrage* et *Continuer d'exécuter les extensions en arrière-plan* si le PC doit être léger.

### Windows 10 en fin de support
Paramètres → Windows Update : si la mise à niveau vers Windows 11 est proposée, la faire (gratuite). Sinon vérifier la compatibilité (TPM 2.0, Secure Boot, processeur) avec l'appli « Contrôle d'intégrité du PC ».

### Entretien régulier
Une fois par mois : relancer le checkup (mises à jour, Temp, démarrage). Tous les 6 mois : dépoussiérer les filtres et ventilateurs, vérifier les pilotes GPU/chipset et le BIOS.

---

## Ce que l'utilisateur fait (procédures à guider)

Adapte chaque procédure au matériel détecté (section 1 de l'audit). Propose toujours de vérifier après.

### Activer XMP / EXPO (RAM sous sa fréquence nominale)
Gain typique : 5 à 15 % sur Ryzen, moins sur Intel. Entrer dans le BIOS : **Suppr** (ou F2) au démarrage.

| Marque | Nom de l'option | Emplacement |
|---|---|---|
| MSI | **A-XMP** (AMD) / XMP (Intel) | Bouton en haut à gauche du mode EZ, ou F7 → OC → Extreme Memory Profile |
| ASUS | **D.O.C.P** (AMD DDR4) / XMP / EXPO | Mode EZ → profil, ou Ai Tweaker → Ai Overclock Tuner |
| Gigabyte | **XMP / EXPO** | Tweaker → Extreme Memory Profile |
| ASRock | **XMP / EXPO** | OC Tweaker → DRAM Configuration → Load XMP Setting |

Puis **Profile 1** → **F10** pour enregistrer.
- Premier démarrage plus long (entraînement mémoire) : ne rien toucher.
- Vérifier ensuite : Gestionnaire des tâches → Performances → Mémoire → Vitesse (ou relancer l'audit, section 2).
- **Barrettes mélangées** (références différentes) : risque d'instabilité. Repli : désactiver XMP et fixer la fréquence à la main un cran en dessous (ex. 3000 au lieu de 3200).
- **Ne démarre plus** : laisser 3-4 tentatives (la plupart des cartes reviennent seules aux réglages sûrs), sinon **Clear CMOS** (cavalier CLR_CMOS/JBAT1 10 s PC débranché, ou retirer la pile 1 min). Aucun risque pour les données.
- Tester la stabilité : Démarrer → `mdsched` → redémarrer et analyser (~20 min). Surveiller ensuite les WHEA / écrans bleus (section 11).

### Mettre à jour le BIOS
Utile si le BIOS a plus de 2 ans (stabilité RAM, AGESA/microcode, sécurité). Pas urgent si tout est stable : XMP fonctionne aussi sur un ancien BIOS.
1. **Avant** : créer un point de restauration ; si BitLocker est actif, noter la clé (account.microsoft.com/devices/recoverykey).
2. Page support **du modèle exact** (vérifier le code carte, ex. MS-7C91 ≠ MS-7C84). Prendre la dernière version ; lire les anciennes versions pour une mention « update to X first ».
3. **Vérifier l'empreinte** si le fabricant la publie — Claude peut le faire :
   ```powershell
   (Get-FileHash '<zip>' -Algorithm SHA256).Hash.ToLower() -eq '<hash publié>'
   ```
4. Extraire avec l'outil Windows intégré, copier **seul** le fichier BIOS à la racine d'une clé USB **FAT32**.
5. Outil de flash du BIOS : MSI **M-FLASH**, ASUS **EZ Flash**, Gigabyte **Q-Flash**, ASRock **Instant Flash**. Ne jamais couper le courant.
6. Après : réactiver XMP, vérifier l'ordre de démarrage, F10. Le fTPM peut être réinitialisé (PIN Windows Hello à refaire, clé BitLocker possible) : choisir de garder la clé si le BIOS le propose.
- Sans clé USB : il n'y a pas d'alternative officielle fiable (flash depuis Windows déconseillé). Une carte SD en lecteur USB ou un disque externe FAT32 fonctionnent. Sinon, reporter la mise à jour.
- Secours si la carte ne démarre plus : bouton **Flash BIOS / BIOS FlashBack** à l'arrière (fichier renommé selon le manuel, ex. `MSI.ROM`, port USB dédié).

### Fréquence d'écran
Paramètres → Système → Affichage → choisir l'écran → **Affichage avancé** → fréquence maximale. Si la valeur max n'apparaît pas : câble DisplayPort (ou HDMI 2.0+) et port de la carte graphique, pas de la carte mère.

### Plan d'alimentation
Commande sans admin, réversible :
```powershell
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c   # Haute performance
powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e   # retour Utilisation normale
```
Sur PC fixe : processeur à pleine fréquence, +10-20 W au repos. Sur portable : rester en Utilisation normale sur batterie. C'est un réglage système : l'utilisateur lance la commande lui-même.

### Points de restauration
Démarrer → « Créer un point de restauration » → disque système → **Configurer** → Activer la protection, ~5 % → OK → **Créer**. Vérification sans admin :
```powershell
Get-WinEvent -FilterHashtable @{LogName='Application';StartTime=(Get-Date).AddHours(-2)} | ? { $_.ProviderName -match 'System ?Restore' -and $_.Id -eq 8194 }
```
`Get-ComputerRestorePoint` sans admin renvoie « Accès refusé » : ce n'est **pas** une absence de points.

### Pilotes
- **Réseau Realtek** : site Realtek → Network Interface Controllers → 10/100/1000M ou 2.5G → PCI Express → Software → « Win11 Auto Installation Program » (un seul paquet pour les puces 1G et 2,5G), ou page support de la carte mère → LAN. Intel : Intel Driver & Support Assistant.
- **Chipset** : AMD → amd.com/support (chipset de la carte, ex. B550) ; Intel → Intel DSA.
- **GPU** : NVIDIA App / AMD Adrenalin. Réglages conseillés NVIDIA (Panneau NVIDIA → Gérer les paramètres 3D) : gestion de l'alimentation « Performances maximales préférées » pour les jeux, mode faible latence « Activé », G-SYNC activé si l'écran le gère.
- Carte réseau 2,5G libre alors que le câble est sur le 1G : brancher sur le port 2,5G si la box/le routeur le gère.

### Applications au démarrage et désinstallations
- Démarrage : Gestionnaire des tâches → **Applications de démarrage** → clic droit → Désactiver (Discord, Steam, Epic, Spotify… si non utilisés au quotidien).
- Désinstaller : Paramètres → Applications → Applications installées. Pour deux applis qui font la même chose, l'utilisateur choisit celle qu'il garde.
- Résidus d'un logiciel désinstallé, dans cet ordre :
  1. **Composant caché** signalé par l'audit (entrée de désinstallation sans nom) : lancer son `UninstallString` tel quel avec `Start-Process -Wait` ; l'utilisateur valide la fenêtre UAC. Ex. vécu : Adobe « CCX Process » restait installé sans apparaître dans Paramètres, et recréait la tâche `Launch Adobe CCXProcess`.
  2. **Tâche planifiée** de l'utilisateur (RunLevel Limited) : `Unregister-ScheduledTask -TaskName '<nom>' -Confirm:$false` fonctionne sans admin.
  3. **Dossiers restants** : dans le profil ou sur un disque secondaire, envoie-les à la corbeille (réversible) :
     `Add-Type -AssemblyName Microsoft.VisualBasic; [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory('<dossier>','OnlyErrorDialogs','SendToRecycleBin')`.
     Dans `Program Files` ou `ProgramData`, la corbeille n'est pas disponible (« fonction non prise en charge ») et l'écriture demande souvent l'admin : donne à l'utilisateur **une seule** commande `Remove-Item -Recurse -Force` listant les dossiers mesurés, à lancer dans Terminal (admin), puis revérifie.
  4. Entrée orpheline dans `HKLM\...\StartupApproved\Run` (ex. `AvastUI.exe`) : inoffensive, à inclure dans la même commande admin via `Remove-ItemProperty`.

### Avant de désinstaller un deuxième Python (ou Node, Java…)
Deux versions coexistent souvent **volontairement**. Avant de proposer d'en retirer une : liste ses modules (`Lib\site-packages\*.dist-info`), cherche son chemin dans les scripts et tâches planifiées, et regarde laquelle répond à `python`. Si elle porte des modules utilisés (ex. faster-whisper, rembg, playwright), on la garde et on le dit ; le conflit `python` / `py` se règle alors en informant l'utilisateur, pas en désinstallant.

### Démarrage rapide
À désactiver seulement en cas de bugs au réveil, de dual boot ou de pilotes qui se chargent mal : Panneau de configuration → Options d'alimentation → Choisir l'action des boutons → décocher « Activer le démarrage rapide ».

### Audit complet avec droits admin
Sans admin, l'usure/température SSD, Secure Boot, TPM et la liste exacte des points de restauration restent `ADMIN REQUIS`. Pour les obtenir, l'utilisateur ouvre **Terminal (admin)** et lance la même commande d'audit vers le même dossier de rapports ; Claude lit ensuite le fichier produit.

### Lire les erreurs récurrentes du journal (section 11)
- `TPM-WMI 1040` : renouvellement des certificats Secure Boot ; se règle généralement avec un BIOS récent et Windows Update.
- `DistributedCOM 10010/10005` : bruit courant, sans impact.
- `Kernel-Power 41`, `WHEA`, `BugCheck 1001` : à prendre au sérieux après un XMP/overclock → revenir à une fréquence plus basse.
