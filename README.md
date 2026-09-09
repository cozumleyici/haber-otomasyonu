# Automated News Aggregation, AI Rewriting & Mobile HITL Publishing Engine

A production-grade, multi-component system that automates news ingestion from RSS feeds and public sources, transforms raw articles using an LLM into structured, engaging summaries, stores drafts in PostgreSQL for human-in-the-loop review, and delivers them to a Flutter mobile app. Upon approval or editing, the system broadcasts the approved content to target platforms (**Telegram Channel** and **WordPress REST API**).

Includes a dedicated **Web Admin Panel Dashboard** on port `:8080` for dynamically managing news sources, Telegram Bot credentials, and WordPress API settings without restarting containers.

> 🇹🇷 **Ayrıntılı Türkçe Kurulum ve Kullanım Rehberi:** Lütfen adım adım açıklamalar için [KULLANIM_KILAVUZU.md](file:///c:/Users/birol.sanli/Birolscom/otomasyon_uygulama/KULLANIM_KILAVUZU.md) dosyasını inceleyin.

---

## System Architecture

```
                                  +-----------------------+
                                  |    RSS / News Feeds   |
                                  +-----------+-----------+
                                              |
                                              v (Cron: Every 15 min)
+-----------------------------------------------------------------------------------------+
| n8n Workflow A (Ingest & AI Rewrite)                                                    |
|                                                                                         |
| 1. Query active news sources from PostgreSQL (news_sources table)                       |
| 2. Fetch RSS Feeds dynamically                                                          |
| 3. Deduplicate against PostgreSQL (source_url check)                                    |
| 4. Send raw article to OpenAI / Gemini LLM -> JSON: { "title": "...", "content": "..." }|
| 5. INSERT INTO news_drafts (status = 'PENDING')                                         |
+---------------------------------------------+-------------------------------------------+
                                              |
                                              v
+-----------------------------------------------------------------------------------------+
| PostgreSQL 16 Alpine Database                                                           |
| Tables: system_settings, news_sources, news_drafts                                      |
+----------------------+----------------------+-------------------------------------------+
                       |                      ^
                       v                      |
+------------------------------------+        |
| Web Admin Dashboard (:8080)        |        |
|                                    |        |
| - Manage RSS / News Sources        |        |
| - Telegram Bot & Channel Settings  |        |
| - WordPress REST API Settings      |        |
| - Live Connection Test Buttons     |        |
| - OpenAI Prompt & Model Config     |        |
+------------------------------------+        |
                                              |
     GET /webhook/news-pending                | POST /webhook/news-action
     (Fetch pending drafts)                   | (Approve / Reject decision)
                                              |
+---------------------------------------------+-------------------------------------------+
| Flutter Mobile Client (Android & iOS)                                                   |
|                                                                                         |
| - Pending Inbox Screen: Pull-to-refresh list with thumbnail, source badge, timestamp   |
| - Review & Edit Screen: Tabbed comparison (Original vs AI), inline field editors,       |
|   destination checkboxes ([x] Telegram, [x] WordPress), Image preview, CTAs            |
| - Cleartext HTTP support enabled for testing direct VPS IP without SSL restrictions    |
+---------------------------------------------+-------------------------------------------+
                                              |
                                              v
+-----------------------------------------------------------------------------------------+
| n8n Workflow B (Publishing Engine)                                                      |
|                                                                                         |
| - Read dynamic Telegram & WordPress credentials from PostgreSQL (system_settings)       |
| - Action = 'reject'  -> UPDATE status = 'REJECTED'                                      |
| - Action = 'approve' -> UPDATE status = 'APPROVED'                                      |
|                      -> If 'telegram'  -> Telegram Bot API (sendPhoto / sendMessage)    |
|                      -> If 'wordpress' -> WordPress REST API (POST /wp/v2/posts)        |
|                      -> UPDATE status = 'PUBLISHED'                                     |
+-----------------------------------------------------------------------------------------+
```

---

## Directory Structure

```
.
├── KULLANIM_KILAVUZU.md                # Türkçe Adım Adım Kurulum ve Kullanım Kılavuzu
├── README.md                           # Proje Ana Dokümantasyonu
│
├── backend/
│   ├── docker-compose.yml              # PostgreSQL, Admin Panel (:8080), n8n (:5678)
│   ├── .env.example                    # Ortam değişkenleri şablonu
│   ├── init.sql                        # system_settings, news_sources, news_drafts tabloları
│   ├── admin/                          # Web Admin Panel Servisi (Node.js + Tailwind CSS)
│   │   ├── Dockerfile
│   │   ├── package.json
│   │   ├── server.js                   # Settings & Sources REST API & Connection Testers
│   │   └── public/index.html           # Modern Responsive SPA Dashboard
│   ├── workflows/
│   │   ├── workflow_a_ingest_rewrite.json   # Dinamik kaynaklardan RSS çekme & AI özeti
│   │   ├── workflow_b_publish_action.json   # Dinamik ayarlarla Telegram & WordPress yayını
│   │   └── workflow_c_get_pending.json      # Mobilde bekleyen taslakları getiren API
│   └── README.md
│
└── mobile/
    ├── pubspec.yaml                    # Flutter 3.x bağımlılıkları (flutter_bloc, dio, etc.)
    ├── analysis_options.yaml
    ├── android/
    │   └── app/src/main/AndroidManifest.xml # usesCleartextTraffic="true"
    ├── ios/
    │   └── Runner/Info.plist           # NSAllowsArbitraryLoads = true
    └── lib/                            # BLoC mimarili Flutter kaynak kodları
```

---

## Quick Start / Hızlı Başlangıç

### 1. Start Docker Containers
```bash
cd backend
cp .env.example .env
docker compose up -d --build
```
Açılan servisler:
- **Admin Paneli:** `http://<VPS_IP>:8080`
- **n8n Orkestratör:** `http://<VPS_IP>:5678`
- **PostgreSQL:** `localhost:5432`

### 2. Configure via Admin Panel (`:8080`)
Open `http://<VPS_IP>:8080` in your browser:
- Enter your **Telegram Bot Token** and **Channel ID** $\rightarrow$ Click **"Bağlantıyı Test Et"**.
- Enter your **WordPress Site URL** and **Application Password** $\rightarrow$ Click **"Bağlantıyı Test Et"**.
- Add your favorite news websites / RSS links under the **Haber Kaynakları** tab.

### 3. Run Mobile App
```bash
cd mobile
flutter pub get
flutter run
```
Set your VPS IP inside the in-app settings (⚙️) and start reviewing news!
