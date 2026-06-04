# Deploying the Ike server to Heroku

App: **ike-timer-prod**. The Rails app lives in `server/` of a monorepo, runs on
a single PostgreSQL database, and processes background jobs (magic-link /
confirmation emails) inside the web dyno via Solid Queue.

Run everything from the **repo root** unless noted. The Heroku CLI must be
installed and logged in (`heroku login`).

## 1. Create the app + database

```sh
heroku create ike-timer-prod
heroku addons:create heroku-postgresql:essential-0 --app ike-timer-prod
```

`essential-0` is the cheapest paid Postgres tier (the old free `mini`/`hobby`
tiers are retired). The add-on sets `DATABASE_URL` automatically.

## 2. Config vars

```sh
heroku config:set --app ike-timer-prod \
  RAILS_MASTER_KEY="$(cat server/config/master.key)" \
  APP_HOST="ike-timer-prod.herokuapp.com" \
  SOLID_QUEUE_IN_PUMA="true" \
  MAIL_FROM="Ike <no-reply@iketimer.com>" \
  SMTP_ADDRESS="<your provider smtp host>" \
  SMTP_PORT="587" \
  SMTP_USERNAME="<smtp username>" \
  SMTP_PASSWORD="<smtp password>" \
  SMTP_AUTHENTICATION="plain"
```

- `RAILS_MASTER_KEY` decrypts credentials and provides `secret_key_base` — no
  separate `SECRET_KEY_BASE` needed. **Never commit `config/master.key`.**
- `APP_HOST` drives both host authorization and the host in magic-link URLs.
  Set it to the custom domain once that's live (see §6).
- `SOLID_QUEUE_IN_PUMA=true` runs the job worker inside the web dyno — one dyno,
  no separate worker process.
- `SMTP_*` are read by `config/environments/production.rb`. Any provider works
  (Postmark, Resend, SendGrid, Mailgun). Example for Postmark:
  `SMTP_ADDRESS=smtp.postmarkapp.com`, username/password = your server API token.

## 3. Deploy the `server/` subdirectory (monorepo)

Heroku's Ruby buildpack expects the Gemfile at the root of what's pushed, so
push only the `server/` subtree:

```sh
git subtree push --prefix server heroku main
```

If a later push is rejected as non-fast-forward, force it:

```sh
git push heroku "$(git subtree split --prefix server main)":refs/heads/main --force
```

The **release phase** (`Procfile`) runs `rails db:prepare` on every deploy: on
the first deploy it loads `db/schema.rb` (creating the app tables *and* the
Solid Queue/Cache/Cable tables); afterwards it runs any new migrations.

## 4. Verify

```sh
heroku open --app ike-timer-prod
heroku logs --tail --app ike-timer-prod
```

Walk the signup → confirmation-email → confirm flow. If the email never
arrives, check `heroku logs` for SMTP errors and re-check the `SMTP_*` vars.

## 5. Point the macOS widget at production

In the app's Preferences → Server, set the Server URL to
`https://ike-timer-prod.herokuapp.com`, then use **Connect** to sign in and
issue the API token.

## 6. Custom domain (when iketimer.com is ready)

```sh
heroku domains:add iketimer.com --app ike-timer-prod
heroku config:set APP_HOST="iketimer.com" --app ike-timer-prod
```

Then add the DNS target Heroku prints (an ALIAS/ANAME or CNAME) at your
registrar. `config.force_ssl` is on, and Heroku provisions the TLS cert
automatically (Automated Certificate Management).

## Review apps

`app.json` (in `server/`) lets a Heroku **pipeline** spin up a disposable review
app per pull request. Each gets its own `heroku-postgresql:essential-0` database
and a `papertrail:choklad` log drain, runs the same release-phase
`rails db:prepare`, and sets `RAILS_LOG_LEVEL=debug`.

Setup once:

1. Create a pipeline and add `ike-timer-prod` as the production stage:
   `heroku pipelines:create ike-timer --app ike-timer-prod`
2. Connect the pipeline to the GitHub repo and enable Review Apps in the
   Heroku Dashboard (Pipeline → Settings → Enable Review Apps), pointing it at
   `server/app.json`.
3. `RAILS_MASTER_KEY` is inherited from the parent app; review apps need no
   extra config. They have no real `SMTP_*`, so magic-link emails won't send on
   a review app unless you set those vars on it — fine for UI review.

Review apps derive their host from `HEROKU_APP_NAME` automatically, so
magic-link URLs and host authorization work without setting `APP_HOST`.

The logging add-on (`papertrail:choklad`) is also attached to production by
`app.json`. View logs in the Papertrail dashboard or `heroku addons:open
papertrail --app ike-timer-prod`. Swap it for another drain (e.g. Better Stack)
by editing the `addons` lists if you prefer.

## Notes

- **Ruby 3.2.2** is pinned in the `Gemfile` and `.ruby-version`.
- No Node buildpack is needed — Tailwind builds via `tailwindcss-rails`'
  standalone binary during `assets:precompile`; JS is import-maps.
- Active Storage is unused server-side, so no S3 bucket is required.
- SQLite remains the local dev/test database; only production uses Postgres.
