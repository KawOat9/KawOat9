#!/bin/sh
# ============================================================
#  แปลงธีม Telegram.sh  (เวอร์ชัน 2)
#  ตัวแปลงธีม Telegram ข้ามแพลตฟอร์ม — รันได้บน iSH / Alpine / Linux / macOS
#  ต้องการแค่ sh + awk + sed + grep + tr (busybox ก็พอ)
#
#  รูปแบบที่รองรับ (ตรวจอัตโนมัติ ทั้งขาเข้าและขาออก)
#    ios      .tgios-theme              Telegram iOS
#    android  .attheme (key=ตัวเลข ARGB) และข้อความ hex (key: #RRGGBB[AA])
#    desktop  .tdesktop-theme (zip) / .tdesktop-palette / colors.tdesktop-theme
#
#  วิธีใช้
#    sh "แปลงธีม Telegram.sh"                          เมนูโต้ตอบ
#    sh "แปลงธีม Telegram.sh" [-t ชนิดผลลัพธ์] [-m โหมดสี] ต้นทาง [ผลลัพธ์]
#
#    -t ios | android | android-txt | desktop | desktop-zip   (ไม่ใส่ = เหมือนต้นทาง)
#    -m keep | light | dark | flip                            (ไม่ใส่ = keep คงโหมดเดิม)
#
#  ตัวอย่าง
#    ... -m light Mocha.tgios-theme                 มืด -> สว่าง
#    ... -t ios Vanilla.txt                         Android -> iOS
#    ... -t desktop -m dark MyTheme.tgios-theme     iOS -> Desktop (บังคับโหมดมืด)
#    ... light|android ...                           คำสั่งแบบเดิมของเวอร์ชัน 1 (ยังใช้ได้)
#
#  ข้อควรรู้
#    - แปลงรูปแบบเดียวกัน (เช่น iOS->iOS) จะคงโครงเดิมไว้ทั้งหมด สลับสว่าง/มืดโดยกลับค่าความสว่างของทุกสี
#    - แปลงข้ามรูปแบบ (เช่น iOS->Desktop) เป็นการประมาณสีตามบทบาท (พื้นหลัง/ตัวอักษร/accent/ลิงก์/ฟองแชท)
#      ใช้แม่แบบคีย์ของแพลตฟอร์มปลายทางที่ฝังไว้ในสคริปต์นี้ จึงอาจต้องปรับบางจุดเอง
#    - ธีม Catppuccin Mocha -> สว่าง ใช้ตารางสี Latte ตรง ๆ (ผลเหมือนเวอร์ชัน 1)
#    - รูปพื้นหลังของ Android (.attheme: ส่วน WPS..WPE) ไม่ถูกคัดลอก / Desktop zip -> zip จะคงรูปเดิมไว้
#    - .tdesktop-theme (zip) ต้องมี unzip และ zip (iSH: apk add zip unzip) ถ้าไม่มี zip จะสร้าง .tdesktop-palette แทน
# ============================================================

LC_ALL=C; export LC_ALL
VERSION="2.0"

# ---------- โฟลเดอร์ชั่วคราว + ลบทิ้งตอนจบ ----------
TMP=$(mktemp -d 2>/dev/null || { mkdir -p /tmp/tgconv.$$ && echo /tmp/tgconv.$$; })
if [ -n "$TGCONV_KEEP" ]; then echo "[debug] TMP=$TMP" >&2; else trap 'rm -rf "$TMP"' EXIT INT TERM; fi

die() { echo "ผิดพลาด: $*" >&2; exit 1; }
note() { echo "หมายเหตุ: $*" >&2; }

# ============================================================
#  ไลบรารี awk: คำนวณสี / แมปสี / สลับสว่าง-มืด / อ่าน-เขียนรูปแบบไฟล์
# ============================================================
cat > "$TMP/lib.awk" <<'LIB_EOF'
# ---------- ฟังก์ชันสีพื้นฐาน ----------
function h2d(s,  i, v) {                       # hex -> เลขฐานสิบ
  v = 0; s = toupper(s)
  for (i = 1; i <= length(s); i++) v = v * 16 + index("0123456789ABCDEF", substr(s, i, 1)) - 1
  return v
}
function d2h(v) { v = int(v + 0.5); if (v < 0) v = 0; if (v > 255) v = 255; return sprintf("%02X", v) }
function cr(h) { return h2d(substr(h, 1, 2)) }
function cg(h) { return h2d(substr(h, 3, 2)) }
function cb(h) { return h2d(substr(h, 5, 2)) }
function rgb(r, g, b) { return d2h(r) d2h(g) d2h(b) }
function lum(h) { return (0.299 * cr(h) + 0.587 * cg(h) + 0.114 * cb(h)) / 255 }   # ความสว่างโดยประมาณ
function lin(c) { c = c / 255; return (c <= 0.03928) ? c / 12.92 : ((c + 0.055) / 1.055) ^ 2.4 }
function wl(h) { return 0.2126 * lin(cr(h)) + 0.7152 * lin(cg(h)) + 0.0722 * lin(cb(h)) }   # WCAG
function contrast(a, b,  x, y, t) { x = wl(a); y = wl(b); if (x < y) { t = x; x = y; y = t } return (x + 0.05) / (y + 0.05) }
function mixc(a, b, t) { return rgb(cr(a) * (1 - t) + cr(b) * t, cg(a) * (1 - t) + cg(b) * t, cb(a) * (1 - t) + cb(b) * t) }
function chroma(h,  mx, mn) {
  mx = cr(h); if (cg(h) > mx) mx = cg(h); if (cb(h) > mx) mx = cb(h)
  mn = cr(h); if (cg(h) < mn) mn = cg(h); if (cb(h) < mn) mn = cb(h)
  return mx - mn
}
function dist(a, b,  x, y, z) { x = cr(a) - cr(b); y = cg(a) - cg(b); z = cb(a) - cb(b); return sqrt(x * x + y * y + z * z) }
function shift(g, c, a) { return rgb(cr(g) + cr(c) - cr(a), cg(g) + cg(c) - cg(a), cb(g) + cb(c) - cb(a)) }

# ---------- HSL ----------
function hsl(h,  r, g, b, mx, mn, d) {         # ผลลัพธ์อยู่ในตัวแปร HH SS LL
  r = cr(h) / 255; g = cg(h) / 255; b = cb(h) / 255
  mx = r; if (g > mx) mx = g; if (b > mx) mx = b
  mn = r; if (g < mn) mn = g; if (b < mn) mn = b
  LL = (mx + mn) / 2; d = mx - mn
  if (d == 0) { HH = 0; SS = 0; return }
  SS = (LL > 0.5) ? d / (2 - mx - mn) : d / (mx + mn)
  if (mx == r) HH = (g - b) / d + ((g < b) ? 6 : 0)
  else if (mx == g) HH = (b - r) / d + 2
  else HH = (r - g) / d + 4
  HH = HH * 60
}
function hue2rgb(p, q, t) {
  if (t < 0) t += 1
  if (t > 1) t -= 1
  if (t < 1 / 6) return p + (q - p) * 6 * t
  if (t < 1 / 2) return q
  if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6
  return p
}
function fromhsl(h, s, l,  q, p, r, g, b) {
  h = h / 360
  if (s == 0) { r = l; g = l; b = l }
  else {
    q = (l < 0.5) ? l * (1 + s) : l + s - l * s; p = 2 * l - q
    r = hue2rgb(p, q, h + 1 / 3); g = hue2rgb(p, q, h); b = hue2rgb(p, q, h - 1 / 3)
  }
  return rgb(r * 255, g * 255, b * 255)
}

# ---------- สลับสว่าง<->มืด (กลับค่าความสว่าง) ----------
function flipc(h, dir,  hh, ss, ll, l2) {
  hsl(h); hh = HH; ss = SS; ll = LL
  l2 = 1 - ll
  # ขาวล้วนในธีมสว่างมักใช้เป็นพื้นยกระดับ (การ์ด/ฟองแชท) -> โหมดมืดต้องสว่างกว่าพื้นหลังเล็กน้อย ไม่ใช่ดำสนิท
  if (dir == "dark" && ll >= 0.985 && chroma(h) < 12) l2 = 0.17
  if (chroma(h) >= 60) {                        # สีสดจริง (วัดจาก chroma ไม่ใช่ HSL เพราะสีมืดมีค่า S สูงเกินจริง)
    if (dir == "light") { if (l2 < 0.28) l2 = 0.28; if (l2 > 0.50) l2 = 0.50 }
    else                { if (l2 < 0.55) l2 = 0.55; if (l2 > 0.78) l2 = 0.78 }
  }
  return fromhsl(hh, ss, l2)
}

# ---------- แมปสีตามบทบาท (remap) ----------
function setup(  i, j, m, k, r, tl, tt, n) {
  n = split("BG SURF SURF2 INBUB MUTED SUB TXT", NN, " ")
  for (i = 1; i <= n; i++) ISR[NN[i]] = 1
  m = 0
  for (i = 1; i <= n; i++) { r = NN[i]; if ((r in TR) && (r in GR)) { m++; RL[m] = lum(TR[r]); RT[m] = GR[r] } }
  for (i = 2; i <= m; i++)                      # เรียงบันไดสีเทาตามความสว่างของแม่แบบ
    for (j = i; j > 1 && RL[j - 1] > RL[j]; j--) {
      tl = RL[j]; RL[j] = RL[j - 1]; RL[j - 1] = tl
      tt = RT[j]; RT[j] = RT[j - 1]; RT[j - 1] = tt
    }
  k = 0
  for (i = 1; i <= m; i++) {
    if (k > 0 && RL[i] - NL[k] < 0.012) continue
    k++; NL[k] = RL[i]; NT[k] = RT[i]
  }
  nramp = k
  nch = 0                                       # จุดยึดสีสด = ทุกบทบาทที่ไม่ใช่สีเทา
  for (i = 1; i <= nord; i++) {
    r = ORD[i]
    if (!(r in ISR) && (r in GR) && chroma(TR[r]) >= 12) CH[++nch] = r
  }
}
function ramp(c,  L, i, t) {
  if (nramp == 0) return c
  L = lum(c)
  if (L <= NL[1]) return NT[1]
  if (L >= NL[nramp]) return NT[nramp]
  for (i = 1; i < nramp; i++)
    if (L <= NL[i + 1]) { t = (L - NL[i]) / (NL[i + 1] - NL[i]); return mixc(NT[i], NT[i + 1], t) }
  return c
}
function remapc(c,  i, r, d, bd, best, h1, dh, cc, lim_h, lim_d) {
  bd = 1e9; best = ""
  hsl(c); h1 = HH; cc = chroma(c)
  for (i = 1; i <= nch; i++) {
    r = CH[i]; d = dist(c, TR[r])
    if (d == 0) { best = r; break }             # ตรงกับจุดยึดเป๊ะ
    if (cc >= 12 && cc >= 0.6 * chroma(TR[r])) {
      hsl(TR[r]); dh = h1 - HH; if (dh < 0) dh = -dh; if (dh > 180) dh = 360 - dh
      # จุดยึดสีจาง (chroma ต่ำ) ใช้เกณฑ์เข้มกว่า เพื่อไม่ให้ไปจับสีพื้นผิวที่อยู่ใกล้เคียง
      lim_h = (chroma(TR[r]) < 45) ? 20 : 30; lim_d = (chroma(TR[r]) < 45) ? 50 : 80
      if (dh <= lim_h && d <= lim_d && d < bd) { bd = d; best = r }
    }
  }
  if (best != "") return shift(GR[best], c, TR[best])
  if (cc >= 55) return c                        # สีสดอื่น ๆ (เช่น สีอวาตาร์) คงเดิม
  return ramp(c)
}

# ---------- แปลงทุกสีในค่าของบรรทัด ----------
function xform(s, key,  out, c, al, rest, pos, res, shadow) {
  shadow = (key ~ /[Ss]hadow|[Dd]im$|[Oo]verlay|[Ff]ade|[Ss]crim/)   # คีย์เกี่ยวกับเงา/ม่านบังสี ต้องคงเป็นสีดำ
  out = ""
  while (match(s, /#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]/)) {
    pos = RSTART
    c = toupper(substr(s, pos + 1, 6)); rest = substr(s, pos + 7); al = ""
    if (rest ~ /^[0-9A-Fa-f][0-9A-Fa-f]([^0-9A-Fa-f]|$)/) { al = toupper(substr(rest, 1, 2)); rest = substr(rest, 3) }
    if (shadow && chroma(c) <= 14 && lum(c) < 0.12) res = c   # เงา/ม่านบังสีดำ คงเดิม
    else if (OP == "flip") res = flipc(c, DIR)
    else res = remapc(c)
    out = out substr(s, 1, pos) res al
    s = rest
  }
  return out s
}

BEGIN {
  # ----- คำสั่งย่อย (พิมพ์ผลแล้วจบ) -----
  if (OP == "mix")  { print mixc(A, B, T); exit }
  if (OP == "mode") { print (lum(A) < 0.5) ? "dark" : "light"; exit }
  if (OP == "lowc") { print (contrast(A, B) < T + 0) ? 1 : 0; exit }
  if (OP == "best") {                           # เลือกสีตัวอักษรที่คอนทราสต์กับพื้น A สูงสุดจากรายการ C
    n = split(C, cand, " "); bestc = cand[1]; bv = -1
    for (i = 1; i <= n; i++) { v = contrast(A, cand[i]); if (v > bv) { bv = v; bestc = cand[i] } }
    print bestc; exit
  }
}

# ---------- ประมวลผลไฟล์ ----------
{ sub(/\r$/, "") }
FNR == 1 { f++ }
OP == "remap" && f == 1 { if (NF >= 2) { TR[$1] = toupper($2); ORD[++nord] = $1 } next }
OP == "remap" && f == 2 { if (NF >= 2) GR[$1] = toupper($2); next }
OP == "fliproles" { if (NF >= 2) print $1, flipc(toupper($2), DIR); next }

(OP == "remap" && f == 3) || OP == "flip" {
  if (OP == "remap" && !ready) { setup(); ready = 1 }
  i = index($0, ":")
  if (i == 0) { print; next }
  key = substr($0, 1, i - 1); val = substr($0, i + 1)
  if (key == "version") { print; next }
  print key ":" xform(val, key)
  next
}

# ---------- อ่านรูปแบบ Android (.attheme / ข้อความ hex) -> "key: #RRGGBB[AA]" ----------
OP == "norm_android" {
  if ($0 ~ /^WPS/) { inwp = 1; next }
  if ($0 ~ /^WPE/) { inwp = 0; next }
  if (inwp) next
  i = index($0, "=")
  if (i > 0) {
    k = substr($0, 1, i - 1); v = substr($0, i + 1)
    if (k ~ /^[A-Za-z0-9_]+$/ && v ~ /^-?[0-9]+$/) {      # ตัวเลข ARGB 32 บิตมีเครื่องหมาย
      v = v + 0; if (v < 0) v += 4294967296
      a = int(v / 16777216); r = int(v / 65536) % 256; g = int(v / 256) % 256; b = v % 256
      printf "%s: #%s%s%s%s\n", k, d2h(r), d2h(g), d2h(b), (a == 255 ? "" : d2h(a))
      next
    }
    if (k ~ /^[A-Za-z0-9_]+$/ && v ~ /^#/) { print k ": " v; next }
  }
  print
  next
}

# ---------- อ่านรูปแบบ Desktop -> "key: ค่า" (ตัดคอมเมนต์และ ;) ----------
OP == "norm_desktop" {
  s = $0; p = index(s, "//"); if (p > 0) s = substr(s, 1, p - 1)
  i = index(s, ":"); if (i == 0) next
  k = substr(s, 1, i - 1); v = substr(s, i + 1)
  gsub(/[ \t]/, "", k); if (k !~ /^[A-Za-z0-9_]+$/) next
  p = index(v, ";"); if (p > 0) v = substr(v, 1, p - 1)
  gsub(/[ \t]/, "", v); if (v == "") next
  print k ": " toupper(substr(v, 1, 1)) substr(v, 2)
  next
}
# แก้ค่าอ้างอิงของ Desktop (key: otherKey) ให้เป็นสีจริง
OP == "resolve" {
  i = index($0, ": "); if (i == 0) next
  k = substr($0, 1, i - 1); V[k] = substr($0, i + 2); KO[++nk] = k
  next
}

# ---------- เขียนรูปแบบ Android (.attheme: key=ตัวเลข ARGB) ----------
OP == "attheme" {
  i = index($0, ":"); if (i == 0) next
  k = substr($0, 1, i - 1); v = substr($0, i + 1); gsub(/[ \t]/, "", v)
  if (v !~ /^#[0-9A-Fa-f]+$/) next
  h = toupper(substr(v, 2))
  if (length(h) == 6) al = 255
  else if (length(h) == 8) al = h2d(substr(h, 7, 2))
  else next
  u = al * 16777216 + cr(h) * 65536 + cg(h) * 256 + cb(h)
  if (u >= 2147483648) u -= 4294967296
  printf "%s=%.0f\n", k, u
  next
}
# ---------- เขียนรูปแบบ Desktop (key: ค่า;) ----------
OP == "desktop" { i = index($0, ": "); if (i > 0) print $0 ";"; next }

END {
  if (OP == "resolve") {
    for (j = 1; j <= nk; j++) {
      k = KO[j]; v = V[k]; d = 0
      while (v !~ /^#/ && (v in V) && d < 40) { v = V[v]; d++ }
      if (v ~ /^#/) print k ": " toupper(v)
    }
  }
}
LIB_EOF

# ============================================================
#  แม่แบบโครงคีย์ของแต่ละแพลตฟอร์ม (ฝังไว้ในสคริปต์)
#  เรียก emit_tpl <ios|android|desktop> เพื่อเขียนลงไฟล์
# ============================================================
emit_tpl() {
  case $1 in
    ios) cat <<'TPL_IOS_EOF'
name: 🌿 Mocha
shortname: ctp_mocha_ios
basedOn: night
dark: true
intro_statusBar: white
intro_primaryText: #CDD6F4
intro_accentText: #6B9968
intro_disabledText: #575B55
intro_startButton: #A6E3A1
intro_dot: #BAC2DE
passcode_bg_top: #585B70
passcode_bg_bottom: #1E1E2E
passcode_button: #313244
root_statusBar: white
root_tabBar_background: #313244
root_tabBar_separator: #11111B
root_tabBar_icon: #7F849C
root_tabBar_selectedIcon: #6B9968
root_tabBar_text: #7F849C
root_tabBar_selectedText: #6B9968
root_tabBar_badgeBackground: #F38BA8
root_tabBar_badgeStroke: #F38BA8
root_tabBar_badgeText: #11111B
root_navBar_button: #6B9968
root_navBar_disabledButton: #575B55
root_navBar_primaryText: #CDD6F4
root_navBar_secondaryText: #BAC2DE
root_navBar_control: #BAC2DE
root_navBar_accentText: #6B9968
root_navBar_background: #313244
root_navBar_opaqueBackground: #313244
root_navBar_separator: #11111B
root_navBar_badgeFill: #F38BA8
root_navBar_badgeStroke: #F38BA8
root_navBar_badgeText: #11111B
root_navBar_segmentedBg: #1E1E2E
root_navBar_segmentedFg: #313244
root_navBar_segmentedText: #CDD6F4
root_navBar_segmentedDivider: #CDD6F47F
root_searchBar_background: #313244
root_searchBar_accent: #6B9968
root_searchBar_inputFill: #1E1E2E
root_searchBar_inputText: #CDD6F4
root_searchBar_inputPlaceholderText: #BAC2DE
root_searchBar_inputIcon: #BAC2DE
root_searchBar_inputClearButton: #BAC2DE
root_searchBar_separator: #1E1E2E
root_keyboard: dark
list_blocksBg: #1E1E2E
list_plainBg: #1E1E2E
list_primaryText: #CDD6F4
list_secondaryText: #CDD6F47F
list_disabledText: #CDD6F47F
list_accent: #6B9968
list_highlighted: #A6E3A1
list_destructive: #F38BA8
list_placeholderText: #CDD6F47F
list_itemBlocksBg: #313244
list_itemHighlightedBg: #313244
list_blocksSeparator: #11111B
list_plainSeparator: #11111B
list_disclosureArrow: #CDD6F47F
list_sectionHeaderText: #585B70
list_freeText: #585B70
list_freeTextError: #F38BA8
list_freeTextSuccess: #A6E3A1
list_freeMonoIcon: #585B70
list_switch_frame: #CDD6F47F
list_switch_handle: #11111B
list_switch_content: #A6E3A1
list_switch_positive: #A6E3A1
list_switch_negative: #F38BA8
list_disclosureActions_neutral1_bg: #A6E3A1
list_disclosureActions_neutral1_fg: #FFFFFF
list_disclosureActions_neutral2_bg: #FAB387
list_disclosureActions_neutral2_fg: #FFFFFF
list_disclosureActions_destructive_bg: #F38BA8
list_disclosureActions_destructive_fg: #FFFFFF
list_disclosureActions_constructive_bg: #A6E3A1
list_disclosureActions_constructive_fg: #FFFFFF
list_disclosureActions_accent_bg: #6B9968
list_disclosureActions_accent_fg: #FFFFFF
list_disclosureActions_warning_bg: #FAB387
list_disclosureActions_warning_fg: #FFFFFF
list_disclosureActions_inactive_bg: #1E1E2E
list_disclosureActions_inactive_fg: #CDD6F4
list_check_bg: #6B9968
list_check_stroke: #CDD6F47F
list_check_fg: #11111B
list_controlSecondary: #CDD6F47F
list_freeInputField_bg: #313244
list_freeInputField_stroke: #313244
list_freeInputField_placeholder: #CDD6F47F
list_freeInputField_primary: #CDD6F4
list_freeInputField_control: #CDD6F47F
list_mediaPlaceholder: #1E1E2E
list_scrollIndicator: #CDD6F47F
list_pageIndicatorInactive: #CDD6F466
list_inputClearButton: #BAC2DE
list_itemBarChart_color1: #6B9968
list_itemBarChart_color2: #CDD6F47F
list_itemBarChart_color3: #1E1E2E
list_itemInputField_bg: #181825
list_itemInputField_stroke: #181825
list_itemInputField_placeholder: #7F849C
list_itemInputField_primary: #CDD6F4
list_itemInputField_control: #7F849C
chatList_bg: #1E1E2E
chatList_itemSeparator: #11111B
chatList_itemBg: #1E1E2E
chatList_pinnedItemBg: #313244
chatList_itemHighlightedBg: #313244
chatList_pinnedItemHighlightedBg: #313244
chatList_itemSelectedBg: #313244
chatList_title: #CDD6F4
chatList_secretTitle: #A6E3A1
chatList_dateText: #CDD6F47F
chatList_authorName: #CDD6F4
chatList_messageText: #CDD6F47F
chatList_messageHighlightedText: #CDD6F4
chatList_messageDraftText: #F38BA8
chatList_checkmark: #A6E3A1
chatList_pendingIndicator: #CDD6F466
chatList_failedFill: #F38BA8
chatList_failedFg: #CDD6F4
chatList_muteIcon: #CDD6F466
chatList_unreadBadgeActiveBg: #6B9968
chatList_unreadBadgeActiveText: #11111B
chatList_unreadBadgeInactiveBg: #CDD6F466
chatList_unreadBadgeInactiveText: #1E1E2E
chatList_reactionBadgeActiveBg: #F38BA8
chatList_pinnedBadge: #CDD6F47F
chatList_pinnedSearchBar: #1E1E2E
chatList_regularSearchBar: #313244
chatList_sectionHeaderBg: #313244
chatList_sectionHeaderText: #CDD6F47F
chatList_verifiedIconBg: #A6E3A1
chatList_verifiedIconFg: #CDD6F4
chatList_secretIcon: #A6E3A1
chatList_pinnedArchiveAvatar_background_top: #89B4FA
chatList_pinnedArchiveAvatar_background_bottom: #89B4FA
chatList_pinnedArchiveAvatar_foreground: #CDD6F4
chatList_unpinnedArchiveAvatar_background_top: #585B70
chatList_unpinnedArchiveAvatar_background_bottom: #585B70
chatList_unpinnedArchiveAvatar_foreground: #1E1E2E
chatList_onlineDot: #A6E3A1
chatList_storyUnseen_top: #34C76F
chatList_storyUnseen_bottom: #3DA1FD
chatList_storyUnseenPrivate_top: #7CD636
chatList_storyUnseenPrivate_bottom: #26B470
chatList_storySeen_top: #D8D8E1
chatList_storySeen_bottom: #D8D8E1
chat_animateMessageColors: false
chat_message_incoming_bubble_withWp_bg: #313244
chat_message_incoming_bubble_withWp_gradientBg: #313244
chat_message_incoming_bubble_withWp_highlightedBg: #313244
chat_message_incoming_bubble_withWp_stroke: #313244
chat_message_incoming_bubble_withWp_reactionInactiveBg: #6B996819
chat_message_incoming_bubble_withWp_reactionInactiveFg: #6B9968
chat_message_incoming_bubble_withWp_reactionActiveBg: #6B9968
chat_message_incoming_bubble_withWp_reactionActiveFg: clear
chat_message_incoming_bubble_withWp_reactionInactiveMediaPlaceholder: #FFFFFF33
chat_message_incoming_bubble_withWp_reactionActiveMediaPlaceholder: #FFFFFF33
chat_message_incoming_bubble_withoutWp_bg: #313244
chat_message_incoming_bubble_withoutWp_gradientBg: #313244
chat_message_incoming_bubble_withoutWp_highlightedBg: #313244
chat_message_incoming_bubble_withoutWp_stroke: #313244
chat_message_incoming_bubble_withoutWp_reactionInactiveBg: #6B996819
chat_message_incoming_bubble_withoutWp_reactionInactiveFg: #6B9968
chat_message_incoming_bubble_withoutWp_reactionActiveBg: #6B9968
chat_message_incoming_bubble_withoutWp_reactionActiveFg: clear
chat_message_incoming_bubble_withoutWp_reactionInactiveMediaPlaceholder: #FFFFFF33
chat_message_incoming_bubble_withoutWp_reactionActiveMediaPlaceholder: #FFFFFF33
chat_message_incoming_primaryText: #CDD6F4
chat_message_incoming_secondaryText: #CDD6F47F
chat_message_incoming_linkText: #A6E3A1
chat_message_incoming_linkHighlight: #A6E3A17F
chat_message_incoming_scam: #F38BA8
chat_message_incoming_textHighlight: #FAB387
chat_message_incoming_accentText: #6B9968
chat_message_incoming_accentControl: #6B9968
chat_message_incoming_mediaActiveControl: #6B9968
chat_message_incoming_mediaInactiveControl: #A6E3A17F
chat_message_incoming_mediaControlInnerBg: #313244
chat_message_incoming_pendingActivity: #CDD6F47F
chat_message_incoming_fileTitle: #6B9968
chat_message_incoming_fileDescription: #CDD6F47F
chat_message_incoming_fileDuration: #CDD6F47F
chat_message_incoming_mediaPlaceholder: #1E1E2E
chat_message_incoming_polls_radioButton: #585B70
chat_message_incoming_polls_radioProgress: #6B9968
chat_message_incoming_polls_highlight: #6B99681E
chat_message_incoming_polls_separator: #11111B
chat_message_incoming_polls_bar: #6B9968
chat_message_incoming_polls_barIconForeground: #CDD6F4
chat_message_incoming_polls_barPositive: #A6E3A1
chat_message_incoming_polls_barNegative: #F38BA8
chat_message_incoming_actionButtonsBg_withWp: #1E1E2E7F
chat_message_incoming_actionButtonsBg_withoutWp: #1E1E2E7F
chat_message_incoming_actionButtonsStroke_withWp: #6C708626
chat_message_incoming_actionButtonsStroke_withoutWp: #6C708626
chat_message_incoming_actionButtonsText_withWp: #CDD6F4
chat_message_incoming_actionButtonsText_withoutWp: #CDD6F4
chat_message_incoming_textSelection: #6B996833
chat_message_incoming_textSelectionKnob: #6B9968
chat_message_outgoing_bubble_withWp_bg: #A6E3A1
chat_message_outgoing_bubble_withWp_gradientBg: #A6E3A1
chat_message_outgoing_bubble_withWp_highlightedBg: #91CA8D
chat_message_outgoing_bubble_withWp_stroke: clear
chat_message_outgoing_bubble_withWp_reactionInactiveBg: #25AD0D19
chat_message_outgoing_bubble_withWp_reactionInactiveFg: #25AD0D
chat_message_outgoing_bubble_withWp_reactionActiveBg: #25AD0D
chat_message_outgoing_bubble_withWp_reactionActiveFg: clear
chat_message_outgoing_bubble_withWp_reactionInactiveMediaPlaceholder: #FFFFFF33
chat_message_outgoing_bubble_withWp_reactionActiveMediaPlaceholder: #FFFFFF33
chat_message_outgoing_bubble_withoutWp_bg: #A6E3A1
chat_message_outgoing_bubble_withoutWp_gradientBg: #A6E3A1
chat_message_outgoing_bubble_withoutWp_highlightedBg: #91CA8D
chat_message_outgoing_bubble_withoutWp_stroke: clear
chat_message_outgoing_bubble_withoutWp_reactionInactiveBg: #25AD0D19
chat_message_outgoing_bubble_withoutWp_reactionInactiveFg: #25AD0D
chat_message_outgoing_bubble_withoutWp_reactionActiveBg: #25AD0D
chat_message_outgoing_bubble_withoutWp_reactionActiveFg: clear
chat_message_outgoing_bubble_withoutWp_reactionInactiveMediaPlaceholder: #FFFFFF33
chat_message_outgoing_bubble_withoutWp_reactionActiveMediaPlaceholder: #FFFFFF33
chat_message_outgoing_primaryText: #000000
chat_message_outgoing_secondaryText: #077C00CC
chat_message_outgoing_linkText: #004BAD
chat_message_outgoing_linkHighlight: #004BAD4C
chat_message_outgoing_scam: #FF3B30
chat_message_outgoing_textHighlight: #FAB387
chat_message_outgoing_accentText: #119400
chat_message_outgoing_accentControl: #25AD0D
chat_message_outgoing_mediaActiveControl: #25AD0D
chat_message_outgoing_mediaInactiveControl: #79C160
chat_message_outgoing_mediaControlInnerBg: clear
chat_message_outgoing_pendingActivity: #077C00CC
chat_message_outgoing_fileTitle: #289715
chat_message_outgoing_fileDescription: #599E49
chat_message_outgoing_fileDuration: #077C00CC
chat_message_outgoing_mediaPlaceholder: #96D790
chat_message_outgoing_polls_radioButton: #79C160
chat_message_outgoing_polls_radioProgress: #25AD0D
chat_message_outgoing_polls_highlight: #25AD0D1E
chat_message_outgoing_polls_separator: #79C160
chat_message_outgoing_polls_bar: #25AD0D
chat_message_outgoing_polls_barIconForeground: clear
chat_message_outgoing_polls_barPositive: #25AD0D
chat_message_outgoing_polls_barNegative: #25AD0D
chat_message_outgoing_actionButtonsBg_withWp: #1E1E2E7F
chat_message_outgoing_actionButtonsBg_withoutWp: #1E1E2E7F
chat_message_outgoing_actionButtonsStroke_withWp: #6C708626
chat_message_outgoing_actionButtonsStroke_withoutWp: #6C708626
chat_message_outgoing_actionButtonsText_withWp: #CDD6F4
chat_message_outgoing_actionButtonsText_withoutWp: #CDD6F4
chat_message_outgoing_textSelection: #A3C57B
chat_message_outgoing_textSelectionKnob: #25AD0D
chat_message_freeform_withWp_bg: #313244
chat_message_freeform_withWp_gradientBg: #313244
chat_message_freeform_withWp_highlightedBg: #313244
chat_message_freeform_withWp_stroke: #313244
chat_message_freeform_withWp_reactionInactiveBg: #313244E5
chat_message_freeform_withWp_reactionInactiveFg: #CDD6F4
chat_message_freeform_withWp_reactionActiveBg: #89B4FA
chat_message_freeform_withWp_reactionActiveFg: #CDD6F4
chat_message_freeform_withWp_reactionInactiveMediaPlaceholder: #11111B19
chat_message_freeform_withWp_reactionActiveMediaPlaceholder: #11111B19
chat_message_freeform_withoutWp_bg: #313244
chat_message_freeform_withoutWp_gradientBg: #313244
chat_message_freeform_withoutWp_highlightedBg: #313244
chat_message_freeform_withoutWp_stroke: #313244
chat_message_freeform_withoutWp_reactionInactiveBg: #313244E5
chat_message_freeform_withoutWp_reactionInactiveFg: #CDD6F4
chat_message_freeform_withoutWp_reactionActiveBg: #89B4FA
chat_message_freeform_withoutWp_reactionActiveFg: #CDD6F4
chat_message_freeform_withoutWp_reactionInactiveMediaPlaceholder: #11111B19
chat_message_freeform_withoutWp_reactionActiveMediaPlaceholder: #11111B19
chat_message_infoPrimaryText: #CDD6F4
chat_message_infoLinkText: #A6E3A1
chat_message_outgoingCheck: #077C00CC
chat_message_mediaDateAndStatusBg: #11111B4C
chat_message_mediaDateAndStatusText: #CDD6F4
chat_message_shareButtonBg_withWp: #1E1E2E7F
chat_message_shareButtonBg_withoutWp: #1E1E2E7F
chat_message_shareButtonStroke_withWp: #6C708626
chat_message_shareButtonStroke_withoutWp: #6C708626
chat_message_shareButtonFg_withWp: #9399B2
chat_message_shareButtonFg_withoutWp: #9399B2
chat_message_mediaOverlayControl_bg: #11111B99
chat_message_mediaOverlayControl_fg: #CDD6F4
chat_message_selectionControl_bg: #6B9968
chat_message_selectionControl_stroke: #CDD6F4
chat_message_selectionControl_fg: #CDD6F4
chat_message_deliveryFailed_bg: #F38BA8
chat_message_deliveryFailed_fg: #CDD6F4
chat_message_mediaHighlightOverlay: #CDD6F499
chat_message_stickerPlaceholder_withWp: #3132447F
chat_message_stickerPlaceholder_withoutWp: #3132447F
chat_message_stickerPlaceholderShimmer_withWp: #CDD6F40C
chat_message_stickerPlaceholderShimmer_withoutWp: #CDD6F40C
chat_serviceMessage_components_withDefaultWp_bg: #1E1E2E
chat_serviceMessage_components_withDefaultWp_primaryText: #CDD6F4
chat_serviceMessage_components_withDefaultWp_linkHighlight: #CDD6F41E
chat_serviceMessage_components_withDefaultWp_scam: #F38BA8
chat_serviceMessage_components_withDefaultWp_dateFillStatic: #1E1E2E99
chat_serviceMessage_components_withDefaultWp_dateFillFloat: #1E1E2E33
chat_serviceMessage_components_withCustomWp_bg: #1E1E2E
chat_serviceMessage_components_withCustomWp_primaryText: #CDD6F4
chat_serviceMessage_components_withCustomWp_linkHighlight: #CDD6F41E
chat_serviceMessage_components_withCustomWp_scam: #F38BA8
chat_serviceMessage_components_withCustomWp_dateFillStatic: #1E1E2E99
chat_serviceMessage_components_withCustomWp_dateFillFloat: #1E1E2E33
chat_serviceMessage_unreadBarBg: #313244
chat_serviceMessage_unreadBarStroke: #313244
chat_serviceMessage_unreadBarText: #CDD6F4
chat_serviceMessage_dateText_withWp: #CDD6F4
chat_serviceMessage_dateText_withoutWp: #CDD6F4
chat_inputPanel_panelBg: #313244
chat_inputPanel_panelSeparator: #11111B
chat_inputPanel_panelControlAccent: #6B9968
chat_inputPanel_panelControl: #CDD6F47F
chat_inputPanel_panelControlDisabled: #7F849C7F
chat_inputPanel_panelControlDestructive: #F38BA8
chat_inputPanel_inputBg: #1E1E2E
chat_inputPanel_inputStroke: #1E1E2E
chat_inputPanel_inputPlaceholder: #CDD6F466
chat_inputPanel_inputText: #CDD6F4
chat_inputPanel_inputControl: #CDD6F466
chat_inputPanel_actionControlBg: #6B9968
chat_inputPanel_actionControlFg: #11111B
chat_inputPanel_primaryText: #CDD6F4
chat_inputPanel_secondaryText: #CDD6F47F
chat_inputPanel_mediaRecordDot: #A6E3A1
chat_inputPanel_mediaRecordControl_button: #6B9968
chat_inputPanel_mediaRecordControl_micLevel: #6B996833
chat_inputPanel_mediaRecordControl_activeIcon: #CDD6F4
chat_inputMediaPanel_panelSeparator: #313244
chat_inputMediaPanel_panelIcon: #CDD6F47F
chat_inputMediaPanel_panelHighlightedIconBg: #CDD6F41F
chat_inputMediaPanel_panelHighlightedIcon: #CDD6F4AC
chat_inputMediaPanel_panelContentVibrantOverlay: #CDD6F47F
chat_inputMediaPanel_panelContentControlVibrantOverlay: #CDD6F44C
chat_inputMediaPanel_panelContentControlVibrantSelection: #CDD6F419
chat_inputMediaPanel_panelContentControlOpaqueOverlay: #CDD6F44C
chat_inputMediaPanel_panelContentControlOpaqueSelection: #CDD6F44C
chat_inputMediaPanel_panelContentVibrantSearchOverlay: #9999998C
chat_inputMediaPanel_panelContentVibrantSearchOverlaySelected: #66666699
chat_inputMediaPanel_panelContentVibrantSearchOverlayHighlight: #33333305
chat_inputMediaPanel_panelContentOpaqueSearchOverlay: #8E8E93
chat_inputMediaPanel_panelContentOpaqueSearchOverlaySelected: #00000066
chat_inputMediaPanel_panelContentOpaqueSearchOverlayHighlight: #00000019
chat_inputMediaPanel_stickersBg: #1E1E2E
chat_inputMediaPanel_stickersSectionText: #CDD6F47F
chat_inputMediaPanel_stickersSearchBg: #6C7086
chat_inputMediaPanel_stickersSearchPlaceholder: #6C7086
chat_inputMediaPanel_stickersSearchPrimary: #CDD6F4
chat_inputMediaPanel_stickersSearchControl: #6C7086
chat_inputMediaPanel_gifsBg: #1E1E2E
chat_inputMediaPanel_bg: #1E1E2EBF
chat_inputButtonPanel_panelBg: #11111B
chat_inputButtonPanel_panelSeparator: #313244
chat_inputButtonPanel_buttonBg: #45475A
chat_inputButtonPanel_buttonHighlight: #FFFFFF33
chat_inputButtonPanel_buttonStroke: #11111B
chat_inputButtonPanel_buttonHighlightedBg: #45475AB2
chat_inputButtonPanel_buttonHighlightedStroke: #11111B
chat_inputButtonPanel_buttonText: #CDD6F4
chat_historyNav_bg: #313244
chat_historyNav_stroke: #11111B
chat_historyNav_fg: #CDD6F47F
chat_historyNav_badgeBg: #6B9968
chat_historyNav_badgeStroke: #6B9968
chat_historyNav_badgeText: #CDD6F4
wallpaper: #11111B
actionSheet_dim: #11111B7F
actionSheet_bgType: dark
actionSheet_opaqueItemBg: #313244
actionSheet_itemBg: #313244CC
actionSheet_opaqueItemHighlightedBg: #313244
actionSheet_itemHighlightedBg: #31324433
actionSheet_opaqueItemSeparator: #1E1E2E
actionSheet_standardActionText: #6B9968
actionSheet_destructiveActionText: #F38BA8
actionSheet_disabledActionText: #CDD6F47F
actionSheet_primaryText: #CDD6F4
actionSheet_secondaryText: #CDD6F47F
actionSheet_controlAccent: #6B9968
actionSheet_inputBg: #1E1E2E
actionSheet_inputHollowBg: #1E1E2E
actionSheet_inputBorder: #1E1E2E
actionSheet_inputPlaceholder: #BAC2DE
actionSheet_inputText: #CDD6F4
actionSheet_inputClearButton: #BAC2DE
actionSheet_checkContent: #11111B
contextMenu_dim: #11111B99
contextMenu_background: #313244C6
contextMenu_itemSeparator: #CDD6F426
contextMenu_sectionSeparator: #11111B33
contextMenu_itemBg: #11111B00
contextMenu_itemHighlightedBg: #CDD6F426
contextMenu_primary: #CDD6F4
contextMenu_secondary: #CDD6F47F
contextMenu_destructive: #F38BA8
notification_bg: #313244
notification_primaryText: #CDD6F4
notification_expanded_bgType: dark
notification_expanded_navBar_background: #313244
notification_expanded_navBar_primaryText: #CDD6F4
notification_expanded_navBar_control: #A6E3A1
notification_expanded_navBar_separator: #11111B
chart_labels: #A6ADC899
chart_helperLines: #7F849C59
chart_strongLines: #7F849C59
chart_barStrongLines: #A6ADC872
chart_detailsText: #CDD6F4
chart_detailsArrow: #CDD6F4
chart_detailsView: #181825
chart_rangeViewFrame: #45475A
chart_rangeViewMarker: #CDD6F4
TPL_IOS_EOF
    ;;
    android) cat <<'TPL_ANDROID_EOF'
chat_unreadMessagesStartText: #FFFFFFDA
chat_inFileBackgroundSelected: #5B5273
windowBackgroundChecked: #110D1B
radioBackgroundChecked: #97A8CD
dialogTextBlue: #97A8CD
dialog_inlineProgressBackground: #1D1B26
chat_inSentClockSelected: #ADA6CF
windowBackgroundWhiteBlueIcon: #97A8CD
avatar_backgroundActionBarGreen: #2E2A39
chat_goDownButtonCounterBackground: #A5738A77
actionBarActionModeDefault: #110D1B
actionBarActionModeDefaultTop: #110D1B
dialogCheckboxSquareBackground: #97A8CD
statisticChartHintLine: #FFFFFF1A
chats_menuPhone: #CCCADB93
chat_outViews: #B3ADDB
statisticChartLine_red: #F34C44
chat_secretTimerBackground: #1E1E1EB6
avatar_actionBarSelectorCyan: #544E68
chat_outViaBotNameText: #C2B5F6
chat_botKeyboardButtonText: #FFFFFF
profile_actionPressedBackground: #8B80D0
key_chat_messagePanelVoiceLock: #FFFFFF
chat_secretChatStatusText: #868395
switchTrack: #6E6C82
chat_inPreviewInstantSelectedText: #C8C2EA
chat_attachAudioBackground: #E96852
location_sendLocationBackground: #9B91D0
actionBarDefaultSubmenuBackground: #130F1E
switchTrackBlueThumb: #282531
avatar_nameInMessageViolet: #9998D2
emptyListPlaceholder: #8A8797
chat_inAudioSelectedProgress: #FFFFFF
chats_nameMessage: #EEEDF3
chat_messagePanelShadow: #110D1B
chat_inMediaIcon: #FFFFFF
actionBarDefaultArchived: #110D1B
avatar_subtitleInProfileViolet: #9593A0
chat_messagePanelCancelInlineBot: #EFEBFD64
voipgroup_topPanelGray: #5F7381
dialogSearchBackground: #3A3648
checkbox: #98BCB3
chat_outAudioSeekbarFill: #BE7AA5
chat_inPsaNameText: #98BCB3
chat_botKeyboardButtonBackgroundPressed: #4E485F
player_time: #8A8797
chat_outFileProgressSelected: #FFFFFF
chat_outTimeSelectedText: #D9D4F6
chat_inFileProgressSelected: #FFFFFF
changephoneinfo_image: #4D495C
avatar_backgroundPink: #CD505A
chat_inAudioPerfomerText: #FFFFFF
chat_attachGalleryText: #98BCB3
statisticChartBackZoomColor: #9389EB
player_button: #FFFFFF
key_sheet_other: #FFFFFF43
login_progressOuter: #948BCB
statisticChartLine_lightblue: #3C78EC
chat_inContactNameText: #B4ABF6
chats_menuPhoneCats: #8E8AA1
chat_outPreviewLine: #97A8CD
dialogScrollGlow: #F6F6F7
chat_messagePanelHint: #EBE8FD6E
windowBackgroundGray: #110D1B
chat_inViaBotNameText: #B4ABF6
chat_outVoiceSeekbar: #6D697D
player_actionBarTitle: #FFFFFF
dialogGrayLine: #111012
chat_outFileIcon: #635984
chats_nameMessage_threeLines: #EEEDF3
chat_inFileProgress: #FFFFFF
dialogIcon: #9996A8
chat_emojiPanelEmptyText: #8A8797
chat_emojiPanelBackspace: #767285
chat_replyPanelClose: #EAEAFE6E
chat_inContactPhoneSelectedText: #ADA6CF
featuredStickers_addButtonPressed: #C29FA9
dialogSearchText: #FFFFFF
actionBarTabUnactiveText: #9593A0
chat_outAudioTitleText: #C29FA9
chat_emojiPanelStickerSetNameIcon: #B6B5BB
statisticChartActivePickerChart: #646076D8
chat_emojiPanelBackground: #110D1B
chats_unreadCounter: #90A0BC
groupcreate_hintText: #8A8797
chat_inReplyMediaMessageSelectedText: #ADA6CF
avatar_actionBarSelectorOrange: #544E68
dialogCheckboxSquareUnchecked: #656176
chat_inMediaIconSelected: #FFFFFF
chat_inBubble: #32394D29
chat_emojiPanelNewTrending: #98BCB3
chat_outSentCheckRead: #98BCB3
chat_emojiPanelStickerPackSelector: #E3DFFC0A
chat_unreadMessagesStartArrowIcon: #E96852
avatar_backgroundActionBarOrange: #2E2A39
profile_tabSelectedLine: #98BCB3
windowBackgroundWhiteBlackText: #FFFFFF
avatar_backgroundActionBarBlue: #110D1B
dialogTextLink: #97A8CD
chat_outReactionButtonText: #98BCB3
chat_recordTime: #FFFFFF
chat_status: #B0A4F0
changephoneinfo_image2: #90A0BC
windowBackgroundWhiteBlueHeader: #FFFFFF
files_folderIconBackground: #9E94E7
chat_messagePanelVoiceBackground: #988ED9
passport_authorizeBackgroundSelected: #9081CE
switchTrackBlueChecked: #B6B4FF
sharedMedia_linkPlaceholderText: #BCBBC2
player_seekBarBackground: #52525247
dialogShadowLine: #00000014
groupcreate_onlineText: #A39AEA
profile_status: #77AECD
divider: #110D1B
actionBarDefaultIcon: #B8B8B8
chat_topPanelLine: #CC9795
avatar_backgroundViolet: #9998D2
dialogTopBackground: #A59BE0
chat_inReplyMessageText: #FFFFFF
dialogInputField: #8A8797
windowBackgroundWhiteInputFieldActivated: #97A8CD
chat_attachGalleryBackground: #98BCB3
chat_outInstantSelected: #D9D4F6
chat_outSentCheck: #98BCB3
key_graySectionText: #8A8797
player_placeholder: #79748E
chat_outFileSelectedIcon: #7769C5
picker_disabledButton: #69657E
groupcreate_spanBackground: #3C384B
dialogButton: #97A8CD
contextProgressInner1: #8D8A9964
chat_inLoaderPhotoIconSelected: #FFFFFF
actionBarDefaultSubtitle: #EBE7FC6E
contextProgressInner2: #D7D3F4
premiumGradient2: #EEC3DB
premiumGradient1: #EEC3DB
premiumGradient4: #EEC3DB
chat_inContactPhoneText: #878395
premiumGradient3: #EEC3DB
chat_inlineResultIcon: #B4ABF6
chat_outBubbleGradientSelectedOverlay: #FFFFFF14
chats_draft: #CD505A
dialogLineProgress: #97A8CD
listSelector: #0000002E
chat_outPreviewInstantText: #7991EE
chat_inMenuSelected: #FFFFFF
avatar_backgroundOrange: #CCA55A
statisticChartNightIconColor: #929093
avatar_actionBarSelectorGreen: #544E68
chat_outLocationIcon: #FFFFFF
chat_inLoaderSelected: #958ACC00
location_liveLocationProgress: #9B91D0
dialogTextRed: #EE686F
chat_inBubbleShadow: #00000032
chat_outAudioProgress: #FFFFFF
dialogProgressCircle: #A39AEA
chat_outSentCheckReadSelected: #98BCB3
stickers_menu: #6C697D
avatar_subtitleInProfilePink: #9593A0
player_progress: #90A0BC
chat_attachLocationBackground: #88B1F3
chat_inReplyLine: #F38671
chat_inAudioPerfomerSelectedText: #FFFFFF
dialogBackground: #110D1B
dialogLineProgressBackground: #403D4F
chat_inReplyNameText: #FFFFFF
chat_outAudioPerfomerSelectedText: #D9D4F6
actionBarActionModeDefaultIcon: #FFFFFF
windowBackgroundWhiteRedText4: #CF8A96
chat_goDownButtonIcon: #FFFFFF
windowBackgroundWhiteRedText5: #CD505A
statisticChartLine_lightgreen: #8FCF39
chat_outAudioSelectedProgress: #FFFFFF
chat_messageTextOut: #FAFAFA
chat_inInstant: #B4ABF6
groupcreate_cursor: #A39AEA
avatar_backgroundSaved: #77AECD
returnToCallBackground: #97A8CD
checkboxSquareUnchecked: #656176
dialogCheckboxSquareDisabled: #524E60
player_actionBar: #2E2A39
chat_fieldOverlayText: #A39AEA
chat_messagePanelSend: #A39AEA
chats_sentReadCheck: #AEF3DB
switchThumb: #5F5973
windowBackgroundWhiteRedText2: #F16D66
passport_authorizeBackground: #7B70B4
chats_nameIcon: #EEEDF3
chat_inSentClock: #6D697D
key_chats_menuTopShadow: #0C0C0C00
avatar_nameInMessageRed: #97A8CD
chat_outLoaderPhoto: #645A84
chat_botSwitchToInlineText: #B4ABF6
chat_mediaSentCheck: #98BCB3
dialogTextRed2: #EE686F
chats_nameMessageArchived: #8A8797
avatar_nameInMessageOrange: #CDACB3
featuredStickers_unread: #968AE5
chats_pinnedIcon: #6A667D
chat_attachActiveTab: #AEA3FA
chat_replyPanelLine: #1A191D5E
avatar_subtitleInProfileOrange: #9593A0
chat_outSentCheckSelected: #98BCB3
dialogSearchHint: #888591
chat_inVenueInfoSelectedText: #ADA6CF
dialogTextBlue2: #77AECD
avatar_backgroundGroupCreateSpanBlue: #5B5186
dialogTextBlue3: #77AECD
switchTrackBlueThumbChecked: #171124
dialogTextBlue4: #77AECD
chat_attachUnactiveTab: #8583A5
windowBackgroundWhiteGreenText: #93A55B
actionBarTabActiveText: #FFFFFF
chat_emojiPanelIcon: #767285
chat_topPanelMessage: #EAEAFE6E
statisticChartLine_golden: #DEAC1F
statisticChartSignatureAlpha: #FFFFFF8B
chat_emojiPanelTrendingDescription: #8A8797
calls_callReceivedGreenIcon: #48DD76
chats_pinnedOverlay: #FFFFFF00
windowBackgroundWhiteInputField: #5A566C
avatar_backgroundRed: #CF8A96
statisticChartLine_green: #3DC23F
chat_emojiPanelIconSelector: #A39AEA
chat_emojiPanelBadgeBackground: #9D93F2
chat_inForwardedNameText: #77AECD
chats_sentError: #CF8A96
chats_actionBackground: #696770
avatar_nameInMessageGreen: #98BCB3
chat_outContactNameText: #FFFFFF
chat_TextSelectionCursor: #8F82E3
chat_inSiteNameText: #B4ABF6
chat_linkSelectBackground: #77AECD34
dialogLinkSelection: #97A8CD1E
windowBackgroundWhiteBlueText: #97A8CD
avatar_nameInMessageCyan: #C2907F
chat_inLocationBackground: #413E4F
statisticChartHighlightColor: #FFFFFF86
switch2TrackChecked: #978EE7
radioBackground: #8A87979E
profile_tabText: #FFFFFF
contextProgressOuter1: #AA9EF0
chat_inFileIcon: #312E40
avatar_backgroundActionBarPink: #2E2A39
dialogTextGray3: #8A8797
dialogTextGray2: #8A8797
chat_attachPollText: #CF8A96
dialogTextGray4: #8A8797
chat_attachContactText: #90A0BC
chat_searchPanelIcons: #B4ABF6
windowBackgroundWhiteLinkText: #90A0BC
chat_inAudioSeekbarSelected: #8C87A8
chat_outVenueInfoText: #B3ADDB
chat_outContactPhoneText: #B3ADDB
chat_inAudioTitleText: #C29FA9
chat_messageLinkIn: #77AECD
chats_menuBackground: #110D1B
windowBackgroundCheckText: #FFFFFF
chat_serviceBackground: #433F4F82
chats_secretIcon: #98BCB3
chat_inFileBackground: #3C3848
chat_inBubbleSelected: #56628529
chat_inPollWrongAnswer: #CD505A
chat_mediaMenu: #FFFFFF
chat_outViewsSelected: #D9D4F6
chat_outInstant: #C2B5F6
chat_emojiPanelShadowLine: #00000032
profile_tabSelector: #88B1F3
actionBarDefaultSearchPlaceholder: #EAEAFE78
actionBarActionModeDefaultSelector: #EAEBFF19
chat_outForwardedNameText: #77AECD
dialogRoundCheckBox: #97A8CD
chat_emojiPanelTrendingTitle: #FFFFFF
player_progressBackground2: #D3D1DA
actionBarTabLine: #88B2CC
switchThumbChecked: #9B92DC
chat_stickersHintPanel: #413C4D
chat_outSiteNameText: #FFFFFF
windowBackgroundWhite: #110D1B
groupcreate_offlineText: #8A8797
chat_inVoiceSeekbarSelected: #8C87A8
avatar_backgroundCyan: #97A8CD
dialogTextGray: #8A8797
chat_messageLinkOut: #77AECD
chat_emojiPanelStickerSetName: #8A8893
avatar_backgroundArchived: #474458
picker_badge: #A392EE
dialogRadioBackgroundChecked: #97A8CD
chat_outFileInfoSelectedText: #D9D4F6
chats_tabletSelectedOverlay: #FFFFFF0F
chat_outAudioDurationSelectedText: #888495
avatar_backgroundArchivedHidden: #A9A0F7
chat_attachCameraIcon1: #FF8255
undo_background: #2F2D39F5
premiumGradientBackground3: #98BCB3
premiumGradientBackground4: #90A0BC
premiumGradientBackground1: #98BCB3
avatar_actionBarSelectorPink: #544E68
premiumGradientBackground2: #90A0BC
actionBarTipBackground: #69628F
dialogTextHint: #8A8797
statisticChartLine_orange: #E5BE0F
chat_topPanelTitle: #AEF3DB
chat_inAudioCacheSeekbar: #5F5C6E
chat_outContactIcon: #FFFFFF
chat_inFileInfoText: #868395
avatar_subtitleInProfileBlue: #9593A0
featuredStickers_addButton: #C29FA9
chat_inPreviewLine: #97A8CD
profile_creatorIcon: #97A8CD
avatar_backgroundGreen: #98BCB3
profile_actionBackground: #C95D74
avatar_subtitleInProfileGreen: #9593A0
chats_sentCheck: #AEF3DB
statisticChartInactivePickerChart: #3E3A4AC8
chat_outPsaNameText: #98BCB3
chats_unreadCounterMuted: #3D3C41
chat_outVoiceSeekbarFill: #BE7AA5
chat_outReplyLine: #78C9C7
chat_inAudioSeekbarFill: #BE7AA5
chat_attachCheckBoxBackground: #8F88F9
chat_messagePanelIcons: #EEEBFD6E
chat_inReplyMediaMessageText: #878395
inappPlayerTitle: #FFFFFF
chat_emojiPanelIconSelected: #97A8CD
progressCircle: #97A8CD
chat_inContactBackground: #958ACC
chat_botKeyboardButtonBackground: #373343
chats_menuItemIcon: #C29FA9
chat_outVenueInfoSelectedText: #D9D4F6
wallpaperFileOffset: #00457C00
chat_outBubbleShadow: #00000032
chat_outVenueNameText: #E5E2FC
checkboxSquareBackground: #9D98E3
chat_mediaSentClock: #FFFFFFB2
files_folderIcon: #FFFFFF
chats_menuCloudBackgroundCats: #110D1B
switchTrackBlue: #63606C
chat_topPanelClose: #EAEAFE6E
profile_adminIcon: #8A8797
chats_verifiedBackground: #77AECD
chat_inTimeSelectedText: #ADA6CF
chat_outFileBackgroundSelected: #8579B6
chat_outVoiceSeekbarSelected: #A598D4
windowBackgroundWhiteGrayIcon: #EEC3DB
avatar_backgroundActionBarViolet: #2E2A39
profile_verifiedCheck: #FFFFFF
chat_attachLocationText: #88B1F3
listSelectorSDK21: #F0EFFE14
featuredStickers_removeButtonText: #8E80CB
key_chat_messagePanelVoiceLockBackground: #443F55
chat_outFileNameText: #FFFFFF
picker_enabledButton: #AEA3FA
inappPlayerBackground: #110D1BA8
avatar_nameInMessagePink: #CF8A96
windowBackgroundWhiteGrayText: #8A8797
statisticChartSignature: #B2AEC0B7
musicPicker_buttonBackground: #9D93E6
actionBarDefaultSubmenuItemIcon: #C29FA9
avatar_actionBarSelectorViolet: #544E68
chat_attachPollBackground: #CF8A96
avatar_nameInMessageBlue: #88B1F3
dialogTextBlack: #F6F6F6
actionBarDefault: #110D1B
location_placeLocationBackground: #9B91D0
profile_actionIcon: #FFFFFF
windowBackgroundUnchecked: #282531
actionBarDefaultSelector: #97A8CD
chats_menuTopShadow: #1C1A25A4
chat_outAudioPerfomerText: #FFFFFF
sharedMedia_startStopLoadIcon: #A39AEA
chat_serviceBackgroundSelected: #786DA796
inappPlayerPlayPause: #7991EE
chat_inVenueInfoText: #868395
checkboxSquareDisabled: #524E6064
chat_replyPanelIcons: #C29FA9
fastScrollInactive: #4B4757
chat_outSentClockSelected: #D9D4F6
featuredStickers_addedIcon: #77AECD
chat_goDownButtonCounter: #FFFFFF
switchTrackBlueSelectorChecked: #BEBBFE32
musicPicker_checkbox: #8482FF
chat_outFileBackground: #6F6594
chats_name: #EEEDF3
switchTrackBlueSelector: #D6D0F719
dialogBadgeBackground: #97A8CD
chat_outBubbleSelected: #64598428
avatar_backgroundInProfileBlue: #110D1B
chat_inFileNameText: #FFFFFF
statisticChartLine_blue: #529FFF
inappPlayerPerformer: #88B1F3
chat_inInstantSelected: #C8C2EA
chat_outFileInfoText: #B3ADDB
chat_inLocationIcon: #FFFFFF
groupcreate_checkboxCheck: #FFFFFF
chat_outContactPhoneSelectedText: #D9D4F6
chat_unreadMessagesStartBackground: #110D1BA3
chat_inLoaderPhoto: #312F40
statisticChartCheckboxInactive: #9B9B9B
chat_inFileInfoSelectedText: #ADA6CF
chat_outMenuSelected: #FFFFFF
fastScrollActive: #9088D7
chat_outLoaderPhotoSelected: #6A609F
chat_muteIcon: #696770
chat_selectedBackground: #A08FDA2A
chat_inAudioDurationText: #888495
chat_recordedVoiceBackground: #9D93E3
chat_secretTimeText: #D7D3E8
groupcreate_sectionText: #8A8797
actionBarDefaultSubmenuItem: #FFFFFF
dialogInputFieldActivated: #97A8CD
chats_actionMessage: #8D8B97E8
login_progressInner: #E8E7F1
chat_inLoaderPhotoIcon: #FFFFFF
chat_addContact: #B4ABF6
avatar_actionBarSelectorBlue: #F1EFFE1E
switchTrackChecked: #98BCB3
player_placeholderBackground: #3F3B4E
windowBackgroundWhiteHintText: #8A8797
chat_inLoader: #00000000
chat_adminSelectedText: #ADA6CF
groupcreate_spanText: #F5F5F5
chat_outPreviewInstantSelectedText: #D9D4F6
player_actionBarSelector: #423E50
key_player_progressCachedBackground: #6B647E
chat_outTimeText: #A5A5A5C2
chat_attachAudioText: #E96852
chat_outPollWrongAnswer: #CD505A
chat_outBubble: #48405F28
avatar_backgroundActionBarCyan: #2E2A39
chat_attachFileBackground: #9998D2
wallet_buttonBackground: #9185E1
chat_attachHideBackground: #3E3953
chat_emojiPanelMasksIconSelected: #9B9BEB
statisticChartChevronColor: #7E7B84
chats_menuItemText: #FFFFFFF4
chats_message: #8A8797
chat_outReplyNameText: #FFFFFF
chats_menuTopBackgroundCats: #312D3D
chat_outReplyMediaMessageText: #B3ADDB
chat_textSelectBackground: #9E93DD5A
chat_messagePanelVoiceDelete: #FFFFFF
chat_inAudioProgress: #FFFFFF
chat_inReactionButtonTextSelected: #98BCB3
chats_date: #7E7B89
chat_messagePanelText: #FFFFFF
actionBarTabSelector: #4D496837
key_sheet_scrollUp: #FFFFFF25
player_buttonActive: #A39AEA
undo_cancelColor: #C2907F
chat_outLoaderPhotoIcon: #FFFFFF
chat_attachFileText: #9998D2
chat_outContactBackground: #9B91D0
sharedMedia_linkPlaceholder: #343243
windowBackgroundWhiteBlueText7: #B4ABF6
windowBackgroundWhiteBlueText6: #8073C9
chat_outLocationBackground: #7B719D
windowBackgroundWhiteBlueText3: #A39AEA
windowBackgroundWhiteBlueText2: #B4ABF6
windowBackgroundWhiteBlueText5: #A39AEA
windowBackgroundWhiteBlueText4: #77AECD
chat_replyPanelMessage: #9593A0
chat_inViewsSelected: #ADA6CF
windowBackgroundWhiteLinkSelection: #77AECD33
player_background: #2A2734
inappPlayerClose: #CD505A
chat_outMediaIcon: #FFFFFF
chats_message_threeLines: #8A8797
player_actionBarSubtitle: #EAEAFE78
chat_outAudioCacheSeekbar: #6D697D
chat_attachContactBackground: #90A0BC
chats_sentClock: #595769
chat_inAudioSeekbar: #5F5C6E
avatar_subtitleInProfileRed: #9593A0
avatar_backgroundActionBarRed: #2E2A39
statisticChartLine_indigo: #875CE2
dialogSearchIcon: #847F8D
chat_inPreviewInstantText: #90A0BC
chats_archiveBackground: #8D83C6
dialog_liveLocationProgress: #9B91D0
chat_inViews: #868395
chat_outLoaderSelected: #9B91D000
dialogButtonSelector: #453F53
chats_archivePinBackground: #3B3849
chats_menuItemCheck: #867DB5
chat_messagePanelCursor: #9288D6
player_actionBarItems: #FFFFFF
chat_sentError: #F6574E
player_progressBackground: #484456
avatar_actionBarSelectorRed: #544E68
chat_inAudioDurationSelectedText: #888495
windowBackgroundWhiteGrayText2: #F7F8FF6F
chat_outAudioSeekbarSelected: #A194CE
chat_outLoaderPhotoIconSelected: #FFFFFF
player_actionBarTop: #23222D
windowBackgroundWhiteGrayText8: #8A8797
windowBackgroundWhiteGrayText5: #8A8797
windowBackgroundWhiteGrayText6: #8A8797
windowBackgroundWhiteGrayText3: #8A8797
windowBackgroundWhiteGrayText4: #8A8797C8
chat_inTimeText: #8E8B9ED9
dialogRadioBackground: #656176
statisticChartRipple: #B8B4CF2C
chat_BlurAlpha: #000000E1
chat_outReplyMessageText: #FFFFFF
chat_recordedVoiceDot: #BE7AA5
chat_messagePanelBackground: #110D1B
chat_recordedVoiceProgress: #D4CEFC
chat_inLoaderPhotoSelected: #3F375F
chat_inReactionButtonText: #FFFFFF
chat_inVoiceSeekbarFill: #98BCB3
graySection: #110D1B
chat_outAudioSeekbar: #9386BCE6
wallet_buttonPressedBackground: #7B6FD1
chats_muteIcon: #5A5969
chat_inVoiceSeekbar: #6D697D
chat_outFileProgress: #FFFFFF
profile_verifiedBackground: #97A8CD
chat_outLoader: #00000000
chats_actionPressedBackground: #696770
wallet_releaseBackground: #7266B6
windowBackgroundWhiteGreenText2: #61D36B
chat_replyPanelName: #B4ABF6
chat_outMediaIconSelected: #FFFFFF
windowBackgroundWhiteValueText: #FFFFFF
chat_outAudioDurationText: #888495
chat_outMenu: #FFFFFF
chat_goDownButton: #281E3F9C
statisticChartActiveLine: #FFFFFF32
chats_secretName: #98BCB3
chat_inMenu: #FFFFFF
chat_recordVoiceCancel: #ABA2E9
chat_inFileSelectedIcon: #3D365F
chat_outReplyMediaMessageSelectedText: #FFFFFF
chat_reportSpam: #E96461
chat_messageTextIn: #FAFAFA
dialogRedIcon: #EE686FDE
avatar_subtitleInProfileCyan: #9593A0
chat_serviceText: #8D8B97E8
chats_attachMessage: #888797
chat_topPanelBackground: #110D1B
chat_outSentClock: #A29DC7
dialogBackgroundGray: #110D1B
chat_searchPanelText: #B4ABF6
chat_inContactIcon: #FFFFFF
windowBackgroundGrayShadow: #000000
chat_mediaLoaderPhotoSelected: #0000007F
sharedMedia_actionMode: #4687B3
sessions_devicesImage: #969696
chats_actionUnreadPressedBackground: #F2F2F2
chat_messagePanelVoicePressed: #FFFFFF
groupcreate_spanDelete: #FFFFFF
chat_attachMediaBanBackground: #464646
contacts_inviteBackground: #55BE61
chat_gifSaveHintText: #FFFFFF
actionBarWhiteSelector: #0000002F
chat_goDownButtonShadow: #000000
chat_emojiSearchBackground: #E5E9EE
chat_outBroadcast: #46AA36
musicPicker_checkboxCheck: #FFFFFF
switch2Track: #F57E7E
location_sendLiveLocationBackground: #FF6464
dialog_inlineProgress: #6B7378
chat_adminText: #C0C6CB
picker_badgeText: #FFFFFF
chat_shareBackgroundSelected: #728FA699
chat_recordedVoiceProgressInner: #FFFFFF
featuredStickers_buttonText: #FFFFFF
chat_stickerViaBotNameText: #FFFFFF
chat_attachAudioIcon: #FFFFFF
chat_attachGalleryIcon: #FFFFFF
chat_stickerReplyLine: #FFFFFF
chat_previewGameText: #FFFFFF
dialogCheckboxSquareCheck: #FFFFFF
chat_attachMediaBanText: #FFFFFF
chat_botProgress: #FFFFFF
chat_attachPhotoBackground: #00000008
featuredStickers_buttonProgress: #FFFFFF
contextProgressInner3: #B3B3B3
contextProgressInner4: #CACDD0
chat_previewDurationText: #FFFFFF
chat_serviceLink: #FFFFFF
location_sendLiveLocationIcon: #FFFFFF
chat_attachContactIcon: #FFFFFF
checkboxSquareCheck: #FFFFFF
chat_stickerReplyMessageText: #FFFFFF
chat_gifSaveHintBackground: #111111CC
profile_title: #FFFFFF
windowBackgroundWhiteRedText3: #D24949
windowBackgroundWhiteRedText6: #FF6666
chats_onlineCircle: #4BCB1C
featuredStickers_delButtonPressed: #C64949
chat_messagePanelVoiceDuration: #FFFFFF
avatar_backgroundBlue: #549CDD
dialogBadgeText: #FFFFFF
chat_mediaLoaderPhotoIcon: #FFFFFF
chat_attachPollIcon: #FFFFFF
chat_emojiPanelStickerSetNameHighlight: #278DDB
actionBarDefaultArchivedSelector: #5E6772
chat_stickerNameText: #FFFFFF
chat_emojiSearchIcon: #94A1AF
dialogRoundCheckBoxCheck: #FFFFFF
chat_botButtonText: #FFFFFF
dialogCameraIcon: #FFFFFF
actionBarDefaultArchivedSearch: #FFFFFF
chat_stickerReplyNameText: #FFFFFF
chat_messagePanelVideoFrame: #4BADF7
chat_mediaLoaderPhotoIconSelected: #D9D9D9
contextProgressOuter3: #FFFFFF
contextProgressOuter4: #2F3438
actionBarDefaultSearch: #FFFFFF
contextProgressOuter2: #FFFFFF
chat_emojiPanelStickerPackSelectorLine: #56ABF0
chat_attachPermissionMark: #E25050
chat_messagePanelPressedSend: #FFFFFF
chat_inUpCall: #FF4848
actionBarDefaultArchivedIcon: #FFFFFF
dialogFloatingButtonPressed: #4CB4F5
windowBackgroundWhiteGrayLine: #DBDBDB
featuredStickers_delButton: #D95757
returnToCallText: #FFFFFF
chats_nameMessageArchived_threeLines: #5E5E5E
chat_outUpCall: #00C853
chats_archiveIcon: #FFFFFF
chats_nameArchived: #525252
fastScrollText: #FFFFFF
chat_mediaViews: #FFFFFF
chats_unreadCounterText: #FFFFFF
key_chat_messagePanelVoiceLockShadow: #000000
chat_mediaTimeText: #FFFFFF
actionBarBrowser: #FFFFFF
chats_mentionIcon: #FFFFFF
actionBarDefaultTitle: #FFFFFF
windowBackgroundWhiteBlueButton: #1E88D3
chat_mediaTimeBackground: #00000066
chat_secretTimerText: #FFFFFF
chats_menuName: #FFFFFF
chat_serviceIcon: #FFFFFF
chats_actionIcon: #FFFFFF
sharedMedia_photoPlaceholder: #EDF3F7
chat_recordedVoicePlayPausePressed: #D9EAFB
chats_actionUnreadBackground: #FFFFFF
chat_lockIcon: #FFFFFF
chat_attachEmptyImage: #CCCCCC
actionBarDefaultSearchArchivedPlaceholder: #FFFFFF88
chats_archiveText: #FFFFFF
chat_inDownCall: #00C853
chats_sentErrorIcon: #FFFFFF
chat_recordedVoicePlayPause: #FFFFFF
chat_attachPermissionImage: #333333
avatar_actionBarIconBlue: #FFFFFF
chats_verifiedCheck: #FFFFFF
actionBarDefaultArchivedTitle: #FFFFFF
musicPicker_buttonIcon: #FFFFFF
chat_mediaBroadcast: #FFFFFF
dialogFloatingIcon: #FFFFFF
checkboxDisabled: #B0B9C2
chat_attachLocationIcon: #FFFFFF
passport_authorizeText: #FFFFFF
chat_emojiPanelBadgeText: #FFFFFF
calls_callReceivedRedIcon: #FF4848
chat_attachPermissionText: #6F777A
stickers_menuSelector: #0000000F
chat_emojiBottomPanelIcon: #8C9197
chat_mediaProgress: #FFFFFF
dialogFloatingButton: #4CB4F5
chat_messagePanelVoiceShadow: #0000000D
chats_menuCloud: #FFFFFF
chat_mediaInfoText: #FFFFFF
chat_attachFileIcon: #FFFFFF
windowBackgroundWhiteGrayText7: #C6C6C6
files_iconText: #FFFFFF
chat_attachCheckBoxCheck: #FFFFFF
windowBackgroundWhiteRedText: #CD5A5A
chats_messageArchived: #919191
chat_shareBackground: #728FA666
groupcreate_sectionShadow: #000000
chat_sentErrorIcon: #FFFFFF
checkboxCheck: #FFFFFF
location_sendLocationIcon: #FFFFFF
contacts_inviteText: #FFFFFF
chats_actionUnreadIcon: #737373
chat_mediaLoaderPhoto: #00000066
undo_infoColor: #FFFFFF
chat_emojiPanelMasksIcon: #FFFFFF
avatar_text: #FFFFFF
TPL_ANDROID_EOF
    ;;
    desktop) cat <<'TPL_DESKTOP_EOF'
windowBg: #17212b
windowFg: #f5f5f5
windowBgOver: #232e3c
windowBgRipple: #24303d
windowFgOver: #e9ecf0
windowSubTextFg: #708499
windowSubTextFgOver: #7c90a4
windowBoldFg: #e9e8e8
windowBoldFgOver: #e9e9e9
windowBgActive: #5288c1
windowFgActive: #ffffff
windowActiveTextFg: #6ab3f3
windowShadowFg: #000000
windowShadowFgFallback: #17212b
shadowFg: #04080e56
slideFadeOutBg: #0000003c
slideFadeOutShadowFg: windowShadowFg
imageBg: #000000
imageBgTransparent: #ffffff
activeButtonBg: #2f6ea5
activeButtonBgOver: #3476ab
activeButtonBgRipple: #3b7cb1
activeButtonFg: #ffffff
activeButtonFgOver: #ffffff
activeButtonSecondaryFg: #9abfe7
activeButtonSecondaryFgOver: activeButtonSecondaryFg
activeLineFg: #6396cb
activeLineFgError: #ef5959
lightButtonBg: #17212b
lightButtonBgOver: #1d2a39
lightButtonBgRipple: #223143
lightButtonFg: #6ab2f2
lightButtonFgOver: lightButtonFg
attentionButtonFg: #ec3942
attentionButtonFgOver: #ec3942
attentionButtonBgOver: #592a2a64
attentionButtonBgRipple: #68323264
outlineButtonBg: windowBg
outlineButtonBgOver: #202b37
outlineButtonOutlineFg: #3983c3
outlineButtonBgRipple: #27323f
menuBg: #17212b
menuBgOver: #ffffff
menuBgRipple: #1f2934
menuIconFg: #6c7883
menuIconFgOver: #dcdcdc
menuSubmenuArrowFg: #637c95
menuFgDisabled: #3d4e5c
menuSeparatorFg: #232f39
scrollBarBg: #ffffff53
scrollBarBgOver: #ffffff7a
scrollBg: #ffffff1a
scrollBgOver: #ffffff2c
smallCloseIconFg: #55616c
smallCloseIconFgOver: #a3a3a3
radialFg: windowFgActive
radialBg: #00000056
placeholderFg: #6d7883
placeholderFgActive: #4f5b67
inputBorderFg: #313c49
filterInputBorderFg: #242f3d
filterInputInactiveBg: #242f3d
checkboxFg: #4f6276
sliderBgInactive: #364554
sliderBgActive: #4a81bc
tooltipBg: #16222d
tooltipFg: #d4e0ea
tooltipBorderFg: #16222d
titleShadow: #00000000
titleBg: #1f2936
titleBgActive: #242f3d
titleButtonBg: titleBg
titleButtonFg: #576673
titleButtonBgOver: #25303e
titleButtonFgOver: #e0e0e0
titleButtonBgActive: #242f3d
titleButtonFgActive: titleButtonFg
titleButtonBgActiveOver: #2c3847
titleButtonFgActiveOver: titleButtonFgOver
titleButtonCloseBg: titleButtonBg
titleButtonCloseFg: titleButtonFg
titleButtonCloseBgOver: #e92539
titleButtonCloseFgOver: windowFgActive
titleButtonCloseBgActive: #242f3d
titleButtonCloseFgActive: titleButtonCloseFg
titleButtonCloseBgActiveOver: #e92539
titleButtonCloseFgActiveOver: titleButtonCloseFgOver
titleFg: #6a7680
titleFgActive: #91a3b3
trayCounterBg: #f23c34
trayCounterBgMute: #888888
trayCounterFg: #ffffff
trayCounterBgMacInvert: #ffffff
trayCounterFgMacInvert: #ffffff01
layerBg: #0000007f
cancelIconFg: #737e87
cancelIconFgOver: #dcdcdc
boxBg: #17212b
boxTextFg: windowFg
boxTextFgGood: #5598db
boxTextFgError: #dc3d3d
boxTitleFg: #ebebeb
boxSearchBg: #17212b
boxTitleAdditionalFg: #6d7f8f
boxTitleCloseFg: cancelIconFg
boxTitleCloseFgOver: cancelIconFgOver
membersAboutLimitFg: #677a8b
contactsBg: #17212b
contactsBgOver: #1f2c39
contactsNameFg: boxTextFg
contactsStatusFg: #677a8b
contactsStatusFgOver: #677a8b
contactsStatusFgOnline: #559be0
photoCropFadeBg: layerBg
photoCropPointFg: #ffffff7f
callArrowFg: #49a2f0
callArrowMissedFg: #ed5050
introBg: windowBg
introTitleFg: #eeeeee
introDescriptionFg: #72879b
introErrorFg: #e94040
introCoverTopBg: #124a82
introCoverBottomBg: #23659f
introCoverIconsFg: #3b7cbd
introCoverPlaneTrace: #3870a8
introCoverPlaneInner: #ced9e2
introCoverPlaneOuter: #97a9b5
introCoverPlaneTop: #ffffff
dialogsMenuIconFg: menuIconFg
dialogsMenuIconFgOver: menuIconFgOver
dialogsBg: windowBg
dialogsNameFg: #f5f5f5
dialogsChatIconFg: dialogsNameFg
dialogsDateFg: #8696a8
dialogsTextFg: #7f91a4
dialogsTextFgService: #73b9f5
dialogsDraftFg: #ff525d
dialogsVerifiedIconBg: #6ab3f3
dialogsVerifiedIconFg: #17212b
dialogsSendingIconFg: #647d96
dialogsSentIconFg: #72bcfd
dialogsUnreadBg: #4082bc
dialogsUnreadBgMuted: #3e546a
dialogsUnreadFg: #ffffff
dialogsBgOver: #202b36
dialogsOnlineBadgeFg: #63b6ff
dialogsNameFgOver: windowBoldFgOver
dialogsChatIconFgOver: dialogsNameFgOver
dialogsDateFgOver: #8495a9
dialogsTextFgOver: #91a3b5
dialogsTextFgServiceOver: #73b9f5
dialogsDraftFgOver: dialogsDraftFg
dialogsVerifiedIconBgOver: #6ab3f3
dialogsVerifiedIconFgOver: dialogsVerifiedIconFg
dialogsSendingIconFgOver: dialogsSendingIconFg
dialogsSentIconFgOver: #72bcfd
dialogsUnreadBgOver: #4082bc
dialogsUnreadBgMutedOver: #4d5762
dialogsUnreadFgOver: dialogsUnreadFg
dialogsBgActive: #2b5278
dialogsNameFgActive: windowFgActive
dialogsChatIconFgActive: dialogsNameFgActive
dialogsDateFgActive: windowFgActive
dialogsTextFgActive: windowFgActive
dialogsTextFgServiceActive: dialogsTextFgActive
dialogsDraftFgActive: #a9caf0
dialogsVerifiedIconBgActive: dialogsTextFgActive
dialogsVerifiedIconFgActive: dialogsBgActive
dialogsSendingIconFgActive: #ffffff99
dialogsSentIconFgActive: dialogsTextFgActive
dialogsUnreadBgActive: dialogsTextFgActive
dialogsUnreadBgMutedActive: #7aa3ca
dialogsUnreadFgActive: #2a5378
dialogsOnlineBadgeFgActive: #ffffff
dialogsRippleBg: #25313d
dialogsRippleBgActive: #315a80
dialogsForwardBg: dialogsBgActive
dialogsForwardFg: dialogsNameFgActive
searchedBarBg: #202b38
searchedBarFg: #8c98a4
topBarBg: #17212b
emojiPanBg: windowBg
emojiPanCategories: #17212b
emojiPanHeaderFg: #7c8d9e
emojiPanHeaderBg: #fffffff2
stickerPanDeleteBg: #000000cc
stickerPanDeleteFg: windowFgActive
stickerPreviewBg: #000000b0
historyTextInFg: windowFg
historyTextInFgSelected: #ffffff
historyTextOutFg: #e4ecf2
historyTextOutFgSelected: #ffffff
historyLinkInFg: #70baf5
historyLinkInFgSelected: #aadcff
historyLinkOutFg: #83caff
historyLinkOutFgSelected: #aadcff
historyFileNameInFg: historyTextInFg
historyFileNameInFgSelected: #ffffff
historyFileNameOutFg: historyTextOutFg
historyFileNameOutFgSelected: #ffffff
historyOutIconFg: #6bbfff
historyOutIconFgSelected: #ffffff
historyIconFgInverted: #ffffffe5
historySendingOutIconFg: #70a4d2
historySendingInIconFg: #76838b
historySendingInvertedIconFg: #ffffffc8
historyCallArrowInFg: #5093d6
historyCallArrowInFgSelected: #ffffff
historyCallArrowMissedInFg: callArrowMissedFg
historyCallArrowMissedInFgSelected: #ffffff
historyCallArrowOutFg: #ffffff
historyCallArrowOutFgSelected: #ffffff
historyUnreadBarBg: #182433
historyUnreadBarBorder: #03080d00
historyUnreadBarFg: #ffffff
historyForwardChooseBg: #0000004c
historyForwardChooseFg: windowFgActive
historyPeer1NameFg: #fb6169
historyPeer1NameFgSelected: #ffffff
historyPeer1UserpicBg: #ff845e
historyPeer2NameFg: #85de85
historyPeer2NameFgSelected: #ffffff
historyPeer2UserpicBg: #9ad164
historyPeer3NameFg: #f3bc5c
historyPeer3NameFgSelected: #ffffff
historyPeer3UserpicBg: #e5ca77
historyPeer4NameFg: #65bdf3
historyPeer4NameFgSelected: #ffffff
historyPeer4UserpicBg: #5caffa
historyPeer5NameFg: #b48bf2
historyPeer5NameFgSelected: #ffffff
historyPeer5UserpicBg: #b694f9
historyPeer6NameFg: #ff5694
historyPeer6NameFgSelected: #ffffff
historyPeer6UserpicBg: #ff8aac
historyPeer7NameFg: #62d4e3
historyPeer7NameFgSelected: #ffffff
historyPeer7UserpicBg: #5bcbe3
historyPeer8NameFg: #faa357
historyPeer8NameFgSelected: #ffffff
historyPeer8UserpicBg: #febb5b
historyPeerUserpicFg: windowFgActive
historyPeer1UserpicBg2: #d45246
historyPeer2UserpicBg2: #46ba43
historyPeer3UserpicBg2: #e5ca77
historyPeer4UserpicBg2: #408acf
historyPeer5UserpicBg2: #6c61df
historyPeer6UserpicBg2: #d95574
historyPeer7UserpicBg2: #359ad4
historyPeer8UserpicBg2: #f68136
historyPeerSavedMessagesBg2: historyPeer4UserpicBg2
historyScrollBarBg: #7f84897a
historyScrollBarBgOver: #64686cbc
historyScrollBg: #565a5e4c
historyScrollBgOver: #5a5d616b
msgInBg: #182533
msgInBgSelected: #2e70a5
msgOutBg: #2b5278
msgOutBgSelected: #2e70a5
msgSelectOverlay: #3585d44c
msgStickerOverlay: #3585d47f
msgInServiceFg: #71bafa
msgInServiceFgSelected: #ffffff
msgOutServiceFg: #90caff
msgOutServiceFgSelected: #ffffff
msgInShadow: #748ea200
msgInShadowSelected: #538ebb00
msgOutShadow: #00000000
msgOutShadowSelected: #366ea600
msgInDateFg: #6d7f8f
msgInDateFgSelected: #ffffff
msgOutDateFg: #7da8d3
msgOutDateFgSelected: #ffffff
msgServiceFg: windowFgActive
msgServiceBg: #213040d5
msgServiceBgSelected: #2e7ab4
msgInReplyBarColor: #429bdb
msgInReplyBarSelColor: #ffffff
msgOutReplyBarColor: #65b9f4
msgOutReplyBarSelColor: #ffffff
msgImgReplyBarColor: msgServiceFg
msgInMonoFg: #5a8cb7
msgOutMonoFg: #aed1f3
msgInMonoFgSelected: #a3cdf7
msgOutMonoFgSelected: #a3cdf7
msgDateImgFg: #fffffff2
msgDateImgBg: #00000054
msgDateImgBgOver: #00000074
msgDateImgBgSelected: #204f7887
msgFileThumbLinkInFg: lightButtonFg
msgFileThumbLinkInFgSelected: #ffffff
msgFileThumbLinkOutFg: #6c9ecf
msgFileThumbLinkOutFgSelected: #ffffff
msgFileInBg: #3f96d0
msgFileInBgOver: #489ed7
msgFileInBgSelected: #6ab4f4
msgFileOutBg: #4c9ce2
msgFileOutBgOver: #54a4e9
msgFileOutBgSelected: #58abf3
msgFile1Bg: #3e7eba
msgFile1BgDark: #24679e
msgFile1BgOver: #1d5e93
msgFile1BgSelected: #ffffff
msgFile2Bg: #3ea34a
msgFile2BgDark: #298835
msgFile2BgOver: #1b7725
msgFile2BgSelected: #1b7725
msgFile3Bg: #d6454c
msgFile3BgDark: #bf333a
msgFile3BgOver: #b2282f
msgFile3BgSelected: #b2282f
msgFile4Bg: #d99546
msgFile4BgDark: #c17d39
msgFile4BgOver: #ac6b29
msgFile4BgSelected: #ac6b29
historyFileInIconFg: #ffffff
historyFileInIconFgSelected: #ffffff
historyFileInRadialFg: #ffffff
historyFileInRadialFgSelected: historyFileInIconFgSelected
historyFileOutIconFg: #ffffff
historyFileOutIconFgSelected: #ffffff
historyFileOutRadialFg: #ffffff
historyFileOutRadialFgSelected: #ffffff
historyFileThumbIconFg: #efefef
historyFileThumbIconFgSelected: #ffffff
historyFileThumbRadialFg: historyFileThumbIconFg
historyFileThumbRadialFgSelected: #ffffff
historyVideoMessageProgressFg: historyFileThumbIconFg
msgWaveformInActive: #549cd7
msgWaveformInActiveSelected: #ffffff
msgWaveformInInactive: #3a4d61
msgWaveformInInactiveSelected: #6fa5d4
msgWaveformOutActive: #62b2fd
msgWaveformOutActiveSelected: #ffffff
msgWaveformOutInactive: #4b7fb3
msgWaveformOutInactiveSelected: #6fa5d4
msgBotKbOverBgAdd: #80b1db0f
msgBotKbIconFg: msgServiceFg
msgBotKbRippleBg: #92c0e50b
mediaInFg: msgInDateFg
mediaInFgSelected: msgInDateFgSelected
mediaOutFg: msgOutDateFg
mediaOutFgSelected: msgOutDateFgSelected
youtubePlayIconBg: #e83131c8
youtubePlayIconFg: windowFgActive
videoPlayIconBg: #0000007f
videoPlayIconFg: #ffffff
toastBg: #000000b2
toastFg: windowFgActive
reportSpamBg: #363c42
reportSpamFg: windowFg
historyToDownBg: #1d2b3a
historyToDownBgOver: #243446
historyToDownBgRipple: #2b3c4f
historyToDownFg: #adb4ba
historyToDownFgOver: menuIconFgOver
historyToDownShadow: #00000040
historyComposeAreaBg: #17212b
historyComposeAreaFg: historyTextInFg
historyComposeAreaFgService: msgInDateFg
historyComposeIconFg: menuIconFg
historyComposeIconFgOver: menuIconFgOver
historySendIconFg: windowBgActive
historySendIconFgOver: windowBgActive
historyPinnedBg: #1b2734
historyReplyBg: historyComposeAreaBg
historyReplyIconFg: windowBgActive
historyReplyCancelFg: cancelIconFg
historyReplyCancelFgOver: cancelIconFgOver
historyComposeButtonBg: historyComposeAreaBg
historyComposeButtonBgOver: #1c2835
historyComposeButtonBgRipple: #222f3e
overviewCheckBg: #00000040
overviewCheckFg: #ffffff
overviewCheckFgActive: #ffffff
overviewPhotoSelectOverlay: #3fa2e333
profileStatusFgOver: #677a8b
profileVerifiedCheckBg: windowBgActive
profileVerifiedCheckFg: #ffffff
profileAdminStartFg: #62a9e6
notificationsBoxMonitorFg: windowFg
notificationsBoxScreenBg: dialogsBgActive
notificationSampleUserpicFg: windowBgActive
notificationSampleCloseFg: #d7d7d7
notificationSampleTextFg: #d7d7d7
notificationSampleNameFg: #939393
changePhoneSimcardFrom: notificationSampleTextFg
changePhoneSimcardTo: notificationSampleNameFg
mainMenuBg: windowBg
mainMenuCoverBg: #276899
mainMenuCoverFg: windowFgActive
mainMenuCloudFg: activeButtonFg
mainMenuCloudBg: #185680
mediaPlayerBg: windowBg
mediaPlayerActiveFg: windowBgActive
mediaPlayerInactiveFg: sliderBgInactive
mediaPlayerDisabledFg: #9dd1ef
mediaviewFileBg: windowBg
mediaviewFileNameFg: windowFg
mediaviewFileSizeFg: windowSubTextFg
mediaviewFileRedCornerFg: #d55959
mediaviewFileYellowCornerFg: #e8a659
mediaviewFileGreenCornerFg: #49a957
mediaviewFileBlueCornerFg: #599dcf
mediaviewFileExtFg: activeButtonFg
mediaviewMenuBg: #383838
mediaviewMenuBgOver: #505050
mediaviewMenuBgRipple: #676767
mediaviewMenuFg: windowFgActive
mediaviewBg: #222222eb
mediaviewVideoBg: imageBg
mediaviewControlBg: #0000003c
mediaviewControlFg: windowFgActive
mediaviewCaptionBg: #11111180
mediaviewCaptionFg: mediaviewControlFg
mediaviewTextLinkFg: #70baf5
mediaviewSaveMsgBg: toastBg
mediaviewSaveMsgFg: toastFg
mediaviewPlaybackActive: #c7c7c7
mediaviewPlaybackInactive: #252525
mediaviewPlaybackActiveOver: #ffffff
mediaviewPlaybackInactiveOver: #474747
mediaviewPlaybackProgressFg: #ffffffc7
mediaviewPlaybackIconFg: mediaviewPlaybackActive
mediaviewPlaybackIconFgOver: mediaviewPlaybackActiveOver
mediaviewTransparentBg: #ffffff
mediaviewTransparentFg: #cccccc
notificationBg: windowBg
callBg: #14191ff5
callNameFg: #ffffff
callFingerprintBg: #00000066
callStatusFg: #aaabac
callIconFg: #ffffff
callAnswerBg: #488fc9
callAnswerRipple: #4286c2
callAnswerBgOuter: #3f95eb26
callHangupBg: #cc4646
callHangupRipple: #ca4141
callCancelBg: #ffffff
callCancelFg: #536271
callCancelRipple: #435363
callMuteRipple: #ffffff12
callBarBg: #366693
callBarMuteRipple: #4b7dab
callBarBgMuted: #35495d
callBarUnmuteRipple: #435b73
callBarFg: dialogsNameFgActive
importantTooltipBg: toastBg
importantTooltipFg: toastFg
importantTooltipFgLink: #65b6fc
filterInputActiveBg: #242f3d
botKbBg: #242f3d
botKbDownBg: #2d3a49
emojiIconFg: #6c7883
emojiIconFgActive: #51a0e5
overviewCheckBorder: #e4eaef
sideBarBg: #0e1621
sideBarBgActive: #25303e
sideBarBgRipple: #1e2733
sideBarTextFg: #768c9e
sideBarTextFgActive: #64b9fa
sideBarIconFg: #768c9e
sideBarIconFgActive: #5eb5f7
sideBarBadgeBg: #5eb5f7
sideBarBadgeBgMuted: #768c9e
statisticsChartInactive: #313d4cc8
statisticsChartActive: #526679d8
TPL_DESKTOP_EOF
    ;;
  esac
}

# ============================================================
#  ตัวช่วยสี (เรียก awk)
# ============================================================
mix()   { awk -v OP=mix -v A="$1" -v B="$2" -v T="$3" -f "$TMP/lib.awk"; }
modeof(){ awk -v OP=mode -v A="$1" -f "$TMP/lib.awk"; }
lowc()  { awk -v OP=lowc -v A="$1" -v B="$2" -v T="$3" -f "$TMP/lib.awk"; }   # คอนทราสต์ต่ำกว่าเกณฑ์? -> 1/0
best()  { awk -v OP=best -v A="$1" -v C="$2" -f "$TMP/lib.awk"; }
rget()  { awk -v R="$1" '$1 == R { print $2; exit }' "$2"; }       # rget บทบาท ไฟล์บทบาท

# cget ไฟล์ คีย์1 คีย์2 ... -> สี RRGGBB ตัวแรกที่พบ (ว่างถ้าไม่พบ)
cget() {
  _f=$1; shift
  for _k in "$@"; do
    _v=$(grep -m1 "^$_k:" "$_f" | sed -n 's/^[^:]*:[ ]*#\([0-9A-Fa-f]\{6\}\).*/\1/p' | tr 'a-f' 'A-F')
    if [ -n "$_v" ]; then echo "$_v"; return; fi
  done
}

# ============================================================
#  ดึง "บทบาทสี" ออกจากธีมแต่ละรูปแบบ -> ไฟล์ "บทบาท HEX"
#  roles_of <รูปแบบ> <ไฟล์ canon> <ไฟล์ผลลัพธ์>
# ============================================================
roles_of() {
  _fmt=$1; _f=$2; _o=$3
  case $_fmt in
    ios)
      bg=$(cget "$_f" chatList_bg list_plainBg);              surf=$(cget "$_f" root_navBar_background list_itemBlocksBg)
      surf2=$(cget "$_f" chat_inputButtonPanel_buttonBg chatList_pinnedItemBg)
      txt=$(cget "$_f" list_primaryText root_navBar_primaryText)
      sub=$(cget "$_f" root_navBar_secondaryText list_secondaryText)
      muted=$(cget "$_f" root_tabBar_icon list_secondaryText)
      acc=$(cget "$_f" list_accent root_navBar_button);       teal=$(cget "$_f" chatList_checkmark list_switch_positive)
      link=$(cget "$_f" chat_message_incoming_linkText);      red=$(cget "$_f" list_destructive)
      orange=$(cget "$_f" list_disclosureActions_warning_bg)
      blue=$(cget "$_f" chatList_pinnedArchiveAvatar_background_top chat_message_freeform_withoutWp_reactionActiveBg)
      violet=""
      outb=$(cget "$_f" chat_message_outgoing_bubble_withoutWp_bg chat_message_outgoing_bubble_withWp_bg)
      inb=$(cget "$_f" chat_message_incoming_bubble_withoutWp_bg chat_message_incoming_bubble_withWp_bg) ;;
    android)
      bg=$(cget "$_f" windowBackgroundWhite);                 surf=$(cget "$_f" player_actionBar dialogSearchBackground actionBarDefault)
      surf2=$(cget "$_f" chat_inFileBackground graySection)
      txt=$(cget "$_f" windowBackgroundWhiteBlackText chats_name)
      sub=$(cget "$_f" windowBackgroundWhiteGrayText chats_message)
      muted=$(cget "$_f" chats_date windowBackgroundWhiteGrayText2)
      acc=$(cget "$_f" windowBackgroundWhiteBlueText dialogTextBlue)
      teal=$(cget "$_f" checkbox chat_outSentCheck);          link=$(cget "$_f" chat_messageLinkIn)
      red=$(cget "$_f" chats_draft dialogTextRed);            orange=$(cget "$_f" avatar_backgroundOrange)
      blue=$(cget "$_f" avatar_backgroundBlue);               violet=$(cget "$_f" chat_messagePanelSend)
      # ฟองขาออกของ Android มักโปร่งแสง: ใช้เฉพาะเมื่อเกือบทึบ
      _ob=$(grep -m1 '^chat_outBubble:' "$_f" | sed -n 's/^[^:]*:[ ]*#\([0-9A-Fa-f]*\).*/\1/p')
      outb=""
      if [ ${#_ob} -eq 6 ]; then outb=$_ob; fi
      inb="" ;;
    desktop)
      bg=$(cget "$_f" windowBg);                              surf=$(cget "$_f" windowBgOver msgInBg)
      surf2=$(cget "$_f" windowBgRipple)
      txt=$(cget "$_f" windowFg);                             sub=$(cget "$_f" windowSubTextFg)
      muted=$(cget "$_f" dialogsDateFg windowSubTextFg)
      acc=$(cget "$_f" windowActiveTextFg);                   teal=$(cget "$_f" dialogsSentIconFg historyOutIconFg)
      link=$(cget "$_f" historyLinkInFg);                     red=$(cget "$_f" boxTextFgError attentionButtonFg)
      orange="";                                              blue=$(cget "$_f" activeButtonBg windowBgActive)
      violet=""
      outb=$(cget "$_f" msgOutBg);                            inb=$(cget "$_f" msgInBg) ;;
  esac
  [ -n "$bg" ]  || die "ไม่พบสีพื้นหลังในไฟล์ธีม (ไม่ใช่ธีมที่รองรับ?)"
  [ -n "$txt" ] || die "ไม่พบสีตัวอักษรหลักในไฟล์ธีม (ไม่ใช่ธีมที่รองรับ?)"
  # ค่าเริ่มต้นสำหรับบทบาทที่ไม่พบ
  [ -n "$surf" ]   || surf=$(mix "$bg" "$txt" 0.08)
  [ -n "$surf2" ]  || surf2=$(mix "$bg" "$txt" 0.14)
  [ -n "$sub" ]    || sub=$(mix "$txt" "$bg" 0.40)
  [ -n "$muted" ]  || muted=$(mix "$txt" "$bg" 0.55)
  _dk=$(modeof "$bg")
  [ -n "$acc" ]    || { if [ "$_dk" = dark ]; then acc=6AB3F3; else acc=2481CC; fi; }
  [ -n "$teal" ]   || teal=$acc
  [ -n "$link" ]   || link=$acc
  [ -n "$red" ]    || { if [ "$_dk" = dark ]; then red=E5636B; else red=D14E4E; fi; }
  [ -n "$orange" ] || { if [ "$_dk" = dark ]; then orange=E5A34F; else orange=D98A1F; fi; }
  [ -n "$blue" ]   || blue=$acc
  [ -n "$violet" ] || violet=$acc
  [ -n "$outb" ]   || outb=$(mix "$bg" "$violet" 0.30)
  [ -n "$inb" ]    || inb=$surf
  {
    echo "BG $bg"; echo "SURF $surf"; echo "SURF2 $surf2"; echo "MUTED $muted"; echo "SUB $sub"; echo "TXT $txt"
    echo "ACCENT $acc"; echo "TEAL $teal"; echo "LINK $link"; echo "RED $red"; echo "ORANGE $orange"
    echo "BLUE $blue"; echo "VIOLET $violet"; echo "OUTBUB $outb"; echo "INBUB $inb"
  } > "$_o"
}

# ============================================================
#  ตัวอ่านไฟล์ต้นทาง: ตรวจรูปแบบ + แปลงเป็น raw/canon
# ============================================================
detect() {
  if [ "$(head -c 2 "$1" 2>/dev/null)" = "PK" ]; then echo zip; return; fi
  if grep -qE 'chat_message_incoming_bubble_|^basedOn:' "$1"; then echo ios
  elif grep -qE '^windowBackgroundWhite[ ]*[:=]|^chat_inBubble[ ]*[:=]' "$1"; then echo android
  elif grep -qE '^windowBg[ ]*:|^msgInBg[ ]*:|^historyComposeAreaBg[ ]*:' "$1"; then echo desktop
  else echo '?'; fi
}
fmtname() {
  case $1 in
    ios) echo "iOS (.tgios-theme)";; android) echo "Android (.attheme / hex)";;
    desktop|zip) echo "Telegram Desktop";; *) echo "ไม่รู้จัก";;
  esac
}
# normalize <รูปแบบ> <ต้นทาง> <raw ผลลัพธ์> <canon ผลลัพธ์>
#   raw   = key: ค่า (Desktop คงค่าอ้างอิงไว้)   canon = ค่าอ้างอิงถูกแก้เป็นสีจริงแล้ว
normalize() {
  case $1 in
    ios)     tr -d '\r' < "$2" > "$3"; cp "$3" "$4" ;;
    android) awk -v OP=norm_android -f "$TMP/lib.awk" "$2" > "$3"; cp "$3" "$4" ;;
    desktop) awk -v OP=norm_desktop -f "$TMP/lib.awk" "$2" > "$3"; awk -v OP=resolve -f "$TMP/lib.awk" "$3" > "$4" ;;
  esac
}

# ============================================================
#  โหมดพิเศษ: Catppuccin Mocha -> Latte แบบตารางสีตรง (ผลเหมือนเวอร์ชัน 1 ทุกไบต์)
# ============================================================
cat > "$TMP/conv.awk" <<'CONV_EOF'
function conv(s,   out, h) {
  out = ""
  while (match(s, /#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]/)) {
    h = toupper(substr(s, RSTART + 1, 6))
    out = out substr(s, 1, RSTART) ((h in M) ? M[h] : h)
    s = substr(s, RSTART + RLENGTH)
  }
  return out s
}
BEGIN { n = split(ONSUF, SUF, " ") }
FNR == 1 { f++ }
f == 1 { if (NF >= 2) M[toupper($1)] = toupper($2); next }
f == 2 { i = index($0, "="); if (i) O[substr($0, 1, i - 1)] = substr($0, i + 1); next }
{
  sub(/\r$/, "")
  i = index($0, ":")
  if (i == 0) { print; next }
  key = substr($0, 1, i - 1); val = substr($0, i + 1)
  if (key in O) { print key ": " O[key]; next }
  if (index(val, "#") && (key ~ /[Ss]eparator$/ || (STROKE == 1 && key ~ /_stroke$/ && key !~ /bubble/))) { print key ": " SEP; next }
  on = 0
  for (j = 1; j <= n; j++) { s = SUF[j]; if (length(key) >= length(s) && substr(key, length(key) - length(s) + 1) == s) on = 1 }
  if (on) { print key ": " ONC; next }
  print key ":" conv(val)
}
CONV_EOF

catppuccin_latte() {   # <ต้นทาง ios raw> <ผลลัพธ์>
  cat > "$TMP/cmap" <<'EOF'
CDD6F4 4C4F69
BAC2DE 5C5F77
A6ADC8 6C6F85
9399B2 7C7F93
7F849C 8C8FA1
6C7086 9CA0B0
585B70 ACB0BE
45475A BCC0CC
313244 CCD0DA
1E1E2E EFF1F5
181825 E6E9EF
11111B DCE0E8
A6E3A1 40A02B
6B9968 40A02B
F38BA8 D20F39
FAB387 FE640B
89B4FA 1E66F5
91CA8D A9D99A
575B55 9CA0B0
EOF
  cat > "$TMP/covr" <<'EOF'
name=☕ Latte
shortname=ctp_latte_ios
basedOn=day
dark=false
intro_statusBar=black
root_statusBar=black
root_keyboard=light
actionSheet_bgType=light
notification_expanded_bgType=light
wallpaper=#DCE0E8
actionSheet_dim=#4C4F697F
contextMenu_dim=#4C4F6999
list_itemBlocksBg=#FFFFFF
list_itemHighlightedBg=#E6E9EF
chat_message_incoming_bubble_withWp_bg=#FFFFFF
chat_message_incoming_bubble_withWp_gradientBg=#FFFFFF
chat_message_incoming_bubble_withWp_stroke=#FFFFFF
chat_message_incoming_bubble_withoutWp_bg=#FFFFFF
chat_message_incoming_bubble_withoutWp_gradientBg=#FFFFFF
chat_message_incoming_bubble_withoutWp_stroke=#FFFFFF
chat_message_outgoing_bubble_withWp_bg=#BFE8B0
chat_message_outgoing_bubble_withWp_gradientBg=#BFE8B0
chat_message_outgoing_bubble_withoutWp_bg=#BFE8B0
chat_message_outgoing_bubble_withoutWp_gradientBg=#BFE8B0
chat_message_incoming_linkText=#1E66F5
chat_message_infoLinkText=#1E66F5
EOF
  awk -v ONC="#FFFFFF" -v SEP="#CCD0DA" -v STROKE=1 \
      -v ONSUF="badgeText unreadBadgeActiveText actionControlFg list_check_fg list_switch_handle actionSheet_checkContent" \
      -f "$TMP/conv.awk" "$TMP/cmap" "$TMP/covr" "$1" > "$2"
}

# ============================================================
#  iOS: ปรับส่วนหัว/สีเฉพาะจุดหลังแปลง (โหมดมืด-สว่าง, ตัวอักษรบนสี accent, เส้นแบ่ง ฯลฯ)
#  ios_post <ไฟล์เข้า> <ไฟล์ออก> <cross 1|0> ใช้ $TMP/roles_work และ $RESMODE
# ============================================================
ios_post() {
  _in=$1; _out=$2; _cross=$3
  bgc=$(rget BG "$TMP/roles_work");  txc=$(rget TXT "$TMP/roles_work"); acc=$(rget ACCENT "$TMP/roles_work")
  lnk=$(rget LINK "$TMP/roles_work"); ob=$(rget OUTBUB "$TMP/roles_work")
  onc=$(best "$acc" "FFFFFF $bgc $txc")
  sep=$(mix "$bgc" "$txc" 0.12)
  if [ "$RESMODE" = dark ]; then
    _d=true; _b=night; _s=white; _k=dark; _t=dark
  else
    _d=false; _b=day; _s=black; _k=light; _t=light
  fi
  {
    echo "name=$THEME_NAME"; echo "shortname=$THEME_SHORT"
    echo "basedOn=$_b"; echo "dark=$_d"
    echo "intro_statusBar=$_s"; echo "root_statusBar=$_s"; echo "root_keyboard=$_k"
    echo "actionSheet_bgType=$_t"; echo "notification_expanded_bgType=$_t"
    echo "actionSheet_dim=#0000007F"; echo "contextMenu_dim=#00000099"
    if [ -n "$WALLPAPER" ]; then echo "wallpaper=$WALLPAPER"; else echo "wallpaper=#$bgc"; fi
    if [ "$_cross" = 1 ]; then
      # แปลงข้ามแพลตฟอร์ม: ตั้งฟองขาออก/ลิงก์ใหม่ทั้งหมด
      otx=$(best "$ob" "$txc $bgc")
      echo "chat_message_outgoing_primaryText=#$otx"
      for g in withWp withoutWp; do
        echo "chat_message_outgoing_bubble_${g}_bg=#$ob"
        echo "chat_message_outgoing_bubble_${g}_gradientBg=#$ob"
        echo "chat_message_outgoing_bubble_${g}_highlightedBg=#$(mix "$ob" "$otx" 0.12)"
      done
      echo "chat_message_outgoing_linkText=#$lnk"
      echo "chat_message_incoming_linkText=#$lnk"
      echo "chat_message_infoLinkText=#$lnk"
    fi
  } > "$TMP/post_ovr"
  echo "ZZZZZZ ZZZZZZ" > "$TMP/post_map"        # ตารางแมปว่าง (awk ต้องมีไฟล์แรกไม่ว่าง)
  awk -v ONC="#$onc" -v SEP="#$sep" -v STROKE=0 \
      -v ONSUF="badgeText unreadBadgeActiveText actionControlFg list_check_fg list_switch_handle actionSheet_checkContent" \
      -f "$TMP/conv.awk" "$TMP/post_map" "$TMP/post_ovr" "$_in" > "$_out"
}

# ---------- ตัวช่วยทั่วไป ----------
clean() { printf '%s' "$1" | sed "s/^['\"]//; s/['\"]\$//"; }

usage() {
  awk 'NR > 1 { print } NR > 1 && /^# =====/ { c++ } c == 2 { exit }' "$0" | sed 's/^# \{0,1\}//'
}

# ============================================================
#  ลำดับงานหลัก
# ============================================================
convert() {
  IN=$1; OUT=$2
  [ -f "$IN" ] || die "ไม่พบไฟล์ต้นทาง: $IN"

  # ---- 1) ตรวจรูปแบบ + อ่านเข้า ----
  FMT=$(detect "$IN"); ISZIP=0
  if [ "$FMT" = zip ]; then
    command -v unzip >/dev/null 2>&1 || die "ต้องใช้ unzip อ่านไฟล์ .tdesktop-theme (iSH: apk add unzip)"
    unzip -p "$IN" colors.tdesktop-theme > "$TMP/src.in" 2>/dev/null || die "ไม่พบ colors.tdesktop-theme ในไฟล์ zip"
    FMT=desktop; ISZIP=1
  else
    cp "$IN" "$TMP/src.in"
  fi
  [ "$FMT" != '?' ] || die "ไม่รู้จักรูปแบบไฟล์ (รองรับ iOS / Android / Desktop)"
  normalize "$FMT" "$TMP/src.in" "$TMP/raw" "$TMP/canon"
  [ -s "$TMP/canon" ] || die "อ่านสีจากไฟล์ไม่ได้"
  roles_of "$FMT" "$TMP/canon" "$TMP/roles_src"
  SRCMODE=$(modeof "$(rget BG "$TMP/roles_src")")

  # ---- 2) ชนิดผลลัพธ์ ----
  ANDROID_HEX=0; grep -q '^[A-Za-z0-9_]*: *#' "$TMP/src.in" && ANDROID_HEX=1
  if [ -z "$TGT" ] || [ "$TGT" = same ]; then
    case $FMT in
      ios) TGT=ios ;;
      android) if [ "$ANDROID_HEX" = 1 ]; then TGT=android-txt; else TGT=android; fi ;;
      desktop) if [ "$ISZIP" = 1 ]; then TGT=desktop-zip; else TGT=desktop; fi ;;
    esac
  fi
  case $TGT in
    ios) TF=ios; EXT=tgios-theme ;;
    android) TF=android; EXT=attheme ;;
    android-txt) TF=android; EXT=txt ;;
    desktop) TF=desktop; EXT=tdesktop-palette ;;
    desktop-zip)
      TF=desktop; EXT=tdesktop-theme
      if ! command -v zip >/dev/null 2>&1; then
        note "ไม่มีคำสั่ง zip (iSH: apk add zip) จึงสร้างเป็น .tdesktop-palette แทน"
        TGT=desktop; EXT=tdesktop-palette
      fi ;;
    *) die "ชนิดผลลัพธ์ไม่ถูกต้อง: $TGT" ;;
  esac

  # ---- 3) โหมดสี ----
  FLIP=0; DIR=""
  case $MODE_OPT in
    keep|"") ;;
    light) if [ "$SRCMODE" = dark ]; then FLIP=1; DIR=light; else note "ธีมนี้เป็นโหมดสว่างอยู่แล้ว ไม่สลับ"; fi ;;
    dark)  if [ "$SRCMODE" = light ]; then FLIP=1; DIR=dark; else note "ธีมนี้เป็นโหมดมืดอยู่แล้ว ไม่สลับ"; fi ;;
    flip)  FLIP=1; if [ "$SRCMODE" = dark ]; then DIR=light; else DIR=dark; fi ;;
    *) die "โหมดสีไม่ถูกต้อง: $MODE_OPT (keep|light|dark|flip)" ;;
  esac
  if [ "$FLIP" = 1 ]; then RESMODE=$DIR; else RESMODE=$SRCMODE; fi

  # ---- 4) ชื่อธีม / ไฟล์ผลลัพธ์ ----
  base=${IN##*/}; base=${base%.*}
  THEME_NAME=$(grep -m1 '^name:' "$TMP/raw" | sed 's/^name:[ ]*//')
  THEME_SHORT=$(grep -m1 '^shortname:' "$TMP/raw" | sed 's/^shortname:[ ]*//')
  [ -n "$THEME_NAME" ] || THEME_NAME=$base
  [ -n "$THEME_SHORT" ] || THEME_SHORT=$(printf '%s' "$base" | tr -c 'A-Za-z0-9\n' '_')
  if [ "$FLIP" = 1 ]; then THEME_NAME="$THEME_NAME ($RESMODE)"; THEME_SHORT="${THEME_SHORT}_$RESMODE"; fi
  WALLPAPER=$(grep -m1 '^wallpaper:' "$TMP/raw" | sed 's/^wallpaper:[ ]*//')

  if [ -z "$OUT" ]; then
    tag=""
    [ "$TF" != "$FMT" ] && tag="$TF"
    [ "$FLIP" = 1 ] && tag="${tag:+$tag-}$RESMODE"
    [ -n "$tag" ] || tag="new"
    OUT="${IN%.*}-$tag.$EXT"
  fi
  [ "$OUT" != "$IN" ] || OUT="${IN%.*}-new.$EXT"

  # ---- 5) บทบาทสีที่ใช้งาน (สลับสว่าง/มืดถ้าสั่ง) ----
  if [ "$FLIP" = 1 ]; then
    awk -v OP=fliproles -v DIR="$DIR" -f "$TMP/lib.awk" "$TMP/roles_src" > "$TMP/roles_work"
  else
    cp "$TMP/roles_src" "$TMP/roles_work"
  fi

  # ---- 6) สร้างธีมเป้าหมายในรูป raw ----
  if [ "$TF" = "$FMT" ]; then
    # รูปแบบเดียวกัน: เก็บโครงเดิมไว้ทั้งหมด (สลับสีเฉพาะเมื่อสั่ง)
    if [ "$FMT" = ios ] && [ "$FLIP" = 1 ] && [ "$DIR" = light ] \
       && [ "$(rget BG "$TMP/roles_src")" = 1E1E2E ] && [ "$(rget TXT "$TMP/roles_src")" = CDD6F4 ]; then
      note "ตรวจพบ Catppuccin Mocha จึงใช้ตารางสี Latte ตรง ๆ"
      catppuccin_latte "$TMP/raw" "$TMP/final"
    else
      if [ "$FLIP" = 1 ]; then
        awk -v OP=flip -v DIR="$DIR" -f "$TMP/lib.awk" "$TMP/raw" > "$TMP/work"
      else
        cp "$TMP/raw" "$TMP/work"
      fi
      if [ "$FMT" = ios ] && [ "$FLIP" = 1 ]; then ios_post "$TMP/work" "$TMP/final" 0
      else cp "$TMP/work" "$TMP/final"; fi
    fi
  else
    # ข้ามรูปแบบ: ใช้แม่แบบของเป้าหมาย แล้วแมปสีตามบทบาทจากธีมต้นทาง
    emit_tpl "$TF" > "$TMP/tpl_raw"
    if [ "$TF" = desktop ]; then awk -v OP=resolve -f "$TMP/lib.awk" "$TMP/tpl_raw" > "$TMP/tpl_canon"
    else cp "$TMP/tpl_raw" "$TMP/tpl_canon"; fi
    roles_of "$TF" "$TMP/tpl_canon" "$TMP/roles_tpl"
    if [ "$TF" != ios ]; then
      _ob=$(rget OUTBUB "$TMP/roles_work"); _tx=$(rget TXT "$TMP/roles_work")
      if [ "$(lowc "$_ob" "$_tx" 3)" = 1 ]; then
        _nb=$(mix "$(rget BG "$TMP/roles_work")" "$(rget ACCENT "$TMP/roles_work")" 0.35)
        awk -v R=OUTBUB -v V="$_nb" '$1 == R { print R, V; next } { print }' "$TMP/roles_work" > "$TMP/rw2" && mv "$TMP/rw2" "$TMP/roles_work"
      fi
    fi
    if [ "$TF" = ios ]; then
      # สีเขียวเฉพาะของฟองขาออกในแม่แบบ iOS -> ผูกกับสีที่คำนวณจากธีมต้นทาง
      ob=$(rget OUTBUB "$TMP/roles_work"); tx=$(rget TXT "$TMP/roles_work"); bgc=$(rget BG "$TMP/roles_work")
      ac=$(rget ACCENT "$TMP/roles_work"); tl=$(rget TEAL "$TMP/roles_work"); lk=$(rget LINK "$TMP/roles_work")
      otx=$(best "$ob" "$tx $bgc")
      {
        echo "OX1 25AD0D"; echo "OX2 077C00"; echo "OX3 119400"; echo "OX4 79C160"; echo "OX5 289715"
        echo "OX6 599E49"; echo "OX7 96D790"; echo "OX8 A3C57B"; echo "OX9 004BAD"
      } >> "$TMP/roles_tpl"
      {
        echo "OX1 $tl"; echo "OX2 $(mix "$otx" "$ob" 0.35)"; echo "OX3 $otx"; echo "OX4 $(mix "$otx" "$ob" 0.40)"
        echo "OX5 $otx"; echo "OX6 $(mix "$otx" "$ob" 0.35)"; echo "OX7 $(mix "$ob" "$otx" 0.15)"
        echo "OX8 $(mix "$ob" "$ac" 0.40)"; echo "OX9 $lk"
      } >> "$TMP/roles_work"
    fi
    awk -v OP=remap -f "$TMP/lib.awk" "$TMP/roles_tpl" "$TMP/roles_work" "$TMP/tpl_raw" > "$TMP/work"
    if [ "$TF" = ios ]; then ios_post "$TMP/work" "$TMP/final" 1
    else cp "$TMP/work" "$TMP/final"; fi
  fi

  # ---- 7) เขียนไฟล์ผลลัพธ์ตามรูปแบบ ----
  case $TGT in
    ios) cp "$TMP/final" "$OUT" ;;
    android-txt) grep '^[A-Za-z0-9_]*: *#' "$TMP/final" > "$OUT" ;;
    android) awk -v OP=attheme -f "$TMP/lib.awk" "$TMP/final" > "$OUT" ;;
    desktop|desktop-zip)
      {
        echo "// Generated by 'แปลงธีม Telegram.sh' v$VERSION  ($THEME_NAME)"
        awk -v OP=desktop -f "$TMP/lib.awk" "$TMP/final"
      } > "$TMP/colors.tdesktop-theme"
      if [ "$TGT" = desktop-zip ]; then
        mkdir -p "$TMP/z"; cp "$TMP/colors.tdesktop-theme" "$TMP/z/"
        if [ "$ISZIP" = 1 ]; then       # คงรูปพื้นหลังเดิมของธีม Desktop ต้นทางไว้
          mkdir -p "$TMP/zs"; unzip -oq "$IN" -d "$TMP/zs" 2>/dev/null
          for _p in "$TMP"/zs/background.* "$TMP"/zs/tiled.*; do [ -f "$_p" ] && cp "$_p" "$TMP/z/"; done
        fi
        # สร้างใน TMP ก่อนแล้วค่อยย้าย (zip จะเติม .zip ให้ชื่อที่ไม่มีนามสกุล และต้องไม่ผูกกับ path สัมพัทธ์)
        rm -f "$TMP/out.zip"
        ( cd "$TMP/z" && zip -q -9 "$TMP/out.zip" ./* ) || die "สร้างไฟล์ zip ไม่สำเร็จ"
        [ -s "$TMP/out.zip" ] || die "สร้างไฟล์ zip ไม่สำเร็จ"
        cp "$TMP/out.zip" "$OUT"
      else
        cp "$TMP/colors.tdesktop-theme" "$OUT"
      fi ;;
  esac

  echo "เสร็จแล้ว: $OUT"
  echo "  $(fmtname $FMT) [$SRCMODE]  ->  $TGT [$RESMODE]"
  if [ "$TF" != "$FMT" ]; then
    note "แปลงข้ามรูปแบบเป็นการประมาณสีตามบทบาท อาจต้องปรับบางจุดเอง"
  fi
  if [ "$TF" = desktop ]; then
    note "ไฟล์ Desktop ที่สร้างยังไม่ได้ทดสอบกับแอปจริง"
  fi
}

# ============================================================
#  เมนูโต้ตอบ
# ============================================================
interactive() {
  echo "=== แปลงธีม Telegram v$VERSION ==="
  printf "path ไฟล์ธีมต้นทาง: "; read -r IN; IN=$(clean "$IN")
  [ -f "$IN" ] || die "ไม่พบไฟล์: $IN"
  _d=$(detect "$IN"); echo "ตรวจพบรูปแบบ: $(fmtname $_d)"
  echo "เลือกชนิดผลลัพธ์:"
  echo "  1) iOS (.tgios-theme)"
  echo "  2) Android (.attheme)"
  echo "  3) Android (ข้อความ hex .txt)"
  echo "  4) Desktop (.tdesktop-palette)"
  echo "  5) Desktop (.tdesktop-theme แบบ zip)"
  echo "  6) เหมือนต้นทาง"
  printf "เลือก [1-6]: "; read -r _c
  case "$_c" in 1) TGT=ios;; 2) TGT=android;; 3) TGT=android-txt;; 4) TGT=desktop;; 5) TGT=desktop-zip;; *) TGT=same;; esac
  echo "โหมดสี:  1) คงเดิม  2) สว่าง  3) มืด  4) สลับกลับด้าน"
  printf "เลือก [1-4]: "; read -r _m
  case "$_m" in 2) MODE_OPT=light;; 3) MODE_OPT=dark;; 4) MODE_OPT=flip;; *) MODE_OPT=keep;; esac
  printf "path ไฟล์ผลลัพธ์ (เว้นว่าง = อัตโนมัติ): "; read -r OUT; OUT=$(clean "$OUT")
}

# ============================================================
#  อ่านอาร์กิวเมนต์
# ============================================================
TGT=""; MODE_OPT=""; IN=""; OUT=""
# คำสั่งแบบเดิมของเวอร์ชัน 1
case "$1" in
  light)   MODE_OPT=light; shift ;;
  android) TGT=ios; shift ;;
esac
while getopts t:m:h _o; do
  case $_o in
    t) case $OPTARG in
         attheme) TGT=android ;; txt) TGT=android-txt ;; palette) TGT=desktop ;; zip) TGT=desktop-zip ;;
         *) TGT=$OPTARG ;;
       esac ;;
    m) MODE_OPT=$OPTARG ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

if [ $# -eq 0 ]; then
  interactive
else
  IN=$(clean "$1"); OUT=$(clean "$2")
fi
convert "$IN" "$OUT"
