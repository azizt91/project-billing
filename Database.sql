-- ==============================================================================
-- PROJECT BILLING / REVAM NET - MASTER DATABASE SETUP SCRIPT
-- ==============================================================================
-- File ini dirancang untuk dijalankan 1 KALI (All-in-One / Idempotent) di Supabase SQL Editor.
-- Mencakup:
-- 1. Ekstensi Postgres
-- 2. Custom ENUM Types
-- 3. Seluruh Tabel Aplikasi & Relasinya
-- 4. Indeks Performa
-- 5. Stored Functions & RPC Lengkap
-- 6. Trigger Otomatis (Auto Profile on Signup, Updated_at)
-- 7. Supabase Storage Bucket ('avatars') & Storage Policies
-- 8. Data Default / Initial Seed (App Settings, WA Templates, GenieACS, Paket)
-- 9. Row Level Security (RLS) & Policies Menyeluruh
-- 10. Hak Akses (Grants) untuk anon, authenticated, service_role
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. EKSTENSI POSTGRES
-- ------------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ------------------------------------------------------------------------------
-- 2. CUSTOM ENUM TYPES (Idempotent)
-- ------------------------------------------------------------------------------
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'customer_status') THEN
        CREATE TYPE public.customer_status AS ENUM ('AKTIF', 'NONAKTIF');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'invoice_status') THEN
        CREATE TYPE public.invoice_status AS ENUM ('unpaid', 'paid', 'partially_paid', 'overdue');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'invoice_payment_status') THEN
        CREATE TYPE public.invoice_payment_status AS ENUM ('unpaid', 'partially_paid', 'paid', 'overdue');
    END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 3. TABEL-TABEL UTAMA
-- ------------------------------------------------------------------------------

-- 3.1. Tabel Paket Internet (packages)
CREATE TABLE IF NOT EXISTS public.packages (
    id SERIAL PRIMARY KEY,
    package_name TEXT NOT NULL,
    price NUMERIC NOT NULL,
    speed_mbps INTEGER,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3.2. Tabel Profil Pengguna & Pelanggan (profiles)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    idpl TEXT UNIQUE,
    full_name TEXT,
    address TEXT,
    gender TEXT,
    whatsapp_number TEXT,
    role TEXT NOT NULL DEFAULT 'USER',
    photo_url TEXT,
    status public.customer_status DEFAULT 'AKTIF',
    installation_date DATE,
    device_type TEXT,
    ip_static_pppoe TEXT,
    package_id INTEGER REFERENCES public.packages(id) ON DELETE SET NULL,
    churn_date DATE,
    latitude NUMERIC,
    longitude NUMERIC,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3.3. Tabel Tagihan (invoices)
CREATE TABLE IF NOT EXISTS public.invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    package_id INTEGER REFERENCES public.packages(id) ON DELETE SET NULL,
    invoice_period TEXT NOT NULL,
    amount NUMERIC NOT NULL,
    total_due NUMERIC,
    amount_paid NUMERIC DEFAULT 0,
    status public.invoice_status NOT NULL DEFAULT 'unpaid',
    due_date DATE,
    paid_at TIMESTAMPTZ,
    last_payment_date TIMESTAMPTZ,
    payment_method TEXT DEFAULT 'cash',
    broadcast_count INTEGER DEFAULT 0,
    payment_history JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3.4. Tabel Pengeluaran Operasional (expenses)
CREATE TABLE IF NOT EXISTS public.expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    description TEXT NOT NULL,
    amount NUMERIC NOT NULL,
    expense_date DATE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3.5. Tabel Notifikasi (notifications)
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    recipient_role TEXT,
    recipient_user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    url TEXT,
    type TEXT,
    data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3.6. Tabel Status Baca Notifikasi (notification_reads)
CREATE TABLE IF NOT EXISTS public.notification_reads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id UUID NOT NULL REFERENCES public.notifications(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    read_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_notification_user UNIQUE (notification_id, user_id)
);

-- 3.7. Tabel Metode Pembayaran (payment_methods)
CREATE TABLE IF NOT EXISTS public.payment_methods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bank_name TEXT NOT NULL,
    account_number TEXT NOT NULL,
    account_holder TEXT NOT NULL,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 3.8. Tabel Pengaturan Aplikasi (app_settings)
CREATE TABLE IF NOT EXISTS public.app_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    app_name TEXT,
    app_short_name TEXT,
    app_description TEXT,
    app_tagline TEXT,
    logo_url TEXT,
    favicon_url TEXT,
    icon_192_url TEXT,
    icon_512_url TEXT,
    whatsapp_number TEXT,
    support_email TEXT,
    office_address TEXT,
    offline_payment_name TEXT,
    offline_payment_address TEXT,
    qris_image_url TEXT,
    show_qris BOOLEAN DEFAULT TRUE,
    theme_color TEXT,
    background_color TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 3.9. Tabel Pengaturan WhatsApp & Template (whatsapp_settings)
CREATE TABLE IF NOT EXISTS public.whatsapp_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    setting_key TEXT UNIQUE NOT NULL,
    setting_value TEXT,
    is_enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3.10. Tabel Pengaturan GenieACS (genieacs_settings)
CREATE TABLE IF NOT EXISTS public.genieacs_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    setting_key TEXT UNIQUE NOT NULL,
    setting_value TEXT,
    is_enabled BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3.11. Tabel Log Perubahan WiFi (wifi_change_logs)
CREATE TABLE IF NOT EXISTS public.wifi_change_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    ip_address TEXT NOT NULL,
    old_ssid TEXT,
    new_ssid TEXT,
    changed_at TIMESTAMPTZ DEFAULT NOW(),
    status TEXT DEFAULT 'pending',
    error_message TEXT
);

-- ------------------------------------------------------------------------------
-- 4. INDEKS UNTUK OPTIMASI PERFORMA
-- ------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_idpl ON public.profiles(idpl);
CREATE INDEX IF NOT EXISTS idx_profiles_status ON public.profiles(status);
CREATE INDEX IF NOT EXISTS idx_profiles_package_id ON public.profiles(package_id);
CREATE INDEX IF NOT EXISTS idx_invoices_customer_id ON public.invoices(customer_id);
CREATE INDEX IF NOT EXISTS idx_invoices_status ON public.invoices(status);
CREATE INDEX IF NOT EXISTS idx_invoices_period ON public.invoices(invoice_period);
CREATE INDEX IF NOT EXISTS idx_notifications_recipient ON public.notifications(recipient_role, recipient_user_id);
CREATE INDEX IF NOT EXISTS idx_notification_reads_user ON public.notification_reads(user_id);
CREATE INDEX IF NOT EXISTS idx_wifi_change_logs_customer ON public.wifi_change_logs(customer_id);

-- ------------------------------------------------------------------------------
-- 5. FUNGSI & PROSEDUR (STORED FUNCTIONS & RPC)
-- ------------------------------------------------------------------------------

-- 5.1. Update updated_at column helper
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.update_whatsapp_settings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.update_genieacs_settings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5.2. Get User Role (SECURITY DEFINER)
CREATE OR REPLACE FUNCTION public.get_user_role(user_id UUID)
RETURNS TEXT
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    user_role TEXT;
BEGIN
    SELECT role INTO user_role FROM public.profiles WHERE id = user_id;
    RETURN COALESCE(user_role, 'USER');
END;
$$;

-- 5.3. Get User Email from auth.users (SECURITY DEFINER)
CREATE OR REPLACE FUNCTION public.get_user_email(user_id UUID)
RETURNS TEXT
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    user_email TEXT;
BEGIN
    SELECT email INTO user_email FROM auth.users WHERE id = user_id;
    RETURN COALESCE(user_email, '');
END;
$$;

-- 5.4. Auto Handle New User Signup (Trigger Function)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (
        id,
        full_name,
        role,
        status,
        photo_url
    )
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
        COALESCE(NEW.raw_user_meta_data->>'role', 'ADMIN'),
        'AKTIF',
        'assets/avatar_male.svg'
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        role = EXCLUDED.role;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5.5. Tambah Notifikasi Pembayaran (add_payment_notification)
CREATE OR REPLACE FUNCTION public.add_payment_notification(
    customer_name TEXT,
    customer_idpl TEXT,
    invoice_period TEXT,
    amount NUMERIC,
    admin_name TEXT
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    notification_id UUID;
    formatted_amount TEXT;
BEGIN
    formatted_amount := 'Rp ' || to_char(amount, 'FM999,999,999');

    INSERT INTO public.notifications (title, body, recipient_role, url)
    VALUES (
        'Pembayaran Lunas Diterima',
        'Dari ' || customer_name || ' (' || customer_idpl || ') sebesar ' || formatted_amount || ' untuk periode ' || invoice_period || '. Diproses oleh ' || admin_name || '.',
        'ADMIN',
        '/tagihan.html?status=paid'
    )
    RETURNING id INTO notification_id;

    RETURN notification_id;
END;
$$;

-- 5.6. Broadcast ke Semua Admin (broadcast_to_all_admins)
CREATE OR REPLACE FUNCTION public.broadcast_to_all_admins(
    notification_type TEXT,
    title TEXT,
    message TEXT,
    data JSONB DEFAULT '{}'::jsonb,
    url TEXT DEFAULT NULL
) RETURNS TEXT
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    admin_record RECORD;
    admin_count INTEGER := 0;
BEGIN
    INSERT INTO public.notifications (title, body, recipient_role, url, type, data)
    VALUES (title, message, 'ADMIN', url, notification_type, data);

    FOR admin_record IN 
        SELECT id FROM public.profiles WHERE role = 'ADMIN'
    LOOP
        admin_count := admin_count + 1;
    END LOOP;

    RETURN 'Notification sent to ' || admin_count || ' admins';
END;
$$;

-- 5.7. Cleanup Notifikasi Lama (cleanup_old_notifications)
CREATE OR REPLACE FUNCTION public.cleanup_old_notifications(days_to_keep INTEGER DEFAULT 30)
RETURNS INTEGER
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM public.notifications
    WHERE created_at < NOW() - (days_to_keep || ' days')::INTERVAL;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$;

-- 5.8. Pembuatan Tagihan Bulanan Otomatis (create_monthly_invoices_v3)
CREATE OR REPLACE FUNCTION public.create_monthly_invoices_v3(
    p_month INTEGER DEFAULT NULL,
    p_year INTEGER DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    target_invoice_period TEXT;
    created_invoices_count INTEGER := 0;
    customer_record RECORD;
    month_name TEXT;
    target_date DATE;
    target_m INTEGER;
    target_y INTEGER;
BEGIN
    target_date := (NOW() AT TIME ZONE 'Asia/Jakarta')::DATE;
    target_m := COALESCE(p_month, EXTRACT(MONTH FROM target_date)::INTEGER);
    target_y := COALESCE(p_year, EXTRACT(YEAR FROM target_date)::INTEGER);

    SELECT 
        CASE target_m
            WHEN 1 THEN 'Januari'
            WHEN 2 THEN 'Februari'
            WHEN 3 THEN 'Maret'
            WHEN 4 THEN 'April'
            WHEN 5 THEN 'Mei'
            WHEN 6 THEN 'Juni'
            WHEN 7 THEN 'Juli'
            WHEN 8 THEN 'Agustus'
            WHEN 9 THEN 'September'
            WHEN 10 THEN 'Oktober'
            WHEN 11 THEN 'November'
            WHEN 12 THEN 'Desember'
        END
    INTO month_name;

    target_invoice_period := month_name || ' ' || target_y;

    FOR customer_record IN 
        SELECT 
            prof.id as customer_id,
            pack.price as customer_price, 
            pack.id as customer_package_id
        FROM 
            public.profiles prof
        JOIN 
            public.packages pack ON prof.package_id = pack.id
        WHERE 
            prof.role = 'USER' 
            AND prof.status = 'AKTIF'
            AND NOT EXISTS (
                SELECT 1 
                FROM public.invoices inv
                WHERE inv.customer_id = prof.id 
                  AND inv.invoice_period = target_invoice_period
            )
    LOOP
        INSERT INTO public.invoices (
            customer_id,
            package_id,
            invoice_period,
            amount,
            total_due,
            status,
            due_date
        ) VALUES (
            customer_record.customer_id,
            customer_record.customer_package_id,
            target_invoice_period,
            customer_record.customer_price,
            customer_record.customer_price,
            'unpaid',
            (target_y || '-' || LPAD(target_m::TEXT, 2, '0') || '-20')::DATE
        );
        created_invoices_count := created_invoices_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'status', 'success',
        'message', 'Generated ' || created_invoices_count || ' invoices for ' || target_invoice_period,
        'count', created_invoices_count,
        'period', target_invoice_period
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('status', 'error', 'message', SQLERRM);
END;
$$;

-- 5.9. Get All Customers dengan Filter & Search (get_all_customers)
CREATE OR REPLACE FUNCTION public.get_all_customers(
    p_filter TEXT DEFAULT 'all',
    p_search_term TEXT DEFAULT ''
) RETURNS TABLE(
    id UUID,
    idpl TEXT,
    full_name TEXT,
    address TEXT,
    gender TEXT,
    whatsapp_number TEXT,
    role TEXT,
    photo_url TEXT,
    status public.customer_status,
    installation_date DATE,
    device_type TEXT,
    ip_static_pppoe TEXT,
    created_at TIMESTAMPTZ,
    churn_date DATE
)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id, p.idpl, p.full_name, p.address, p.gender, p.whatsapp_number,
        p.role, p.photo_url, p.status, p.installation_date, p.device_type,
        p.ip_static_pppoe, p.created_at, p.churn_date
    FROM public.profiles p
    WHERE p.role = 'USER'
      AND (
          p_filter = 'all' 
          OR (p_filter = 'active' AND p.status = 'AKTIF')
          OR (p_filter = 'inactive' AND p.status = 'NONAKTIF')
      )
      AND (
          p_search_term = ''
          OR p.full_name ILIKE '%' || p_search_term || '%'
          OR p.idpl ILIKE '%' || p_search_term || '%'
          OR p.address ILIKE '%' || p_search_term || '%'
          OR p.whatsapp_number ILIKE '%' || p_search_term || '%'
      )
    ORDER BY p.created_at DESC;
END;
$$;

-- 5.10. Dashboard Statistics (get_dashboard_stats)
CREATE OR REPLACE FUNCTION public.get_dashboard_stats(
    p_month INTEGER DEFAULT 0,
    p_year INTEGER DEFAULT (EXTRACT(YEAR FROM CURRENT_DATE))::INTEGER
) RETURNS TABLE(
    total_revenue NUMERIC,
    total_expenses NUMERIC,
    profit NUMERIC,
    active_customers INTEGER,
    inactive_customers INTEGER,
    unpaid_invoices_count INTEGER,
    paid_invoices_count INTEGER
)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_total_revenue NUMERIC := 0;
    v_total_expenses NUMERIC := 0;
    v_profit NUMERIC := 0;
    v_active_customers INTEGER := 0;
    v_inactive_customers INTEGER := 0;
    v_unpaid_invoices_count INTEGER := 0;
    v_paid_invoices_count INTEGER := 0;
BEGIN
    -- Hitung Pendapatan dari invoices (amount_paid)
    SELECT COALESCE(SUM(amount_paid), 0) INTO v_total_revenue
    FROM public.invoices
    WHERE 
        (p_month = 0 OR EXTRACT(MONTH FROM COALESCE(last_payment_date, paid_at, created_at)) = p_month)
        AND (p_year = 0 OR EXTRACT(YEAR FROM COALESCE(last_payment_date, paid_at, created_at)) = p_year)
        AND amount_paid > 0;

    -- Hitung Pengeluaran
    SELECT COALESCE(SUM(amount), 0) INTO v_total_expenses
    FROM public.expenses
    WHERE 
        (p_month = 0 OR EXTRACT(MONTH FROM expense_date) = p_month)
        AND (p_year = 0 OR EXTRACT(YEAR FROM expense_date) = p_year);

    v_profit := v_total_revenue - v_total_expenses;

    -- Jumlah Pelanggan
    SELECT 
        COUNT(CASE WHEN status = 'AKTIF' THEN 1 END),
        COUNT(CASE WHEN status = 'NONAKTIF' THEN 1 END)
    INTO v_active_customers, v_inactive_customers
    FROM public.profiles
    WHERE role = 'USER';

    -- Status Tagihan
    SELECT 
        COUNT(CASE WHEN status = 'unpaid' THEN 1 END),
        COUNT(CASE WHEN status = 'paid' THEN 1 END)
    INTO v_unpaid_invoices_count, v_paid_invoices_count
    FROM public.invoices
    WHERE 
        (p_month = 0 OR EXTRACT(MONTH FROM created_at) = p_month)
        AND (p_year = 0 OR EXTRACT(YEAR FROM created_at) = p_year);

    RETURN QUERY SELECT 
        v_total_revenue,
        v_total_expenses,
        v_profit,
        v_active_customers,
        v_inactive_customers,
        v_unpaid_invoices_count,
        v_paid_invoices_count;
END;
$$;

-- 5.11. Dashboard Chart Data (get_dashboard_charts_data)
CREATE OR REPLACE FUNCTION public.get_dashboard_charts_data(p_months INTEGER DEFAULT 6)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    chart_data JSONB := '[]'::jsonb;
    month_cursor DATE;
    start_date DATE;
    m_name TEXT;
    m_num INTEGER;
    y_num INTEGER;
    rev NUMERIC;
    exp NUMERIC;
BEGIN
    start_date := (DATE_TRUNC('month', CURRENT_DATE) - ((p_months - 1) || ' months')::INTERVAL)::DATE;

    FOR i IN 0..(p_months - 1) LOOP
        month_cursor := (start_date + (i || ' months')::INTERVAL)::DATE;
        m_num := EXTRACT(MONTH FROM month_cursor)::INTEGER;
        y_num := EXTRACT(YEAR FROM month_cursor)::INTEGER;

        SELECT CASE m_num
            WHEN 1 THEN 'Jan' WHEN 2 THEN 'Feb' WHEN 3 THEN 'Mar'
            WHEN 4 THEN 'Apr' WHEN 5 THEN 'Mei' WHEN 6 THEN 'Jun'
            WHEN 7 THEN 'Jul' WHEN 8 THEN 'Agu' WHEN 9 THEN 'Sep'
            WHEN 10 THEN 'Okt' WHEN 11 THEN 'Nov' WHEN 12 THEN 'Des'
        END INTO m_name;

        SELECT COALESCE(SUM(amount_paid), 0) INTO rev
        FROM public.invoices
        WHERE EXTRACT(MONTH FROM COALESCE(last_payment_date, paid_at, created_at)) = m_num
          AND EXTRACT(YEAR FROM COALESCE(last_payment_date, paid_at, created_at)) = y_num;

        SELECT COALESCE(SUM(amount), 0) INTO exp
        FROM public.expenses
        WHERE EXTRACT(MONTH FROM expense_date) = m_num
          AND EXTRACT(YEAR FROM expense_date) = y_num;

        chart_data := chart_data || jsonb_build_object(
            'period', m_name || ' ' || y_num,
            'revenue', rev,
            'expense', exp,
            'profit', rev - exp
        );
    END LOOP;

    RETURN chart_data;
END;
$$;

-- 5.12. Get Invoices With Payment Info (get_invoices_with_payment_info)
CREATE OR REPLACE FUNCTION public.get_invoices_with_payment_info(
    p_status TEXT DEFAULT 'all',
    p_customer_id UUID DEFAULT NULL
) RETURNS TABLE(
    id UUID,
    customer_id UUID,
    customer_name TEXT,
    whatsapp_number TEXT,
    invoice_period TEXT,
    total_due NUMERIC,
    amount_paid NUMERIC,
    remaining_amount NUMERIC,
    status public.invoice_status,
    due_date DATE,
    last_payment_date TIMESTAMPTZ,
    payment_count INTEGER,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        inv.id,
        inv.customer_id,
        p.full_name AS customer_name,
        p.whatsapp_number,
        inv.invoice_period,
        COALESCE(inv.total_due, inv.amount) AS total_due,
        COALESCE(inv.amount_paid, 0) AS amount_paid,
        (COALESCE(inv.total_due, inv.amount) - COALESCE(inv.amount_paid, 0)) AS remaining_amount,
        inv.status,
        inv.due_date,
        inv.last_payment_date,
        COALESCE(jsonb_array_length(inv.payment_history), 0)::INTEGER AS payment_count,
        inv.created_at
    FROM public.invoices inv
    JOIN public.profiles p ON inv.customer_id = p.id
    WHERE 
        (p_customer_id IS NULL OR inv.customer_id = p_customer_id)
        AND (
            p_status = 'all'
            OR (p_status = 'paid' AND inv.status = 'paid')
            OR (p_status = 'unpaid' AND inv.status IN ('unpaid', 'partially_paid'))
            OR (p_status = 'overdue' AND inv.status = 'overdue')
        )
    ORDER BY inv.created_at DESC;
END;
$$;

-- 5.13. Get Payment History (get_payment_history)
CREATE OR REPLACE FUNCTION public.get_payment_history(p_invoice_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    history JSONB;
BEGIN
    SELECT COALESCE(payment_history, '[]'::jsonb) INTO history
    FROM public.invoices
    WHERE id = p_invoice_id;
    
    RETURN history;
END;
$$;

-- 5.14. Proses Pembayaran Cicilan / Pelunasan (process_installment_payment)
CREATE OR REPLACE FUNCTION public.process_installment_payment(
    p_invoice_id UUID,
    p_payment_amount NUMERIC,
    p_admin_name TEXT,
    p_payment_method TEXT DEFAULT 'cash',
    p_note TEXT DEFAULT ''
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    current_invoice RECORD;
    v_total_due NUMERIC;
    v_new_amount_paid NUMERIC;
    v_new_remaining NUMERIC;
    v_new_status public.invoice_status;
    new_entry JSONB;
    current_history JSONB;
BEGIN
    SELECT * INTO current_invoice FROM public.invoices WHERE id = p_invoice_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Tagihan tidak ditemukan');
    END IF;

    IF current_invoice.status = 'paid' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Tagihan sudah lunas');
    END IF;

    IF p_payment_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'Jumlah pembayaran harus lebih dari 0');
    END IF;

    v_total_due := COALESCE(current_invoice.total_due, current_invoice.amount);
    v_new_amount_paid := COALESCE(current_invoice.amount_paid, 0) + p_payment_amount;
    v_new_remaining := v_total_due - v_new_amount_paid;

    IF v_new_remaining < 0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'Pembayaran melebihi sisa tagihan');
    END IF;

    IF v_new_remaining = 0 THEN
        v_new_status := 'paid';
    ELSE
        v_new_status := 'partially_paid';
    END IF;

    new_entry := jsonb_build_object(
        'payment_id', gen_random_uuid(),
        'amount', p_payment_amount,
        'paid_at', NOW(),
        'processed_by', p_admin_name,
        'payment_method', p_payment_method,
        'note', p_note,
        'remaining_after', v_new_remaining
    );

    current_history := COALESCE(current_invoice.payment_history, '[]'::jsonb) || jsonb_build_array(new_entry);

    UPDATE public.invoices
    SET 
        amount_paid = v_new_amount_paid,
        status = v_new_status,
        last_payment_date = NOW(),
        paid_at = CASE WHEN v_new_status = 'paid' THEN NOW() ELSE paid_at END,
        payment_method = p_payment_method,
        payment_history = current_history
    WHERE id = p_invoice_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Pembayaran berhasil diproses',
        'status', v_new_status,
        'amount_paid', v_new_amount_paid,
        'remaining_amount', v_new_remaining
    );
END;
$$;

-- 5.15. Notifikasi RPC Helpers
CREATE OR REPLACE FUNCTION public.get_unread_notification_count(user_id_param UUID)
RETURNS INTEGER
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    unread_count INTEGER;
    u_role TEXT;
BEGIN
    SELECT role INTO u_role FROM public.profiles WHERE id = user_id_param;

    SELECT COUNT(*)::INTEGER INTO unread_count
    FROM public.notifications n
    WHERE (n.recipient_user_id = user_id_param OR (n.recipient_role = u_role AND n.recipient_user_id IS NULL))
      AND NOT EXISTS (
          SELECT 1 FROM public.notification_reads nr
          WHERE nr.notification_id = n.id AND nr.user_id = user_id_param
      );

    RETURN COALESCE(unread_count, 0);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_user_notifications(user_id_param UUID DEFAULT NULL)
RETURNS TABLE(
    id UUID,
    title TEXT,
    body TEXT,
    url TEXT,
    created_at TIMESTAMPTZ,
    is_read BOOLEAN
)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    target_user UUID;
    u_role TEXT;
BEGIN
    target_user := COALESCE(user_id_param, auth.uid());
    SELECT role INTO u_role FROM public.profiles WHERE id = target_user;

    RETURN QUERY
    SELECT 
        n.id,
        n.title,
        n.body,
        n.url,
        n.created_at,
        EXISTS (
            SELECT 1 FROM public.notification_reads nr
            WHERE nr.notification_id = n.id AND nr.user_id = target_user
        ) AS is_read
    FROM public.notifications n
    WHERE n.recipient_user_id = target_user 
       OR (n.recipient_role = u_role AND n.recipient_user_id IS NULL)
    ORDER BY n.created_at DESC
    LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_notification_read(
    notification_id_param UUID,
    user_id_param UUID
) RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.notification_reads (notification_id, user_id, read_at)
    VALUES (notification_id_param, user_id_param, NOW())
    ON CONFLICT (notification_id, user_id) DO UPDATE SET read_at = NOW();
    RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION public.send_admin_login_notification(admin_name TEXT)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.notifications (title, body, recipient_role, url)
    VALUES ('Admin Login', admin_name || ' telah login ke sistem.', 'ADMIN', '/dashboard.html');
    RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.send_customer_added_notification(admin_name TEXT, customer_name TEXT)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.notifications (title, body, recipient_role, url)
    VALUES ('Pelanggan Baru', customer_name || ' berhasil ditambahkan oleh ' || admin_name || '.', 'ADMIN', '/pelanggan.html');
    RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.send_invoice_creation_notification(admin_name TEXT, invoice_count INTEGER, period TEXT)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.notifications (title, body, recipient_role, url)
    VALUES ('Tagihan Dibuat', invoice_count || ' tagihan baru periode ' || period || ' berhasil dibuat oleh ' || admin_name || '.', 'ADMIN', '/tagihan.html');
    RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.send_payment_notification(
    customer_name TEXT,
    customer_idpl TEXT,
    invoice_period TEXT,
    amount NUMERIC,
    admin_name TEXT,
    customer_id UUID DEFAULT NULL,
    invoice_id UUID DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
    PERFORM public.add_payment_notification(customer_name, customer_idpl, invoice_period, amount, admin_name);
    RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.log_admin_activity(
    admin_id UUID,
    action TEXT,
    description TEXT,
    additional_data JSONB DEFAULT '{}'::jsonb,
    activity_timestamp TIMESTAMPTZ DEFAULT NOW()
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.notifications (title, body, recipient_role, type, data, created_at)
    VALUES (action, description, 'ADMIN', 'activity_log', additional_data, activity_timestamp);
END;
$$;

-- ------------------------------------------------------------------------------
-- 6. TRIGGERS
-- ------------------------------------------------------------------------------

-- Trigger registrasi user baru di auth.users -> public.profiles
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- Trigger update timestamp pada tabel-tabel konfigurasi
DROP TRIGGER IF EXISTS app_settings_updated_at ON public.app_settings;
CREATE TRIGGER app_settings_updated_at
    BEFORE UPDATE ON public.app_settings
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS payment_methods_updated_at ON public.payment_methods;
CREATE TRIGGER payment_methods_updated_at
    BEFORE UPDATE ON public.payment_methods
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS whatsapp_settings_updated_at ON public.whatsapp_settings;
CREATE TRIGGER whatsapp_settings_updated_at
    BEFORE UPDATE ON public.whatsapp_settings
    FOR EACH ROW
    EXECUTE FUNCTION public.update_whatsapp_settings_updated_at();

DROP TRIGGER IF EXISTS genieacs_settings_updated_at ON public.genieacs_settings;
CREATE TRIGGER genieacs_settings_updated_at
    BEFORE UPDATE ON public.genieacs_settings
    FOR EACH ROW
    EXECUTE FUNCTION public.update_genieacs_settings_updated_at();

-- ------------------------------------------------------------------------------
-- 7. SUPABASE STORAGE BUCKET & POLICIES ('avatars')
-- ------------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'avatars',
    'avatars',
    TRUE,
    5242880, -- 5 MB
    ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/svg+xml']
)
ON CONFLICT (id) DO UPDATE SET public = TRUE;

-- Storage Policies
DROP POLICY IF EXISTS "Avatar Public Access" ON storage.objects;
CREATE POLICY "Avatar Public Access"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Authenticated User Upload Avatar" ON storage.objects;
CREATE POLICY "Authenticated User Upload Avatar"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Authenticated User Update Avatar" ON storage.objects;
CREATE POLICY "Authenticated User Update Avatar"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Authenticated User Delete Avatar" ON storage.objects;
CREATE POLICY "Authenticated User Delete Avatar"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (bucket_id = 'avatars');

-- ------------------------------------------------------------------------------
-- 8. DATA AWAL / INITIAL SEED DATA (Idempotent)
-- ------------------------------------------------------------------------------

-- 8.1. Default Packages
INSERT INTO public.packages (id, package_name, price, speed_mbps, description) VALUES
(1, 'Paket Hemat 10 Mbps', 100000, 10, 'Akses internet stabil untuk kebutuhan browsing & streaming ringan'),
(2, 'Paket Super 20 Mbps', 150000, 20, 'Cocok untuk kebutuhan keluarga, belajar & bekerja dari rumah'),
(3, 'Paket Ultra 50 Mbps', 250000, 50, 'Kecepatan tinggi untuk streaming 4K, gaming & multi device')
ON CONFLICT (id) DO NOTHING;
SELECT setval('public.packages_id_seq', (SELECT COALESCE(MAX(id), 1) FROM public.packages));

-- 8.2. Default App Settings
INSERT INTO public.app_settings (
    id, app_name, app_short_name, app_tagline, app_description,
    whatsapp_number, support_email, office_address,
    offline_payment_name, offline_payment_address, show_qris,
    theme_color, background_color
) VALUES (
    '00000000-0000-0000-0000-000000000001',
    'REVAM NET',
    'REVAM',
    'Internet Cepat & Tanpa Batas',
    'Sistem Manajemen Tagihan & Layanan Pelanggan Internet WiFi',
    '081234567890',
    'support@revamnet.com',
    'Jl. Telekomunikasi No. 1, Indonesia',
    'Kasir Kantor REVAM NET',
    'Loket Pembayaran Utama REVAM NET',
    TRUE,
    '#683fe4',
    '#f9f8fc'
) ON CONFLICT (id) DO NOTHING;

-- 8.3. Default Payment Methods
INSERT INTO public.payment_methods (bank_name, account_number, account_holder, sort_order, is_active) VALUES
('TUNAI (CASH)', 'LOKET-KASIR', 'KASIR REVAM NET', 1, TRUE),
('BANK BCA', '1234567890', 'REVAM NET BILLING', 2, TRUE),
('BANK BRI', '098765432112345', 'REVAM NET BILLING', 3, TRUE),
('DANA / OVO / GOPAY', '081234567890', 'REVAM NET', 4, TRUE)
ON CONFLICT DO NOTHING;

-- 8.4. Default WhatsApp Settings & Templates
INSERT INTO public.whatsapp_settings (setting_key, setting_value, is_enabled) VALUES
('auto_notification_enabled', 'true', TRUE),
('fonnte_token', '', TRUE),
('app_url', 'http://localhost/project-billing', TRUE),
('default_admin_phone', '081234567890', TRUE),
('auto_send_manual_payment', 'true', TRUE),
('send_on_invoice_created', 'true', TRUE),
('template_custom_message',
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
TRUE),
('template_payment_full',
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
TRUE),
('template_payment_installment',
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
TRUE)
ON CONFLICT (setting_key) DO UPDATE SET
    is_enabled = EXCLUDED.is_enabled;

-- 8.5. Default GenieACS Settings
INSERT INTO public.genieacs_settings (setting_key, setting_value, is_enabled) VALUES
('genieacs_enabled', 'false', FALSE),
('genieacs_url', 'http://acs.bayardong.my.id', TRUE),
('genieacs_username', '', TRUE),
('genieacs_password', '', TRUE)
ON CONFLICT (setting_key) DO NOTHING;

-- ------------------------------------------------------------------------------
-- 9. ROW LEVEL SECURITY (RLS) & POLICIES MENYELURUH
-- ------------------------------------------------------------------------------

-- Aktifkan RLS di seluruh tabel
ALTER TABLE public.packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_reads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whatsapp_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.genieacs_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wifi_change_logs ENABLE ROW LEVEL SECURITY;

-- 9.1. Policies: public.profiles
DROP POLICY IF EXISTS "profiles_admin_all" ON public.profiles;
CREATE POLICY "profiles_admin_all"
    ON public.profiles FOR ALL
    TO authenticated
    USING (public.get_user_role(auth.uid()) = 'ADMIN')
    WITH CHECK (public.get_user_role(auth.uid()) = 'ADMIN');

DROP POLICY IF EXISTS "profiles_user_select_own" ON public.profiles;
CREATE POLICY "profiles_user_select_own"
    ON public.profiles FOR SELECT
    TO authenticated
    USING (id = auth.uid());

DROP POLICY IF EXISTS "profiles_user_update_own" ON public.profiles;
CREATE POLICY "profiles_user_update_own"
    ON public.profiles FOR UPDATE
    TO authenticated
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS "profiles_user_insert_own" ON public.profiles;
CREATE POLICY "profiles_user_insert_own"
    ON public.profiles FOR INSERT
    TO authenticated
    WITH CHECK (id = auth.uid());

-- 9.2. Policies: public.packages
DROP POLICY IF EXISTS "packages_read_all" ON public.packages;
CREATE POLICY "packages_read_all"
    ON public.packages FOR SELECT
    USING (TRUE);

DROP POLICY IF EXISTS "packages_admin_all" ON public.packages;
CREATE POLICY "packages_admin_all"
    ON public.packages FOR ALL
    TO authenticated
    USING (public.get_user_role(auth.uid()) = 'ADMIN')
    WITH CHECK (public.get_user_role(auth.uid()) = 'ADMIN');

-- 9.3. Policies: public.invoices
DROP POLICY IF EXISTS "invoices_admin_all" ON public.invoices;
CREATE POLICY "invoices_admin_all"
    ON public.invoices FOR ALL
    TO authenticated
    USING (public.get_user_role(auth.uid()) = 'ADMIN')
    WITH CHECK (public.get_user_role(auth.uid()) = 'ADMIN');

DROP POLICY IF EXISTS "invoices_user_select_own" ON public.invoices;
CREATE POLICY "invoices_user_select_own"
    ON public.invoices FOR SELECT
    TO authenticated
    USING (customer_id = auth.uid());

-- 9.4. Policies: public.expenses
DROP POLICY IF EXISTS "expenses_admin_all" ON public.expenses;
CREATE POLICY "expenses_admin_all"
    ON public.expenses FOR ALL
    TO authenticated
    USING (public.get_user_role(auth.uid()) = 'ADMIN')
    WITH CHECK (public.get_user_role(auth.uid()) = 'ADMIN');

-- 9.5. Policies: public.payment_methods
DROP POLICY IF EXISTS "payment_methods_read_all" ON public.payment_methods;
CREATE POLICY "payment_methods_read_all"
    ON public.payment_methods FOR SELECT
    USING (TRUE);

DROP POLICY IF EXISTS "payment_methods_admin_all" ON public.payment_methods;
CREATE POLICY "payment_methods_admin_all"
    ON public.payment_methods FOR ALL
    TO authenticated
    USING (public.get_user_role(auth.uid()) = 'ADMIN')
    WITH CHECK (public.get_user_role(auth.uid()) = 'ADMIN');

-- 9.6. Policies: public.app_settings
DROP POLICY IF EXISTS "app_settings_read_all" ON public.app_settings;
CREATE POLICY "app_settings_read_all"
    ON public.app_settings FOR SELECT
    USING (TRUE);

DROP POLICY IF EXISTS "app_settings_admin_all" ON public.app_settings;
CREATE POLICY "app_settings_admin_all"
    ON public.app_settings FOR ALL
    TO authenticated
    USING (public.get_user_role(auth.uid()) = 'ADMIN')
    WITH CHECK (public.get_user_role(auth.uid()) = 'ADMIN');

-- 9.7. Policies: public.whatsapp_settings
DROP POLICY IF EXISTS "whatsapp_settings_read_all" ON public.whatsapp_settings;
CREATE POLICY "whatsapp_settings_read_all"
    ON public.whatsapp_settings FOR SELECT
    USING (TRUE);

DROP POLICY IF EXISTS "whatsapp_settings_authenticated_all" ON public.whatsapp_settings;
CREATE POLICY "whatsapp_settings_authenticated_all"
    ON public.whatsapp_settings FOR ALL
    TO authenticated
    USING (TRUE)
    WITH CHECK (TRUE);

-- 9.8. Policies: public.genieacs_settings
DROP POLICY IF EXISTS "genieacs_settings_all" ON public.genieacs_settings;
CREATE POLICY "genieacs_settings_all"
    ON public.genieacs_settings FOR ALL
    TO authenticated
    USING (TRUE)
    WITH CHECK (TRUE);

-- 9.9. Policies: public.wifi_change_logs
DROP POLICY IF EXISTS "wifi_logs_admin_all" ON public.wifi_change_logs;
CREATE POLICY "wifi_logs_admin_all"
    ON public.wifi_change_logs FOR ALL
    TO authenticated
    USING (public.get_user_role(auth.uid()) = 'ADMIN')
    WITH CHECK (public.get_user_role(auth.uid()) = 'ADMIN');

DROP POLICY IF EXISTS "wifi_logs_user_select_own" ON public.wifi_change_logs;
CREATE POLICY "wifi_logs_user_select_own"
    ON public.wifi_change_logs FOR SELECT
    TO authenticated
    USING (customer_id = auth.uid());

DROP POLICY IF EXISTS "wifi_logs_user_insert_own" ON public.wifi_change_logs;
CREATE POLICY "wifi_logs_user_insert_own"
    ON public.wifi_change_logs FOR INSERT
    TO authenticated
    WITH CHECK (customer_id = auth.uid());

DROP POLICY IF EXISTS "wifi_logs_user_update_own" ON public.wifi_change_logs;
CREATE POLICY "wifi_logs_user_update_own"
    ON public.wifi_change_logs FOR UPDATE
    TO authenticated
    USING (customer_id = auth.uid())
    WITH CHECK (customer_id = auth.uid());

-- 9.10. Policies: public.notifications
DROP POLICY IF EXISTS "notifications_admin_all" ON public.notifications;
CREATE POLICY "notifications_admin_all"
    ON public.notifications FOR ALL
    TO authenticated
    USING (public.get_user_role(auth.uid()) = 'ADMIN')
    WITH CHECK (public.get_user_role(auth.uid()) = 'ADMIN');

DROP POLICY IF EXISTS "notifications_user_select_own" ON public.notifications;
CREATE POLICY "notifications_user_select_own"
    ON public.notifications FOR SELECT
    TO authenticated
    USING (
        recipient_user_id = auth.uid() 
        OR (recipient_role = public.get_user_role(auth.uid()) AND recipient_user_id IS NULL)
    );

DROP POLICY IF EXISTS "notifications_insert_authenticated" ON public.notifications;
CREATE POLICY "notifications_insert_authenticated"
    ON public.notifications FOR INSERT
    TO authenticated
    WITH CHECK (TRUE);

-- 9.11. Policies: public.notification_reads
DROP POLICY IF EXISTS "notification_reads_user_all" ON public.notification_reads;
CREATE POLICY "notification_reads_user_all"
    ON public.notification_reads FOR ALL
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- ------------------------------------------------------------------------------
-- 10. HAK AKSES SKEMA & TABEL (GRANTS)
-- ------------------------------------------------------------------------------
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;

-- Pastikan izin masa depan (default privileges)
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON ROUTINES TO anon, authenticated, service_role;

-- Selesai
SELECT 'Database schema, tables, functions, triggers, storage, and policies setup successfully!' AS result;
