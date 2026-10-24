-- Migration: Fix WhatsApp Settings Policies & Default Rows
-- Menambahkan izin INSERT pada RLS whatsapp_settings dan memasukkan data default

-- 1. Berikan permission lengkap pada tabel whatsapp_settings
GRANT ALL ON TABLE public.whatsapp_settings TO authenticated;
GRANT ALL ON TABLE public.whatsapp_settings TO anon;
GRANT ALL ON TABLE public.whatsapp_settings TO service_role;

-- 2. Pastikan RLS aktif dan perbaiki policy agar authenticated user bisa INSERT, SELECT, UPDATE
ALTER TABLE public.whatsapp_settings ENABLE ROW LEVEL SECURITY;

-- Hapus policy lama jika ada
DROP POLICY IF EXISTS "Allow authenticated users to read whatsapp_settings" ON public.whatsapp_settings;
DROP POLICY IF EXISTS "Allow authenticated users to update whatsapp_settings" ON public.whatsapp_settings;
DROP POLICY IF EXISTS "Allow authenticated users to insert whatsapp_settings" ON public.whatsapp_settings;
DROP POLICY IF EXISTS "Allow authenticated users all whatsapp_settings" ON public.whatsapp_settings;
DROP POLICY IF EXISTS "allow_all_for_authenticated_wa" ON public.whatsapp_settings;
DROP POLICY IF EXISTS "allow_anon_read_whatsapp_settings" ON public.whatsapp_settings;

-- Buat policy komprehensif untuk pengguna yang login (authenticated)
CREATE POLICY "allow_all_for_authenticated_wa"
    ON public.whatsapp_settings
    FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- Buat policy SELECT untuk anon (opsional agar dasbor pelanggan bisa baca template/app_url jika anon)
CREATE POLICY "allow_anon_read_whatsapp_settings"
    ON public.whatsapp_settings
    FOR SELECT
    TO anon
    USING (true);

-- 3. Masukkan baris konfigurasi default (jika belum ada)
INSERT INTO public.whatsapp_settings (setting_key, setting_value, is_enabled) VALUES
(
    'auto_notification_enabled',
    'true',
    true
),
(
    'fonnte_token',
    '',
    true
),
(
    'app_url',
    '',
    true
),
(
    'template_custom_message',
    'Informasi Tagihan WiFi Anda

Hai Bapak/Ibu {nama_pelanggan},
ID Pelanggan: {idpl}

Informasi tagihan Bapak/Ibu bulan ini adalah:
Jumlah Tagihan: {total_tagihan}
Periode Tagihan: {periode}

Metode Pembayaran:
{metode_pembayaran}

Terima kasih atas kepercayaan Anda menggunakan layanan kami.
_____________________________
*Ini adalah pesan otomatis. Jika telah membayar tagihan, abaikan pesan ini.*',
    true
),
(
    'template_payment_full',
    'Konfirmasi Pembayaran LUNAS

Hai Bapak/Ibu {nama_pelanggan},
ID Pelanggan: {idpl}

✅ *TAGIHAN TELAH LUNAS!*

*Detail Pembayaran:*
• Periode: *{periode}*
• Total Tagihan: *{total_tagihan}*
• Metode: {metode_pembayaran}
• Status: *LUNAS*

Terima kasih atas pembayaran Anda.
_____________________________
*Pesan otomatis dari REVAM NET*',
    true
),
(
    'template_payment_installment',
    'Konfirmasi Pembayaran Cicilan

Hai Bapak/Ibu {nama_pelanggan},
ID Pelanggan: {idpl}

✅ *Pembayaran cicilan diterima!*

*Detail Pembayaran:*
• Periode: *{periode}*
• Jumlah Dibayar: *{jumlah_dibayar}*
• Metode: {metode_pembayaran}
• Sisa Tagihan: *{sisa_tagihan}*

Terima kasih atas pembayaran Anda.
_____________________________
*Pesan otomatis dari REVAM NET*',
    true
)
ON CONFLICT (setting_key) DO NOTHING;
