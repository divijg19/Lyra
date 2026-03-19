# Lyra

# 🎵 Lyra

> *A personal music intelligence layer- built on top of your listening history.*

---

## 🧠 Overview

**Lyra** is a standalone application that sits alongside platforms like Spotify and YouTube Music.

It does **not replace playback**.

Instead, Lyra transforms your fragmented listening history into a **clean, structured, and controllable system**, allowing you to generate playlists based on your actual taste.

---

## ✨ Core Idea

> Your music apps know what you listen to.
> Lyra lets you **use that knowledge intentionally**.

---

## 🚀 What Lyra Does

* 🔌 Connects to your music platforms
* 📥 Ingests your listening history
* 🧹 Cleans and structures your data
* 🎛️ Lets you filter by:

  * language
  * energy
  * recency
* 📜 Generates dynamic playlists
* 🔗 Opens tracks back in the original app

---

## 🚫 What Lyra is NOT

* ❌ Not a music player
* ❌ Not a recommendation engine (yet)
* ❌ Not trying to replace Spotify

---

## 🧰 Tech Stack

### Frontend

* Flutter

### Backend

* Python (FastAPI)
* Go (orchestration, future services)

### Database

* PostgreSQL

### Infra

* Podman (preferred)
* Docker (fallback)

---

## 🔁 User Flow

1. User connects Spotify
2. Lyra fetches listening history
3. Data is normalized + stored
4. Enrichment adds metadata
5. User applies filters
6. Playlist is generated
7. Tracks open in Spotify

---

## ⚙️ API (v0.1)

### Auth

* `GET /auth/login`
* `GET /auth/callback`

### Sync

* `GET /sync/recent`
* `GET /sync/top`

### Playlist

* `POST /playlist/generate`

### Presets

* `POST /presets/save`
* `GET /presets`

---

## ⚠️ Current Limitations (v0.1)

* Spotify-only integration
* Basic language detection
* No advanced intelligence
* No cross-platform deduplication

---

## 🧭 Roadmap

### v0.2: Understanding

* mood classification
* improved tagging

### v0.3: Taste Modeling

* embeddings
* similarity search

### v0.4: Flow Engine

* dynamic sequencing
* context-aware playlists

### v1.0

* full taste identity system
* adaptive playback intelligence

---

## 🧠 Philosophy

> **understanding your relationship with the music you already love.**

---

## 📜 License

MIT (or TBD)
