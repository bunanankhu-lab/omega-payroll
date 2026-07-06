-- ============================================================
-- ระบบ Authentication + Role (ADMIN / SALES) สำหรับ CRM
-- - SALES เห็นเฉพาะข้อมูลของตัวเอง (owner_id) · ADMIN เห็นทั้งหมด
-- - บังคับที่ระดับฐานข้อมูลด้วย RLS (ปลอดภัยจริง ไม่ใช่แค่ซ่อนในหน้าเว็บ)
-- วิธีใช้: Supabase Dashboard → SQL Editor → วางทั้งไฟล์ → Run (รันซ้ำได้)
-- ============================================================

create extension if not exists pgcrypto with schema extensions;

-- 1) โปรไฟล์ผู้ใช้ CRM + role
create table if not exists public.crm_profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  email      text not null default '',
  name       text not null default '',
  role       text not null default 'SALES' check (role in ('ADMIN', 'SALES')),
  created_at timestamptz not null default now()
);

-- 2) ฟังก์ชันอ่าน role ของผู้ใช้ปัจจุบัน (security definer กัน RLS วนซ้ำ)
create or replace function public.crm_role()
returns text
language sql stable security definer
set search_path = public
as $$
  select role from public.crm_profiles where id = auth.uid()
$$;
grant execute on function public.crm_role() to authenticated;

-- 3) คอลัมน์เจ้าของข้อมูล
alter table public.crm_contacts   add column if not exists owner_id uuid default auth.uid();
alter table public.crm_deals      add column if not exists owner_id uuid default auth.uid();
alter table public.crm_activities add column if not exists owner_id uuid default auth.uid();
alter table public.crm_tasks      add column if not exists owner_id uuid default auth.uid();

-- 4) เปิด RLS (เฉพาะตาราง CRM — ตารางเงินเดือนไม่ถูกแตะ)
alter table public.crm_contacts   enable row level security;
alter table public.crm_deals      enable row level security;
alter table public.crm_activities enable row level security;
alter table public.crm_tasks      enable row level security;
alter table public.crm_profiles   enable row level security;

-- 5) นโยบาย: ADMIN เห็น/แก้ทั้งหมด · SALES เฉพาะแถวที่ตัวเองเป็นเจ้าของ
drop policy if exists "crm all" on public.crm_contacts;
create policy "crm all" on public.crm_contacts for all to authenticated
  using (public.crm_role() = 'ADMIN' or (public.crm_role() = 'SALES' and owner_id = auth.uid()))
  with check (public.crm_role() = 'ADMIN' or (public.crm_role() = 'SALES' and owner_id = auth.uid()));

drop policy if exists "crm all" on public.crm_deals;
create policy "crm all" on public.crm_deals for all to authenticated
  using (public.crm_role() = 'ADMIN' or (public.crm_role() = 'SALES' and owner_id = auth.uid()))
  with check (public.crm_role() = 'ADMIN' or (public.crm_role() = 'SALES' and owner_id = auth.uid()));

drop policy if exists "crm all" on public.crm_activities;
create policy "crm all" on public.crm_activities for all to authenticated
  using (public.crm_role() = 'ADMIN' or (public.crm_role() = 'SALES' and owner_id = auth.uid()))
  with check (public.crm_role() = 'ADMIN' or (public.crm_role() = 'SALES' and owner_id = auth.uid()));

drop policy if exists "crm all" on public.crm_tasks;
create policy "crm all" on public.crm_tasks for all to authenticated
  using (public.crm_role() = 'ADMIN' or (public.crm_role() = 'SALES' and owner_id = auth.uid()))
  with check (public.crm_role() = 'ADMIN' or (public.crm_role() = 'SALES' and owner_id = auth.uid()));

-- โปรไฟล์: ทุกคนที่ล็อกอินอ่านได้ (ไว้แสดงชื่อเจ้าของ) แต่ ADMIN เท่านั้นที่จัดการได้
drop policy if exists "profiles read" on public.crm_profiles;
create policy "profiles read" on public.crm_profiles for select to authenticated using (true);
drop policy if exists "profiles admin insert" on public.crm_profiles;
create policy "profiles admin insert" on public.crm_profiles for insert to authenticated
  with check (public.crm_role() = 'ADMIN');
drop policy if exists "profiles admin update" on public.crm_profiles;
create policy "profiles admin update" on public.crm_profiles for update to authenticated
  using (public.crm_role() = 'ADMIN') with check (public.crm_role() = 'ADMIN');
drop policy if exists "profiles admin delete" on public.crm_profiles;
create policy "profiles admin delete" on public.crm_profiles for delete to authenticated
  using (public.crm_role() = 'ADMIN');

-- ============================================================
-- 6) Seed ผู้ใช้: admin 1 คน + sales 2 คน (รันซ้ำได้ — ไม่ทับรหัสผ่านของผู้ใช้ที่มีอยู่แล้ว)
--    ⚠️ เปลี่ยน CHANGE_ME_xxx เป็นรหัสผ่านจริงก่อนรัน (อย่า commit รหัสจริงลง git)
-- ============================================================
do $$
declare
  u record;
  uid uuid;
begin
  for u in
    select * from (values
      ('admin@omegaesan.com',  'CHANGE_ME_ADMIN',  'ผู้ดูแลระบบ', 'ADMIN'),
      ('sales1@omegaesan.com', 'CHANGE_ME_SALES1', 'ฝ่ายขาย 1',  'SALES'),
      ('sales2@omegaesan.com', 'CHANGE_ME_SALES2', 'ฝ่ายขาย 2',  'SALES')
    ) as t(email, pw, name, role)
  loop
    select id into uid from auth.users where email = u.email;
    if uid is null then
      uid := gen_random_uuid();
      insert into auth.users (
        instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
        raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
        confirmation_token, recovery_token, email_change, email_change_token_new,
        email_change_token_current, phone_change, phone_change_token, reauthentication_token
      ) values (
        '00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated', u.email,
        extensions.crypt(u.pw, extensions.gen_salt('bf')), now(),
        '{"provider":"email","providers":["email"]}'::jsonb, jsonb_build_object('name', u.name),
        now(), now(), '', '', '', '', '', '', '', ''
      );
    else
      -- ผู้ใช้มีอยู่แล้ว: ยืนยันอีเมลให้ แต่ไม่แตะรหัสผ่านเดิม
      update auth.users set
        email_confirmed_at = coalesce(email_confirmed_at, now()),
        confirmation_token = '', recovery_token = ''
      where id = uid;
    end if;

    if not exists (select 1 from auth.identities where provider = 'email' and user_id = uid) then
      insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
      values (gen_random_uuid(), uid, uid::text,
        jsonb_build_object('sub', uid::text, 'email', u.email, 'email_verified', true),
        'email', now(), now(), now());
    end if;

    insert into public.crm_profiles (id, email, name, role)
    values (uid, u.email, u.name, u.role)
    on conflict (id) do update set email = excluded.email, name = excluded.name, role = excluded.role;
  end loop;
end $$;

-- ============================================================
-- 7) ข้อมูลตัวอย่าง (แท็ก "ตัวอย่าง" ลบทีหลังได้) — ใส่เฉพาะตอนตารางยังว่าง
-- ============================================================
do $$
declare
  s1 uuid; s2 uuid;
  c1 uuid; c2 uuid; c3 uuid; c4 uuid;
  d1 uuid; d2 uuid; d3 uuid; d4 uuid;
begin
  if exists (select 1 from public.crm_contacts) then return; end if;
  select id into s1 from public.crm_profiles where email = 'sales1@omegaesan.com';
  select id into s2 from public.crm_profiles where email = 'sales2@omegaesan.com';
  if s1 is null or s2 is null then return; end if;

  insert into public.crm_contacts (name, phone, email, company, position, address, tags, owner_id)
  values ('สมชาย ใจดี', '081-234-5678', 'somchai@siamtrading.co.th', 'บจก. สยามเทรดดิ้ง', 'ผู้จัดการฝ่ายจัดซื้อ', 'กรุงเทพมหานคร', 'ตัวอย่าง, VIP', s1)
  returning id into c1;
  insert into public.crm_contacts (name, phone, email, company, position, address, tags, owner_id)
  values ('วิภาดา ศรีสุข', '089-876-5432', 'wipada@koratfoods.com', 'บมจ. โคราชฟู้ดส์', 'กรรมการผู้จัดการ', 'นครราชสีมา', 'ตัวอย่าง, โรงงาน', s1)
  returning id into c2;
  insert into public.crm_contacts (name, phone, email, company, position, address, tags, owner_id)
  values ('ณัฐพล วงศ์สว่าง', '062-111-2233', 'nattapon@esanmat.co.th', 'หจก. อีสานค้าวัสดุ', 'เจ้าของกิจการ', 'ขอนแก่น', 'ตัวอย่าง, ค้าปลีก', s2)
  returning id into c3;
  insert into public.crm_contacts (name, phone, email, company, position, address, tags, owner_id)
  values ('ปรียานุช ทองดี', '095-444-5566', 'preeyanuch@udonlogistics.com', 'บจก. อุดรโลจิสติกส์', 'ผู้จัดการทั่วไป', 'อุดรธานี', 'ตัวอย่าง, ขนส่ง', s2)
  returning id into c4;

  insert into public.crm_deals (title, value, stage, probability, expected_close, notes, contact_id, owner_id)
  values ('ระบบกรองน้ำโรงงานโคราชฟู้ดส์', 850000, 'NEGOTIATION', 70, current_date + 10, 'รอเคาะราคารอบสุดท้าย', c2, s1)
  returning id into d1;
  insert into public.crm_deals (title, value, stage, probability, expected_close, notes, closed_at, contact_id, owner_id)
  values ('สัญญาบำรุงรักษารายปี', 240000, 'WON', 100, current_date - 3, 'เซ็นสัญญาเรียบร้อย', now() - interval '3 days', c1, s1)
  returning id into d2;
  insert into public.crm_deals (title, value, stage, probability, expected_close, notes, contact_id, owner_id)
  values ('เครื่องกรองน้ำ 12 สาขา', 320000, 'PROPOSAL', 55, current_date + 21, 'ส่งใบเสนอราคาแล้ว', c3, s2)
  returning id into d3;
  insert into public.crm_deals (title, value, stage, probability, expected_close, notes, contact_id, owner_id)
  values ('งานติดตั้งระบบน้ำดื่มสำนักงาน', 150000, 'LEAD', 25, current_date + 45, 'ได้รายชื่อจากงานแสดงสินค้า', c4, s2)
  returning id into d4;

  insert into public.crm_activities (type, title, detail, contact_id, deal_id, owner_id) values
    ('MEETING', 'ประชุมสรุปขอบเขตงาน', 'สรุป requirement กับทีมลูกค้าครบแล้ว', c2, d1, s1),
    ('CALL', 'โทรติดตามใบเสนอราคา', 'ลูกค้าขอเวลาพิจารณาถึงสิ้นเดือน', c3, d3, s2),
    ('EMAIL', 'ส่งสัญญาฉบับลงนาม', 'ลูกค้าลงนามครบถ้วน', c1, d2, s1);

  insert into public.crm_tasks (title, due_date, done, contact_id, deal_id, owner_id) values
    ('ส่งใบเสนอราคาแก้ไข', current_date - 1, false, c2, d1, s1),
    ('เตรียมเอกสารเดโมสินค้า', current_date, false, c3, d3, s2),
    ('นัดประชุม kickoff', current_date + 3, false, c1, d2, s1),
    ('โทรหาลูกค้าใหม่จากงานแสดงสินค้า', current_date + 5, false, c4, d4, s2);
end $$;
