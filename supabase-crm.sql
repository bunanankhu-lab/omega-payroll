-- ============================================================
-- ตารางระบบ CRM (ลูกค้า/ดีล/กิจกรรม/งาน) — ใช้กับหน้า crm.html
-- วิธีใช้: Supabase Dashboard → SQL Editor → วางทั้งไฟล์ → Run
-- ============================================================

-- 1) ลูกค้า (Contacts)
create table if not exists public.crm_contacts (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  phone      text not null default '',
  email      text not null default '',
  company    text not null default '',
  position   text not null default '',
  address    text not null default '',
  tags       text not null default '',          -- คั่นด้วยจุลภาค เช่น "VIP, โรงงาน"
  created_at timestamptz not null default now()
);

-- 2) ดีล (Sales Pipeline)
create table if not exists public.crm_deals (
  id             uuid primary key default gen_random_uuid(),
  title          text not null,
  value          numeric not null default 0,
  stage          text not null default 'LEAD',  -- LEAD/QUALIFIED/PROPOSAL/NEGOTIATION/WON/LOST
  probability    int not null default 50,
  expected_close date,
  notes          text not null default '',
  closed_at      timestamptz,                   -- บันทึกอัตโนมัติเมื่อย้ายเข้า WON/LOST
  contact_id     uuid references public.crm_contacts(id) on delete set null,
  created_at     timestamptz not null default now()
);

-- 3) กิจกรรม (โทร/ประชุม/อีเมล/โน้ต)
create table if not exists public.crm_activities (
  id         uuid primary key default gen_random_uuid(),
  type       text not null default 'NOTE',      -- CALL/MEETING/EMAIL/NOTE
  title      text not null,
  detail     text not null default '',
  contact_id uuid references public.crm_contacts(id) on delete cascade,
  deal_id    uuid references public.crm_deals(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- 4) งาน (Tasks)
create table if not exists public.crm_tasks (
  id         uuid primary key default gen_random_uuid(),
  title      text not null,
  due_date   date,
  done       boolean not null default false,
  contact_id uuid references public.crm_contacts(id) on delete set null,
  deal_id    uuid references public.crm_deals(id) on delete set null,
  created_at timestamptz not null default now()
);

-- ============================================================
-- RLS: ช่วงพัฒนา (DEV_BYPASS_LOGIN = true) ปล่อยปิดไว้เหมือนตารางอื่น
-- เมื่อเปิดระบบล็อกอินจริง ค่อยรันส่วนนี้ (เอา -- ออก):
-- ============================================================
-- alter table public.crm_contacts   enable row level security;
-- alter table public.crm_deals      enable row level security;
-- alter table public.crm_activities enable row level security;
-- alter table public.crm_tasks      enable row level security;
-- create policy "auth full" on public.crm_contacts   for all to authenticated using (true) with check (true);
-- create policy "auth full" on public.crm_deals      for all to authenticated using (true) with check (true);
-- create policy "auth full" on public.crm_activities for all to authenticated using (true) with check (true);
-- create policy "auth full" on public.crm_tasks      for all to authenticated using (true) with check (true);
