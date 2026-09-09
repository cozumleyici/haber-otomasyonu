const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const axios = require('axios');
const path = require('path');
require('dotenv').config();

const app = express();
const PORT = process.env.ADMIN_PORT || 8080;

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// PostgreSQL Connection Pool
const pool = new Pool({
  host: process.env.DB_HOST || 'postgres',
  port: parseInt(process.env.DB_PORT || '5432'),
  user: process.env.DB_USER || 'news_user',
  password: process.env.DB_PASSWORD || 'news_secret_pass',
  database: process.env.DB_NAME || 'news_engine',
  max: 10,
  idleTimeoutMillis: 30000,
});

pool.on('error', (err) => {
  console.error('[DB Error] Unexpected error on idle client:', err);
});

// Helper: Query DB
async function query(text, params) {
  return await pool.query(text, params);
}

// -------------------------------------------------------------
// 1. STATS API
// -------------------------------------------------------------
app.get('/api/stats', async (req, res) => {
  try {
    const sourcesCount = await query('SELECT COUNT(*) FROM news_sources WHERE is_active = true');
    const statusCounts = await query(`
      SELECT status, COUNT(*) as count 
      FROM news_drafts 
      GROUP BY status
    `);

    const stats = {
      activeSources: parseInt(sourcesCount.rows[0].count),
      pending: 0,
      approved: 0,
      published: 0,
      rejected: 0,
    };

    statusCounts.rows.forEach(row => {
      const key = row.status.toLowerCase();
      if (stats[key] !== undefined) {
        stats[key] = parseInt(row.count);
      }
    });

    res.json({ success: true, data: stats });
  } catch (err) {
    console.error('Stats error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// -------------------------------------------------------------
// 2. SETTINGS API (Telegram, WordPress, AI)
// -------------------------------------------------------------
app.get('/api/settings', async (req, res) => {
  try {
    const result = await query('SELECT key, value, category, description FROM system_settings ORDER BY category, key');
    const settingsMap = {};
    result.rows.forEach(r => {
      settingsMap[r.key] = r.value;
    });
    res.json({ success: true, settings: settingsMap, raw: result.rows });
  } catch (err) {
    console.error('Get settings error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/settings', async (req, res) => {
  try {
    const payload = req.body; // e.g. { telegram_bot_token: '...', ... }
    const keys = Object.keys(payload);

    for (const key of keys) {
      await query(`
        INSERT INTO system_settings (key, value, updated_at) 
        VALUES ($1, $2, NOW())
        ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW()
      `, [key, String(payload[key])]);
    }

    res.json({ success: true, message: 'Ayarlar başarıyla güncellendi!' });
  } catch (err) {
    console.error('Save settings error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// -------------------------------------------------------------
// 3. NEWS SOURCES API (Haber Kaynakları)
// -------------------------------------------------------------
app.get('/api/sources', async (req, res) => {
  try {
    const result = await query('SELECT * FROM news_sources ORDER BY created_at DESC');
    res.json({ success: true, data: result.rows });
  } catch (err) {
    console.error('Get sources error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

app.post('/api/sources', async (req, res) => {
  try {
    const { name, url, source_type = 'rss', is_active = true } = req.body;
    if (!name || !url) {
      return res.status(400).json({ success: false, error: 'Kaynak adı ve URL zorunludur.' });
    }

    const result = await query(`
      INSERT INTO news_sources (name, url, source_type, is_active)
      VALUES ($1, $2, $3, $4)
      RETURNING *
    `, [name.trim(), url.trim(), source_type, is_active]);

    res.status(201).json({ success: true, data: result.rows[0], message: 'Haber kaynağı eklendi.' });
  } catch (err) {
    console.error('Add source error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

app.put('/api/sources/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { name, url, is_active, source_type } = req.body;

    const result = await query(`
      UPDATE news_sources
      SET name = COALESCE($1, name),
          url = COALESCE($2, url),
          is_active = COALESCE($3, is_active),
          source_type = COALESCE($4, source_type),
          updated_at = NOW()
      WHERE id = $5
      RETURNING *
    `, [name, url, is_active, source_type, id]);

    if (result.rowCount === 0) {
      return res.status(404).json({ success: false, error: 'Kaynak bulunamadı.' });
    }

    res.json({ success: true, data: result.rows[0], message: 'Kaynak güncellendi.' });
  } catch (err) {
    console.error('Update source error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

app.delete('/api/sources/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await query('DELETE FROM news_sources WHERE id = $1 RETURNING id', [id]);
    if (result.rowCount === 0) {
      return res.status(404).json({ success: false, error: 'Kaynak bulunamadı.' });
    }
    res.json({ success: true, message: 'Kaynak başarıyla silindi.' });
  } catch (err) {
    console.error('Delete source error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// -------------------------------------------------------------
// 4. DRAFTS (TASLAKLAR) API
// -------------------------------------------------------------
app.get('/api/drafts', async (req, res) => {
  try {
    const { status, limit = 50, offset = 0 } = req.query;
    let sql = 'SELECT * FROM news_drafts';
    const params = [];

    if (status) {
      params.push(status.toUpperCase());
      sql += ' WHERE status = $1';
    }

    sql += ' ORDER BY created_at DESC LIMIT $' + (params.length + 1) + ' OFFSET $' + (params.length + 2);
    params.push(parseInt(limit), parseInt(offset));

    const result = await query(sql, params);
    res.json({ success: true, data: result.rows });
  } catch (err) {
    console.error('Get drafts error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// -------------------------------------------------------------
// 5. CONNECTION TESTING (TELEGRAM & WORDPRESS)
// -------------------------------------------------------------
app.post('/api/test/telegram', async (req, res) => {
  try {
    const { bot_token, chat_id } = req.body;

    if (!bot_token) {
      return res.status(400).json({ success: false, error: 'Bot token girilmelidir.' });
    }

    // 1. Check Bot validity
    const botMeRes = await axios.get(`https://api.telegram.org/bot${bot_token}/getMe`, { timeout: 10000 });
    const botUser = botMeRes.data.result;

    // 2. If chat_id provided, send a test ping
    let pingMessage = null;
    if (chat_id) {
      const sendRes = await axios.post(`https://api.telegram.org/bot${bot_token}/sendMessage`, {
        chat_id: chat_id,
        text: `🤖 *Haber Otomasyonu Test Mesajı*\n\n✅ Bot başarıyla bağlandı!\n• Bot Adı: @${botUser.username}\n• Zaman: ${new Date().toLocaleString('tr-TR')}`,
        parse_mode: 'Markdown'
      }, { timeout: 10000 });
      pingMessage = sendRes.data.ok;
    }

    res.json({
      success: true,
      message: `Telegram bağlantısı başarılı! Bot: @${botUser.username}${chat_id ? ' (Test mesajı kanala gönderildi)' : ''}`,
      bot: botUser
    });
  } catch (err) {
    const errorMsg = err.response?.data?.description || err.message;
    res.status(400).json({ success: false, error: `Telegram Hatası: ${errorMsg}` });
  }
});

app.post('/api/test/wordpress', async (req, res) => {
  try {
    let { base_url, username, app_password } = req.body;
    if (!base_url || !username || !app_password) {
      return res.status(400).json({ success: false, error: 'WordPress URL, kullanıcı adı ve uygulama parolası zorunludur.' });
    }

    base_url = base_url.trim().replace(/\/$/, '');
    const authHeader = 'Basic ' + Buffer.from(`${username.trim()}:${app_password.trim().replace(/\s/g, '')}`).toString('base64');

    const wpRes = await axios.get(`${base_url}/wp-json/wp/v2/users/me`, {
      headers: { Authorization: authHeader },
      timeout: 10000
    });

    res.json({
      success: true,
      message: `WordPress bağlantısı başarılı! Giriş yapılan kullanıcı: ${wpRes.data.name} (Roller: ${wpRes.data.roles ? wpRes.data.roles.join(', ') : 'OK'})`,
      user: wpRes.data
    });
  } catch (err) {
    const errorMsg = err.response?.data?.message || err.message;
    res.status(400).json({ success: false, error: `WordPress Hatası: ${errorMsg}` });
  }
});

// Serve frontend for all remaining routes
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`[Admin Panel] Running on http://0.0.0.0:${PORT}`);
});
