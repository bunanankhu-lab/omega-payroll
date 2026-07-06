-- ============================================================
-- สร้างตารางครบชุดสำหรับระบบเงินเดือนโอเมก้าอีสาน (โปรเจกต์ใหม่)
-- วิธีใช้: Supabase Dashboard → SQL Editor → วางทั้งไฟล์ → Run
-- ============================================================

-- 1) พนักงาน
create table if not exists public.employees (
  id          uuid primary key default gen_random_uuid(),
  code        text not null default '',
  name        text not null,
  position    text not null default '',
  department  text not null default '',
  base_salary numeric not null default 0,
  start_date  date,
  ss_enabled  boolean not null default true,
  created_at  timestamptz not null default now()
);

-- 2) สลิปเงินเดือนรายเดือน
create table if not exists public.payslips (
  id              uuid primary key default gen_random_uuid(),
  employee_id     uuid not null references public.employees(id) on delete cascade,
  month           text not null,              -- "YYYY-MM"
  base_salary     numeric not null default 0,
  ot              numeric not null default 0,
  allowance       numeric not null default 0,
  social_security numeric not null default 0,
  pos_allow       numeric not null default 0,
  housing         numeric not null default 0,
  edu_allow       numeric not null default 0,
  install_amt     numeric not null default 0,
  pm_amt          numeric not null default 0,
  leave_deduct    numeric not null default 0,
  ot_hours        numeric,
  late_minutes    numeric,
  note            text not null default '',
  created_at      timestamptz not null default now(),
  unique (employee_id, month)                 -- ให้ upsert onConflict ทำงานได้
);

-- 3) การตั้งค่าแอป (แถวเดียว id=1)
create table if not exists public.app_settings (
  id   int primary key,
  data jsonb not null default '{}'::jsonb
);

-- 4) ใบงาน FO + ใบถอด
create table if not exists public.fo_orders (
  id          uuid primary key default gen_random_uuid(),
  fo_no       text not null,
  customer    text not null,
  site        text not null default '',
  job_desc    text not null default '',
  job_date    date,
  technician  text not null default '',
  coordinator text not null default '',
  status      text not null default 'draft',
  items       jsonb not null default '[]'::jsonb,
  picked_by   text not null default '',
  note        text not null default '',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create unique index if not exists fo_orders_fo_no_key on public.fo_orders (fo_no);

-- 5) ข้อมูลดิบ: ชุดอุปกรณ์มาตรฐาน (เทมเพลตใบถอด)
create table if not exists public.fo_templates (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  machine    text not null default '',
  items      jsonb not null default '[]'::jsonb,
  note       text not null default '',
  created_at timestamptz not null default now()
);

-- 6) ข้อมูลดิบ: ทะเบียนลูกค้า/เครื่องในระบบ (นำเข้าจาก Excel ชีท "งานทั้งระบบ")
create table if not exists public.fo_customers (
  id            uuid primary key default gen_random_uuid(),
  customer      text not null,
  machine_model text not null default '',
  serial        text not null default '',
  feeder        text not null default '',
  location      text not null default '',
  customer_type text not null default '',
  pm_cycle      text not null default '',
  contract      text not null default '',
  note          text not null default '',
  created_at    timestamptz not null default now()
);

-- ============================================================
-- RLS: ช่วงพัฒนา (DEV_BYPASS_LOGIN = true) ปล่อยปิดไว้ตามค่าเริ่มต้นของ SQL
-- เมื่อเปิดระบบล็อกอินจริง ค่อยรันส่วนนี้ (เอา -- ออก):
-- ============================================================
-- alter table public.employees    enable row level security;
-- alter table public.payslips     enable row level security;
-- alter table public.app_settings enable row level security;
-- alter table public.fo_orders    enable row level security;
-- create policy "auth full" on public.employees    for all to authenticated using (true) with check (true);
-- create policy "auth full" on public.payslips     for all to authenticated using (true) with check (true);
-- create policy "auth full" on public.app_settings for all to authenticated using (true) with check (true);
-- create policy "auth full" on public.fo_orders    for all to authenticated using (true) with check (true);
