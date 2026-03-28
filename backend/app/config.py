from pydantic_settings import BaseSettings


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
        env_file = ".env"


settings = Settings()
