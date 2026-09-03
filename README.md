# Pleasant Interactions

A small Rails app for managing interaction queues. Users can have a Profile
with configurable Questions (text, select, or radio); each profile has a
current Queue of Interactions whose Answers snapshot the question text at
creation time.

- Rails 8.1 / Ruby 3.4, SQLite database
- Bulma CSS (vendored, no build step), vanilla JS only — no JS framework

## Running locally

```sh
bundle install
bin/rails db:setup   # creates, migrates, and seeds
bin/rails server
```

Log in at http://localhost:3000 with `admin` / `password123` (seeds also
create `alice` and `bob`, same password, each with a profile, questions, and
a current queue with example interactions).

## Running with Docker

```sh
docker-compose up --build   # or: docker compose up --build
```

The app is served on http://localhost:3000. The SQLite databases live in a
named volume (`sqlite_data`) so data persists across restarts; the entrypoint
runs `db:prepare` (migrating and seeding on first boot). The credentials
master key is mounted from `config/master.key`. Set `FORCE_SSL=true` when
deploying behind a TLS-terminating proxy.

## Connecting to the Fly.io deployment

Deployment config lives in `fly.toml` (first-time setup steps are in its header
comment). The app runs as a single machine in `syd` with the SQLite databases on
a volume mounted at `/rails/storage`.

Open a Rails console on the running machine:

```sh
fly ssh console --pty --user rails -C "/rails/bin/rails console"
```

Or get a shell, and run whatever from there:

```sh
fly ssh console --user rails      # --pty is implied when no -C is given
cd /rails && bin/rails console
```

`--user rails` matters: `fly ssh console` connects as `root` by default, but the
app runs as uid 1000 (see `USER 1000:1000` in the Dockerfile). A root console
that writes creates root-owned `production.sqlite3-wal`/`-shm` files next to the
database, and Puma then fails with `attempt to write a readonly database` once
the console exits.

Use `fly ssh console` (exec into the running machine), *not* `fly console` — the
latter starts a fresh ephemeral machine with no volume attached, so it would show
an empty database and discard anything written.

Status and logs:

```sh
fly status
fly logs
```

The machine auto-stops when idle (`min_machines_running = 0`), so SSH will fail
to connect while it's stopped. Wake it with `fly machine start <machine-id>`, or
just load the app URL.

## Tests

```sh
bin/rails test
```

## Domain notes

- The queue model is `ProfileQueue` (table `queues`) because Ruby reserves the
  `Queue` constant; associations still read `profile.queues`,
  `interaction.queue`.
- Question options for select/radio types are stored in the `config` JSON
  column as `{"options" => [...]}`.
- Interactions soft-delete: state is one of `pending`, `in_progress`,
  `finished`, `deleted`; only one interaction per queue may be in progress
  at a time.
- Answers keep a `question_text` snapshot so they still render if their
  question is later edited or deleted.
