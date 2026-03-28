# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Layout

Monadic-Flow is a monorepo with the following components:

- `energy/` — Grid Singularity Energy Exchange engine (`gsy-e`), a Python simulation engine for decentralised energy markets. This is a git submodule pointing to the upstream `gridsingularity/gsy-e` repo.
- `client/` — Flutter frontend application (early-stage scaffold).
- `backend/` — Currently empty; reserved for a future backend service.
- `contracts/` — Currently empty; reserved for smart contracts.

## Energy Engine (`energy/`)

**⚠️ Platform Requirement:** Gsy-e only runs on **Linux, macOS, or WSL (Windows Subsystem for Linux)**. It is not compatible with native Windows due to Unix-specific dependencies (e.g., `termios` module). On Windows, use WSL2 or Docker (with proper large-file support) to run simulations.

### Setup

```bash
cd energy
pip install -e .
```

The package depends on `gsy-framework` from GitHub. The `setup.py` pulls the branch specified by `GSY_FRAMEWORK_BRANCH` env var (defaults to `master`). Python 3.11+ is required.

### Running a Simulation

```bash
gsy-e run --setup default_2a
gsy-e run --help          # all options
```

Key flags: `--market-type` (0=none, 1=one-sided, 2=two-sided, 3=coefficient), `--duration`, `--slot-length`, `--tick-length`, `--settings-file`.

### Testing

Tests must run on **Linux/macOS/WSL** (not native Windows). Use Python 3.11.

```bash
cd energy

# Full test suite with tox (sets up Python 3.11 env automatically)
tox -e setup && tox -e unittests

# Run tests directly (after tox setup env is active)
pytest -n auto ./

# Single test file or test
pytest tests/test_simulation.py
pytest tests/test_simulation.py::test_function_name

# With coverage
pytest --cov-report term --cov=src -n 8

# Lint only
tox -e lint            # runs flake8

# Integration tests (requires integration-tests submodule)
tox -e integrationtests
```

**Code style:** Line length limit: **99** characters (both `flake8` and `black`).

### Architecture

The simulation is composed of a tree of **`Area`** objects. Each `Area` is either a market node (containing child areas) or a leaf device (with a `Strategy` attached). The three public aliases are:

- `Area` — generic base (don't use in setup files directly)
- `Market` — a market node (aggregates child areas)
- `Asset` — a leaf device node

**Simulation lifecycle** (`gsy_e_core/simulation/`):
- `Simulation` class drives the main loop — it iterates time slots and dispatches events top-to-bottom (or bottom-to-top depending on `DISPATCH_EVENTS_BOTTOM_TO_TOP` env var).
- `SimulationSetup` loads the setup module and builds the `Area` tree.
- `SimulationResultsManager` exports results (default to `~/gsy-e-simulation/`).

**Market types** (`models/market/`): `one_sided.py`, `two_sided.py`, `balancing.py`, `settlement.py`, `forward.py`, `future.py`.

**Strategies** (`models/strategy/`): device strategies for PV (`pv.py`), loads (`load_hours.py`, `predefined_load.py`), storage (`storage.py`), heat pump (`heat_pump.py`), EV charger (`ev_charger.py`), commercial producer, infinite bus, smart meter, and more. External/API-controlled strategies live in `external_strategies/`.

**External connectivity**: Areas can be connected to external agents via Redis (`redis_connections/`, `gsy_e_core/redis_connections/`). The matching engine singleton (`matching_engine_singleton.py`) handles bid/offer matching.

**Distributed events**: The codebase supports Kafka (see `tools/docker-compose.yml`) for distributed event handling across multiple services. This is optional for single-machine simulations. Environment variable `DISPATCH_EVENTS_BOTTOM_TO_TOP` controls event dispatch order.

**Setup files**: Custom simulation scenarios go in `src/gsy_e/setup/` as Python modules that return an `Area` tree. Pass them via `--setup <module_name>`.

### Running on Windows: WSL2

On Windows, use WSL2 (Windows Subsystem for Linux 2) with Ubuntu:

```bash
# In WSL2 bash:
cd /mnt/c/Projeler/Monadic-Flow/energy
python3 -m venv venv
source venv/bin/activate
pip install -e .
gsy-e run --setup default_2a -t 15s -d 1d --no-export
```

### Docker

Docker build can be slow or unstable on some systems due to large dependency downloads (e.g., NumPy, SymPy compilation). If you encounter errors:

```bash
# Try building with increased timeout:
docker build -t gsy-e . --progress=plain

# Or use the helper script:
./run_gsy_e_on_docker.sh "gsy-e run --setup default_2a -t 15s" ~/output

# Run without building:
docker run --rm -it gsy-e gsy-e run --setup default_2a
```

**Note:** Docker build requires sufficient disk space (>5GB) and stable internet connection.

## Flutter Client (`client/`)

```bash
cd client
flutter pub get
flutter run                        # run on connected device/emulator
flutter test                       # run all tests
flutter test test/widget_test.dart # single test file
flutter build apk                  # Android
flutter build ios                  # iOS
flutter build windows              # Windows
```

SDK constraint: `^3.8.0`. The app is currently a minimal scaffold.
