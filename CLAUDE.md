# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Layout

Monadic-Flow is a monorepo with the following components:

- `energy/` — Grid Singularity Energy Exchange engine (`gsy-e`), a Python simulation engine for decentralised energy markets. This is a git submodule pointing to the upstream `gridsingularity/gsy-e` repo.
- `client/` — Flutter frontend application (early-stage scaffold).
- `backend/` — Currently empty; reserved for a future backend service.
- `contracts/` — Currently empty; reserved for smart contracts.

## Energy Engine (`energy/`)

### Setup

```bash
cd energy
pip install -e .
```

The package depends on `gsy-framework` from GitHub. The `setup.py` pulls the branch specified by `GSY_FRAMEWORK_BRANCH` env var (defaults to `master`).

### Running a Simulation

```bash
gsy-e run --setup default_2a
gsy-e run --help          # all options
```

Key flags: `--market-type` (0=none, 1=one-sided, 2=two-sided, 3=coefficient), `--duration`, `--slot-length`, `--tick-length`, `--settings-file`.

### Testing

```bash
cd energy

# Full unit test suite
tox -e setup && tox -e unittests

# Run tests directly (after setup env is active)
pytest -n auto ./

# Single test file or test
pytest tests/test_simulation.py
pytest tests/test_simulation.py::test_function_name

# With coverage
pytest --cov-report term --cov=src -n 8

# Lint only
tox -e lint            # runs flake8
```

Line length limit: **99** characters (both `flake8` and `black`). Python version: **3.11**.

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

**Setup files**: Custom simulation scenarios go in `src/gsy_e/setup/` as Python modules that return an `Area` tree. Pass them via `--setup <module_name>`.

### Docker

```bash
docker build -t gsy-e .
docker run --rm -it gsy-e
# or use the helper script:
./run_gsy_e_on_docker.sh "gsy-e run --setup default_2a -t 15s" ~/output
```

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
