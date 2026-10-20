#!/usr/bin/env zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PORT="${PORT:-18080}"
BASE_URL="http://127.0.0.1:${PORT}/api/v1"

echo "🐎 =================================================================="
echo "🐎  HORSY — FULL-STACK END-TO-END LIVE DEMO"
echo "🐎 =================================================================="

# Ensure Postgres container is running
if ! docker ps --format '{{.Names}}' | grep -q '^stallion-postgres$'; then
  echo "📦 Starting PostgreSQL 16 Docker container..."
  docker start stallion-postgres >/dev/null 2>&1 || \
    docker run -d --name stallion-postgres \
      -e POSTGRES_USER=stallion \
      -e POSTGRES_PASSWORD=stallion_pass \
      -e POSTGRES_DB=stallion_match \
      -p 5432:5432 postgres:16-alpine >/dev/null
  sleep 2
fi

echo "🚀 Launching Vapor Server on port ${PORT}..."
cd "${ROOT_DIR}/Server"
PORT="${PORT}" DATABASE_NAME="stallion_match" ./.build/debug/Run >/tmp/stallion_demo_server.log 2>&1 &
SERVER_PID=$!
trap 'kill ${SERVER_PID} 2>/dev/null || true' EXIT
sleep 2

TS="$(date +%s)"

echo ""
echo "1️⃣  Health Check (GET /api/v1/health)"
curl -s "${BASE_URL}/health"
echo -e "\n"

echo "2️⃣  Sign Up Owner #1 (Clara) & Owner #2 (Mateo)"
S1=$(curl -s -X POST "${BASE_URL}/auth/signup" -H "Content-Type: application/json" \
  -d "{\"email\":\"clara.${TS}@stallionmatch.app\",\"password\":\"StablePass123\",\"displayName\":\"Clara Vance\"}")
TOKEN1=$(echo "$S1" | python3 -c "import sys,json; print(json.load(sys.stdin)['accessToken'])")
echo "   Clara user created: $(echo "$S1" | python3 -c "import sys,json; d=json.load(sys.stdin)['user']; print(f\"{d['displayName']} ({d['email']}) — id={d['id']}\")")"

S2=$(curl -s -X POST "${BASE_URL}/auth/signup" -H "Content-Type: application/json" \
  -d "{\"email\":\"mateo.${TS}@stallionmatch.app\",\"password\":\"StablePass123\",\"displayName\":\"Mateo Rojas\"}")
TOKEN2=$(echo "$S2" | python3 -c "import sys,json; print(json.load(sys.stdin)['accessToken'])")
echo "   Mateo user created: $(echo "$S2" | python3 -c "import sys,json; d=json.load(sys.stdin)['user']; print(f\"{d['displayName']} ({d['email']}) — id={d['id']}\")")"
echo ""

echo "3️⃣  Create Horse Profiles (Apollo in Lexington, KY & Luna in Georgetown, KY)"
H1=$(curl -s -X POST "${BASE_URL}/horses" -H "Authorization: Bearer ${TOKEN1}" -H "Content-Type: application/json" \
  -d '{"name":"Apollo","age":6,"sex":"stallion","breed":"Warmblood","color":"Bay","heightHands":16.2,"disciplines":["dressage","jumping"],"temperamentTags":["Bold","Athletic"],"bio":"FEI prospect looking for training & trail companions.","location":{"city":"Lexington, KY","coarseLatitude":38.04,"coarseLongitude":-84.50},"lookingFor":["riding_companion","trail_buddy"],"healthInfo":{"vaccinationsUpToDate":true},"pedigree":"Sire: Donnerhall II"}')
H1_ID=$(echo "$H1" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
echo "   Created Horse #1: Apollo (id=${H1_ID})"

H2=$(curl -s -X POST "${BASE_URL}/horses" -H "Authorization: Bearer ${TOKEN2}" -H "Content-Type: application/json" \
  -d '{"name":"Luna","age":5,"sex":"mare","breed":"Andalusian","color":"Dapple Grey","heightHands":15.3,"disciplines":["dressage","trail"],"temperamentTags":["Calm","Affectionate"],"bio":"Quiet trail & classical dressage mare.","location":{"city":"Georgetown, KY","coarseLatitude":38.20,"coarseLongitude":-84.56},"lookingFor":["trail_buddy","friendship"],"healthInfo":{"vaccinationsUpToDate":true}}')
H2_ID=$(echo "$H2" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
echo "   Created Horse #2: Luna   (id=${H2_ID})"
echo ""

echo "4️⃣  Upload 2 Verified Photos Each (Multipart Form-Data -> StorageService)"
printf '\xFF\xD8\xFF\xE0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00\xFF\xD9' >/tmp/horse_demo.jpg
for idx in 0 1; do
  curl -s -X POST "${BASE_URL}/horses/${H1_ID}/photos" -H "Authorization: Bearer ${TOKEN1}" -F "file=@/tmp/horse_demo.jpg;type=image/jpeg" -F "position=${idx}" >/dev/null
  curl -s -X POST "${BASE_URL}/horses/${H2_ID}/photos" -H "Authorization: Bearer ${TOKEN2}" -F "file=@/tmp/horse_demo.jpg;type=image/jpeg" -F "position=${idx}" >/dev/null
done
echo "   Uploaded 2 photos for Apollo and 2 photos for Luna."
echo ""

echo "5️⃣  Query Discovery Feed for Apollo (Radius 50km, Discipline=dressage)"
DISC=$(curl -s "${BASE_URL}/discovery?activeHorseID=${H1_ID}&maxDistanceKm=50&discipline=dressage" -H "Authorization: Bearer ${TOKEN1}")
echo "$DISC" | python3 -m json.tool
echo ""

echo "6️⃣  Swipe Right: Apollo likes Luna, then Luna likes Apollo (Atomic Match + APNs)"
SW1=$(curl -s -X POST "${BASE_URL}/swipes" -H "Authorization: Bearer ${TOKEN1}" -H "Content-Type: application/json" \
  -d "{\"swiperHorseID\":\"${H1_ID}\",\"targetHorseID\":\"${H2_ID}\",\"direction\":\"like\"}")
echo "   Apollo -> Luna: $(echo "$SW1" | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"isMatch={d['isMatch']}\")")"

SW2=$(curl -s -X POST "${BASE_URL}/swipes" -H "Authorization: Bearer ${TOKEN2}" -H "Content-Type: application/json" \
  -d "{\"swiperHorseID\":\"${H2_ID}\",\"targetHorseID\":\"${H1_ID}\",\"direction\":\"like\"}")
echo "   Luna -> Apollo (MUTUAL MATCH!):"
echo "$SW2" | python3 -m json.tool
CONV_ID=$(echo "$SW2" | python3 -c "import sys,json; print(json.load(sys.stdin)['match']['conversationID'])")
echo ""

echo "7️⃣  Send Chat Message in Conversation (${CONV_ID}) & Check Unread Count"
MSG=$(curl -s -X POST "${BASE_URL}/conversations/${CONV_ID}/messages" -H "Authorization: Bearer ${TOKEN1}" -H "Content-Type: application/json" \
  -d "{\"senderHorseID\":\"${H1_ID}\",\"body\":\"Hi Mateo! Would Luna like to join Apollo at the Kentucky Horse Park trails this Saturday?\"}")
echo "   Sent Message:"
echo "$MSG" | python3 -m json.tool
echo ""

echo "8️⃣  Fetch Mateo's Conversation List (Unread Count & Last Message Preview)"
CONVS=$(curl -s "${BASE_URL}/conversations" -H "Authorization: Bearer ${TOKEN2}")
echo "$CONVS" | python3 -m json.tool
echo ""
echo "✅ End-to-End Demo Completed Successfully!"
