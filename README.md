# Stallion Match

A full-stack Swift matching application for horses and their owners/handlers. Horse owners create profiles for their horses, discover nearby horses by discipline, breed, age, sex, and connection goals, match on mutual right-swipes, and chat in real time.

---

## Monorepo Structure

```text
/
├── SharedModels/      # Local Swift Package containing Sendable, Codable DTOs shared by Server & iOSApp
├── Server/            # Vapor 4 backend (Fluent + PostgreSQL, JWT auth, WebSockets, StorageService, APNs)
├── iOSApp/            # SwiftUI iOS client (iOS 17+, @Observable MVVM, NavigationStack, Keychain, APIClient actor)
├── .env.example       # Template for server environment variables
└── README.md          # Architecture, setup, and API reference
```

---

## Environment & Toolchain

Verified on this machine:
- **macOS**: 27.0.1 (Build `26A434`, Apple Silicon `arm64`)
- **Swift Toolchain**: Apple Swift version 6.3.3 (`swiftlang-6.3.3.1.3 clang-2100.1.1.101`)
- **Xcode**: Xcode 26.6 (`Build version 17F113`, bundled `iPhoneOS 26.5` & `MacOSX 26.5` SDKs)
- **Container Runtime**: Docker (Rancher Desktop) available at `/Users/tupt/.rd/bin/docker`

---

## Quick Start

### 1. Build & Test `SharedModels`
```bash
cd SharedModels
swift build
swift test
```

### 2. Configure Environment
```bash
cp .env.example Server/.env
```

---

## REST & WebSocket API Reference (`/api/v1`)

All endpoints accept and return JSON with `ISO-8601` dates.
Errors follow a uniform structure:
```json
{
  "code": "VALIDATION_FAILED",
  "message": "Human-readable description of the error."
}
```

### Authentication (`/api/v1/auth`)
| Method | Endpoint | Auth | Description |
| :--- | :--- | :--- | :--- |
| `POST` | `/api/v1/auth/signup` | Public (Rate-limited) | Register with email & password (Bcrypt), logs email verification link in dev |
| `POST` | `/api/v1/auth/login` | Public (Rate-limited) | Authenticate with email & password; returns 15-min access JWT + 30-day refresh token |
| `POST` | `/api/v1/auth/apple` | Public (Rate-limited) | Authenticate with Sign in with Apple identity token |
| `POST` | `/api/v1/auth/refresh` | Public (Rate-limited) | Rotate refresh token (stored hashed) and issue a new access/refresh token pair |
| `POST` | `/api/v1/auth/logout` | Bearer JWT | Revoke refresh token |
| `POST` | `/api/v1/auth/verify-email` | Public | Verify email address using verification token |

### User & Settings (`/api/v1/users`)
| Method | Endpoint | Auth | Description |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/v1/users/me` | Bearer JWT | Retrieve current user profile & preferences |
| `PATCH` | `/api/v1/users/me` | Bearer JWT | Update display name, notification toggles, or accepted terms version |
| `POST` | `/api/v1/users/me/devices` | Bearer JWT | Register APNs device token |
| `DELETE` | `/api/v1/users/me` | Bearer JWT | Permanently delete account and all associated data |

### Horse Profiles & Photos (`/api/v1/horses`)
| Method | Endpoint | Auth | Description |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/v1/horses/mine` | Bearer JWT | List all horse profiles owned by the authenticated user |
| `POST` | `/api/v1/horses` | Bearer JWT | Create a horse profile (coarse location rounding & bio safety filter enforced) |
| `GET` | `/api/v1/horses/:horseID` | Bearer JWT | Get details of a specific horse profile |
| `PATCH` | `/api/v1/horses/:horseID` | Bearer JWT | Update a horse profile owned by the user |
| `DELETE` | `/api/v1/horses/:horseID` | Bearer JWT | Delete a horse profile owned by the user |
| `POST` | `/api/v1/horses/:horseID/photos` | Bearer JWT | Upload a photo (`multipart/form-data` or binary) via `StorageService` (max 6 photos) |
| `PUT` | `/api/v1/horses/:horseID/photos/reorder` | Bearer JWT | Reorder photos on a horse profile |
| `DELETE` | `/api/v1/horses/:horseID/photos/:photoID` | Bearer JWT | Delete a photo from a horse profile |

### Discovery, Swipes & Matches (`/api/v1/discovery`, `/api/v1/swipes`, `/api/v1/matches`)
| Method | Endpoint | Auth | Description |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/v1/discovery` | Bearer JWT | Cursor-paginated discovery feed filtered by distance, breed, sex, age range, discipline, looking-for |
| `POST` | `/api/v1/swipes` | Bearer JWT (Rate-limited) | Record an idempotent, atomic `like` or `pass`; creates a `Match` + `Conversation` on mutual `like` |
| `GET` | `/api/v1/matches` | Bearer JWT | List matches for the authenticated user's horses |

### Chat & Real-Time WebSocket (`/api/v1/conversations`, `/api/v1/ws`)
| Method | Endpoint | Auth | Description |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/v1/conversations` | Bearer JWT | List conversations with last message and unread counts |
| `GET` | `/api/v1/conversations/:conversationID/messages` | Bearer JWT | Cursor-paginated message history |
| `POST` | `/api/v1/conversations/:conversationID/messages` | Bearer JWT | Send a message over REST fallback |
| `POST` | `/api/v1/conversations/:conversationID/read` | Bearer JWT | Mark conversation messages as read and emit read receipt |
| `WS` | `/api/v1/ws` | Bearer JWT | Real-time WebSocket (`WebSocketMessage` Codable enum in `SharedModels`) |

### Safety & Moderation (`/api/v1/blocks`, `/api/v1/reports`)
| Method | Endpoint | Auth | Description |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/v1/blocks` | Bearer JWT | List blocked users |
| `POST` | `/api/v1/blocks` | Bearer JWT | Block a user (hides their horses from discovery and disables chat) |
| `DELETE` | `/api/v1/blocks/:blockedUserID` | Bearer JWT | Unblock a user |
| `POST` | `/api/v1/reports` | Bearer JWT | Report a user, horse profile, or message into the server moderation queue |

---

## Animal Welfare & No In-App Payments Policy
Stallion Match does not facilitate payments, deposits, or commercial animal sales in the app. All breeding inquiries and equine introductions must comply with local, state, and federal animal-welfare laws and veterinary health regulations.

---

## Phase Progress
- [x] **Phase 0**: Environment check, repo scaffold, `SharedModels` package, `README.md` skeleton
- [ ] **Phase 1**: Vapor server, PostgreSQL connection, Fluent models & reversible migrations, JWT + Apple auth
- [ ] **Phase 2**: Horse profiles + photo upload + `StorageService` (local disk & S3-compatible)
- [ ] **Phase 3**: Discovery query with filters & distance, atomic swipes, matches, blocks, reports
- [ ] **Phase 4**: Chat (REST history, WebSocket `/api/v1/ws`, read receipts, typing indicator, unread counts)
- [ ] **Phase 5**: iOS app foundation (`APIClient` actor, Keychain, auth screens, `NavigationStack`)
- [ ] **Phase 6**: iOS features (profile create/edit, Discover card stack, matches, chat, safety/reporting, settings)
- [ ] **Phase 7**: APNs push notifications, end-to-end account deletion, Terms & Privacy screens, App Store checklist
- [ ] **Phase 8**: Final security & quality audit

### Not Implemented (Deferred to Subsequent Phases)
- Phases 1–8 server and iOS implementations (scheduled in order per phase plan).
