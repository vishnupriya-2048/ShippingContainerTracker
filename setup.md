
# setup.md — Environment setup for the Shipment Tracker assignment

Context file. Give this together with `README.md` (the assignment) and `TASKS.md` (the feature roadmap) to Claude.
Goal of this file: get an **empty, working Rails 8 + Tailwind + Postgres + Kafka (Karafka) dev environment** and nothing more. No models, no screens — those are built feature by feature in `TASKS.md`.

> **Working style requested by the user:** go step by step, one feature branch at a time. Explain each concept briefly (the user is new to Ruby on Rails, Kafka and Docker). Do not generate multiple features at once. Wait for the user to confirm each step.

---

## 0. Machine facts (Windows 11)
- Shell: PowerShell. Editor: VS Code. Git is installed.
- Ruby is **not** installed on Windows. Everything Ruby runs **inside Docker containers**. This avoids Windows build problems with the native `rdkafka` gem (used by Karafka).
- Docker Desktop must be **running** (whale icon green) before any `docker` command works.
- Google Maps key is in `.env` as `MAPS_JS_API_KEY=...` (no space after `=`). `.env` must stay gitignored.

## 1. Versions
| Tool | Version |
|---|---|
| Ruby | 4.0.6 (fall back to 3.4.x if a gem fails to build) |
| Rails | 8.1.x |
| Database | PostgreSQL 16 |
| CSS | TailwindCSS 4 via `tailwindcss-rails` (no Node needed) |
| JS | Stimulus + Importmap (come with Rails 8, no Node needed) |
| Kafka | `apache/kafka` image (KRaft mode, no Zookeeper) |
| Kafka client | `karafka` gem |

## 2. Concepts in one line each (for the user)
- **Docker image**: a packaged mini-computer with Ruby installed. **Container**: a running copy of it.
- **docker-compose**: one file that starts several containers together (web app, database, Kafka).
- **Rails**: Ruby web framework. Model = DB table + logic. Controller = handles a URL. View = HTML page.
- **Stimulus**: tiny JS framework; a "controller" JS class attaches behaviour to HTML via `data-controller`.
- **Kafka**: a message log. A *producer* writes messages to a *topic*; a *consumer* reads them. Here: GPS devices (simulator) -> topic `shipment_locations` -> Karafka consumer -> database.
- **Karafka**: the Ruby framework that runs Kafka consumers and producers.

## 3. Create the project folder
1. Create an empty GitHub repo, clone it, open the folder in VS Code and PowerShell.
2. Put `README.md` (assignment) aside, e.g. rename it `ASSIGNMENT.md`, because `rails new` generates its own `README.md`. Also keep `TASKS.md` and `setup.md` there.
3. Pull the images once:
```powershell
docker pull ruby:4.0.6
docker pull postgres:16
docker pull apache/kafka:latest
```

## 4. Generate the Rails app (inside a throwaway container, from the repo folder)
```powershell
docker run --rm -v "${PWD}:/app" -w /app ruby:4.0.6 bash -c "apt-get update -qq && apt-get install -y -qq libpq-dev libyaml-dev >/dev/null && gem install rails --no-document && rails new . --name shipment_tracker -d postgresql --css tailwind --skip-bundle --force"
```
`--skip-bundle` is deliberate; gems are installed in step 6 inside the dev image.
If the repo already has a README.md, `--force` overwrites it — rename first (step 3).

## 5. Create `Dockerfile.dev`
```dockerfile
FROM ruby:4.0.6
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    libpq-dev libyaml-dev libsasl2-dev libzstd-dev postgresql-client \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
ENV BUNDLE_PATH=/bundle
```

## 6. Create `docker-compose.yml`
```yaml
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: postgres
    volumes:
      - pgdata:/var/lib/postgresql/data
    ports: ["5432:5432"]

  kafka:
    image: apache/kafka:latest
    ports: ["9092:9092"]
    environment:
      KAFKA_NODE_ID: 1
      KAFKA_PROCESS_ROLES: broker,controller
      KAFKA_LISTENERS: INTERNAL://:29092,EXTERNAL://:9092,CONTROLLER://:9093
      KAFKA_ADVERTISED_LISTENERS: INTERNAL://kafka:29092,EXTERNAL://localhost:9092
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: INTERNAL:PLAINTEXT,EXTERNAL:PLAINTEXT,CONTROLLER:PLAINTEXT
      KAFKA_INTER_BROKER_LISTENER_NAME: INTERNAL
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka:9093
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: "true"

  web: &app
    build: { context: ., dockerfile: Dockerfile.dev }
    command: bash -c "rm -f tmp/pids/server.pid && bin/rails db:prepare && bin/dev"
    volumes:
      - .:/app
      - bundle:/bundle
    ports: ["3000:3000"]
    env_file: .env
    environment:
      DB_HOST: db
      DB_USER: postgres
      DB_PASSWORD: postgres
      KAFKA_BROKERS: kafka:29092
    depends_on: [db, kafka]

  karafka:
    <<: *app
    command: bundle exec karafka server
    ports: []

volumes:
  pgdata:
  bundle:
```
Note: `kafka` has two listeners — containers talk to `kafka:29092`, the host machine to `localhost:9092`.

## 7. Wire the app to the containers
1. `config/database.yml` — in the `default:` block add:
```yaml
  host: <%= ENV.fetch("DB_HOST", "localhost") %>
  username: <%= ENV["DB_USER"] %>
  password: <%= ENV["DB_PASSWORD"] %>
```
2. `Gemfile` — add `gem "karafka"` (below `tailwindcss-rails`).
3. Create `.env` (gitignored by Rails by default) containing `MAPS_JS_API_KEY=your_key` (no spaces).

## 8. Install everything
```powershell
docker compose build web
docker compose run --rm --no-deps web bundle install
docker compose run --rm --no-deps web bin/rails tailwindcss:install
docker compose run --rm --no-deps web bundle exec karafka install
```

## 9. Fix three known gotchas
1. **Bind address.** `Procfile.dev` must be exactly:
```
web: bin/rails server -b 0.0.0.0
css: bin/rails tailwindcss:watch[always]
```
(`0.0.0.0` so the browser can reach the container; `[always]` so the Tailwind watcher doesn't quit when no terminal is attached.)
2. **Kafka address.** In `karafka.rb` change the broker line to:
```ruby
config.kafka = { 'bootstrap.servers': ENV.fetch('KAFKA_BROKERS', '127.0.0.1:9092') }
```
3. `bundle exec karafka install` creates an `example` topic/consumer. Delete the example consumer + route when building the real one (see TASKS.md).

## 10. Start and verify
```powershell
docker compose up -d db kafka web
docker compose logs web --tail 20     # expect: Listening on http://0.0.0.0:3000
```
Open http://localhost:3000 — the Rails welcome page means the environment works.
Verify Kafka reachability: `docker compose run --rm --no-deps web bundle exec karafka topics create example` should say "Created topic".

## 11. Daily commands (PowerShell, repo root)
```powershell
docker compose up -d                                  # start everything
docker compose down                                   # stop everything
docker compose logs -f web                            # follow Rails logs
docker compose run --rm web bin/rails console         # Rails console
docker compose run --rm web bin/rails db:migrate      # run migrations
docker compose run --rm web bin/rails generate ...    # generators
docker compose run --rm web bundle add <gem>          # add a gem
docker compose restart web                            # after Gemfile/.env changes
```

## 12. Google Maps key checklist
- Maps JavaScript API enabled in Google Cloud, billing enabled on the project.
- If the key has HTTP referrer restrictions, allow `http://localhost:3000/*`.
- Read it in Rails as `ENV["MAPS_JS_API_KEY"]`. Never commit `.env`.
- Can only be verified once a page loads the map (TASKS.md step 3).

## 13. VS Code (optional)
Ruby is not installed locally, so Ruby LSP is optional. Useful: **Tailwind CSS IntelliSense** (`bradlc.vscode-tailwindcss`), **Docker** (`ms-azuretools.vscode-containers`).

## 14. Troubleshooting
| Symptom | Fix |
|---|---|
| `error during connect ... dockerDesktopLinuxEngine` | Docker Desktop isn't running; start it. If still failing, restart the PC / `wsl --update`. |
| Browser can't reach localhost:3000 but container is up | `Procfile.dev` is missing `-b 0.0.0.0`. |
| Tailwind classes not applying | Watcher died; check `docker compose logs web`; `Procfile.dev` needs `[always]`. |
| `rdkafka` connection refused to `127.0.0.1:9092` inside a container | `karafka.rb` must use `KAFKA_BROKERS` (`kafka:29092`). |
| Bash `cannot overwrite existing file` | Shell `noclobber`; use `>|` or write the file with the editor. |
| Gem won't build on Ruby 4 | Change to `ruby:3.4` in `Dockerfile.dev` and `.ruby-version`. |

## 15. Definition of done for setup
- [ ] `http://localhost:3000` shows the Rails page
- [ ] Tailwind builds (`app/assets/builds/tailwind.css` exists)
- [ ] `karafka topics create example` succeeds
- [ ] `.env` is gitignored; first commit pushed to GitHub on `main`
- [ ] Then stop. Feature work starts with TASKS.md step 1.
