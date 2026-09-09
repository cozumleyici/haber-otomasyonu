-- PostgreSQL Schema Initialization for News Engine
-- File: init.sql

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. News Sources Table (Haber Kaynakları Yönetimi)
CREATE TABLE IF NOT EXISTS news_sources (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(150) NOT NULL,
    url TEXT UNIQUE NOT NULL,
    source_type VARCHAR(50) DEFAULT 'rss', -- 'rss', 'telegram', 'web'
    is_active BOOLEAN DEFAULT TRUE,
    fetch_interval_minutes INT DEFAULT 15,
    last_fetched_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. System Settings Table (Telegram, WordPress, AI Dinamik Ayarları)
CREATE TABLE IF NOT EXISTS system_settings (
    key VARCHAR(100) PRIMARY KEY,
    value TEXT NOT NULL,
    category VARCHAR(50) DEFAULT 'general', -- 'telegram', 'wordpress', 'ai', 'general'
    description TEXT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. News Drafts Table (Taslaklar ve Yayın Kayıtları)
CREATE TABLE IF NOT EXISTS news_drafts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id UUID REFERENCES news_sources(id) ON DELETE SET NULL,
    source_type VARCHAR(50) NOT NULL,
    source_url TEXT UNIQUE,
    original_title TEXT,
    original_content TEXT,
    ai_title TEXT,
    ai_content TEXT,
    image_url TEXT,
    status VARCHAR(20) DEFAULT 'PENDING', -- 'PENDING', 'APPROVED', 'REJECTED', 'PUBLISHED'
    target_platforms JSONB DEFAULT '["telegram", "wordpress"]'::jsonb,
    publish_metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexing for High-Performance Querying
CREATE INDEX IF NOT EXISTS idx_news_drafts_status ON news_drafts(status);
CREATE INDEX IF NOT EXISTS idx_news_drafts_created_at ON news_drafts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_news_drafts_source_url ON news_drafts(source_url);
CREATE INDEX IF NOT EXISTS idx_news_sources_is_active ON news_sources(is_active);

-- Automatic update of updated_at column
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS trg_news_drafts_updated_at ON news_drafts;
CREATE TRIGGER trg_news_drafts_updated_at
    BEFORE UPDATE ON news_drafts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trg_news_sources_updated_at ON news_sources;
CREATE TRIGGER trg_news_sources_updated_at
    BEFORE UPDATE ON news_sources
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- SEED DATA: Varsayılan Ayarlar & Örnek Haber Kaynakları
INSERT INTO system_settings (key, value, category, description) VALUES
('telegram_bot_token', '', 'telegram', 'Telegram Bot Token (BotFather tarafından verilir)'),
('telegram_chat_id', '', 'telegram', 'Telegram Kanalı veya Grubu (@kanaladi veya -100... ID)'),
('telegram_enabled', 'true', 'telegram', 'Telegram yayını aktif mi?'),
('wordpress_base_url', '', 'wordpress', 'WordPress Site URL adresi (Örn: https://orneksite.com)'),
('wordpress_username', '', 'wordpress', 'WordPress Yönetici veya Editör Kullanıcı Adı'),
('wordpress_app_password', '', 'wordpress', 'WordPress Uygulama Parolası (Application Password)'),
('wordpress_enabled', 'true', 'wordpress', 'WordPress yayını aktif mi?'),
('openai_api_key', '', 'ai', 'OpenAI API Anahtarı (sk-...)'),
('openai_model', 'gpt-4o-mini', 'ai', 'Kullanılacak Yapay Zeka Modeli'),
('ai_system_prompt', 'Sen profesyonel bir haber editörüsün. Sana verilen haber metnini tarafsız, dikkat çekici, Türkçe ve akıcı 2 paragraflık bir özet haline getir. Tıklama oranı yüksek (yüksek CTR) ilgi çekici bir başlık üret. SADECE geçerli JSON formatında şu yapıda cevap ver: {"title": "...", "content": "..."}', 'ai', 'Yapay zeka haber dönüştürme sistem istemi')
ON CONFLICT (key) DO NOTHING;

-- Örnek başlangıç haber kaynakları
INSERT INTO news_sources (name, url, source_type, is_active) VALUES
('BBC Türkçe', 'https://feeds.bbci.co.uk/turkce/rss.xml', 'rss', true),
('Anadolu Ajansı Güncel', 'https://www.aa.com.tr/tr/rss/default?cat=guncel', 'rss', true)
ON CONFLICT (url) DO NOTHING;
