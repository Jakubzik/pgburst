#!/bin/bash
#
# ======================================
# EDIT
PGBURSTVERSION="0.2.3" 
MSG="Update libraries" # COMMIT MSG FOR GIT
# ======================================

function check_outcome {
  ret_code=$1
  if [ $ret_code -ne 0 ] ; then
    echo -e "\e[31mFAIL: $ret_code\e[0m";
    exit 1;
  else
    echo -e "\e[32mok\e[0m"
  fi;
}

ORDNER="/home/heiko/development/rust/pgburst"
AUR_ORDNER="/home/heiko/tools/pgburst_upstream"
DATUM=$(date '+%B %d, %Y')
TMPFOLDER="/tmp/pgburst"
MANFILE="./pgburst.1.gz"

echo "BUILD: Setting dates and version (to $DATUM and $PGBURSTVERSION)..."
sed -e "s/#PGBURSTVERSION#/$PGBURSTVERSION/g" "$ORDNER/manpage_template.md" > "$ORDNER/manpage.md"
sed -i -e "s/#DATUM#/$DATUM/g" "$ORDNER/manpage.md" 
sed -e "s/#PGBURSTVERSION#/$PGBURSTVERSION/g" "$ORDNER/Cargo_template.toml" > "$ORDNER/Cargo.toml"
echo "BUILD: ...set."
echo ""
echo "BUILD: Compiling manpage..."
rm $MANFILE
pandoc ./manpage.md -s -t man -o ./pgburst.1
gzip ./pgburst.1
echo "BUILD: ...compiled"
check_outcome

echo "BUILD: Compiling binary for AUR with -m..."
cargo-aur -m b
echo "BUILD: ...compiled."
check_outcome

PGV="pgburst-$PGBURSTVERSION-x86_64.tar.gz"
echo "BUILD: Producing binary $PGV with manpage inside..."
rm -rf $TMPFOLDER
mkdir -p "$TMPFOLDER"
cp "$ORDNER/target/cargo-aur/$PGV" "$TMPFOLDER/"
cp "$ORDNER/target/cargo-aur/LICENSE.md" "$TMPFOLDER/"
cp "$ORDNER/pgburst.1.gz" "$TMPFOLDER/"
cd $TMPFOLDER
tar -xf "$PGV"
rm "$PGV"
tar -czf $PGV pgburst LICENSE.md pgburst.1.gz
cp $PGV "$ORDNER/target/cargo-aur/"
cp $PGV ~/tools/pgburst_upstream/
echo "BUILD: ...produced."
check_outcome

cd "$ORDNER"
echo "BUILD: Updating GIT..."
git add .
git commit -m "$MSG"
git push origin
gh release create v"$PGBURSTVERSION" --notes "$MSG" "$ORDNER/target/cargo-aur/$PGV"
echo "BUILD: ...committed"
check_outcome

SHASUM=$(sha256sum  "$AUR_ORDNER/$PGV" | awk '{print $1}')

sed -e "s/#SHASUM#/$SHASUM/g" "$AUR_ORDNER/SRCINFO_template.md" > "$AUR_ORDNER/pgburst/.SRCINFO"
sed -i -e "s/#PGBURSTVERSION#/$PGBURSTVERSION/g" "$AUR_ORDNER/pgburst/.SRCINFO" 

sed -e "s/#SHASUM#/$SHASUM/g" "$AUR_ORDNER/PKGBUILD_template.md" > "$AUR_ORDNER/pgburst/PKGBUILD"
sed -i -e "s/#PGBURSTVERSION#/$PGBURSTVERSION/g" "$AUR_ORDNER/pgburst/PKGBUILD" 

echo "BUILD: Going to $AUR_ORDNER, pushing commit there..."
cd "$AUR_ORDNER/pgburst"
git add .
git commit -m "$MSG"
git push
echo "BUILD: ...pushed"
check_outcome

# gh release create v"$PGBURSTVERSION" "$ORDNER/target/cargo-aur/$PGV"
#

echo "BUILD: Publishing on crates.io?"
cd "$ORDNER"
cargo publish
echo "BUILD: finished"

check_outcome
