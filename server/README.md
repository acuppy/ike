# Ike server

A Rails 8 backend for the [Ike](../README.md) menu bar app: stores quadrant
blocks per user in SQLite, signs you in with Google, renders the same Today /
Weekly trends / All activity views as the macOS app, lets you edit any block
in place, and exposes a JSON API for the widget and a future iOS app.

## What's in here

- **Web UI** (Hotwire/Turbo + Tailwind):
  - `/` — Today's blocks, with trending banner, colored timeline, per-quadrant
    totals.
  - `/week` — stacked-bar chart of the last seven days.
  - `/blocks` — all activity, grouped by day, edit any block in place via
    Turbo Frames.
- **JSON API** at `/api/v1/*`, token-authenticated:
  - `GET /api/v1/me` — verify the token, return the user.
  - `GET /api/v1/blocks?from=…&to=…` — list blocks.
  - `POST /api/v1/blocks` — create or **upsert by `external_id`** (idempotent
    so clients can safely retry pushes).
  - `PATCH /api/v1/blocks/:id` — update a block.
  - `DELETE /api/v1/blocks/:id` — delete a block.
- **Auth**: Google sign-in via OmniAuth; a dev-only `developer` strategy lets
  you sign in without OAuth credentials when working locally.

## Setup

Prereqs: Ruby 3.2+, Bundler, SQLite, Node (used by Tailwind).

```sh
cd server
bundle install
bin/rails db:prepare
bin/rails db:seed       # creates a dev user with a week of sample blocks
```

The seed prints an API token you can use for `curl`.

### Google OAuth credentials

1. Visit https://console.cloud.google.com/apis/credentials and create an
   OAuth 2.0 Client ID (Application type: **Web application**).
2. Add **Authorized redirect URI**:
   `http://localhost:3000/auth/google_oauth2/callback`.
3. Copy `.env.example` to `.env` and paste the client id / secret.

In development you can skip steps 1–3 and use the **"Sign in as a test user"**
link on the login page (powered by the OmniAuth `developer` strategy — never
enabled outside development).

## Running

```sh
bin/dev        # Rails + Tailwind watcher (foreman)
# or
bin/rails server
```

Then open http://localhost:3000.

## Using the JSON API

```sh
TOKEN=…  # from `bin/rails db:seed` or `User#api_token` in console

# Confirm the token
curl -H "Authorization: Bearer $TOKEN" http://localhost:3000/api/v1/me

# List blocks
curl -H "Authorization: Bearer $TOKEN" http://localhost:3000/api/v1/blocks

# Idempotent push from the widget — repeating the same external_id updates
# the existing block rather than creating a duplicate.
curl -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{
    "block": {
      "external_id": "2026-05-27T16:00:00Z",
      "starts_at":   "2026-05-27T16:00:00Z",
      "ends_at":     "2026-05-27T16:50:00Z",
      "quadrant":    "q2",
      "note":        "Refactor",
      "auto":        false
    }
  }' \
  http://localhost:3000/api/v1/blocks
```

The widget integration (wiring `BlockLogger` in the Swift app to POST here) is
a separate change — this server is the destination.

## Data model

```
User
  email, name, avatar_url
  provider, uid        # OmniAuth identity
  api_token            # bearer token for the JSON API
  has_many :blocks

Block (belongs_to :user)
  starts_at, ends_at
  quadrant             # "q1" | "q2" | "q3" | "q4" | "break"
  note
  auto                 # was the entry auto-logged?
  external_id          # client-supplied id for idempotent upsert (unique per user)
```

The `Quadrant` value object holds all the labels and colors in one place so
they match `Quadrant.swift` in the macOS app.

## Layout

```
app/
  models/
    user.rb, block.rb              # persistence
    quadrant.rb                    # value object: label + color
    day_log.rb, week_log.rb        # derived dashboard data (pure functions)
    trending_summary.rb            # "Today is trending toward …"
  controllers/
    sessions_controller.rb         # OmniAuth callback + dev login + sign out
    dashboard_controller.rb        # Today
    weeks_controller.rb            # This week
    blocks_controller.rb           # All activity + inline edit (Turbo Frames)
    api/v1/
      base_controller.rb           # token auth
      blocks_controller.rb         # CRUD + idempotent upsert
      sessions_controller.rb       # /me
  views/                           # Hotwire/Turbo + Tailwind
```
