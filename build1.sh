#!/bin/bash
#
# ======================================
# EDIT
PROGRAMMVERSION="0.3.2" 
MSG="Include table export" # COMMIT MSG FOR GIT
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
ORDNER="/home/heiko/development/rust/pgburst/"
AUR_ORDNER="/home/heiko/tools/pgburst_upstream/"
DATUM=$(date '+%B %d, %Y')
TMPFOLDER="/tmp/pgburst"
MANFILE="./pgburst.1.gz"

echo "BUILD: Setting dates and version (to $DATUM and $PROGRAMMVERSION)..."
sed -e "s/#PROGRAMMVERSION#/$PROGRAMMVERSION/g" "$ORDNER/manpage_template.md" > "$ORDNER/manpage.md"
sed -i -e "s/#DATUM#/$DATUM/g" "$ORDNER/manpage.md" 
sed -i -e "s/#DATUM#/$DATUM/g" "$ORDNER/manpage.md" 
sed -e "s/#PROGRAMMVERSION#/$PROGRAMMVERSION/g" "$ORDNER/Cargo_template.toml" > "$ORDNER/Cargo.toml"
echo "BUILD: ...set."
echo ""
echo "BUILD: Compiling manpage..."
rm $MANFILE
pandoc ./manpage.md -s -t man -o ./pgburst.1
gzip ./pgburst.1
check_test_outcome
echo "BUILD: ...compiled"
echo 
echo
echo
sleep 3

echo "BUILD: Compiling binary for AUR with -m..."
cargo-aur -m b
check_test_outcome
echo "BUILD: ...compiled."
echo 
echo
echo
sleep 3

PGV="pgburst-$PROGRAMMVERSION-x86_64.tar.gz"
echo "BUILD: Producing binary $PGV with manpage inside..."
rm -rf $TMPFOLDER
mkdir -p "$TMPFOLDER"
cp "$ORDNER/target/cargo-aur/$PGV" "$TMPFOLDER/"
cp "$ORDNER/LICENSE.md" "$TMPFOLDER/"
cp "$ORDNER/pgburst.1.gz" "$TMPFOLDER/"
cd $TMPFOLDER
tar -xf "$PGV"
rm "$PGV"
tar -czf $PGV pgburst LICENSE.md pgburst.1.gz
cp $PGV "$ORDNER/target/cargo-aur/"
cp $PGV ~/tools/pgburst_upstream/
echo "BUILD: ...produced."
echo 
echo
echo
sleep 3

# Entwicklungsordner-Update (Github)
cd "$ORDNER"
echo "BUILD: Updating GIT..."
git add .
check_test_outcome
git commit -m "$MSG"
check_test_outcome
git push origin
check_test_outcome
# gh release create v"$PROGRAMMVERSION" --notes "$MSG" "$ORDNER/target/cargo-aur/$PGV"
echo "BUILD: ...committed"
echo 
echo
echo
sleep 3

echo "Lade Version für AUR hoch"
SHASUM=$(sha256sum  "$AUR_ORDNER/$PGV" | awk '{print $1}')

sed -e "s/#SHASUM#/$SHASUM/g" "$AUR_ORDNER/SRCINFO_template.md" > "$AUR_ORDNER/pgburst/.SRCINFO"
sed -i -e "s/#PROGRAMMVERSION#/$PROGRAMMVERSION/g" "$AUR_ORDNER/pgburst/.SRCINFO" 

sed -e "s/#SHASUM#/$SHASUM/g" "$AUR_ORDNER/PKGBUILD_template.md" > "$AUR_ORDNER/pgburst/PKGBUILD"
sed -i -e "s/#PROGRAMMVERSION#/$PROGRAMMVERSION/g" "$AUR_ORDNER/pgburst/PKGBUILD" 

echo "BUILD: Going to $AUR_ORDNER, pushing commit there..."
cd "$AUR_ORDNER/pgburst"
git add .
check_test_outcome
git commit -m "$MSG"
check_test_outcome
git push
check_test_outcome
echo "BUILD: ...pushed to AUR"
echo 
echo
echo
sleep 3

echo "OK, you can start Git Hub release (build2)"
