## 🧩 v0.1 Feature Set

### 🔐 Authentication

* Spotify OAuth integration

---

### 📡 Data Ingestion

* Recently played tracks
* Top tracks

---

### 🧠 Enrichment (Lightweight)

* Energy (via Spotify audio features)
* Language (basic detection)

---

### 🎛️ Filter Engine (Core)

* Language filter
* Energy range
* Recency toggle

---

### 📜 Playlist Generation

* Filter → sort → return
* Sort by:

  * recency
  * frequency

---

### 🔗 Deep Linking

* Open tracks directly in Spotify

---

### 💾 Presets

* Save filter configurations
* Reuse playlists instantly

---

## 🏗️ Architecture

### 🧱 Approach

**Modular Monorepo**

* Fast iteration
* Clean boundaries
* Future-ready for service extraction

---

### 📁 Structure

```bash
lyra/
├── apps/
│   ├── mobile/        # Flutter app
│   └── api/           # FastAPI backend
│
├── internal/
│   ├── db/
│   ├── models/
│   └── utils/
│
├── services/          # future (not deployed separately yet)
│   ├── ingest/
│   ├── core/
│   └── flow/
│
├── infra/
│   ├── podman-compose.yml
│   └── Dockerfile
│
└── README.md
```

## 🗄️ Database Schema (Simplified)

### tracks

* id
* spotify_id
* title
* artist
* energy
* language

---

### plays

* id
* track_id
* played_at

---

### users

* id
* spotify_id

---

### presets

* id
* user_id
* filters_json

---