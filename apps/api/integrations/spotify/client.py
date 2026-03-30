from typing import AsyncGenerator, List

import httpx


async def fetch_saved_tracks(access_token: str) -> AsyncGenerator[List[dict], None]:
    """Yield pages of saved tracks from Spotify for the current user.

    Yields lists of raw item dicts as returned by Spotify's /me/tracks endpoint.
    """
    headers = {"Authorization": f"Bearer {access_token}"}
    url = "https://api.spotify.com/v1/me/tracks"
    params = {"limit": 50}

    async with httpx.AsyncClient(headers=headers, timeout=30.0) as client:
        while url is not None:
            resp = await client.get(url, params=params)
            resp.raise_for_status()
            data = resp.json()
            items = data.get("items", [])
            if items:
                yield items

            # Spotify provides a full next URL or null
            url = data.get("next")
            # clear params after first request since `next` is full url
            params = None
