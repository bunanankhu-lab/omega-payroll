// Vercel Serverless Function — ตัวกลางส่งข้อความเข้า LINE
// หน้าเว็บ (index.html) เรียก POST /api/notify-line  →  ฟังก์ชันนี้ยิงเข้า LINE Messaging API
//
// เหตุผลที่ต้องมีตัวกลาง:
//   1) LINE บล็อกการเรียกตรงจาก browser (CORS)
//   2) Channel Access Token ต้องเก็บฝั่งเซิร์ฟเวอร์ ห้ามฝังใน index.html (ใครก็เปิด source เห็น)
//
// ตั้งค่า Environment Variables บน Vercel (Project → Settings → Environment Variables):
//   LINE_CHANNEL_ACCESS_TOKEN = <Channel Access Token ของ LINE OA>
//   LINE_TARGET_ID            = <Group ID ของกลุ่มบริษัท (หรือ User ID)>
//   NOTIFY_SECRET             = <รหัสลับสั้น ๆ กันคนนอกยิง API> (ไม่บังคับ แต่แนะนำให้ตั้ง)

export default async function handler(req, res) {
  // ---- CORS (เผื่อเปิดจากโดเมนอื่น/ทดสอบในเครื่อง) ----
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, x-notify-secret");
  if (req.method === "OPTIONS") return res.status(204).end();

  if (req.method !== "POST") {
    return res.status(405).json({ ok: false, error: "ใช้ได้เฉพาะ POST" });
  }

  const TOKEN = process.env.LINE_CHANNEL_ACCESS_TOKEN;
  const TARGET = process.env.LINE_TARGET_ID;
  const SECRET = process.env.NOTIFY_SECRET;

  if (!TOKEN || !TARGET) {
    return res.status(500).json({
      ok: false,
      error: "ยังไม่ได้ตั้งค่า LINE_CHANNEL_ACCESS_TOKEN หรือ LINE_TARGET_ID บน Vercel",
    });
  }

  // ---- ตรวจรหัสลับ (ถ้าตั้งไว้) ----
  if (SECRET) {
    const sent = req.headers["x-notify-secret"];
    if (sent !== SECRET) {
      return res.status(401).json({ ok: false, error: "รหัสลับไม่ถูกต้อง" });
    }
  }

  // ---- อ่าน body ----
  let body = req.body;
  if (typeof body === "string") {
    try { body = JSON.parse(body); } catch { body = {}; }
  }
  body = body || {};

  // รองรับ 2 แบบ:
  //   { text: "ข้อความ" }                         → ส่งข้อความธรรมดา
  //   { imageBase64: "...", text: "คำบรรยาย" }    → ส่งข้อความ + รูป (เช่น สลิป)
  const text = (body.text || "").toString().slice(0, 4900); // LINE จำกัด 5000 ตัวอักษร
  const imageBase64 = body.imageBase64; // dataURL หรือ base64 ของรูป PNG/JPG

  const messages = [];
  if (text) messages.push({ type: "text", text });

  // ---- ถ้ามีรูป ต้องอัปขึ้นที่สาธารณะก่อน เพราะ LINE ต้องการ URL (ไม่รับ base64 ตรง ๆ) ----
  if (imageBase64) {
    const uploaded = await uploadImage(imageBase64);
    if (uploaded) {
      messages.push({
        type: "image",
        originalContentUrl: uploaded,
        previewImageUrl: uploaded,
      });
    } else if (!text) {
      // อัปรูปไม่ได้ และไม่มีข้อความ → แจ้งกลับ
      return res.status(502).json({ ok: false, error: "อัปโหลดรูปไม่สำเร็จ และไม่มีข้อความให้ส่ง" });
    }
  }

  if (!messages.length) {
    return res.status(400).json({ ok: false, error: "ไม่มีข้อความหรือรูปให้ส่ง" });
  }

  // ---- ยิงเข้า LINE (push message) ----
  try {
    const r = await fetch("https://api.line.me/v2/bot/message/push", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: "Bearer " + TOKEN,
      },
      body: JSON.stringify({ to: TARGET, messages }),
    });

    if (!r.ok) {
      const detail = await r.text();
      return res.status(502).json({ ok: false, error: "LINE ปฏิเสธ: " + detail });
    }
    return res.status(200).json({ ok: true });
  } catch (err) {
    return res.status(500).json({ ok: false, error: "ส่งไม่สำเร็จ: " + (err && err.message ? err.message : String(err)) });
  }
}

// อัปรูปขึ้น 0x0.st (ฝากไฟล์ฟรี ไม่ต้องสมัคร) แล้วคืน URL สาธารณะให้ LINE ดึงไปแสดง
// ถ้าต้องการความเสถียร/เป็นส่วนตัวกว่านี้ แนะนำเปลี่ยนไปใช้ Supabase Storage แทน (ดูหมายเหตุท้ายไฟล์)
async function uploadImage(imageBase64) {
  try {
    // ตัด prefix "data:image/png;base64," ถ้ามี
    const comma = imageBase64.indexOf(",");
    const raw = comma >= 0 ? imageBase64.slice(comma + 1) : imageBase64;
    const buf = Buffer.from(raw, "base64");

    const form = new FormData();
    const blob = new Blob([buf], { type: "image/png" });
    form.append("file", blob, "slip.png");

    const r = await fetch("https://0x0.st", { method: "POST", body: form });
    if (!r.ok) return null;
    const url = (await r.text()).trim();
    return url.startsWith("http") ? url : null;
  } catch {
    return null;
  }
}

// ── หมายเหตุ: ส่งรูปผ่าน Supabase Storage (ทางเลือกที่เสถียร/เป็นส่วนตัวกว่า) ──
// แทนที่ uploadImage() ด้วยการอัปขึ้น bucket สาธารณะของ Supabase แล้วใช้ public URL
// ต้องสร้าง bucket "slips" (public) และตั้ง env SUPABASE_SERVICE_KEY เพิ่ม
// แจ้งได้ถ้าต้องการให้เปลี่ยนเป็นแบบนี้
