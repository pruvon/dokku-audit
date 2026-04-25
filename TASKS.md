# dokku-audit — Geliştirme Planı (TASKS)

Kaynak: `dokku-audit-SPEC.md` v0.1-draft

> Görev durumları: `[ ]` yapılmadı · `[~]` kısmi / dış işlem gerekiyor · `[x]` tamamlandı

---

## Faz 1 — Plugin İskeleti & Altyapı

### 1.1 Dizin yapısı ve plugin manifest
- [x] `plugin.toml` oluştur (SPEC §39)
- [x] `commands` dosyası oluştur (help/usage entry point) (SPEC §6.3)
- [x] `subcommands/default` oluştur (`audit` → `audit:status` yönlendirmesi) (SPEC §16.2)
- [x] `subcommands/help` oluştur (SPEC §16.3)

### 1.2 Bağımlılık yönetimi
- [x] `dependencies` trigger script'i oluştur — `sqlite3` ve `flock` kontrolü (SPEC §18.2, §11.1)

### 1.3 Ortak fonksiyon kütüphanesi (`functions`)
- [x] `functions` dosyası oluştur (SPEC §28.2)
- [x] Yol ve ortam değişkeni yardımcıları (`AUDIT_DB_PATH`, `AUDIT_DATA_DIR`, `AUDIT_BACKUP_DIR`, `AUDIT_LOCK_FILE`)
- [x] SQLite çağrı wrapper'ları (`audit_db_exec`, `audit_db_query_single`) (SPEC §28.3)
- [x] Pragma başlatma fonksiyonu (WAL, busy_timeout, foreign_keys) (SPEC §8)
- [x] Transaction yardımcıları
- [x] Event insert yardımcısı (`audit_insert_event`) (SPEC §28.3)
- [x] Pending deploy upsert/delete yardımcıları (`audit_upsert_pending_deploy`) (SPEC §28.3)
- [x] Çıktı biçimlendirme yardımcıları (table, json, jsonl) (SPEC §16.1)
- [x] Sanitizasyon yardımcıları (SQL escape, meta_json güvenli oluşturma) (SPEC §22, §28.3)
- [x] Correlation ID üretici (`aud_<epoch_ms>_<random_hex>`) (SPEC §13.2)
- [x] Zaman damgası üretici (UTC ISO-8601 `Z` formatlı) (SPEC §10)
- [x] Mesaj üretici fonksiyonları (SPEC §29)

---

## Faz 2 — Migrasyon Sistemi

### 2.1 Migrasyon altyapısı
- [x] `migrations/` dizini oluştur
- [x] Migrasyon runner fonksiyonu yaz (SPEC §19.5):
  - flock ile kilit al
  - DB dosyası yoksa oluştur
  - `application_id` set/validate
  - `user_version` oku
  - Sıralı migrasyon dosyalarını uygula
  - Her migrasyon BEGIN IMMEDIATE + COMMIT (SPEC §19.6)
  - Hata durumunda rollback + dur
- [x] `subcommands/migrate` oluştur (SPEC §16.6) — `--dry-run`, `--verbose` flag'leri

### 2.2 İlk migrasyon dosyaları
- [x] `migrations/001_init.sql` — `events`, `pending_deploys`, `meta` tabloları (SPEC §9.1, §38.1)
- [x] `migrations/002_add_indexes.sql` — tüm indeksler (SPEC §9.2, §38.2)

---

## Faz 3 — Install / Update / Uninstall Lifecycle

### 3.1 Install
- [x] `install` trigger script'i oluştur (SPEC §18.1):
  - Veri dizini oluştur
  - `sqlite3` varlığını doğrula
  - DB yoksa oluştur
  - Migrasyonları çalıştır
  - İdempotent olmalı

### 3.2 Update
- [x] `update` trigger script'i oluştur (SPEC §18.3):
  - `audit:migrate` çalıştır
  - Maintenance eventi yaz
  - `PRAGMA optimize` çalıştır

### 3.3 Uninstall
- [x] `uninstall` trigger script'i oluştur (SPEC §18.4):
  - Plugin adını doğrula
  - DB'yi **silme** — korunacağını operatöre bildir

---

## Faz 4 — `audit:status` Komutu
- [x] `subcommands/status` oluştur (SPEC §16.4):
  - Plugin versiyonu
  - DB yolu
  - `application_id`
  - `user_version`
  - Journal mode
  - Toplam event sayısı
  - Pending deploy sayısı
  - Son event zaman damgası
  - Son migrasyon zaman damgası
  - Exit code: 0 sağlıklı, non-zero hatalı

---

## Faz 5 — Deploy Trigger Zinciri

### 5.1 `receive-app` trigger
- [x] `receive-app` script'i oluştur (SPEC §12.2):
  - `pending_deploys` upsert (correlation_id, rev)
  - Event: category=deploy, action=receive, classification=source_received
  - `$REV` boş olabilir — hata değil

### 5.2 `deploy-source-set` trigger
- [x] `deploy-source-set` script'i oluştur (SPEC §12.3):
  - `pending_deploys` upsert (source_type, metadata merge)
  - Event: category=deploy, action=source-set, classification=deploy_source_metadata

### 5.3 `post-extract` trigger
- [x] `post-extract` script'i oluştur (SPEC §12.4):
  - Event: category=deploy, action=extract, classification=source_extracted
  - Pending row'da rev güncelle
  - `TMP_WORK_DIR` kullanma

### 5.4 `post-deploy` trigger (sınıflandırma mantığı)
- [x] `post-deploy` script'i oluştur (SPEC §12.5):
  - Write transaction aç
  - `pending_deploys`'da app'i kontrol et
  - Varsa → `source_deploy`, pending'den veri al, pending sil
  - Yoksa → `release_only`
  - Event: category=deploy, action=finish
  - `meta_json`: internal_port, internal_ip_address, image_tag, source_type, rev

---

## Faz 6 — `audit:last-deploys` Komutu
- [x] `subcommands/last-deploys` oluştur (SPEC §16.7):
  - Son 20 deploy (varsayılan)
  - `--limit N`, `--app APP`, `--classification`, `--format table|json|jsonl`
  - Tablo çıktısı: id, time, app, classification, source_type, rev (12 char), image_tag

---

## Faz 7 — Config / Domain / Port Trigger'ları

### 7.1 `post-config-update`
- [x] `post-config-update` script'i oluştur (SPEC §12.6):
  - Event: category=config, action=set|unset, classification=config_change
  - **Değer kaydetme** — yalnızca key isimleri (SPEC §22.1)
  - meta_json: `{"keys": [...], "value_redacted": true}`

### 7.2 `post-domains-update`
- [x] `post-domains-update` script'i oluştur (SPEC §12.7):
  - Event: category=domains, action=add|clear|remove|reset|set
  - classification=domains_change
  - Domain listesini meta_json'a kaydet

### 7.3 `post-proxy-ports-update`
- [x] `post-proxy-ports-update` script'i oluştur (SPEC §12.8):
  - Event: category=ports, action=add|clear|remove
  - classification=ports_change

---

## Faz 8 — App Lifecycle Trigger'ları

### 8.1 `app-create`
- [x] `app-create` script'i oluştur (SPEC §12.1):
  - Event: category=app, action=create, classification=app_create

### 8.2 `app-destroy`
- [x] `app-destroy` script'i oluştur (SPEC §12.1):
  - Event: category=app, action=destroy, classification=app_destroy

---

## Faz 9 — Sorgu Komutları

### 9.1 `audit:timeline`
- [x] `subcommands/timeline` oluştur (SPEC §16.8):
  - `<app>` zorunlu argüman
  - Azalan sıra, varsayılan 50 event
  - `--limit`, `--since`, `--until`, `--category`, `--format`

### 9.2 `audit:recent`
- [x] `subcommands/recent` oluştur (SPEC §16.9):
  - Tüm app'ler, son eventler
  - `--limit`, `--category`, `--classification`, `--status`, `--since`, `--format`

### 9.3 `audit:show`
- [x] `subcommands/show` oluştur (SPEC §16.10):
  - `<event-id>` zorunlu argüman
  - Detaylı çıktı + pretty-printed meta_json

---

## Faz 10 — `audit:doctor`
- [x] `subcommands/doctor` oluştur (SPEC §16.5):
  - `sqlite3` erişilebilirliği
  - DB dosyası erişimi
  - `application_id` doğrulama
  - `user_version` kontrolü
  - Tablo/indeks varlığı
  - WAL/rollback modu
  - Stale pending_deploys uyarısı (>24 saat)
  - `PRAGMA integrity_check`
  - Exit: 0 sağlıklı, 1 sorunlu

---

## Faz 11 — Bakım Komutları

### 11.1 `audit:backup`
- [x] `subcommands/backup` oluştur (SPEC §16.12, §35.1):
  - `sqlite3 "$DB" ".backup '$TARGET'"` kullan
  - Varsayılan: `backups/audit-YYYYmmdd-HHMMSS.db`
  - `--output PATH`
  - Maintenance event kaydet

### 11.2 `audit:export`
- [x] `subcommands/export` oluştur (SPEC §16.11, §26):
  - `--format jsonl|json`
  - `--app`, `--since`, `--until`, `--output`
  - JSONL: satır başına tam event objesi
  - JSON: `{"plugin":"dokku-audit","exported_at":"...","events":[...]}`

### 11.3 `audit:vacuum`
- [x] `subcommands/vacuum` oluştur (SPEC §16.13):
  - `VACUUM` + `PRAGMA optimize`
  - Maintenance event kaydet

### 11.4 `audit:prune`
- [x] `subcommands/prune` oluştur (SPEC §16.14):
  - `--older-than DAYS` zorunlu
  - `--category`, `--classification`, `--yes`
  - Onaysız silme yapma
  - Maintenance event kaydet

---

## Faz 12 — `report` Entegrasyonu
- [x] `report` trigger script'i oluştur (SPEC §27):
  - `audit plugin enabled`
  - `audit database path`
  - `audit schema version`
  - `audit total events`
  - `audit pending deploys`
  - `audit last event`

---

## Faz 13 — Hata Yönetimi & Güvenlik Kontrolü

- [x] Trigger write hatalarında uyarı yaz, başarı döndür (SPEC §20.4, §21.1)
- [x] CLI hatalarında non-zero exit + açıklayıcı mesaj (SPEC §21.2)
- [x] `application_id` uyumsuzluğunda sert hata (SPEC §24.3)
- [x] Tüm meta_json üretiminde sanitizasyon kontrolü (SPEC §22.2)
- [x] DB dosya izinleri dokümantasyonu (SPEC §7.3)

---

## Faz 14 — Testler

### 14.1 Test altyapısı
- [x] Test çerçevesi seç ve kur (bats veya benzeri)
- [x] Test yardımcı fonksiyonları oluştur (geçici DB, mock ortam)

### 14.2 Entegrasyon testleri (SPEC §32.2)
- [x] `receive-app` + `deploy-source-set` + `post-deploy` → `source_deploy`
- [x] `post-deploy` pending olmadan → `release_only`
- [x] Config change — key kaydeder, değer kaydetmez
- [x] Boş DB'den migrasyon
- [x] N → N+1 migrasyon
- [x] `audit:backup` geçerli kopya oluşturur
- [x] `audit:doctor` geçersiz `application_id` yakalar
- [x] Stale `pending_deploys` uyarısı

### 14.3 CLI golden testleri
- [x] `audit:status` çıktı testi
- [x] `audit:last-deploys` çıktı testi
- [x] `audit:timeline` çıktı testi
- [x] JSON/JSONL çıktı format testleri

---

## Faz 15 — Dokümantasyon & Sürüm

- [x] README.md oluştur (kurulum, kullanım, yedekleme, migrasyon, retention)
- [x] LICENSE dosyası ekle
- [x] CHANGELOG.md başlat
- [~] v0.1.0 tag'i ve release
  - Uygulama ve testler hazırlandı.
  - Yerel commit/tag ve dış release yayını bu çalışma oturumunda yapılmadı.

---

## Gözlem Raporu & Geliştirme Backlog

Aşağıdaki maddeler v0.1.0 sonrası geliştirme gözlemleri ve önerileridir.

> Öncelik sıralaması: **Yüksek** > **Orta** > **Düşük**

### Yüksek Öncelik

- [x] **1. `post-deploy` Meta Verisinin Zenginleştirilmesi**
  - `post-deploy` trigger'ı `$INTERNAL_PORT` (`$2`) ve `$INTERNAL_IP_ADDRESS` (`$3`) alıyordu ama kodda sadece `$IMAGE_TAG` (`$4`) kullanılıyordu.
  - `internal_port` ve `internal_ip_address` değerleri `meta_json`'a eklendi.

- [x] **2. Secret Redaction Kapsamının Genişletilmesi**
  - `audit_is_sensitive_deploy_metadata_key` içinde `secret`, `token`, `password`, `credential`, `auth`, `private-key`, `access-key`, `api-key` kelimeleri vardı.
  - `passphrase`, `client_secret`, `privatekey`, `apikey`, `auth_token`, `bearer`, `session` gibi yaygın varyasyonlar da listeye eklendi.

- [ ] **3. Başarısız İşlem ve Hata Durumlarının Kaydı**
  - Bugün sadece başarılı akışlarda çalışan trigger'lar (`post-deploy`, `post-config-update`, vb.) dinleniyor.
  - Deploy veya sertifika yüklemesinin başarısız olduğu durumlar da kaydedilmeli.
  - `report-deploy-status` veya `pre-deploy` hataları gibi olası hook'lar araştırılmalı.
  - Event `status` kolonu `error` değeriyle kullanılabilir.

- [ ] **4. `apps:rename` Olayının Yakalanması**
  - Uygulama adı değiştiğinde (`dokku apps:rename old new`) hiçbir event üretilmiyordu.
  - `post-app-rename` trigger'ı eklendi; event'te `old_app` ve `new_app` meta verisi tutuluyor.

- [ ] **5. `scheduler-run` ve `scheduler-enter` için Tam Yaşam Döngüsü**
  - `run` ve `enter` event'leri sadece "talep edildi" olarak kaydediliyor.
  - `scheduler-post-run` sonrasında ilgili event güncellenerek `exit_code`, `duration_seconds`, `status` (success/error) eklenmeli.
  - Audit sadece "kim çalıştırdı" değil, "sonuç ne oldu" bilgisini de vermeli.

### Orta Öncelik

- [x] **6. Partial Index ile Sorgu Performansı**
  - `events` tablosundaki indeksler tüm satırları kapsıyordu.
  - `category = 'deploy'` gibi sık filtrelenen kriterler için partial index eklendi:
    ```sql
    CREATE INDEX idx_events_deploy ON events(ts DESC) WHERE category = 'deploy';
    ```

- [x] **7. Event Arama Komutu (`audit:search`)**
  - `meta_json` veya `message` içinde serbest metin araması yoktu.
  - `audit:search --query "TEXT" [--app APP] [--limit N] [--format table|json|jsonl] [--quiet]` komutu eklendi.
  - SQLite `LOWER()` + `LIKE` kombinasyonuyla çalışır.

- [ ] **8. Otomatik Saklama Süresi (Retention) ve Zamanlanmış Temizlik**
  - `audit:prune` tamamen manuel; eski event'ler ve yedekler birikebilir.
  - `audit:prune --enable-schedule --older-than 180` gibi bir mekanizma.
  - `audit:prune-backups --older-than 30` ile eski `.db` yedeklerinin temizlenmesi.

- [ ] **9. Konfigürasyon Yönetimi (`audit:get` / `audit:set`)**
  - Sadece `DOKKU_AUDIT_*` ortam değişkenleri dışında runtime ayar yok.
  - `audit:set strict-mode true`, `audit:set deploy-metadata-max-bytes 2048` gibi komutlar.
  - Ayarlar `meta` tablosunda saklanabilir.

### İyileştirmeler (Düşük / Gelecek)

- [ ] **10. `audit:doctor` Derinlemesine Kontrol**
  - `PRAGMA freelist_count` ve `PRAGMA page_count` ile DB büyüklüğü/boş alan raporu.
  - `ANALYZE;` sonrası en yavaş sorgu planı tespiti (opsiyonel).
  - WAL dosyasının (`-wal`, `-shm`) anormal büyümesi uyarısı.

- [ ] **11. `prune` İşleminde Silinen Event Detayları**
  - `audit:prune` sadece `deleted_count` sayısını maintenance event'e yazıyor.
  - Silinen event'lerin ID aralığı (`min_id`, `max_id`) veya kategori özetleri `meta_json`'a eklenebilir.

- [ ] **12. `audit_export` CSV Desteği**
  - Sadece `json` ve `jsonl` destekleniyor.
  - `audit:export --format csv` eklenmeli; `events` tablosunun flat kolonları CSV'ye dönüştürülebilir.

- [ ] **13. Git Branch Bilgisinin Kaydedilmesi**
  - `receive-app` trigger'ında `REV` alınıyor ama branch bilgisi (`refs/heads/main` vb.) kaydedilmiyor.
  - Branch ismi `pending_deploys` veya son event'in `meta_json`'ına `branch` anahtarı olarak eklenebilir.

- [ ] **14. Dokku Versiyonunun Event Meta Verisine Eklenmesi**
  - Event'lerin hiçbirinde o anda çalışan Dokku versiyonu bilgisi yok.
  - `meta_json` içine `dokku_version` eklenmesi (örneğin `dokku version` çıktısından).

- [ ] **15. Zaman Dilimi Desteği ve İnsan Okunabilir Zamanlar**
  - Tüm zamanlar UTC (`Z` suffix) ve tablo çıktısında da öyle gösteriliyor.
  - `--tz Europe/Istanbul` veya sistem yerel zamanına çevirme seçeneği.

- [ ] **16. Trigger Guard ve Strict Mode Test Kapsamı**
  - Testler çoğunlukla "happy path" senaryoları kapsıyor.
  - `audit_trigger_guard`'ın `DOKKU_AUDIT_STRICT_MODE=true` durumunda hata döndürdüğü.
  - DB kilitlenmesi (`busy_timeout` aşımı) durumunda trigger'ın uygulama operasyonunu kırmadığı.
  - Corrupt DB senaryosunda `audit:doctor`'ın doğru çıkış kodunu verdiği.

- [ ] **17. SQL Enjeksiyon Riskinin Ek Testlerle Doğrulanması**
  - `audit_sql_quote` tek tırnak kaçışı yapıyor; SQLite shell prepared statement desteği olmadığı için bu yöntem kullanılıyor.
  - `app`, `message`, `meta_json` gibi kullanıcı kaynaklı string'lerin `'` dışında `\0`, `\x1a` gibi edge case'ler için test fixture'ları eklenmeli.

- [ ] **18. Event ID Sequence veya Hash Zinciri (Opsiyonel / Gelecek)**
  - Event'ler `AUTOINCREMENT` ile artıyor ama bir satırın sonradan değiştirilip değiştirilmediğini kanıtlayan bir mekanizma yok.
  - Her event'in `meta_json`'ına önceki event'in `id` ve `ts` değerinden türetilmiş basit bir `previous_ref` veya hash eklenmesi düşünülebilir (compliance için).

---

## Notlar

- Shell convention: her script `#!/usr/bin/env bash` + `set -eo pipefail` + `[[ $DOKKU_TRACE ]] && set -x` (SPEC §6.2)
- Failure posture: audit yazma hatası app operasyonlarını kırmamalı (SPEC §20.4)
- Hassas veri: config değerleri **asla** kaydedilmez (SPEC §22.1)
- Zaman formatı: UTC ISO-8601 `Z` sonekli (SPEC §10)
- `application_id`: sabit integer, `user_version`: şema versiyonu (SPEC §8.1)
- Correlation ID: `aud_<epoch_ms>_<random_hex>` (SPEC §13.2)
- Pending timeout: varsayılan 24 saat (SPEC §13.4)
