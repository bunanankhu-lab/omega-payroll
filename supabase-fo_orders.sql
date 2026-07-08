-- ============================================================
-- ตารางใบงาน FO + ใบถอด (Component Breakdown)
-- วิธีใช้: Supabase Dashboard → SQL Editor → วางสคริปต์นี้ → Run
-- ============================================================

create table if not exists public.fo_orders (
  id          uuid primary key default gen_random_uuid(),
  fo_no       text not null,                    -- เลขที่ใบงาน เช่น FO-6907-001
  customer    text not null,                    -- ลูกค้า / ร้าน
  site        text not null default '',         -- สถานที่ / สาขา
  job_desc    text not null default '',         -- รายละเอียดงาน / ขอบเขตงาน
  job_date    date,                             -- วันที่นัดงาน
  technician  text not null default '',         -- ช่างผู้รับผิดชอบ
  coordinator text not null default '',         -- ผู้ประสานงาน
  status      text not null default 'draft',    -- draft/picking/picked/onsite/done/billed
  items       jsonb not null default '[]'::jsonb, -- ใบถอด: [{name, spec, qty, unit, picked}]
  picked_by   text not null default '',         -- ผู้หยิบของ (คลังสินค้า)
  note        text not null default '',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- เลขที่ FO ห้ามซ้ำ
create unique index if not exists fo_orders_fo_no_key on public.fo_orders (fo_no);

-- รายละเอียดเครื่อง (เพิ่ม 2026-07-06 — รันซ้ำได้ ไม่กระทบข้อมูลเดิม)
alter table public.fo_orders add column if not exists machine_model  text not null default '';  -- ยี่ห้อ/รุ่นเครื่อง
alter table public.fo_orders add column if not exists machine_serial text not null default '';  -- Serial No.

-- ลายเซ็นลูกค้าอนุมัติปิดใบงาน (เพิ่ม 2026-07-08 — รันซ้ำได้ ไม่กระทบข้อมูลเดิม)
alter table public.fo_orders add column if not exists sign_data text not null default '';  -- รูปลายเซ็น (PNG data URL)
alter table public.fo_orders add column if not exists sign_name text not null default '';  -- ชื่อลูกค้าผู้เซ็น
alter table public.fo_orders add column if not exists sign_at   timestamptz;               -- เวลาที่เซ็น

-- ============================================================
-- หมายเหตุ RLS: ตอนนี้แอปอยู่โหมดพัฒนา (DEV_BYPASS_LOGIN = true)
-- ตารางที่สร้างด้วย SQL จะ "ปิด RLS" โดยอัตโนมัติ เหมือนตารางอื่นๆ ที่ใช้อยู่
-- เมื่อเปิดระบบล็อกอินจริง ให้รันส่วนล่างนี้ด้วย (เอา -- ออก):
-- ============================================================
-- alter table public.fo_orders enable row level security;
-- create policy "authenticated full access" on public.fo_orders
--   for all to authenticated using (true) with check (true);
