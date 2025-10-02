#!/bin/bash
# Script om booleans in docker-compose.yml te fixen
set -e
FILE="docker-compose.yml"
cp "$FILE" "$FILE.bak"
sed -i 's/: true/: "true"/g' "$FILE"
sed -i 's/: false/: "false"/g' "$FILE"
sed -i 's/: yes/: "yes"/g' "$FILE"
sed -i 's/: no/: "no"/g' "$FILE"
echo "Booleans in $FILE zijn nu strings. Backup: $FILE.bak"
