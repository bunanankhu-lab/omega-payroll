# ตั้งค่าแจ้งเตือน LINE (กลุ่มบริษัท)

ระบบส่งแจ้งเตือนเข้ากลุ่ม LINE ผ่าน **LINE Messaging API** โดยมี Vercel Function (`api/notify-line.js`)
เป็นตัวกลาง — หน้าเว็บเรียกฟังก์ชันนี้ ฟังก์ชันถือ token แล้วยิงเข้า LINE (token ไม่โผล่ในหน้าเว็บ)

```
index.html  ──POST /api/notify-line──►  Vercel Function  ──push──►  กลุ่ม LINE บริษัท
```

## สิ่งที่ต้องเตรียม (ทำครั้งเดียว)

### 1) Channel Access Token
1. ไปที่ https://developers.line.biz/console/ → เลือก Provider → Channel แบบ **Messaging API**
   (ถ้ายังไม่มี: สร้าง Provider แล้วสร้าง Messaging API channel ผูกกับ LINE Official Account ของบริษัท)
2. แท็บ **Messaging API** → หัวข้อ **Channel access token (long-lived)** → กด Issue → คัดลอกค่ามาเก็บ

### 2) Group ID ของกลุ่มบริษัท
LINE ไม่แสดง Group ID ตรง ๆ ต้องดึงจาก webhook event วิธีง่ายสุด:
1. เชิญ LINE OA (บอท) เข้ากลุ่มบริษัท
2. ที่ LINE Developers Console แท็บ **Messaging API** → เปิด **Use webhook** และตั้ง Webhook URL ชั่วคราว
   (เช่น https://webhook.site เพื่อดู payload)
3. พิมพ์ข้อความอะไรก็ได้ในกลุ่ม → ดู event ที่เข้ามา จะมี `"source": { "type": "group", "groupId": "Cxxxxxxxx..." }`
4. คัดลอก `groupId` มาเก็บ
> ส่งเข้าแชทส่วนตัวก็ได้ ใช้ `userId` แทน (จาก 1-1 chat event)

## ตั้งค่า Environment Variables บน Vercel

Vercel Dashboard → โปรเจกต์ → **Settings → Environment Variables** → เพิ่ม 3 ตัว
(เลือก scope ครบทั้ง Production / Preview / Development):

| Name | Value | จำเป็น |
|------|-------|--------|
| `LINE_CHANNEL_ACCESS_TOKEN` | Channel access token จากข้อ 1 | ✅ |
| `LINE_TARGET_ID` | Group ID (หรือ User ID) จากข้อ 2 | ✅ |
| `NOTIFY_SECRET` | รหัสลับสั้น ๆ กันคนนอกยิง API | ไม่บังคับ |

> ถ้าตั้ง `NOTIFY_SECRET` ต้องส่ง header `x-notify-secret` มาด้วยจากหน้าเว็บ
> (ตอนนี้หน้าเว็บยังไม่ได้ส่ง — แจ้งได้ถ้าต้องการเปิดใช้ แล้วผมจะเพิ่มให้)

หลังเพิ่ม env แล้ว ต้อง **Redeploy** หนึ่งครั้งเพื่อให้ค่ามีผล

## วิธีใช้งานในแอป

- **แท็บ สลิป** → ปุ่ม **💬 ส่งสลิปเข้า LINE** — ส่งรูปสลิป + สรุปยอดของพนักงานที่เลือก
- **แท็บ ภาพรวม** → ปุ่ม **💬 ส่งสรุปยอดเดือนนี้เข้า LINE** — ส่งสรุปยอดจ่ายทั้งบริษัทของเดือนนั้น (มี confirm ก่อนส่ง)

## หมายเหตุเรื่องรูปสลิป

LINE Messaging API ส่งรูปด้วย **URL สาธารณะ** เท่านั้น (ไม่รับ base64 ตรง ๆ)
ตอนนี้ฟังก์ชันอัปรูปขึ้น `0x0.st` (ฝากไฟล์ฟรี) ชั่วคราวเพื่อให้ได้ URL
ถ้าต้องการความเสถียร/เป็นส่วนตัวกว่า แนะนำเปลี่ยนไปเก็บใน **Supabase Storage** (bucket สาธารณะ)
— แจ้งได้ถ้าต้องการให้เปลี่ยน

## ทดสอบเร็ว ๆ (ไม่ต้องเปิดหน้าเว็บ)

หลัง deploy แล้ว ยิงทดสอบจาก terminal:

```bash
curl -X POST https://<โดเมนของคุณ>.vercel.app/api/notify-line \
  -H "Content-Type: application/json" \
  -d '{"text":"ทดสอบแจ้งเตือนจากระบบเงินเดือน ✅"}'
```

ถ้าได้ `{"ok":true}` และข้อความเด้งเข้ากลุ่ม = ใช้งานได้แล้ว
