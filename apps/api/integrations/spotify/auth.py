import base64
from dataclasses import dataclass
from urllib.parse import urlencode

import httpx

from core.config.settings import settings

SPOTIFY_ACCOUNTS_BASE_URL = "https://accounts.spotify.com"


@dataclass(frozen=True)
class SpotifyTokenResponse:
    access_token: str
    refresh_token: str
    expires_in: int
    token_type: str
    scope: str


def generate_spotify_authorization_url() -> str:
    query = urlencode(
        {
            "client_id": settings.SPOTIFY_CLIENT_ID,
            "response_type": "code",
            "redirect_uri": settings.SPOTIFY_REDIRECT_URI,
            "scope": "user-read-email user-read-private",
        }
    )
    return f"{SPOTIFY_ACCOUNTS_BASE_URL}/authorize?{query}"


async def exchange_spotify_code_for_token(code: str) -> SpotifyTokenResponse:
    client_credentials = (
        f"{settings.SPOTIFY_CLIENT_ID}:{settings.SPOTIFY_CLIENT_SECRET}".encode()
    )
    encoded_credentials = base64.b64encode(client_credentials).decode()

    async with httpx.AsyncClient(timeout=10.0) as client:
        response = await client.post(
            f"{SPOTIFY_ACCOUNTS_BASE_URL}/api/token",
            data={
                "grant_type": "authorization_code",
                "code": code,
                "redirect_uri": settings.SPOTIFY_REDIRECT_URI,
            },
            headers={
                "Authorization": f"Basic {encoded_credentials}",
                "Content-Type": "application/x-www-form-urlencoded",
            },
        )
        response.raise_for_status()
        payload = response.json()

    refresh_token = payload.get("refresh_token", "")
    return SpotifyTokenResponse(
        access_token=payload["access_token"],
        refresh_token=refresh_token,
        expires_in=payload["expires_in"],
        token_type=payload.get("token_type", "Bearer"),
        scope=payload.get("scope", ""),
    )
