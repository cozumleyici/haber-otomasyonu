# News Engine Backend & Orchestration

This directory contains the production Dockerized infrastructure and n8n workflows for the **Automated News Aggregation, AI Rewriting, and Multi-Platform Publishing Engine**.

---

## Architecture Overview

- **PostgreSQL 16 Alpine**: Persistent storage for raw news, AI drafts, publication status, and platform metadata. Initialized automatically with `init.sql`.
- **n8n**: Primary workflow orchestrator that runs the cron jobs, LLM API calls, webhook handlers, and publication dispatches.

---

## 1. Quick Start / Deployment (VPS / Ubuntu / Local)

### Prerequisites
- Docker (version 24+) & Docker Compose (`docker compose`)
- Ports `5432` (PostgreSQL) and `5678` (n8n) accessible.

### Step 1: Clone & Configure Environment
```bash
cp .env.example .env
```
Edit `.env` and configure:
- `POSTGRES_PASSWORD`: Secure database password.
- `WEBHOOK_URL`: Your VPS IP or domain, e.g., `http://<YOUR_VPS_IP>:5678/`.
- `N8N_ENCRYPTION_KEY`: A 32+ character random hex string (generate with `openssl rand -hex 32`).
- `OPENAI_API_KEY`: Your OpenAI or Gemini API key.
- `TELEGRAM_BOT_TOKEN` & `TELEGRAM_CHAT_ID`: Telegram bot credentials.
- `WORDPRESS_BASE_URL`, `WORDPRESS_USERNAME`, `WORDPRESS_APP_PASSWORD`: WordPress credentials.

### Step 2: Start Containers
```bash
docker compose up -d
```

Verify that both containers are running and healthy:
```bash
docker compose ps
```

---

## 2. Setting Up Credentials in n8n

Open `http://<YOUR_VPS_IP>:5678` in your browser and complete the initial owner account creation.

1. **PostgreSQL Credential (`Postgres News DB`)**:
   - Host: `postgres` (internal Docker hostname)
   - Database: `news_engine` (or from `.env`)
   - User: `news_user`
   - Password: `<your_postgres_password>`
   - Port: `5432`
   - SSL: `disable`

2. **OpenAI Credential (`OpenAI Auth Header`)**:
   - Header Name: `Authorization`
   - Header Value: `Bearer <your_openai_api_key>`

3. **WordPress Credential (`WordPress App Password`)**:
   - Type: HTTP Basic Auth
   - User: `<your_wp_username>`
   - Password: `<your_wp_application_password>`

---

## 3. Importing Workflows

Navigate to **Workflows -> Add Workflow -> Import from File** and import each JSON file from `workflows/`:

1. **`workflow_a_ingest_rewrite.json`**:
   - Ingests RSS feeds every 15 minutes.
   - Deduplicates URLs against PostgreSQL.
   - Rewrites the article using OpenAI / LLM into a neutral 2-paragraph summary + high-CTR title.
   - Saves record into `news_drafts` with `status = 'PENDING'`.

2. **`workflow_b_publish_action.json`**:
   - Exposes `POST /webhook/news-action`.
   - Handles `approve` and `reject` actions from the mobile app.
   - Dispatches to Telegram Bot API (`sendPhoto` / `sendMessage`) and WordPress REST API (`/wp/v2/posts`).
   - Updates status to `PUBLISHED` or `REJECTED`.

3. **`workflow_c_get_pending.json`**:
   - Exposes `GET /webhook/news-pending`.
   - Serves the list of all pending news drafts to the Flutter mobile app.

> **Note**: After importing, activate each workflow using the toggle in the top right corner of the n8n canvas.
