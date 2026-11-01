import json, os, re, sys, time
import requests
from bs4 import BeautifulSoup

BASE = "https://st-takla.org/pub_Deuterocanon/Deuterocanon-Apocrypha_El-Asfar_El-Kanoneya_El-Tanya__"
BOOKS = {
    16: "1-Tobit_",
    17: "2-Judith_",
    48: "3-Esther_",
    24: "4-Wisdon-of-Solomon_",
    25: "5-Wisdon-of-Joshua-Son-of-Sirach_",
    29: "6-Baruch_",
    47: "7-Daniel_",
    44: "8-First-of-Maccabees_",
    45: "9-Second-of-Maccabees_",
}
REMAP = {47: {3: 1, 13: 2, 14: 3}, 48: {10: 1, 11: 2, 12: 3, 13: 4, 14: 5, 15: 6, 16: 7}}

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out_dir = os.path.join(root, "assets", "bible", "ar_extra")
cache = os.path.join(os.path.dirname(os.path.abspath(__file__)), "cache")
os.makedirs(out_dir, exist_ok=True)
os.makedirs(cache, exist_ok=True)
counts = json.load(open(os.path.join(root, "assets", "bible", "counts.json"), encoding="utf-8"))

REF = re.compile(r"(?m)^[ \t]*(?:[؀-ۿ\.]{1,14}[ \t]*)?(\d{1,3})[ \t]*[:：][ \t]*\n?[ \t]*(\d{1,3})[ \t]*[\-–]?[ \t]*(.*)$")


def get(idx, slug):
    p = os.path.join(cache, f"{idx}.html")
    if os.path.exists(p):
        return open(p, encoding="utf-8").read()
    for i in range(3):
        try:
            r = requests.get(BASE + slug + ".html", timeout=60, headers={"User-Agent": "Mozilla/5.0"})
            r.encoding = "utf-8"
            r.raise_for_status()
            open(p, "w", encoding="utf-8").write(r.text)
            return r.text
        except Exception as e:
            print("retry", idx, e)
            time.sleep(2)
    raise SystemExit("failed " + slug)


def parse(html):
    soup = BeautifulSoup(html, "html.parser")
    for t in soup(["script", "style", "nav", "noscript"]):
        t.decompose()
    lines = [l.strip() for l in soup.get_text("\n").split("\n")]
    lines = [l for l in lines if l]
    found = {}
    i = 0
    while i < len(lines):
        m = re.match(r"^(?:[؀-ۿ\.]{1,14}\s*)?(\d{1,3})\s*[:：]\s*(\d{1,3})\s*(.*)$", lines[i])
        if not m and i + 1 < len(lines):
            m2 = re.match(r"^(?:[؀-ۿ\.]{1,14}\s*)?(\d{1,3})\s*[:：]\s*$", lines[i])
            if m2 and re.match(r"^\d{1,3}\b", lines[i + 1]):
                n = re.match(r"^(\d{1,3})\s*(.*)$", lines[i + 1])
                m = re.match(r".*", "")
                c, v, txt = int(m2.group(1)), int(n.group(1)), n.group(2)
                i += 1
                m = (c, v, txt)
        elif m:
            m = (int(m.group(1)), int(m.group(2)), m.group(3))
        if m and isinstance(m, tuple):
            c, v, txt = m
            if not txt.strip() and i + 1 < len(lines):
                txt = lines[i + 1]
                i += 1
            txt = txt.strip()
            if len(txt) > 3 and "تفسير" not in txt[:10]:
                found[(c, v)] = txt
        i += 1
    return found


def build(idx, found):
    remap = REMAP.get(idx)
    chs = {}
    for (c, v), t in found.items():
        if remap:
            if c not in remap:
                continue
            c = remap[c]
        chs.setdefault(c, {})[v] = t
    if not chs:
        return None, ["no verses parsed"]
    warn = []
    n = max(chs)
    book = []
    for c in range(1, n + 1):
        vs = chs.get(c, {})
        if not vs:
            warn.append(f"chapter {c} empty")
            book.append([])
            continue
        mx = max(vs)
        miss = [v for v in range(1, mx + 1) if v not in vs]
        if miss:
            warn.append(f"chapter {c} missing verses {miss[:8]}")
        book.append([vs.get(v, "") for v in range(1, mx + 1)])
    exp = counts[idx][0]
    if n != exp:
        warn.append(f"chapters {n} != expected {exp}")
    return book, warn


only = [int(x) for x in sys.argv[1:]] or list(BOOKS)
for idx in only:
    html = get(idx, BOOKS[idx])
    found = parse(html)
    book, warn = build(idx, found)
    if book is None:
        print(idx, "FAILED", warn)
        continue
    json.dump(book, open(os.path.join(out_dir, f"{idx}.json"), "w", encoding="utf-8"), ensure_ascii=False)
    print(idx, "chapters", len(book), "verses", sum(len(c) for c in book), "warnings:", warn if warn else "none")
