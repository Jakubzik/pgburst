#!/bin/bash
#
# ======================================
# EDIT
PROGRAMMVERSION="0.2.5" 
# MSG="Added functionality to edit config file and archive appointments that are past." # COMMIT MSG FOR GIT
# ======================================

function check_test_outcome {
  ret_code=$1
  if [[ "$ret_code" -ne 0 ]] ; then
    echo -e "\e[31mFAIL: $ret_code\e[0m";
    exit 1;
  else
    echo -e "\e[32mok\e[0m"
  fi;
}

# Installiert als crate für cargo install;
# Lädt einen Release by Github hoch
# Lädt PKGBUILD und .SRCINFO (via tools/rremind_upstream/remind) auf AUR
ORDNER="/home/heiko/development/rust/pgbrst"
AUR_ORDNER="/home/heiko/tools/pgbrst_upstream"
DATUM=$(date '+%B %d, %Y')
TMPFOLDER="/tmp/pgburst"
MANFILE="./pgburst.1.gz"
PGV="pgburst-$PROGRAMMVERSION-x86_64.tar.gz"


cd $ORDNER
echo "Lade Release auf GitHub hoch"
gh release create v"$PROGRAMMVERSION" "$ORDNER/target/cargo-aur/$PGV"
check_test_outcome
sleep 3


