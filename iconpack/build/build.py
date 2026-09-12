#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Build the Live Takt icon pack APK.

There is no Android SDK in this environment and dl.google.com is not reachable,
so the toolchain is assembled from Maven Central: aapt2 (and the framework
resource jar) out of the apktool distribution, dx for dexing, and apksig for
verification.  Signing is v1 via the JDK's jarsigner plus a v2 block written by
build/v2sign.py, and the archive is packed by build/apkzip.py so resources.arsc
stays uncompressed and 4-byte aligned - Android 11+ refuses to install it
otherwise.

    python3 build/build.py            # full build
    python3 build/build.py --icons    # only re-render the PNGs
"""

import argparse
import os
import shutil
import subprocess
import sys
import time
import urllib.request
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SRC = os.path.join(ROOT, "src")
ANDROID = os.path.join(ROOT, "android")
TOOLS = os.path.join(ROOT, "tools")
WORK = os.path.join(ROOT, "build", "work")
DIST = os.path.join(ROOT, "dist")

sys.path.insert(0, SRC)
sys.path.insert(0, HERE)

MAVEN = "https://repo1.maven.org/maven2"
ARTIFACTS = {
    "apktool.jar": "%s/org/apktool/apktool-cli/3.0.3/apktool-cli-3.0.3.jar" % MAVEN,
    "dx.jar": "%s/com/jakewharton/android/repackaged/dalvik-dx/16.0.1/dalvik-dx-16.0.1.jar" % MAVEN,
    "apksig.jar": "%s/com/android/tools/build/apksig/2.3.0/apksig-2.3.0.jar" % MAVEN,
}

PACKAGE = "ua.forge.livetakt"
VERSION_CODE = 1
VERSION_NAME = "1.0"
MIN_SDK = 21
TARGET_SDK = 34
FALLBACK_SCALE = "0.70"

# apksig 2.3.0 predates the module system and reaches into JDK internals.
JVM_OPENS = [
    "--add-exports", "java.base/sun.security.x509=ALL-UNNAMED",
    "--add-exports", "java.base/sun.security.pkcs=ALL-UNNAMED",
    "--add-exports", "java.base/sun.security.util=ALL-UNNAMED",
]

KEYSTORE = os.path.join(ROOT, "build", "keystore", "livetakt.p12")
KEY_ALIAS = "livetakt"
KEY_PASS = "livetakt"


def log(msg):
    print("[build] %s" % msg, flush=True)


def run(cmd, **kw):
    env = dict(os.environ)
    env["JAVA_TOOL_OPTIONS"] = ""          # silence the proxy banner on every JVM start
    proc = subprocess.run(cmd, capture_output=True, text=True, env=env, **kw)
    if proc.returncode != 0:
        sys.stderr.write(proc.stdout + "\n" + proc.stderr + "\n")
        raise SystemExit("command failed: %s" % " ".join(cmd[:3]))
    return proc.stdout


# --------------------------------------------------------------------------- #
# toolchain
# --------------------------------------------------------------------------- #

def fetch_tools():
    os.makedirs(TOOLS, exist_ok=True)
    for name, url in ARTIFACTS.items():
        path = os.path.join(TOOLS, name)
        if not os.path.exists(path):
            log("downloading %s" % name)
            urllib.request.urlretrieve(url, path)
    aapt2 = os.path.join(TOOLS, "aapt2")
    framework = os.path.join(TOOLS, "android-framework.jar")
    if not (os.path.exists(aapt2) and os.path.exists(framework)):
        log("extracting aapt2 and framework resources from apktool")
        with zipfile.ZipFile(os.path.join(TOOLS, "apktool.jar")) as zf:
            with open(aapt2, "wb") as fh:
                fh.write(zf.read("prebuilt/linux/aapt2"))
            with open(framework, "wb") as fh:
                fh.write(zf.read("prebuilt/android-framework.jar"))
        os.chmod(aapt2, 0o755)
    return aapt2, framework


def ensure_keystore():
    if os.path.exists(KEYSTORE):
        return
    os.makedirs(os.path.dirname(KEYSTORE), exist_ok=True)
    log("generating signing key")
    run(["keytool", "-genkeypair", "-keystore", KEYSTORE, "-storetype", "PKCS12",
         "-storepass", KEY_PASS, "-alias", KEY_ALIAS, "-keypass", KEY_PASS,
         "-keyalg", "RSA", "-keysize", "2048", "-sigalg", "SHA256withRSA",
         "-validity", "10950", "-dname", "CN=Live Takt Icons, O=ForgeMind, C=UA"])


# --------------------------------------------------------------------------- #
# sanity checks
# --------------------------------------------------------------------------- #

def check_catalog(apps, catalog):
    """Catch the mistakes that would otherwise ship as a blank tile."""
    import os as _os

    import marks
    import glyphs
    from fontTools.ttLib import TTFont

    cmaps = {}
    problems = []
    claimed = {}

    for app in apps:
        kind, value, opts = app.glyph
        if kind == "mark":
            if value not in marks.MARKS:
                problems.append("%s: unknown mark %r" % (app.slug, value))
        else:
            filename = glyphs.FONTS[opts.get("face", "geo")][0]
            if filename not in cmaps:
                cmaps[filename] = TTFont(_os.path.join(glyphs.FONT_DIR, filename),
                                         lazy=True).getBestCmap()
            for ch in value:
                if ord(ch) not in cmaps[filename]:
                    problems.append("%s: %r missing from %s" % (app.slug, ch, filename))
        if not app.packages and not app.components:
            problems.append("%s: no packages or components" % app.slug)
        for comp in catalog.components_for(app):
            if comp in claimed and claimed[comp] != app.slug:
                problems.append("%s and %s both claim %s" % (claimed[comp], app.slug, comp))
            claimed[comp] = app.slug

    if problems:
        for line in problems:
            log("  ! %s" % line)
        raise SystemExit("catalogue has %d problem(s)" % len(problems))
    log("catalogue checks passed")


# --------------------------------------------------------------------------- #
# resources
# --------------------------------------------------------------------------- #

def render_icons(apps, res_dir):
    import render
    out = os.path.join(res_dir, "drawable-nodpi")
    started = time.time()
    render.render_all(apps, out, progress=lambda i, n: log("  icons %d/%d" % (i, n)))
    log("rendered %d icons in %.1fs" % (len(apps), time.time() - started))


def xml_escape(text):
    return (text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
            .replace('"', "&quot;"))


def write_appfilter(apps, path, catalog):
    lines = ['<?xml version="1.0" encoding="utf-8"?>', "<resources>"]
    lines.append('    <iconback img1="iconback_0" img2="iconback_1" img3="iconback_2" img4="iconback_3"/>')
    lines.append('    <iconmask img1="iconmask"/>')
    lines.append('    <iconupon img1="iconupon"/>')
    lines.append('    <scale factor="%s"/>' % FALLBACK_SCALE)
    total = 0
    for app in apps:
        lines.append("    <!-- %s -->" % xml_escape(app.name))
        for comp in catalog.components_for(app):
            lines.append('    <item component="ComponentInfo{%s}" drawable="%s"/>'
                         % (xml_escape(comp), app.slug))
            total += 1
    lines.append("</resources>")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    return total


def write_drawable_xml(apps, path):
    groups = [("Українські застосунки", "ua"), ("Системні", "system"), ("Світові", None)]
    lines = ['<?xml version="1.0" encoding="utf-8"?>', "<resources>"]
    used = set()
    for title, tag in groups:
        picked = [a for a in apps if (tag in a.tags if tag else a.slug not in used)]
        if tag:
            used.update(a.slug for a in picked)
        if not picked:
            continue
        lines.append('    <category title="%s"/>' % xml_escape(title))
        for app in picked:
            lines.append('    <item drawable="%s"/>' % app.slug)
    lines.append("</resources>")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")


def write_theme_resources(apps, path):
    lines = ['<?xml version="1.0" encoding="utf-8"?>', "<Theme>",
             "    <Version>%s</Version>" % VERSION_NAME,
             "    <PackageName>%s</PackageName>" % PACKAGE,
             "    <AppFilter>appfilter</AppFilter>", "</Theme>"]
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")


def write_generated_strings(path, icons, components, packages):
    stats = "%d іконок · %d застосунків · %d компонентів" % (icons, packages, components)
    body = ('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
            '    <string name="pack_stats">%s</string>\n'
            '    <string name="version_name">%s</string>\n</resources>\n'
            % (xml_escape(stats), VERSION_NAME))
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(body)


def stage_resources(apps, catalog):
    res = os.path.join(WORK, "res")
    assets = os.path.join(WORK, "assets")
    if os.path.exists(WORK):
        shutil.rmtree(WORK)
    os.makedirs(os.path.join(res, "xml"), exist_ok=True)
    os.makedirs(assets, exist_ok=True)

    for entry in os.listdir(os.path.join(ANDROID, "res")):
        shutil.copytree(os.path.join(ANDROID, "res", entry), os.path.join(res, entry),
                        dirs_exist_ok=True)

    render_icons(apps, res)

    appfilter = os.path.join(res, "xml", "appfilter.xml")
    total = write_appfilter(apps, appfilter, catalog)
    shutil.copy(appfilter, os.path.join(assets, "appfilter.xml"))
    write_drawable_xml(apps, os.path.join(res, "xml", "drawable.xml"))
    shutil.copy(os.path.join(res, "xml", "drawable.xml"), os.path.join(assets, "drawable.xml"))
    write_theme_resources(apps, os.path.join(res, "xml", "theme_resources.xml"))
    write_generated_strings(os.path.join(res, "values", "generated.xml"), len(apps), total,
                            sum(len(a.packages) for a in apps))
    log("appfilter: %d component mappings" % total)
    return res, assets, total


# --------------------------------------------------------------------------- #
# apk
# --------------------------------------------------------------------------- #

def link_resources(aapt2, framework, res, assets):
    flat = os.path.join(WORK, "compiled.zip")
    run([aapt2, "compile", "--dir", res, "-o", flat, "--no-crunch"])
    base = os.path.join(WORK, "base.apk")
    gen = os.path.join(WORK, "gen")
    os.makedirs(gen, exist_ok=True)
    run([aapt2, "link", "-o", base, "-I", framework,
         "--manifest", os.path.join(ANDROID, "AndroidManifest.xml"),
         "-A", assets, "--java", gen,
         "--min-sdk-version", str(MIN_SDK), "--target-sdk-version", str(TARGET_SDK),
         "--version-code", str(VERSION_CODE), "--version-name", VERSION_NAME,
         flat])
    return base, gen


def build_dex(gen):
    classes = os.path.join(WORK, "classes")
    stubs_out = os.path.join(WORK, "stubs")
    os.makedirs(classes, exist_ok=True)
    os.makedirs(stubs_out, exist_ok=True)

    stub_sources = []
    for root, _, files in os.walk(os.path.join(ANDROID, "stubs")):
        stub_sources += [os.path.join(root, f) for f in files if f.endswith(".java")]
    run(["javac", "--release", "8", "-nowarn", "-d", stubs_out] + stub_sources)

    app_sources = []
    for base in (os.path.join(ANDROID, "java"), gen):
        for root, _, files in os.walk(base):
            app_sources += [os.path.join(root, f) for f in files if f.endswith(".java")]
    run(["javac", "--release", "8", "-nowarn", "-cp", stubs_out, "-d", classes] + app_sources)

    dex = os.path.join(WORK, "classes.dex")
    run(["java", "-cp", os.path.join(TOOLS, "dx.jar"), "com.android.dx.command.Main",
         "--dex", "--min-sdk-version=%d" % MIN_SDK, "--output=%s" % dex, classes])
    return dex


def package(base_apk, dex, out_path, extra_entries=()):
    """Rebuild the archive with alignment we control."""
    from apkzip import Entry, write_apk

    stored = lambda name: name.endswith(".png") or name == "resources.arsc"
    entries = []
    names = []
    with zipfile.ZipFile(base_apk) as zf:
        names = zf.namelist()
        # Manifest first, resources.arsc last: conventional, and keeps the
        # aligned (stored) payloads at the tail where they belong.
        order = (["META-INF/MANIFEST.MF"] if "META-INF/MANIFEST.MF" in names else [])
        order += [n for n in names if n not in order and n != "resources.arsc"]
        if "resources.arsc" in names:
            order.append("resources.arsc")
        for name in order:
            entries.append(Entry(name, zf.read(name), compress=not stored(name)))
    if dex:
        entries.insert(1 if entries and entries[0].name == b"AndroidManifest.xml" else 0,
                       Entry("classes.dex", open(dex, "rb").read(), compress=True))
    for name, data in extra_entries:
        entries.append(Entry(name, data, compress=True))
    write_apk(out_path, entries)
    return out_path


def sign(unsigned, out_path):
    import v2sign
    from apkzip import check_alignment
    from cryptography.hazmat.primitives.serialization import pkcs12, Encoding

    ensure_keystore()
    v1 = os.path.join(WORK, "v1.apk")
    run(["jarsigner", "-keystore", KEYSTORE, "-storetype", "PKCS12", "-storepass", KEY_PASS,
         "-digestalg", "SHA-256", "-sigalg", "SHA256withRSA",
         "-signedjar", v1, unsigned, KEY_ALIAS])

    # jarsigner rewrites the archive, so re-pack to restore alignment, then v2.
    aligned = os.path.join(WORK, "aligned.apk")
    package(v1, None, aligned)
    problems = check_alignment(aligned)
    if problems:
        raise SystemExit("alignment lost: %s" % problems)

    with open(KEYSTORE, "rb") as fh:
        key, cert, _ = pkcs12.load_key_and_certificates(fh.read(), KEY_PASS.encode())
    v2sign.sign(aligned, out_path, key, cert.public_bytes(Encoding.DER))
    return out_path


def verify(apk):
    from apkzip import check_alignment
    out = run(["java"] + JVM_OPENS + ["-cp", os.path.join(TOOLS, "apksig.jar"),
               os.path.join(HERE, "Signer.java"), "verify", apk, str(MIN_SDK)])
    log(out.strip().splitlines()[-1])
    if "verified=true" not in out:
        raise SystemExit("signature verification failed")
    problems = check_alignment(apk)
    if problems:
        raise SystemExit("alignment problems: %s" % problems)
    log("resources.arsc stored and 4-byte aligned")


# --------------------------------------------------------------------------- #

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--icons", action="store_true", help="only render the icons")
    parser.add_argument("--sheet", action="store_true", help="also write a contact sheet")
    args = parser.parse_args()

    import catalog
    apps = catalog.load()
    log("%d apps in catalogue" % len(apps))
    check_catalog(apps, catalog)

    if args.icons:
        render_icons(apps, os.path.join(WORK, "res"))
        return

    aapt2, framework = fetch_tools()
    res, assets, _ = stage_resources(apps, catalog)
    base, gen = link_resources(aapt2, framework, res, assets)
    dex = build_dex(gen)

    unsigned = os.path.join(WORK, "unsigned.apk")
    package(base, dex, unsigned)

    os.makedirs(DIST, exist_ok=True)
    apk = os.path.join(DIST, "LiveTakt-IconPack-%s.apk" % VERSION_NAME)
    sign(unsigned, apk)
    verify(apk)

    if args.sheet:
        import render
        sheet = render.contact_sheet([render.render_app(a) for a in apps[:70]], cols=10)
        sheet.save(os.path.join(DIST, "preview.png"))
        log("preview written")

    log("APK: %s (%.1f MB)" % (apk, os.path.getsize(apk) / 1048576.0))


if __name__ == "__main__":
    main()
