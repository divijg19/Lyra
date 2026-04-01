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


async def fetch_audio_features(access_token: str, track_ids: List[str]) -> List[dict]:
    """Fetch audio features for up to 100 track IDs per request.

    Returns only non-null feature objects. If Spotify is temporarily rate-limited
    or a request fails, this function returns features collected so far.
    """
    if not track_ids:
        return []

    headers = {"Authorization": f"Bearer {access_token}"}
    url = "https://api.spotify.com/v1/audio-features"
    features: List[dict] = []

    async with httpx.AsyncClient(headers=headers, timeout=30.0) as client:
        for idx in range(0, len(track_ids), 100):
            batch = track_ids[idx : idx + 100]
            resp = await client.get(url, params={"ids": ",".join(batch)})

            # 429 is common when Spotify throttles; fail gracefully.
            if resp.status_code == 429:
                break

            try:
                resp.raise_for_status()
            except httpx.HTTPError:
                continue

            data = resp.json()
            batch_features = data.get("audio_features") or []
            for item in batch_features:
                if item:
                    features.append(item)

    return features
