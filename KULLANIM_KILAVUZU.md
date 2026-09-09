# 📖 Uçtan Uca Haber Otomasyonu ve Yayın Motoru: Adım Adım Kullanım Kılavuzu

Bu kılavuz, sistemi sıfırdan kurmanız, **Web Yönetim Panelini (Admin Dashboard)** kullanarak Telegram ve WordPress bilgilerinizi girmeniz, haber kaynaklarını yönetmeniz ve **Mobil Uygulama** üzerinden yayın yapmanız için gereken tüm adımları ayrıntılı olarak açıklamaktadır.

---

## 🧭 Sistemin Çalışma Mantığı

```
[Haber Siteleri / RSS] 
       │
       ▼ (15 dakikada bir otomatik çekilir)
  [n8n + AI] ─── (Başlık ve 2 paragraflık özet üretir)
       │
       ▼
 [PostgreSQL] ─── (Taslak olarak "PENDING" durumunda saklar)
       │
       ▼ (Mobil Uygulamaya düşer)
[Flutter Mobil] ─── (Editör Orijinal vs AI karşılaştırır, düzenler, Onayla/Reddet basar)
       │
       ├─────────────────────────┐
       ▼                         ▼
[Telegram Kanalı]       [WordPress Sitesi]
 (Görselli / Metin)      (Blog/Haber Postu)
```

Tüm sistem ayarlarını (Telegram Bot Token, Kanal ID, WordPress Şifresi, Haber Siteleri, AI Modeli vb.) **Web Yönetim Paneli** üzerinden istediğiniz an değiştirebilirsiniz. Değişiklikler anında veritabanına işlenir, sunucuyu yeniden başlatmanız gerekmez.

---

## 🚀 ADIM 1: Sistemi Başlatma (Docker)

### Gereksinimler:
- Docker ve Docker Compose kurulu bir sunucu (Ubuntu / Oracle Cloud VPS veya yerel bilgisayarınız).

### 1.1. Kurulum ve Başlatma
Terminalinizi açın ve `backend` klasörüne girin:
```bash
cd backend
cp .env.example .env
docker compose up -d --build
```

Bu komut 3 adet servisi ayağa kaldırır:
1. **PostgreSQL 16** (`:5432`): Veritabanı ve ayarlar deposu.
2. **Yönetim Paneli (Admin Dashboard)** (`:8080`): Tarayıcıdan yöneteceğiniz web arayüzü.
3. **n8n Orkestratör** (`:5678`): Otomasyon ve yapay zeka motoru.

Konteynerlerin çalıştığını kontrol etmek için:
```bash
docker compose ps
```

---

## 🎛️ ADIM 2: Yönetim Panelini Açma (`:8080`)

Tarayıcınızı açın ve şu adrese gidin:
```
http://<SUNUCU_IP_ADRESINIZ>:8080
```
*(Kendi bilgisayarınızda çalışıyorsanız: `http://localhost:8080`)*

Karşınıza modern, Türkçe **Haber Otomasyonu Yönetim Paneli** çıkacaktır. Menüde şunlar bulunur:
- **Genel Bakış:** İstatistikler (Bekleyen, Yayınlanan, Reddedilen haber sayıları).
- **Haber Kaynakları (RSS):** Haber çekilecek sitelerin listesi.
- **Telegram Ayarları:** Bot ve kanal bağlantı ayarları.
- **WordPress Ayarları:** Site ve API bağlantı ayarları.
- **Yapay Zeka (AI):** OpenAI anahtarı, model seçimi ve sistem istemi (prompt).
- **Taslaklar & Arşiv:** Çekilen ve işlenen haberlerin geçmişi.

---

## ✈️ ADIM 3: Telegram Botu ve Kanal Bilgilerini Alma & Panele Ekleme

### 3.1. Telegram Botu Oluşturma
1. Telegram uygulamanızı açın ve arama çubuğuna **`@BotFather`** yazın (mavi onay rozetli olanı seçin).
2. Konuşmayı başlatın (`/start`) ve ardından şu komutu gönderin:
   ```
   /newbot
   ```
3. Botunuz için bir isim belirleyin (Örn: `Haber Ajansı Botu`).
4. Botunuz için sonu `bot` ile biten bir kullanıcı adı (username) belirleyin (Örn: `haber_ajansi_yayinci_bot`).
5. BotFather size bir **HTTP API Token** verecektir. Şunun gibi görünür:
   ```
   7123456789:AAHfkWz99sKLLd-exampleTokenXyZ
   ```
   Bu tokenı kopyalayın.

### 3.2. Kanal Oluşturma ve Botu Yönetici Yapma
1. Telegram'da yeni bir **Kanal (Channel)** oluşturun (Örn: `@benim_haber_kanali`).
2. Kanal ayarlarına girin -> **Yöneticiler (Administrators)** -> **Yönetici Ekle (Add Admin)** seçeneğine tıklayın.
3. Az önce oluşturduğunuz botun kullanıcı adını aratıp kanala **Yönetici (Admin)** olarak ekleyin. *(Mesaj gönderme yetkisi açık olmalıdır).*

### 3.3. Kanal ID'sini (Chat ID) Bulma
- Eğer kanalınız **herkese açık (Public)** ise Chat ID, kanalın kullanıcı adıdır:
  Örn: `@benim_haber_kanali`
- Eğer kanalınız **gizli (Private)** ise: Kanala botu yönetici yaptıktan sonra kanala rastgele bir mesaj atın, ardından tarayıcınızda şu linki açın:
  `https://api.telegram.org/bot<BOT_TOKENINIZ>/getUpdates`
  Buradaki `"chat":{"id": -1001234567890}` değerini kopyalayın.

### 3.4. Bilgileri Panele Girme ve Test Etme
1. Yönetim Panelinde (`:8080`) **Telegram Ayarları** sekmesine geçin.
2. **Telegram Bot Token** alanına aldığınız tokenı yapıştırın.
3. **Telegram Kanalı (Chat ID)** alanına `@kanaladi` veya `-100...` ID'sini yazın.
4. **"Bağlantıyı Test Et & Mesaj Gönder"** butonuna basın.
   - Botunuz kanalınıza anında bir test mesajı gönderecektir.
5. Mesaj geldiyse **"Telegram Ayarlarını Kaydet"** butonuna tıklayın.

---

## 🌐 ADIM 4: WordPress Bilgilerini Alma & Panele Ekleme

Sistem, WordPress sitenize içerik basmak için güvenli **WordPress REST API** ve **Uygulama Parolası (Application Password)** kullanır.

### 4.1. WordPress Uygulama Parolası Oluşturma
1. WordPress Yönetici Panelinize (`wp-admin`) giriş yapın.
2. Sol menüden **Kullanıcılar -> Profiliniz (Users -> Profile)** bölümüne gidin.
3. Sayfanın en altına doğru kaydırın, **"Uygulama Parolaları (Application Passwords)"** bölümünü bulun.
4. "Yeni Uygulama Parolası Adı" kutucuğuna `Haber Botu` yazın ve **"Yeni Uygulama Parolası Ekle"** butonuna basın.
5. WordPress size 16 haneli bir parola verecektir (Örn: `abcd 1234 efgh 5678`). Bu parolayı kopyalayın.

### 4.2. Bilgileri Panele Girme ve Test Etme
1. Yönetim Panelinde (`:8080`) **WordPress Ayarları** sekmesine gidin.
2. **WordPress Site Adresi:** Sitenizin tam URL'si (Örn: `https://siteadi.com` - *sonunda taksim / olmamalıdır*).
3. **Kullanıcı Adı:** WordPress kullanıcı adınız.
4. **Uygulama Parolası:** Az önce oluşturduğunuz 16 haneli parola.
5. **"WordPress Bağlantısını Test Et"** butonuna basın.
   - Sistem sitenize bağlanır ve kullanıcı yetkilerini doğrular.
6. Başarılı uyarısını gördükten sonra **"WordPress Ayarlarını Kaydet"** butonuna basın.

---

## 📰 ADIM 5: Haber Sitelerini / RSS Kaynaklarını Panele Ekleme

İstediğiniz kadar haber sitesini panelden ekleyip çıkarabilirsiniz.

1. Yönetim Panelinde **Haber Kaynakları (RSS)** sekmesine gelin.
2. **"Yeni Kaynak Ekle"** butonuna tıklayın.
3. Açılan pencerede:
   - **Kaynak Adı:** Örn: `Cumhuriyet Gündem` veya `NTV Son Dakika`.
   - **RSS / Akış URL:** Sitenin RSS akış bağlantısı (Örn: `https://www.cumhuriyet.com.tr/rss`, `https://www.ntv.com.tr/gundem.rss`).
   - "Aktif" onay kutusunu işaretleyip **Kaydet** deyin.
4. Eklediğiniz kaynaklar anında listelenir. İstediğiniz kaynağı tek tıkla **Aktif/Pasif** yapabilir veya silebilirsiniz.

---

## 🧠 ADIM 6: n8n Otomasyonunu Yapılandırma (`:5678`)

n8n, haberleri çekip yapay zekaya gönderen arka plan orkestratörüdür.

1. Tarayıcınızdan `http://<SUNUCU_IP_ADRESINIZ>:5678` adresine gidin.
2. İlk girişte n8n bir yönetici hesabı oluşturmanızı isteyecektir (e-posta ve şifre belirleyin).
3. **PostgreSQL Bağlantısı Tanımlama:**
   - Sol menüden **Credentials -> New Credential -> Postgres** seçin.
   - Değerleri şöyle doldurun:
     - **Name:** `Postgres News DB`
     - **Host:** `postgres`
     - **Database:** `news_engine`
     - **User:** `news_user`
     - **Password:** `news_secret_pass` *(veya .env dosyasında belirlediğiniz parola)*
     - **Port:** `5432`
     - **SSL:** `disable`
   - **Save** butonuna basarak kaydedin.
4. **OpenAI Kimliği Tanımlama:**
   - Sol menüden **Credentials -> New Credential -> Header Auth** seçin.
   - **Name:** `OpenAI Auth Header`
   - **Header Name:** `Authorization`
   - **Header Value:** `Bearer sk-proj-YOUR_API_KEY`
   - **Save** diyerek kaydedin.
5. **İş Akışlarını İçe Aktarma (Import):**
   - Sol menüden **Workflows -> Add Workflow -> üç nokta (...) -> Import from File** yolunu izleyin.
   - `backend/workflows/` klasöründeki şu 3 dosyayı tek tek içe aktarın:
     1. `workflow_a_ingest_rewrite.json`
     2. `workflow_b_publish_action.json`
     3. `workflow_c_get_pending.json`
   - Her bir akışı açıp sağ üst köşedeki **Inactive** anahtarını **Active** yapın.

---

## 📱 ADIM 7: Flutter Mobil Uygulamasını Çalıştırma ve Kullanma

Mobil uygulama, haberleri yayınlamadan önce insan onayından geçirmenizi (Human-in-the-Loop) sağlar.

### 7.1. Uygulamayı Başlatma
Bilgisayarınızda terminal açıp `mobile` klasörüne girin:
```bash
cd mobile
flutter pub get
flutter run
```

### 7.2. Sunucu Bağlantısını Ayarlama
1. Mobil uygulama açıldığında sağ üst köşedeki **Ayarlar (⚙️)** simgesine dokunun.
2. Sunucunuzun adresini yazın:
   - Gerçek VPS veya Yerel Ağ için: `http://192.168.1.50:5678` (veya `http://<VPS_IP>:5678`)
   - Android Emülatörü için: `http://10.0.2.2:5678`
3. **Save & Apply** butonuna basın.

### 7.3. Haber İnceleme ve Yayınlama (HITL Süreci)
1. **Gelen Kutusu (Inbox):** n8n tarafından taranıp yapay zekayla özetlenen haberler listede görünür. Listeyi aşağı kaydırarak yenileyebilirsiniz (Pull-to-refresh).
2. İncelemek istediğiniz bir haber kartına dokunun:
   - **Orijinal vs AI Karşılaştırması:** Üstteki sekmelerden taranan orijinal haber metni ile yapay zekanın yazdığı özeti yan yana kıyaslayabilirsiniz.
   - **Canlı Düzenleme:** Başlığı veya metni yayınlamadan önce kendi isteğinize göre doğrudan düzenleyebilirsiniz.
   - **Hedef Platform Seçimi:** İster sadece `[x] Telegram`, ister sadece `[x] WordPress`, isterseniz her ikisini birden seçebilirsiniz.
   - **Reddet (Reject):** Haberi çöpe atmak istiyorsanız kırmızı butona basıp onaylayın. Veritabanında `REJECTED` olarak arşivlenir.
   - **Onayla & Yayınla (Approve & Publish):** Yeşil butona bastığınız anda n8n üzerinden haber saniyeler içinde hem Telegram kanalınıza görselli olarak düşer hem de WordPress sitenizde yeni bir yazı olarak anında yayına girer!
