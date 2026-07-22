#!/usr/bin/env bash
# Phase-2 GENERATOR: migrate one eval cell → a type=batch agent-spec (the "st eval" / st2 batch format),
# a byte-identical WRAP of the cell's existing fixtures. Uses the proven reference shape:
#   - STEV_DRYRUN runs the cell's spin.sh to build the world + personas + extract the seats + kick (no agents).
#   - render each extracted seat up-front into the catalog (=$SB/st-root); world overlay survives (no wipe).
#   - job kdl: setup=no-op (world pre-built), run={seats + kick + done-when message-mode}, grade={grade.sh + verdict grader-output}.
#   - st2 batch auto-pretrusts seats + dual-seeds the kick (HEAD af1aebb), so no manual pretrust / no symlink needed here.
# Fixtures (setup-sandbox.sh / compose / grade.sh / kick.md) are UNCHANGED — only a KDL DAG declared around them.
#   gen-batch.sh <cell>            # emits + validates the catalog; prints the st2 batch command
#   gen-batch.sh <cell> --run      # also runs it live and prints the verdict
set -uo pipefail
CELL="${1:?cell}"; RUN="${2:-}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
ST2="${ST2_BIN:-st2}"
export PERSONAS_DIR="$REPO/.personas"
GSB=/tmp/eg/$CELL            # generator world sandbox (short, isolated from the gate's /tmp/e)
SEATS=$(mktemp); KICK=$(mktemp)
HOST=h

echo "### GEN $CELL"
rm -rf "$GSB"; mkdir -p "$GSB"
# 1) extract seats+kick + build world+personas via the cell's OWN spin.sh in dry-run
STEV_DRYRUN=1 STEV_SEATS_FILE="$SEATS" STEV_KICK_FILE="$KICK" \
  EVAL_SANDBOX=/tmp/eg PERSONAS_DIR="$PERSONAS_DIR" "$REPO/cells/$CELL/fixture/spin.sh" >/dev/null 2>&1
[ -s "$SEATS" ] || { echo "  FAIL: no seats extracted (cell may not use the stev_convoy_add seam)"; exit 1; }
# the cell's actual sandbox (spin.sh chooses $EVAL_SANDBOX/<subdir>); derive it from the first seat's dir
SB=$(head -1 "$SEATS" | cut -f4 | sed 's#/[^/]*$##')   # seat dir = $SB/<seatdir> → strip last component
CAT="$SB/st-root"
echo "  sandbox=$SB  seats=$(wc -l <"$SEATS")  catalog=$CAT"

# 2) render each seat up-front into the catalog
while IFS=$'\t' read -r id role harness dir persona; do
  ea=""; # (extra-args like skill-inheritance's --plugin-dir would be threaded here; none for most cells)
  "$ST2" render-agent "$CAT" --identity "$id" --role "$role" --dir "$dir" --persona "$persona" --harness "$harness" --host "$HOST" >/dev/null 2>&1 \
    || { echo "  FAIL: render-agent $id"; exit 1; }
done < "$SEATS"

# 3) kick + grade wrapper + the job kdl
mkdir -p "$CAT/$HOST/$CELL" "$CAT/scripts"
read -r RECIP REQ KICKFILE < <(head -1 "$KICK" | tr '\t' ' ')
sed '/^<!--/,/-->/d' "$KICKFILE" | sed '/^$/{/./!d}' > "$CAT/kick.md"
SUP=$(awk -F'\t' '$2=="supervisor"{print $1; exit}' "$SEATS"); SUP="${SUP:-$RECIP}"
printf '#!/usr/bin/env sh\nexec sh "%s/cells/%s/fixture/grade.sh" "%s"\n' "$REPO" "$CELL" "$SB" > "$CAT/scripts/grade.sh"; chmod +x "$CAT/scripts/grade.sh"
{
  echo "agent \"$CELL\" {"
  echo "  identity \"$CELL\""
  echo "  host \"$HOST\""
  echo "  type \"batch\""
  echo "  run {"
  while IFS=$'\t' read -r id role harness dir persona; do echo "    seat \"$id\" { agent \"$id\" }"; done < "$SEATS"
  echo "    kick      { to \"$RECIP\"; from-file \"\$CATALOG/kick.md\" }"
  echo "    done-when { grade; timeout \"1200s\" }"
  echo "  }"
  echo "  stage \"setup\" { exec { command \"true\" } }"
  echo "  stage \"run\"   { after \"setup\"; run }"
  echo "  stage \"grade\" { after \"run\"; exec { command \"sh \$CATALOG/scripts/grade.sh\" }; verdict \"grader-output\" }"
  echo "}"
} > "$CAT/$HOST/$CELL/agent.kdl"

echo "  kick→$RECIP  done-when from=$SUP to=$REQ"
echo "### validate:"; "$ST2" validate "$CAT" 2>&1 | tail -2 | sed 's/^/  /'
echo "### run:  $ST2 batch $CAT $CELL --host $HOST"
rm -f "$SEATS" "$KICK"
if [ "$RUN" = "--run" ]; then
  echo "### LIVE:"; "$ST2" batch "$CAT" "$CELL" --host "$HOST" 2>&1 | grep -E 'SCORE|VERDICT|verdict|Error|done-when' | tail -5
fi
