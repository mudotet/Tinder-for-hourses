# Stallion Match

A full-stack Swift matching application for horses and their owners/handlers. Horse owners create profiles for their horses, discover nearby horses by discipline, breed, age, sex, and connection goals, match on mutual right-swipes, and chat in real time over WebSockets.

---

## Monorepo Layout

```text
/
├── SharedModels/      # Local Swift Package containing Sendable, Codable DTOs shared by Server & iOSApp
├── Server/            # Vapor 4 backend (Fluent + PostgreSQL, JWT auth, WebSockets, StorageService, APNs)
├── iOSApp/            # SwiftUI iOS client (iOS 17+, @Observable MVVM, NavigationStack, Keychain, APIClient actor)
├── .env.example       # Template for server environment variables
└── README.md          # Setup guide, curl examples, API reference, App Store checklist, and security audit
```

---

## Environment & Toolchain (Verified)

- **macOS**: 27.0.1 (`BuildVersion 26A434`, Apple Silicon `arm64`)
- **Swift**: Apple Swift version 6.3.3 (`swiftlang-6.3.3.1.3 clang-2100.1.1.101`)
- **Xcode**: Xcode 26.6 (`Build version 17F113`, bundled `iPhoneOS 26.5` & `MacOSX 26.5` SDKs)
- **PostgreSQL**: PostgreSQL 16 (`postgres:16-alpine` via Docker or `postgresql@16` via Homebrew)

---

## Fresh Mac Setup Guide

### 1. Start PostgreSQL 16
Using Docker (recommended):
```bash
docker run -d --name stallion-postgres \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=stallion_match \
  -p 5432:5432 \
  postgres:16-alpine

docker exec stallion-postgres psql -U postgres -c "CREATE DATABASE stallion_match_test;"
```
Or using Homebrew:
```bash
brew install postgresql@16
brew services start postgresql@16
createdb stallion_match
createdb stallion_match_test
```

### 2. Configure Environment Variables
```bash
cp .env.example Server/.env
```

### 3. Build & Test All Packages
```bash
# 1. SharedModels
cd SharedModels && swift build && swift test

# 2. Vapor Server
cd ../Server && swift build

# 3. iOS Client Library & ViewModels
cd ../iOSApp && swift build && swift test
```

### 4. Run the Vapor Server
```bash
cd Server
swift run Run serve --hostname 127.0.0.1 --port 8080
```

### 5. Open & Run the iOS App in Xcode
```bash
open iOSApp/StallionMatch.xcodeproj
```
> **Note**: Set `USE_MOCK_API=1` in the scheme environment variables (or pass `--uitesting-mock`) to run the iOS app standalone with `MockAPIClient` without starting the backend server.

---

## REST & WebSocket API Reference (`/api/v1`)

All endpoints accept and return JSON with `ISO-8601` dates.
All errors return a uniform structure:
```json
{
  "code": "VALIDATION_FAILED",
  "message": "Human-readable description of the error."
}
```

| Method | Endpoint | Auth | Description |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/v1/health` | Public | Health check |
| `POST` | `/api/v1/auth/signup` | Public (Rate-limited) | Register with email & password (Bcrypt), logs email verification link in dev |
| `POST` | `/api/v1/auth/login` | Public (Rate-limited) | Authenticate with email & password; returns 15-min access JWT + 30-day refresh token |
| `POST` | `/api/v1/auth/apple` | Public (Rate-limited) | Authenticate with Sign in with Apple identity token |
| `POST` | `/api/v1/auth/refresh` | Public (Rate-limited) | Rotate refresh token (stored SHA-256 hashed) and issue a new token pair |
| `POST` | `/api/v1/auth/verify-email` | Public (Rate-limited) | Verify email address using token |
| `POST` | `/api/v1/auth/logout` | Bearer JWT | Revoke refresh token |
| `GET` | `/api/v1/users/me` | Bearer JWT | Get current authenticated user profile |
| `PATCH` | `/api/v1/users/me` | Bearer JWT | Update display name, notification toggles, or accepted terms version |
| `POST` | `/api/v1/users/me/devices` | Bearer JWT | Register APNs device token |
| `DELETE` | `/api/v1/users/me` | Bearer JWT | Permanently delete account, horses, photos, swipes, matches, and messages |
| `GET` | `/api/v1/horses/mine` | Bearer JWT | List all horse profiles owned by the authenticated user |
| `POST` | `/api/v1/horses` | Bearer JWT | Create a horse profile (coarse location rounding & bio safety filter enforced) |
| `GET` | `/api/v1/horses/:horseID` | Bearer JWT | Get details of a specific horse profile |
| `PATCH` | `/api/v1/horses/:horseID` | Bearer JWT | Update a horse profile owned by the user |
| `DELETE` | `/api/v1/horses/:horseID` | Bearer JWT | Delete a horse profile owned by the user |
| `POST` | `/api/v1/horses/:horseID/photos` | Bearer JWT | Upload a photo (`multipart/form-data` or binary JPEG/PNG) via `StorageService` (max 6 photos) |
| `PUT` | `/api/v1/horses/:horseID/photos/reorder` | Bearer JWT | Reorder photos on a horse profile |
| `DELETE` | `/api/v1/horses/:horseID/photos/:photoID` | Bearer JWT | Delete a photo from a horse profile |
| `GET` | `/api/v1/discovery` | Bearer JWT | Cursor-paginated discovery feed filtered by distance, breed, sex, age range, discipline, looking-for |
| `POST` | `/api/v1/swipes` | Bearer JWT (Rate-limited) | Record an idempotent, atomic `like` or `pass`; creates a `Match` + `Conversation` on mutual `like` |
| `GET` | `/api/v1/matches` | Bearer JWT | List matches for the authenticated user's horses |
| `GET` | `/api/v1/conversations` | Bearer JWT | List conversations with last message and unread counts |
| `GET` | `/api/v1/conversations/:conversationID/messages` | Bearer JWT | Cursor-paginated message history |
| `POST` | `/api/v1/conversations/:conversationID/messages` | Bearer JWT | Send a message over REST fallback |
| `POST` | `/api/v1/conversations/:conversationID/read` | Bearer JWT | Mark conversation messages as read and emit read receipt |
| `WS` | `/api/v1/ws` | Bearer JWT | Real-time WebSocket (`WebSocketMessage` Codable enum in `SharedModels`) |
| `GET` | `/api/v1/blocks` | Bearer JWT | List blocked users |
| `POST` | `/api/v1/blocks` | Bearer JWT | Block a user (hides their horses from discovery and disables chat) |
| `DELETE` | `/api/v1/blocks/:blockedUserID` | Bearer JWT | Unblock a user |
| `POST` | `/api/v1/reports` | Bearer JWT | Report a user, horse profile, or message into the `moderation_queue` table |

---

## Verified `curl` Walkthrough

```bash
# 1. Sign up User 1
SIGNUP_1=$(curl -s -X POST http://127.0.0.1:8080/api/v1/auth/signup \
  -H "Content-Type: application/json" \
  -d '{"email":"clara@stallionmatch.com","password":"Password123!","displayName":"Clara Vance"}')
TOKEN_1=$(echo "$SIGNUP_1" | python3 -c "import sys,json; print(json.load(sys.stdin)['accessToken'])")

# 2. Create Horse Profile for User 1
HORSE_1=$(curl -s -X POST http://127.0.0.1:8080/api/v1/horses \
  -H "Authorization: Bearer $TOKEN_1" \
  -H "Content-Type: application/json" \
  -d '{
    "name":"Apollo",
    "age":7,
    "sex":"stallion",
    "breed":"Hanoverian",
    "color":"Dark Bay",
    "heightHands":16.3,
    "disciplines":["dressage","jumping"],
    "temperamentTags":["Calm","Forward"],
    "bio":"Gentle Hanoverian stallion looking for trail buddies and dressage companions.",
    "location":{"city":"Lexington, KY","coarseLatitude":38.0464,"coarseLongitude":-84.4970},
    "lookingFor":["trail_buddy","breeding_inquiry"]
  }')
HORSE_1_ID=$(echo "$HORSE_1" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

# 3. Upload Photo for Horse 1
curl -s -X POST "http://127.0.0.1:8080/api/v1/horses/$HORSE_1_ID/photos" \
  -H "Authorization: Bearer $TOKEN_1" \
  -H "Content-Type: image/jpeg" \
  --data-binary $'\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\xff\xd9'

# 4. Query Discovery Feed
curl -s "http://127.0.0.1:8080/api/v1/discovery?activeHorseID=$HORSE_1_ID&maxDistanceKm=100" \
  -H "Authorization: Bearer $TOKEN_1"

# 5. Record a Swipe
curl -s -X POST http://127.0.0.1:8080/api/v1/swipes \
  -H "Authorization: Bearer $TOKEN_1" \
  -H "Content-Type: application/json" \
  -d "{\"swiperHorseID\":\"$HORSE_1_ID\",\"targetHorseID\":\"<TARGET_HORSE_UUID>\",\"direction\":\"like\"}"
```

---

## App Store Readiness Checklist (Phase 7)

### 1. Required App Store Screenshots
1. **Welcome & Sign In Screen**: Shows email/password + Sign in with Apple and the Animal Welfare & No-Payments compliance banner.
2. **Create Horse Profile**: Shows `PhotosPicker` (2–6 photos), breed, discipline, height in hands, Coggins test date, and coarse city-level location note.
3. **Discover Card Stack & Filters**: Shows swipeable horse card ("Luna, 6 • Andalusian Mare • 20.2 km away"), accessible Like/Pass buttons, and distance/discipline filters.
4. **"It's a Match!" Celebration**: Shows mutual match celebration screen between two horses.
5. **Real-Time Equestrian Chat**: Shows live messaging with read receipts, typing indicator, Animal Welfare compliance notice, and Report/Block safety menu.
6. **Profile, Safety & Account Deletion**: Shows horse profile switcher, push notification toggles, Terms of Use, Privacy Policy, and one-tap Account Deletion.

### 2. App Privacy Nutrition Labels Summary (Matches `PrivacyInfo.xcprivacy`)
- **Contact Info (Email Address, Name)**: Collected, Linked to User, Not Used for Tracking — Purpose: *App Functionality (Authentication & Account Management)*.
- **Location (Coarse Location)**: Collected, Linked to User, Not Used for Tracking — Purpose: *App Functionality (Approximate distance filtering; rounded to 2 decimal places ~1.1 km precision; exact location never collected or stored)*.
- **Photos or Videos**: Collected, Linked to User, Not Used for Tracking — Purpose: *App Functionality (Horse profile photos)*.
- **User Content (Horse Bios & Chat Messages)**: Collected, Linked to User, Not Used for Tracking — Purpose: *App Functionality*.

### 3. App Review Notes (UGC Moderation, Reporting & Animal Welfare)
- **User-Generated Content Safety (Guideline 1.2)**:
  - Users must accept the Terms of Use (zero tolerance for objectionable content or animal abuse) upon registration.
  - All horse bios and chat messages pass through a synchronous objectionable-content and anti-payment-solicitation filter (`ObjectionableContentFilter`).
  - Users can report any horse profile, user, or chat message (`POST /api/v1/reports`), which inserts an entry into the server's `moderation_queue` table for review within 24 hours.
  - Users can immediately block any user (`POST /api/v1/blocks`), which removes their horses from Discovery, Matches, and Conversations in both directions.
- **Account Deletion (Guideline 5.1.1(v))**:
  - Users can permanently delete their account in **Profile & Settings -> Delete Account & All Data** (`DELETE /api/v1/users/me`), which cascades deletion across all database tables and deletes uploaded photo files via `StorageService`.
- **Animal Welfare & No In-App Payments**:
  - No payments, deposits, or animal sales are processed in the app. Every profile detail sheet, chat view, and auth screen displays a prominent notice reminding users to follow all local, state, and federal animal-welfare and veterinary health laws.

---

## Security & Quality Audit Summary (Phase 8)

- **Authentication & Token Security**:
  - Access JWTs expire in 15 minutes (`HS256`).
  - Refresh tokens expire in 30 days, are stored only as SHA-256 hashes in PostgreSQL (`refresh_tokens.token_hash`), and are atomically rotated in a database transaction on every `/api/v1/auth/refresh` call.
  - iOS stores tokens exclusively in `KeychainTokenStore` (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`), never in `UserDefaults`.
- **IDOR & Access Control**:
  - Every horse mutation (`PATCH/DELETE /api/v1/horses/:horseID`, photo upload/reorder/delete) verifies `horse.$owner.id == authenticatedUserID`.
  - Discovery and Swipe endpoints verify `activeHorse.$owner.id == authenticatedUserID`.
  - Chat REST and WebSocket handlers verify the user owns one of the two matched horses in the conversation and that neither user has blocked the other.
- **SQL Injection & Concurrency**:
  - All Fluent queries and raw SQL statements use bound parameters (`\(bind: ...)`).
  - Mutual likes use canonical UUID pair ordering (`horse_a_id < horse_b_id`) + PostgreSQL `UNIQUE(horse_a_id, horse_b_id)` + `ON CONFLICT DO NOTHING` inside a transaction, proven by `testConcurrentMutualLikesCreateExactlyOneMatch`.
- **Upload & Rate-Limit Protection**:
  - Auth (`/api/v1/auth/*`) and Swipe (`/api/v1/swipes`) endpoints are protected by `RateLimitMiddleware`.
  - Request bodies are capped (`10mb` global, `5mb` per photo) and compressed client-side via `ImageCompressor`.

### Not Implemented
- All specified features across Phases 0–8 are implemented. In local development, `APNS_DRIVER=stub` and `STORAGE_DRIVER=local` are active by default and switch to live `APNsPushNotificationService` (`APNS_DRIVER=apns`) and `S3CompatibleStorageService` (`STORAGE_DRIVER=s3`) when production credentials are supplied in `.env`.
