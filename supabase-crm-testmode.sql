-- ============================================================
-- โหมดทดสอบ CRM: ปิด RLS ชั่วคราว (ใช้คู่กับ DEV_BYPASS_LOGIN = true ใน crm.html)
-- ⚠️ ระหว่างนี้ใครมีลิงก์ก็เข้าถึงข้อมูล CRM ได้โดยไม่ต้องล็อกอิน
-- ============================================================
alter table public.crm_contacts   disable row level security;
alter table public.crm_deals      disable row level security;
alter table public.crm_activities disable row level security;
alter table public.crm_tasks      disable row level security;
alter table public.crm_profiles   disable row level security;

-- ============================================================
-- เปิดระบบล็อกอินกลับ: ตั้ง DEV_BYPASS_LOGIN = false ใน crm.html
-- แล้วรันส่วนนี้ (เอา -- ออก) — นโยบายสิทธิ์เดิมยังอยู่ครบ ไม่ต้องสร้างใหม่
-- ============================================================
-- alter table public.crm_contacts   enable row level security;
-- alter table public.crm_deals      enable row level security;
-- alter table public.crm_activities enable row level security;
-- alter table public.crm_tasks      enable row level security;
-- alter table public.crm_profiles   enable row level security;
