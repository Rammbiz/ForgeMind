"""Build the art-prompt library page from docs/design/heroes_prompts.md (prompts verbatim, Vesta = variant B)."""
import html
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))  # crystal-rush/
SRC = os.path.join(ROOT, 'docs', 'design', 'heroes_prompts.md')
# The self-contained page (data-URI images) for the Claude app artifact; --repo writes docs/art_prompts/index.html instead.
OUT = os.environ.get('ART_PROMPTS_OUT', os.path.join(HERE, 'out', 'crystal_rush_art_prompts.html'))

GEM_KEY = {'Кварц': 'quartz', 'Сапфір': 'sapphire', 'Аметист': 'amethyst', 'Топаз': 'topaz', 'Опал': 'opal'}

lines = open(SRC, encoding='utf-8').read().split('\n')


def find(prefix, start=0):
    for i in range(start, len(lines)):
        if lines[i].startswith(prefix):
            return i
    raise SystemExit('not found: ' + prefix)


# ---------------------------------------------------------------- Vesta: the owner chose variant B (crimson-orange cape)
v0 = find('### H07 `vesta`')
v1 = find('### ', v0 + 1)
vs = lines[v0:v1]


def vidx(prefix):
    for i, l in enumerate(vs):
        if l.startswith(prefix):
            return i
    raise SystemExit('vesta marker: ' + prefix)


a_start = vidx('*Варіант A')
b_start = vidx('*Варіант B')
b1 = vidx('*b1 Фронт*')
b2 = vidx('*b2 Бік + спина*')
b2b = vidx('Варіант B (референс')
new = vs[:a_start]
new += ['VESTA_REF', '']
new += ['Обрано варіант B: багряно-помаранчевий плащ (твоє рішення). Варіант A з рожевим плащем прибрано.', '', '*Сплеш, варіант B* — `vesta_splash.png`', '']
new += vs[b_start + 1:b1]
new += ['*b1 Фронт* — уже є: твій A-pose лист Вести (і `vesta_sheet_v1.png`). Нічого не генеруйте; якщо на листі ще видно глефу, прибери її правкою в тому ж чаті Gemini: `Remove the glaive from her hand, keep the hand open and empty; change nothing else.`', '']
new += ['*b2 Бік + спина* — `vesta_sheet_sideback.png` (референс — твій A-pose лист Вести):', '']
new += vs[b2b + 1:]
lines[v0:v1] = new
# the splash settings line names vesta_gemini.jpg as the reference; keep it (it IS the reference for the first run)

text = '\n'.join(lines)


# ---------------------------------------------------------------- tiny markdown renderer
def inline(s):
    s = html.escape(s, quote=False)
    s = re.sub(r'`([^`]+)`', r'<code>\1</code>', s)
    s = re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', s)
    s = re.sub(r'(?<![\w*])\*([^*\n]+?)\*(?![\w*])', r'<em>\1</em>', s)
    return s


prompt_counter = [0]
import base64, io
from PIL import Image as _Img
ART = os.path.join(ROOT, 'art_src', 'heroes') + os.sep
RECEIVED = {  # hero id -> [(file, caption)], the owner's finished art (newest first is not needed: one per kind)
    'vesta': [('vesta/vesta_splash_src.jpg', 'Сплеш')],
    'titan': [('titan/titan_splash_src.jpg', 'Сплеш')],
    'bolt': [('bolt/bolt_splash_src.jpg', 'Сплеш')],
    'seer': [('seer/seer_splash_src.jpg', 'Сплеш'), ('seer/seer_splash_eyes_closed_src.jpg', 'Очі заплющені')],
    'lumen': [('lumen/lumen_splash_src.jpg', 'Сплеш')],
    'arin': [('arin/arin_splash_src.jpg', 'Сплеш')],
    'eira': [('eira/eira_splash_src.jpg', 'Сплеш')],
    'iskar': [('iskar/iskar_splash_src.jpg', 'Сплеш')],
    'vartan': [('vartan/vartan_splash_src.jpg', 'Сплеш')],
    'pava': [('pava/pava_splash_src.jpg', 'Сплеш (4K)')],
    'otto': [('otto/otto_card_src.jpg', 'Картка (4K)')],
    'alba': [('alba/alba_card_src.jpg', 'Картка (4K)')],
    'mila': [('mila/mila_card_src.jpg', 'Картка (4K)')],
    'ivo': [('ivo/ivo_card_src.jpg', 'Картка (4K)')],
    'borko': [('borko/borko_card_src.jpg', 'Картка (4K)')],
    'taya': [('taya/taya_card_src.jpg', 'Картка (4K)')],
    'taras': [('taras/taras_card_src.jpg', 'Картка (4K)')],
    'snaryad': [('snaryad/snaryad_card_src.jpg', 'Картка (4K)')],
    'dovbush': [('dovbush/dovbush_card_src.jpg', 'Картка (4K)')],
    'sirko': [('sirko/sirko_splash_src.jpg', 'Сплеш (4K)')],
}
_uri_cache = {}


REPO_MODE = '--repo' in sys.argv


def art_uri(rel):
    if REPO_MODE:   # the repo page links the committed sources (served next to it by raw.githack)
        return '../../art_src/heroes/' + rel
    if rel not in _uri_cache:
        im = _Img.open(ART + rel).convert('RGB')
        if im.width > 768:   # embedded copies stay phone-sized (the 4K masters live in the repo)
            im = im.resize((768, round(768 * im.height / im.width)), _Img.LANCZOS)
        buf = io.BytesIO(); im.save(buf, 'JPEG', quality=86, optimize=True)
        _uri_cache[rel] = 'data:image/jpeg;base64,' + base64.b64encode(buf.getvalue()).decode()
    return _uri_cache[rel]


def art_figs(cid, name, cls='artrow'):
    figs = ''.join(f'<figure class="art"><img src="{art_uri(f)}" alt="{html.escape(name)}: {html.escape(cap)}" loading="lazy" width="768" height="1376"><figcaption>{html.escape(cap)}</figcaption></figure>' for f, cap in RECEIVED.get(cid, []))
    return f'<div class="{cls}">{figs}</div>' if figs else ''
VESTA_FIG = open(os.path.join(HERE, 'vesta_fig.html'), encoding='utf-8').read()
prompts_index = []   # (id, char_id, label, kind)


def render(md_lines, char_id, char_name):
    out = []
    i = 0
    label = ''
    para = []

    def flush():
        if para:
            out.append('<p>' + inline(' '.join(para)) + '</p>')
            para.clear()

    while i < len(md_lines):
        l = md_lines[i]
        if l.startswith('```'):
            flush()
            j = i + 1
            body = []
            while j < len(md_lines) and not md_lines[j].startswith('```'):
                body.append(md_lines[j])
                j += 1
            prompt_counter[0] += 1
            pid = f'p{prompt_counter[0]}'
            kind = classify(label, body)
            nice = re.sub(r'<[^>]+>', '', inline(label)).strip() or 'Промт'
            fm = re.search(r'^(.*?\b[\w]+\.(?:png|glb|jpg))', nice)
            if fm:
                nice = fm.group(1)
            elif len(nice) > 90:
                nice = nice[:nice.find('.') + 1] if 0 < nice.find('.') < 90 else nice[:88] + '…'
            nice = nice.rstrip(':').strip()
            ref = char_id in ('guide', 'order', 'open')
            got = char_id in RECEIVED and (kind in ('splash', 'card') or 'eyes_closed' in nice)
            if not ref:
                prompts_index.append({'id': pid, 'char': char_id, 'name': char_name, 'label': nice, 'kind': kind, 'got': got})
            donebox = '' if ref else (f'<span class="got">Отримано ✓</span>' if got else f'<label class="done"><input type="checkbox" data-done="{pid}" id="done-{pid}"> Готово</label>')
            out.append(
                f'<div class="prompt" id="{pid}" data-kind="{kind}">'
                f'<div class="ptools"><span class="plabel">{html.escape("Довідка: " + nice if ref and nice == "Промт" else nice)}</span>'
                f'{donebox}'
                f'<button class="copy" type="button" data-copy="{pid}">Копіювати</button></div>'
                f'<pre><code>{html.escape(chr(10).join(body))}</code></pre></div>')
            i = j + 1
            continue
        if l.startswith('|'):
            flush()
            rows = []
            while i < len(md_lines) and md_lines[i].startswith('|'):
                rows.append(md_lines[i])
                i += 1
            cells = [[c.strip() for c in r.strip().strip('|').split('|')] for r in rows]
            head, body = cells[0], [r for r in cells[1:] if not all(re.fullmatch(r':?-{2,}:?', c) for c in r)]
            t = ['<div class="tablewrap"><table><thead><tr>' + ''.join(f'<th>{inline(c)}</th>' for c in head) + '</tr></thead><tbody>']
            for r in body:
                t.append('<tr>' + ''.join(f'<td>{inline(c)}</td>' for c in r) + '</tr>')
            t.append('</tbody></table></div>')
            out.append(''.join(t))
            continue
        m = re.match(r'^(#{2,4}) (.*)', l)
        if m:
            flush()
            lvl = len(m.group(1)) + 1
            out.append(f'<h{min(lvl, 5)}>{inline(m.group(2))}</h{min(lvl, 5)}>')
            i += 1
            continue
        if re.match(r'^\s*([-*]|\d+\.) ', l) and not re.match(r'^\*[^ ]', l):
            flush()
            ordered = bool(re.match(r'^\s*\d+\. ', l))
            items = []
            while i < len(md_lines) and re.match(r'^\s*([-*]|\d+\.) ', md_lines[i]) and not re.match(r'^\*[^ ]', md_lines[i]):
                items.append(re.sub(r'^\s*([-*]|\d+\.) ', '', md_lines[i]))
                i += 1
            tag = 'ol' if ordered else 'ul'
            out.append(f'<{tag}>' + ''.join(f'<li>{inline(x)}</li>' for x in items) + f'</{tag}>')
            continue
        if l.strip() == '---':
            flush()
            out.append('<hr>')
            i += 1
            continue
        if not l.strip():
            flush()
            i += 1
            continue
        if l.strip() == 'VESTA_REF':
            flush()
            out.append(VESTA_FIG)
            i += 1
            continue
        if l.startswith('**(') or (l.startswith('*') and not l.startswith('**')) or l.startswith('Варіант'):
            label = l
        para.append(l)
        i += 1
    flush()
    return '\n'.join(out)


def classify(label, body):
    first = body[0] if body else ''
    lab = label.lower()
    if 'hero splash' in first:
        return 'splash'
    if 'champion card' in first:
        return 'card'
    if 'image-to-3D' in first or 'turnaround' in first:
        return 'sheet'
    if 'skill icon' in first or 'action icon' in first.lower():
        return 'icon'
    if '(c) meshy' in lab or first.startswith(('Tall ', 'A ', 'An ', 'Young', 'Old')) and 'Create ONE' not in first:
        return 'meshy'
    return 'other'


# ---------------------------------------------------------------- split into sections
def section(start_prefix, end_prefix=None):
    s = find(start_prefix)
    e = find(end_prefix, s + 1) if end_prefix else len(text.split('\n'))
    return s, e


lines = text.split('\n')
s1 = find('## 1. ')
s2 = find('## 2. ')
s3 = find('## 3. ')
s4 = find('## 4. ')
s5 = find('## 5. ')
s6 = find('## 6. ')

guide_html = render(lines[s1 + 1:s2], 'guide', 'Біблія стилю')
order_html = render(lines[s2 + 1:s3], 'order', 'Порядок')


def characters(a, b):
    idx = [i for i in range(a, b) if lines[i].startswith('### ')]
    chars = []
    for k, st in enumerate(idx):
        en = idx[k + 1] if k + 1 < len(idx) else b
        head = lines[st][4:]
        m = re.match(r'([HC]\d+) `(\w+)` — ([^—]+) — (.+)', head)
        code, cid, uk, title = m.group(1), m.group(2), m.group(3).strip(), m.group(4).strip()
        body = lines[st + 1:en]
        gem = ''
        cls = el = fac = ''
        for l in body:
            if l.startswith('| ') and '/' in l and not l.startswith('| Самоцвіт') and not l.startswith('|---'):
                cells = [c.strip() for c in l.strip().strip('|').split('|')]
                gem = cells[0].split('/')[0].strip()
                cls, el, fac = cells[1], cells[2], cells[3]
                break
        chars.append({'code': code, 'id': cid, 'uk': uk, 'title': title, 'gem': GEM_KEY.get(gem, 'quartz'), 'gem_uk': gem,
                      'cls': cls, 'el': el, 'fac': fac, 'html': render(body, cid, uk)})
    return chars


heroes = characters(s3, s4)
champs = characters(s4, s5)
shared_idx = [i for i in range(s5, s6) if lines[i].startswith('### ')]
shared = []
for k, st in enumerate(shared_idx):
    en = shared_idx[k + 1] if k + 1 < len(shared_idx) else s6
    sid = 'shared' + str(k + 1)
    shared.append({'id': sid, 'title': lines[st][4:], 'html': render(lines[st + 1:en], sid, lines[st][4:])})
open_q = render(lines[s6 + 1:], 'open', 'Питання')

# batch A = every hero splash + every champion card
batch = [p for p in prompts_index if p['kind'] in ('splash', 'card')]
print('prompts', len(prompts_index), 'splash/card', len(batch), file=sys.stderr)


def char_block(c, kind):
    return (f'<details class="char gem-{c["gem"]}" id="{c["id"]}"><summary>'
            f'<span class="gemmark" aria-hidden="true"></span>'
            f'<span class="cname"><b>{html.escape(c["uk"])}</b> <span class="ctitle">{inline(c["title"])}</span></span>'
            f'<span class="cmeta">{html.escape(c["gem_uk"])} · {html.escape(c["cls"])} · {html.escape(c["el"])} · {html.escape(c["fac"])}</span>'
            f'<span class="cprog" data-prog="{c["id"]}"></span></summary><div class="cbody">{art_figs(c["id"], c["uk"])}{c["html"]}</div></details>')


batch_rows = ''.join(
    f'<li><a href="#{p["id"]}" data-jump="{p["id"]}"><span class="bname">{html.escape(p["name"])}</span>'
    f'<span class="bkind">{"сплеш 9:16" if p["kind"] == "splash" else "картка 3:4"}</span></a>'
    f'<span class="bstate{" got" if p.get("got") else ""}" data-state="{p["id"]}">{"✓" if p.get("got") else ""}</span></li>' for p in batch)

gallery = ''.join(
    f'<a class="gal" href="#{c["id"]}" data-open="{c["id"]}"><img src="{art_uri(RECEIVED[c["id"]][0][0])}" alt="{html.escape(c["uk"])}" loading="lazy" width="768" height="1376"><span>{html.escape(c["uk"])}</span></a>'
    for c in heroes + champs if c['id'] in RECEIVED)
n_got = sum(1 for c in heroes if c['id'] in RECEIVED)
n_got_c = sum(1 for c in champs if c['id'] in RECEIVED)
missing_h = [c['uk'] for c in heroes if c['id'] not in RECEIVED]
def uk_prompt_word(n):
    if n % 10 == 1 and n % 100 != 11:
        return 'промт'
    if 2 <= n % 10 <= 4 and not 12 <= n % 100 <= 14:
        return 'промти'
    return 'промтів'
missing = ('героїв: ' + ', '.join(missing_h) + '; ' if missing_h else '') + 'карток чемпіонів: ' + str(len(champs) - n_got_c) + ' з ' + str(len(champs))
page = open(os.path.join(HERE, 'template.html'), encoding='utf-8').read()
page = (page.replace('{{BATCH}}', batch_rows)
        .replace('{{HEROES}}', '\n'.join(char_block(c, 'hero') for c in heroes))
        .replace('{{CHAMPS}}', '\n'.join(char_block(c, 'champ') for c in champs))
        .replace('{{SHARED}}', '\n'.join(f'<details class="char shared" id="{s["id"]}"><summary><span class="cname"><b>{inline(s["title"])}</b></span><span class="cprog" data-prog="{s["id"]}"></span></summary><div class="cbody">{s["html"]}</div></details>' for s in shared))
        .replace('{{GUIDE}}', guide_html)
        .replace('{{ORDER}}', order_html)
        .replace('{{OPEN}}', open_q)
        .replace('{{INDEX}}', json.dumps(prompts_index, ensure_ascii=False))
        .replace('{{NPROMPTS}}', str(len(prompts_index)))
        .replace('{{NPROMPTS_WORD}}', uk_prompt_word(len(prompts_index)))
        .replace('{{NBATCH}}', str(len(batch)))
        .replace('{{GALLERY}}', gallery).replace('{{NGOT}}', str(n_got)).replace('{{NHEROES}}', str(len(heroes)))
        .replace('{{NGOTC}}', str(n_got_c)).replace('{{NCHAMPS}}', str(len(champs)))
        .replace('{{MISSING}}', html.escape(missing)))
if REPO_MODE:
    # htmlpreview.github.io disables every <script> and only re-enables them in a pass that does not run
    # for this page, so the repo build boots its script from an image's onload attribute instead.
    i0 = page.index('<script>'); i1 = page.index('</script>', i0)
    js = page[i0 + len('<script>'):i1]
    assert '<script' not in js
    gif = 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7'
    boot = ('<img alt="" hidden width="1" height="1" src="' + gif + '" onload="'
            + html.escape('this.onload=null;' + js, quote=True) + '">')
    page = page[:i0] + boot + page[i1 + len('</script>'):]
    OUT = os.path.join(ROOT, 'docs', 'art_prompts', 'index.html')
    import os
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    page = ('<!doctype html>\n<html lang="uk">\n<head>\n<meta charset="utf-8">\n'
            '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n'
            '<style>:root{padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}'
            'body{margin:0}img{max-width:100%}[hidden]{display:none!important}</style>\n</head>\n<body>\n'
            + page + '\n</body>\n</html>\n')
open(OUT, 'w', encoding='utf-8').write(page)
print('written', OUT, len(page), file=sys.stderr)
