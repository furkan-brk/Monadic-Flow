from pathlib import Path

from pydantic_settings import BaseSettings

# Project root = backend/app/../../.. = Monadic-Flow/
# Both Docker (WORKDIR /app) and local-dev paths resolve correctly via __file__.
_ROOT_ENV = Path(__file__).parent.parent.parent / ".env"


class Settings(BaseSettings):
    contract_address: str = "0x0000000000000000000000000000000000000000"
    rpc_url: str = "https://testnet-rpc.monad.xyz"
    internal_token: str = "parallelpulse-internal-secret"
    host: str = "0.0.0.0"
    port: int = 8000
    # Sprint 2: BESS Ethereum addresses for grid topology bus-ID resolution.
    # BESS_B is at Bus 12 (main trunk); BESS_A is at Bus 22 (Lateral A1 end).
    bess_b_address: str = "0x0000000000000000000000000000000000000001"
    bess_a_address: str = "0x0000000000000000000000000000000000000002"

    class Config:
        # Single source of truth: project-root .env
        # Falls back to shell environment variables when file is absent (Docker).
        env_file = str(_ROOT_ENV)


settings = Settings()
