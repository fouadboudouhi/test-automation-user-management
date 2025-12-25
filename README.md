# Test Automation – Practice Software Testing (Toolshop)

Dieses Repository enthält UI-Testautomatisierung mit **Robot Framework** + **Robot Framework Browser (Playwright)** gegen eine lokal/CI gestartete **Docker-Compose** Instanz der *Practice Software Testing / Toolshop* Anwendung.

Ziele:
- **Smoke Tests** laufen schnell als **Quality Gate** (Push/PR).
- **Regression Tests** laufen nach dem Gate und **dürfen** Bugs zuverlässig rot machen.
- **Deterministische Testdaten** durch DB **migrate + seed** vor jedem Lauf.
- **Saubere Artefakte** (Robot Report/Log/Output + Screenshots) lokal und in GitHub Actions.

---

## Architektur (ASCII)

```
                 ┌──────────────────────────────────────────────────┐
                 │                 GitHub Actions CI                │
                 │        (ubuntu-latest, Python 3.11, headless)    │
                 └──────────────────────────────────────────────────┘
                                   │
                                   │  docker compose up
                                   ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                             Docker Compose Stack                             │
│                                                                              │
│   ┌───────────────┐     ┌─────────────────────┐     ┌─────────────────────┐  │
│   │  angular-ui   │     │        web          │     │     laravel-api     │  │
│   │  :4200        │<--->│ :8091 (proxy/api)   │<--->│ (php-fpm/app)       │  │
│   └───────────────┘     └─────────────────────┘     └─────────┬───────────┘  │
│                                                               │              │
│                                                               ▼              │
│                                                     ┌───────────────────┐    │
│                                                     │      mariadb      │    │
│                                                     │      :3306        │    │
│                                                     └───────────────────┘    │
└──────────────────────────────────────────────────────────────────────────────┘
                                   │
                                   │ Robot Framework Browser (Playwright)
                                   ▼
                      ┌─────────────────────────────────┐
                      │     Robot UI Tests (ui-tests)   │
                      │  - smoke (tag: smoke)           │
                      │  - regression (tag: regression) │
                      └─────────────────────────────────┘
```

Wichtig: **UI erreichbar ≠ DB ready**. Daher warten wir explizit auf DB-Readiness und führen **migrate:fresh --seed** aus.

---

## Projektstruktur (Kurz)

```
.
├── docker/
│   ├── docker-compose.yml
│   ├── nginx/
│   │   └── default.conf
│   └── .env
├── ui-tests/
│   ├── resources/
│   │   └── keywords/
│   │       └── common.robot
│   ├── smoke/                     # Quality Gate (schnell)
│   │   ├── __init__.robot          # Suite Setup/Teardown + Force Tags: smoke
│   │   ├── home.robot
│   │   ├── login.robot
│   │   ├── navigation.robot
│   │   ├── product.robot
│   │   └── search.robot
│   └── regression/                # Läuft nur wenn Smoke grün ist
│       ├── __init__.robot          # Suite Setup/Teardown + Force Tags: regression
│       ├── cart/
│       │   ├── add_to_cart.robot
│       │   └── open_cart.robot
│       ├── filters/
│       │   └── filter_by_category.robot
│       ├── login/
│       │   └── negative_login.robot
│       ├── navigation/
│       │   └── categories_dropdown.robot
│       ├── products/
│       │   ├── product_details.robot
│       │   └── navigate_back_home.robot
│       ├── search/
│       │   ├── search_results.robot
│       │   └── search_no_results.robot
│       └── sorting/
│           ├── sort_by_price.robot
│           └── sort_by_price_desc.robot
├── Scripts/
│   └── run_all.sh
├── Makefile
└── .github/workflows/ui-tests.yml
```

---

## Voraussetzungen

### Lokal
- Docker Desktop / Docker Engine
- Python 3.11+ (empfohlen) + pip

### Python Dependencies installieren
```bash
python -m pip install --upgrade pip
pip install -r requirements.txt
```

### Playwright / Robot Browser initialisieren
```bash
rfbrowser init
```

---

## Quickstart (empfohlen)

### 1) Einmal “frisch” starten (inkl. DB reset)
```bash
make clean
make up
make seed
```

### 2) Smoke (Quality Gate)
```bash
make smoke
```

### 3) Regression
```bash
make regression
```

### Oder alles in einem Rutsch
```bash
make test-all
```

Artefakte lokal:
- Smoke: `artifacts_local/smoke/`
- Regression: `artifacts_local/regression/`

---

## Lokaler “One-Command” Runner: `run_all.sh`

Der Runner startet den Stack, wartet auf API/DB, seedet deterministisch, führt Smoke als Gate aus und danach Regression.

```bash
chmod +x Scripts/run_all.sh
./Scripts/run_all.sh
```

Option: Stack nach dem Run entfernen (inkl. Volumes/DB):
```bash
CLEANUP=true ./Scripts/run_all.sh
```

---

## Tags: Smoke vs Regression

Wir nutzen Robot-Tags, damit wir unabhängig von Ordnerstrukturen selektiv laufen lassen können.

- Smoke Tests haben Tag: `smoke`
- Regression Tests haben Tag: `regression`

Beispiele:
```bash
robot --include smoke ui-tests
robot --include regression ui-tests
```

---

## Reports & Artefakte

Robot erzeugt pro Run:
- `output.xml` (maschinenlesbar)
- `log.html` (Details, Step-by-step, Keywords, Timing)
- `report.html` (Zusammenfassung)

Zusätzlich erstellen wir Screenshots bei Failures:
- `.../screenshots/*.png`

Lokal liegen die Artefakte unter:
- `artifacts_local/smoke/`
- `artifacts_local/regression/`

In GitHub Actions werden die Artefakte als Artifacts hochgeladen:
- `robot-artifacts-smoke`
- `robot-artifacts-regression`

---

## CI Pipeline (GitHub Actions)

### Trigger
- Läuft bei **push** und **pull_request** auf `main`
- Kein nightly / keine schedules

### Ablauf (Smoke als QGate, danach Regression)
```
push/PR
  │
  ├─ Job: smoke (QGate)
  │    ├─ docker compose up
  │    ├─ wait API
  │    ├─ wait DB
  │    ├─ migrate:fresh --seed
  │    ├─ verify seed (products > 0)
  │    ├─ rfbrowser init
  │    ├─ robot --include smoke   ✅/❌ (Gate)
  │    └─ upload artifacts (always)
  │
  └─ Job: regression (nur wenn smoke grün)
       ├─ docker compose up
       ├─ wait API/DB
       ├─ migrate:fresh --seed
       ├─ rfbrowser init
       ├─ robot --include regression ✅/❌ (Bug => rot)
       └─ upload artifacts (always)
```

Warum seeden wir in beiden Jobs?
- Jobs laufen auf separaten Runnern. Für deterministische Tests wird pro Job ein frischer Zustand aufgebaut.

---

## Troubleshooting

### “Connection refused” beim Seed
Symptom:
- `SQLSTATE[HY000] [2002] Connection refused`

Ursache:
- DB ist noch nicht bereit. Lösung: DB-ready wait (Makefile/Script macht das automatisch).

### “products table doesn’t exist”
Symptom:
- `Table '...products' doesn't exist`

Lösung:
- `php artisan migrate:fresh --seed` muss erfolgreich durchlaufen.
- Verify:
```bash
docker compose --env-file docker/.env -f docker/docker-compose.yml exec -T laravel-api \
  php artisan tinker --execute="echo \\App\\Models\\Product::count();"
```

### Apple Silicon: amd64 Images
Warnung:
- `requested image's platform (linux/amd64) does not match host (linux/arm64)`

Das läuft über Emulation und kann langsamer starten -> Readiness-Waits sind wichtig.

---

## Makefile Targets (Cheatsheet)

```bash
make up           # docker compose up -d
make down         # docker compose down
make clean        # docker compose down -v
make seed         # wait-api + wait-db + migrate:fresh --seed + verify
make smoke        # robot --include smoke
make regression   # robot --include regression
make test-all     # up -> seed -> smoke -> regression
make logs         # tail logs
make ps           # docker compose ps
```

---

## FAQ

### “Warum nicht direkt gegen practicesoftwaretesting.com testen?”
Öffentliche Seiten haben oft Bot-Schutz/Rate-Limits. Für deterministische CI testen wir gegen einen kontrollierten Docker-Stack mit Seed-Daten.

### “Warum ist Regression rot?”
Regression rot bedeutet: **Bug gefunden**. Das soll so sein. In CI wird das als Failure markiert.

---

## Hinweis
Privates Lern-/Demo-Projekt zur Testautomatisierung.
