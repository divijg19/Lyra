from typing import Any, AsyncGenerator, List

import httpx


async def fetch_saved_tracks_page(
    access_token: str,
    url: str | None = None,
) -> dict[str, Any]:
    headers = {"Authorization": f"Bearer {access_token}"}
    request_url = url or "https://api.spotify.com/v1/me/tracks"
    params = None if url else {"limit": 50}

    async with httpx.AsyncClient(headers=headers, timeout=30.0) as client:
        resp = await client.get(request_url, params=params)
        resp.raise_for_status()
        return resp.json()


async def fetch_saved_tracks(access_token: str) -> AsyncGenerator[List[dict], None]:
    """Yield pages of saved tracks from Spotify for the current user.

    Yields lists of raw item dicts as returned by Spotify's /me/tracks endpoint.
    """
    url: str | None = None
    while True:
        data = await fetch_saved_tracks_page(access_token, url)
        items = data.get("items", [])
        if items:
            yield items

        url = data.get("next")
        if url is None:
            break


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
