#!/bin/bash
# mac-checkup - audit macOS en LECTURE SEULE.
# Ne modifie rien, n'utilise jamais sudo. Compatible bash 3.2 (celui fourni avec macOS).
# Usage : bash audit.sh [--quick]
#   --quick : saute les mesures de taille, la recherche de doublons et la vérification des mises à jour.
# Chaque ligne "[!]" est un point à examiner, "[ok]" est conforme, "[i]" est une info.
# macOS peut demander l'accès à Bureau / Documents / Téléchargements : accepter donne un audit complet,
# refuser n'empêche pas le reste du rapport.

if [ "$(uname -s)" != "Darwin" ]; then
  echo "mac-checkup est prévu pour macOS uniquement (sous Windows, utiliser pc-checkup)."
  exit 1
fi

QUICK=0
[ "$1" = "--quick" ] && QUICK=1
export LC_NUMERIC=C
WORK=$(mktemp -d "${TMPDIR:-/tmp}/mac-checkup.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

section() { printf '\n## %s\n' "$1"; }
flag()    { printf '[!] %s\n' "$*"; }
ok()      { printf '[ok] %s\n' "$*"; }
info()    { printf '[i] %s\n' "$*"; }
has()     { command -v "$1" >/dev/null 2>&1; }
# Taille d'un dossier en Go (vide si absent)
size_gb() { [ -e "$1" ] && du -sk "$1" 2>/dev/null | awk '{printf "%.2f", $1/1048576}'; }
# JSON system_profiler mis en cache, puis extraction d'une clé (plutil -extract ... raw : macOS 12+)
spjson()  { local f="$WORK/$1.json"; [ -s "$f" ] || system_profiler -json "$1" > "$f" 2>/dev/null; echo "$f"; }
pl()      { plutil -extract "$2" raw -o - "$1" 2>/dev/null; }
plist_get() { plutil -extract "$2" raw -o - "$1" 2>/dev/null; }
now=$(date +%s)
days_since() { # date au format "YYYY-MM-DD HH:MM:SS +0000" -> jours écoulés
  local t; t=$(date -j -f "%Y-%m-%d %H:%M:%S %z" "$1" +%s 2>/dev/null) || return 1
  echo $(( (now - t) / 86400 ))
}

ARCH=$(uname -m)
OSV=$(sw_vers -productVersion)
MAJOR=${OSV%%.*}
echo "# Rapport mac-checkup - $(date '+%Y-%m-%d %H:%M') - macOS $OSV - $ARCH"

# ---------------------------------------------------------------- 1
section "1. Matériel et système"
HWJ=$(spjson SPHardwareDataType)
MODEL=$(pl "$HWJ" SPHardwareDataType.0.machine_name)
MODELID=$(sysctl -n hw.model 2>/dev/null)
CPU=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
RAMGB=$(( $(sysctl -n hw.memsize) / 1073741824 ))
info "Mac : ${MODEL:-?} ($MODELID) - $CPU - ${RAMGB} Go de RAM"
if [ "$ARCH" = "arm64" ]; then info "Puce Apple Silicon"; else info "Processeur Intel"; fi
info "macOS $OSV (build $(sw_vers -buildVersion))"
if [ "$MAJOR" -lt 15 ] 2>/dev/null; then
  flag "macOS $OSV : version ancienne, Apple ne publie des correctifs de sécurité que pour les versions récentes -> vérifier si une mise à jour majeure est proposée"
fi
BOOT=$(sysctl -n kern.boottime | sed -E 's/^\{ *sec = ([0-9]+),.*/\1/')
UPD=$(( (now - BOOT) / 86400 ))
if [ "$UPD" -gt 30 ]; then flag "Uptime : $UPD jours sans redémarrage -> redémarrer de temps en temps libère la mémoire et applique les mises à jour"
else ok "Uptime : $UPD jour(s)"; fi
MP=$(memory_pressure -Q 2>/dev/null | awk -F': ' '/free percentage/{gsub(/%/,"",$2); print $2}')
SWAP=$(sysctl -n vm.swapusage | awk '{for(i=1;i<=NF;i++) if($i=="used") {v=$(i+2); sub(/M/,"",v); printf "%.1f", v/1024}}')
line="Mémoire : ${MP:-?} % libre, swap utilisé ${SWAP:-?} Go"
if [ -n "$MP" ] && [ "$MP" -lt 15 ]; then flag "$line -> mémoire saturée : fermer des applis / onglets, vérifier les processus gourmands (section 5)"
elif [ -n "$SWAP" ] && awk "BEGIN{exit !($SWAP > 4)}"; then flag "$line -> beaucoup de swap : le Mac manque de RAM pour l'usage actuel"
else ok "$line"; fi
# Batterie (portables)
BAT=$(ioreg -rc AppleSmartBattery 2>/dev/null)
if [ -n "$BAT" ]; then
  CYC=$(echo "$BAT" | awk -F'= ' '/"CycleCount" =/{print $2; exit}')
  DES=$(echo "$BAT" | awk -F'= ' '/"DesignCapacity" =/{print $2; exit}')
  RAW=$(echo "$BAT" | awk -F'= ' '/"AppleRawMaxCapacity" =/{print $2; exit}')
  [ -z "$RAW" ] && RAW=$(echo "$BAT" | awk -F'= ' '/"MaxCapacity" =/{print $2; exit}')
  if [ -n "$DES" ] && [ -n "$RAW" ] && [ "$DES" -gt 0 ] && [ "$RAW" -gt 100 ]; then HEALTH=$(( RAW * 100 / DES )); else HEALTH=$RAW; fi
  line="Batterie : $CYC cycles, capacité max ${HEALTH:-?} %"
  if [ -n "$HEALTH" ] && [ "$HEALTH" -lt 80 ]; then flag "$line -> batterie usée (< 80 %), autonomie réduite : remplacement à envisager"
  else ok "$line"; fi
fi

# ---------------------------------------------------------------- 2
section "2. Stockage"
DATA=/System/Volumes/Data; [ -d "$DATA" ] || DATA=/
read -r TOT AV <<EOF
$(df -k "$DATA" | awk 'NR==2{print $2, $4}')
EOF
PCT=$(( AV * 100 / TOT ))
line="Disque interne : $(( AV / 1048576 )) Go libres sur $(( TOT / 1048576 )) Go ($PCT %)"
if [ "$PCT" -lt 15 ] || [ $(( AV / 1048576 )) -lt 20 ]; then flag "$line -> espace faible : macOS ralentit et ne peut plus installer ses mises à jour"
else ok "$line"; fi
DI="$WORK/diskinfo.plist"; diskutil info -plist / > "$DI" 2>/dev/null
SSD=$(plist_get "$DI" SolidState); SMART=$(plist_get "$DI" SMARTStatus)
if [ -n "$SMART" ] && [ "$SMART" != "Verified" ] && [ "$SMART" != "Not Supported" ]; then flag "Santé du disque (SMART) : $SMART -> sauvegarder immédiatement"
else ok "Disque : SSD=${SSD:-?}, SMART=${SMART:-?}"; fi
SNAP=$(tmutil listlocalsnapshots / 2>/dev/null | grep -c 'com.apple')
info "Instantanés locaux Time Machine : $SNAP (macOS les supprime seul quand l'espace manque)"
for v in /Volumes/*; do
  [ -d "$v" ] || continue
  case "$v" in "/Volumes/Macintosh HD"*|"/Volumes/Recovery"*|"/Volumes/Preboot"*) continue;; esac
  [ "$(cd "$v" 2>/dev/null && pwd -P)" = "/" ] && continue
  info "Volume externe/secondaire : $v ($(df -h "$v" 2>/dev/null | awk 'NR==2{print $4" libres sur "$2}'))"
done

# ---------------------------------------------------------------- 3
section "3. Mises à jour"
if [ "$QUICK" -eq 0 ]; then
  SU=$(softwareupdate --list 2>&1)
  if echo "$SU" | grep -q '\* Label:'; then
    echo "$SU" | awk -F'Label: ' '/\* Label:/{print $2}' | while IFS= read -r l; do flag "Mise à jour Apple disponible : $l"; done
  elif echo "$SU" | grep -qi 'No new software'; then ok "macOS et logiciels Apple : à jour"
  else info "softwareupdate : $(echo "$SU" | tail -1)"; fi
else info "Mode --quick : mises à jour Apple non vérifiées"; fi
SUP=/Library/Preferences/com.apple.SoftwareUpdate
for k in AutomaticCheckEnabled AutomaticDownload CriticalUpdateInstall; do
  v=$(defaults read "$SUP" "$k" 2>/dev/null)
  case "$k" in
    AutomaticCheckEnabled) lbl="Recherche automatique des mises à jour";;
    AutomaticDownload) lbl="Téléchargement automatique";;
    CriticalUpdateInstall) lbl="Installation auto des réponses de sécurité";;
  esac
  if [ "$v" = "0" ]; then flag "$lbl : désactivé"; else ok "$lbl : ${v:-par défaut (activé)}"; fi
done
if has brew; then
  OUT=$(brew outdated --verbose 2>/dev/null)
  if [ -n "$OUT" ]; then echo "$OUT" | while IFS= read -r l; do flag "Homebrew à mettre à jour : $l"; done
  else ok "Homebrew : tout est à jour"; fi
else info "Homebrew non installé"; fi
if has mas; then
  OUT=$(mas outdated 2>/dev/null)
  if [ -n "$OUT" ]; then echo "$OUT" | while IFS= read -r l; do flag "App Store à mettre à jour : $l"; done; else ok "App Store (mas) : à jour"; fi
else info "Applis de l'App Store : vérifier App Store > Mises à jour (outil mas non installé)"; fi

# ---------------------------------------------------------------- 4
section "4. Applications"
ADWARE='MacKeeper|Advanced Mac Cleaner|Mac Auto Fixer|Mac Cleanup Pro|Mac Tonic|Smart Mac Booster|Genieo|Similar Photo Cleaner|Mac Optimizer Pro|Search Baron|ChillTab|MacBooster'
REDUNDANT='Avast|AVG|Norton|McAfee|Kaspersky|Bitdefender|Intego|Sophos|CleanMyMac|CCleaner|OnyX|Clean Master'
: > "$WORK/apps.tsv"
for app in /Applications/*.app /Applications/*/*.app "$HOME"/Applications/*.app; do
  [ -d "$app" ] || continue
  case "$app" in /Applications/Utilities/*) continue;; esac
  P="$app/Contents/Info"
  BID=$(defaults read "$P" CFBundleIdentifier 2>/dev/null)
  VER=$(defaults read "$P" CFBundleShortVersionString 2>/dev/null)
  EXE=$(defaults read "$P" CFBundleExecutable 2>/dev/null)
  ARCHS=""; [ -n "$EXE" ] && ARCHS=$(lipo -archs "$app/Contents/MacOS/$EXE" 2>/dev/null)
  LU=$(mdls -raw -name kMDItemLastUsedDate "$app" 2>/dev/null)
  AGE=""; [ -n "$LU" ] && [ "$LU" != "(null)" ] && AGE=$(days_since "$LU")
  SZ=""; [ "$QUICK" -eq 0 ] && SZ=$(size_gb "$app")
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$app" "$BID" "$VER" "$ARCHS" "$AGE" "$SZ" >> "$WORK/apps.tsv"
done
NAPPS=$(wc -l < "$WORK/apps.tsv" | tr -d ' ')
info "$NAPPS applications installées :"
while IFS=$'\t' read -r app bid ver archs age sz; do
  name=$(basename "$app" .app)
  printf '    - %s | %s | %s Go | %s | %s\n' "$name" "${ver:-?}" "${sz:-?}" "${archs:-?}" "$( [ -n "$age" ] && echo "ouverte il y a $age j" || echo "jamais ouverte / inconnu")"
done < "$WORK/apps.tsv"
# Applis Intel sur puce Apple (passent par Rosetta, plus lentes)
if [ "$ARCH" = "arm64" ]; then
  awk -F'\t' '$4!="" && $4 !~ /arm64/ {print $1}' "$WORK/apps.tsv" | while IFS= read -r a; do
    flag "Appli Intel uniquement (Rosetta, plus lente et plus gourmande) : $(basename "$a" .app) -> chercher une version Apple Silicon"
  done
fi
# Même appli installée deux fois (même identifiant)
awk -F'\t' '$2!="" {print $2"\t"$1}' "$WORK/apps.tsv" | sort | awk -F'\t' '{c[$1]++; p[$1]=p[$1] (p[$1]?" ; ":"") $2} END{for(k in c) if(c[k]>1) print k"\t"p[k]}' |
  while IFS=$'\t' read -r bid paths; do flag "Même appli installée plusieurs fois ($bid) : $paths"; done
# Pas ouvertes depuis plus de 6 mois (hors applis Apple)
awk -F'\t' '$5!="" && $5>180 && $2 !~ /^com\.apple\./ {print $1"\t"$5"\t"$6}' "$WORK/apps.tsv" | while IFS=$'\t' read -r a d s; do
  flag "Pas ouverte depuis $d jours : $(basename "$a" .app)$( [ -n "$s" ] && echo " ($s Go)") -> à désinstaller si inutile"
done
# Logiciels indésirables / redondants
awk -F'\t' '{print $1}' "$WORK/apps.tsv" | while IFS= read -r a; do
  n=$(basename "$a" .app)
  if echo "$n" | grep -Eqi "$ADWARE"; then flag "Logiciel indésirable (adware / faux nettoyeur) : $n -> à supprimer en priorité"
  elif echo "$n" | grep -Eqi "$REDUNDANT"; then flag "Antivirus ou nettoyeur tiers : $n -> redondant avec les protections intégrées de macOS (XProtect, Gatekeeper), consomme des ressources"; fi
done
if has brew; then info "Homebrew : $(brew list --formula 2>/dev/null | wc -l | tr -d ' ') formules, $(brew list --cask 2>/dev/null | wc -l | tr -d ' ') casks"; fi
# Restes d'applis désinstallées : conteneurs dont l'appli n'existe plus (on ne lit que les noms, pas le contenu)
awk -F'\t' '$2!="" {print $2}' "$WORK/apps.tsv" > "$WORK/bids.txt"
for d in "$HOME/Library/Containers"/*; do
  [ -d "$d" ] || continue
  b=$(basename "$d")
  case "$b" in com.apple.*|group.*|*.apple.*) continue;; esac
  if ! awk -v b="$b" 'index(b,$0)==1 {f=1} END{exit !f}' "$WORK/bids.txt"; then echo "$b"; fi
done > "$WORK/orphans.txt"
if [ -s "$WORK/orphans.txt" ]; then
  flag "Conteneurs sans appli correspondante (restes probables, à confirmer) : $(tr '\n' ' ' < "$WORK/orphans.txt")"
fi
if [ "$QUICK" -eq 0 ]; then
  section "4b. Plus gros dossiers dans ~/Library/Application Support"
  for d in "$HOME/Library/Application Support"/*; do
    [ -d "$d" ] && du -sk "$d" 2>/dev/null
  done | sort -rn | head -10 | awk -F'\t' '{printf "    - %7.2f Go  %s\n", $1/1048576, $2}'
fi

# ---------------------------------------------------------------- 5
section "5. Démarrage et arrière-plan"
info "Éléments ouverts à la connexion : à vérifier dans Réglages Système > Général > Ouverture (non lisible sans droits)"
for dir in "$HOME/Library/LaunchAgents" /Library/LaunchAgents /Library/LaunchDaemons; do
  for p in "$dir"/*.plist; do
    [ -f "$p" ] || continue
    lbl=$(plist_get "$p" Label); [ -z "$lbl" ] && lbl=$(basename "$p" .plist)
    case "$lbl" in com.apple.*) continue;; esac
    prog=$(plist_get "$p" Program); [ -z "$prog" ] && prog=$(plist_get "$p" ProgramArguments.0)
    if [ -n "$prog" ] && [ "${prog#/}" != "$prog" ] && [ ! -e "$prog" ]; then
      flag "Tâche de fond orpheline : $p -> $prog (programme absent : reste d'une appli désinstallée)"
    else info "Tâche de fond : $lbl -> ${prog:-?} [$dir]"; fi
  done
done
NBG=$(launchctl list 2>/dev/null | awk 'NR>1 && $3 !~ /^com\.apple\./' | wc -l | tr -d ' ')
info "$NBG processus de fond tiers chargés pour cet utilisateur"
section "5b. Processus les plus gourmands"
ps -Aceo rss=,pcpu=,comm= | awk '{rs=$1; cp=$2; $1=""; $2=""; sub(/^[ \t]+/,""); r[$0]+=rs; c[$0]+=cp; n[$0]++} END{for(k in r) printf "%d\t%.1f\t%d\t%s\n", r[k]/1024, c[k], n[k], k}' |
  sort -rn | head -15 | awk -F'\t' '{printf "    - %s x%s : %s Mo RAM, %s %% CPU\n", $4, $3, $1, $2}'

# ---------------------------------------------------------------- 6
section "6. Fichiers inutiles et espace récupérable"
if [ "$QUICK" -eq 0 ]; then
  BREWCACHE=""; has brew && BREWCACHE=$(brew --cache 2>/dev/null)
  while IFS='|' read -r label path; do
    [ -z "$path" ] && continue
    g=$(size_gb "$path")
    [ -n "$g" ] && awk "BEGIN{exit !($g > 0.05)}" && printf '    - %7s Go  %s  [%s]\n' "$g" "$label" "$path"
  done <<EOF
Caches utilisateur (se reconstruisent, voir fixes.md)|$HOME/Library/Caches
Journaux utilisateur|$HOME/Library/Logs
Corbeille|$HOME/.Trash
Téléchargements|$HOME/Downloads
Xcode DerivedData (nettoyable)|$HOME/Library/Developer/Xcode/DerivedData
Xcode Archives|$HOME/Library/Developer/Xcode/Archives
Xcode iOS DeviceSupport (nettoyable)|$HOME/Library/Developer/Xcode/iOS DeviceSupport
Simulateurs iOS|$HOME/Library/Developer/CoreSimulator/Devices
Sauvegardes iPhone/iPad|$HOME/Library/Application Support/MobileSync/Backup
Cache Homebrew (nettoyable)|$BREWCACHE
Cache npm (nettoyable)|$HOME/.npm/_cacache
Cache pip (nettoyable)|$HOME/Library/Caches/pip
EOF
  TR=$(size_gb "$HOME/.Trash")
  [ -n "$TR" ] && awk "BEGIN{exit !($TR > 1)}" && flag "Corbeille : $TR Go -> à vider (après vérification)"
  find "$HOME/Downloads" -type f -size +500M 2>/dev/null | while IFS= read -r f; do
    info "Gros fichier dans Téléchargements : $(basename "$f") ($(du -h "$f" | cut -f1))"
  done
  [ -d "$HOME/Library/Containers/com.docker.docker" ] && info "Docker Desktop installé : son disque virtuel peut occuper des dizaines de Go (Docker > Settings > Resources)"
  # Gros fichiers en double (ignore les fichiers iCloud non téléchargés et les dossiers de projets / bibliothèques)
  for d in Desktop Documents Downloads Pictures Movies Music; do
    [ -d "$HOME/$d" ] && find "$HOME/$d" -type f -size +20M \
      -not -path '*.photoslibrary/*' -not -path '*.app/*' -not -path '*/node_modules/*' -not -path '*/.git/*' \
      -not -path '*/build/*' -not -path '*/dist/*' -not -path '*/out/*' -not -path '*/DerivedData/*' 2>/dev/null
  done | while IFS= read -r f; do
    fl=$(stat -f '%Xf' "$f" 2>/dev/null); [ -n "$fl" ] && [ $(( 0x$fl & 0x40000000 )) -ne 0 ] && continue
    printf '%s\t%s\n' "$(stat -f '%z' "$f")" "$f"
  done | sort -n > "$WORK/big.tsv"
  awk -F'\t' '{c[$1]++} END{for(k in c) if(c[k]>1) print k}' "$WORK/big.tsv" > "$WORK/dupsizes.txt"
  if [ -s "$WORK/dupsizes.txt" ]; then
    awk -F'\t' 'NR==FNR{s[$1]=1; next} ($1 in s){print $2}' "$WORK/dupsizes.txt" "$WORK/big.tsv" | while IFS= read -r f; do
      printf '%s\t%s\n' "$(md5 -q "$f" 2>/dev/null)" "$f"
    done | sort | awk -F'\t' '{c[$1]++; p[$1]=p[$1] (p[$1]?" ; ":"") $2} END{for(k in c) if(c[k]>1) print c[k]"\t"p[k]}' |
      while IFS=$'\t' read -r n paths; do flag "Fichiers identiques ($n copies) : $paths"; done
  else ok "Aucun gros fichier en double (> 20 Mo) dans les dossiers perso"; fi
else info "Mode --quick : tailles et doublons non mesurés"; fi

# ---------------------------------------------------------------- 7
section "7. Réglages performance et confort"
LPM=$(pmset -g 2>/dev/null | awk '/lowpowermode/{print $2}')
if [ -n "$BAT" ]; then info "Mode économie d'énergie : ${LPM:-?} (1 = activé ; normal sur batterie, ralentit le Mac)"
elif [ "$LPM" = "1" ]; then flag "Mode économie d'énergie activé sur un Mac de bureau : performances bridées"
else ok "Mode économie d'énergie : désactivé"; fi
info "Mise en veille : $(pmset -g 2>/dev/null | awk '$1=="sleep"{print $2" min"}') ; écran : $(pmset -g 2>/dev/null | awk '$1=="displaysleep"{print $2" min"}')"
SPOT=$(mdutil -s / 2>/dev/null | tail -1 | sed 's/^[[:space:]]*//')
info "Spotlight (/) : $SPOT"
RT=$(defaults read com.apple.universalaccess reduceTransparency 2>/dev/null)
RM=$(defaults read com.apple.universalaccess reduceMotion 2>/dev/null)
info "Réduire la transparence : ${RT:-0} ; réduire les animations : ${RM:-0} (1 = activé, allège l'affichage sur les Mac modestes)"
DJ=$(spjson SPDisplaysDataType)
i=0
while :; do
  n=$(pl "$DJ" "SPDisplaysDataType.0.spdisplays_ndrvs.$i._name"); [ -z "$n" ] && break
  res=$(pl "$DJ" "SPDisplaysDataType.0.spdisplays_ndrvs.$i._spdisplays_resolution")
  case "$res" in
    *"@ 60"*|*"@ 59"*) info "Écran $n : $res -> si l'écran gère plus de 60 Hz, régler le taux dans Réglages Système > Moniteurs";;
    *) info "Écran $n : ${res:-?}";;
  esac
  i=$((i+1))
done
MS=$(defaults read -g com.apple.mouse.scaling 2>/dev/null)
ML=$(defaults read -g com.apple.mouse.linear 2>/dev/null)
info "Souris : vitesse ${MS:-défaut}$( [ "$ML" = "1" ] && echo ', accélération désactivée')"

# ---------------------------------------------------------------- 8
section "8. Sécurité et sauvegarde"
FV=$(fdesetup status 2>/dev/null)
case "$FV" in *"On"*) ok "FileVault : activé";; *"Off"*) if [ -n "$BAT" ]; then flag "FileVault désactivé sur un portable : en cas de vol, les données sont lisibles"; else info "FileVault : désactivé"; fi;; *) info "FileVault : $FV";; esac
FW=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null)
case "$FW" in *enabled*|*"State = 1"*|*"State = 2"*) ok "Pare-feu : activé";; *) flag "Pare-feu macOS désactivé ($FW)";; esac
GK=$(spctl --status 2>/dev/null)
case "$GK" in *enabled*) ok "Gatekeeper : activé";; *) flag "Gatekeeper désactivé ($GK) : n'importe quelle appli peut s'ouvrir sans contrôle";; esac
SIP=$(csrutil status 2>/dev/null)
case "$SIP" in *enabled*) ok "Protection de l'intégrité du système (SIP) : activée";; *) flag "SIP : $SIP";; esac
TMD=$(tmutil destinationinfo 2>/dev/null)
if echo "$TMD" | grep -qi 'No destinations'; then flag "Time Machine : aucune sauvegarde configurée"
elif [ -n "$TMD" ]; then
  LB=$(tmutil latestbackup 2>/dev/null)
  if [ -n "$LB" ]; then ok "Time Machine : dernière sauvegarde $(basename "$LB")"; else info "Time Machine configuré (date de la dernière sauvegarde : ACCÈS COMPLET AU DISQUE REQUIS)"; fi
else info "Time Machine : état non lisible"; fi

# ---------------------------------------------------------------- 9
section "9. Stabilité (30 derniers jours)"
find "$HOME/Library/Logs/DiagnosticReports" /Library/Logs/DiagnosticReports -maxdepth 2 -type f -mtime -30 \
  \( -name '*.ips' -o -name '*.crash' -o -name '*.panic' -o -name '*.diag' -o -name '*.hang' \) 2>/dev/null > "$WORK/diag.txt"
PAN=$(grep -ci 'panic' "$WORK/diag.txt"); JET=$(grep -c 'JetsamEvent' "$WORK/diag.txt")
if [ "$PAN" -gt 0 ]; then flag "$PAN kernel panic(s) (redémarrage brutal) : souvent matériel, extension système ou macOS à mettre à jour"; else ok "Aucun kernel panic"; fi
if [ "$JET" -gt 0 ]; then flag "$JET événement(s) de manque de mémoire (Jetsam) : macOS a dû fermer des applis"; fi
grep -viE 'panic|JetsamEvent' "$WORK/diag.txt" | sed -E 's#.*/##; s/[-_][0-9]{4}-[0-9]{2}-[0-9]{2}.*$//; s/\.(ips|crash|diag|hang)$//' | sort | uniq -c | sort -rn | head -8 |
  while read -r n a; do flag "Plantage d'application : $a x$n"; done
[ -s "$WORK/diag.txt" ] || ok "Aucun rapport de plantage"

# ---------------------------------------------------------------- 10
section "10. Réseau"
IF=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')
PORT=$(networksetup -listallhardwareports 2>/dev/null | awk -v d="$IF" '/Hardware Port/{p=$0; sub(/Hardware Port: /,"",p)} $0=="Device: "d{print p}')
info "Connexion active : ${PORT:-?} ($IF) - DNS : $(scutil --dns 2>/dev/null | awk '/nameserver\[[0-9]+\]/{print $3}' | sort -u | head -3 | tr '\n' ' ')"
if echo "$PORT" | grep -qi 'wi-fi\|airport'; then
  AJ=$(spjson SPAirPortDataType)
  SN=$(pl "$AJ" SPAirPortDataType.0.spairport_airport_interfaces.0.spairport_current_network_information.spairport_signal_noise)
  PHY=$(pl "$AJ" SPAirPortDataType.0.spairport_airport_interfaces.0.spairport_current_network_information.spairport_network_phymode)
  CH=$(pl "$AJ" SPAirPortDataType.0.spairport_airport_interfaces.0.spairport_current_network_information.spairport_network_channel)
  SIG=$(echo "$SN" | sed -E 's/^(-?[0-9]+).*/\1/')
  line="Wi-Fi : signal/bruit ${SN:-?}, norme ${PHY:-?}, canal ${CH:-?}"
  if [ -n "$SIG" ] && [ "$SIG" -lt -70 ] 2>/dev/null; then flag "$line -> signal faible : se rapprocher de la box, bande 5 GHz, ou câble Ethernet"
  else info "$line"; fi
fi
for h in 1.1.1.1 8.8.8.8; do
  P=$(ping -c 4 -t 8 "$h" 2>/dev/null)
  AVG=$(echo "$P" | awk -F'/' '/round-trip|rtt/{printf "%d", $5}')
  LOSS=$(echo "$P" | sed -nE 's/.* ([0-9.]+)% packet loss.*/\1/p')
  if [ -z "$AVG" ]; then flag "Ping $h : aucune réponse"
  elif [ "$AVG" -gt 60 ] || [ "${LOSS%.*}" -gt 0 ]; then flag "Ping $h : $AVG ms, $LOSS % de pertes -> connexion lente ou instable"
  else ok "Ping $h : $AVG ms, $LOSS % de pertes"; fi
done

printf '\n# Fin du rapport\n'
