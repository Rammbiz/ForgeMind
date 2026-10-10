"""Generates an image with Gemini (Google AI Studio) from a prompt and optional reference images.

    py crystal-rush/tools/art/gemini_image.py --out <png> (--prompt "..." | --prompt-file <txt>)
        [--ref <image> ...] [--size 1K|2K|4K] [--aspect 3:4] [--search] [--model models/gemini-nano-banana-2.1]

The key is GEMINI_API_KEY: the environment, else the Windows user variable in the registry (the owner sets it
with ~/.claude/mcp/set-gemini-key.py; it never goes into the repo or a chat). Several images in the answer are
saved as <out>_2.png, <out>_3.png ...; the model's text, if any, is printed. Needs `pip install google-genai`.
"""
import argparse
import base64
import mimetypes
import os
import sys


def api_key() -> str:
    key = os.environ.get("GEMINI_API_KEY", "")
    if not key and sys.platform == "win32":
        import winreg
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as k:
                key = winreg.QueryValueEx(k, "GEMINI_API_KEY")[0]
        except OSError:
            key = ""
    if not key:
        sys.exit("GEMINI_API_KEY is not set: run ~/.claude/mcp/set-gemini-key.py first.")
    return key


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--prompt")
    ap.add_argument("--prompt-file")
    ap.add_argument("--ref", action="append", default=[], help="reference image (repeatable)")
    ap.add_argument("--size", default="1K", choices=["512", "1K", "2K", "4K"])
    ap.add_argument("--aspect", help="e.g. 1:1, 3:4, 16:9 (default: the model's choice)")
    ap.add_argument("--search", action="store_true", help="let the model use Google Search")
    ap.add_argument("--model", default="models/gemini-nano-banana-2.1")
    a = ap.parse_args()
    prompt = a.prompt if a.prompt else open(a.prompt_file, encoding="utf-8").read()
    from google import genai

    content = [{"type": "text", "text": prompt}]
    for path in a.ref:
        mime = mimetypes.guess_type(path)[0] or "image/png"
        with open(path, "rb") as f:
            content.append({"type": "image", "mime_type": mime, "data": base64.b64encode(f.read()).decode()})
    image_config = {"image_size": a.size}
    if a.aspect:
        image_config["aspect_ratio"] = a.aspect
    client = genai.Client(api_key=api_key())
    interaction = client.interactions.create(
        model=a.model,
        input=content if a.ref else prompt,
        tools=[{"type": "google_search"}] if a.search else [],
        generation_config={"max_output_tokens": 65536, "thinking_level": "medium", "image_config": image_config},
        response_modalities=["image", "text"],
    )
    saved = []
    for step in interaction.steps or []:
        if getattr(step, "type", "") != "model_output":
            continue
        if getattr(step, "error", None):
            print("model error:", step.error)
        for c in step.content or []:
            if getattr(c, "type", "") == "image" and getattr(c, "data", None):
                root, ext = os.path.splitext(a.out)
                path = a.out if not saved else "%s_%d%s" % (root, len(saved) + 1, ext or ".png")
                data = c.data if isinstance(c.data, bytes) else base64.b64decode(c.data)
                os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
                with open(path, "wb") as f:
                    f.write(data)
                saved.append(path)
            elif getattr(c, "type", "") == "text" and getattr(c, "text", ""):
                print(c.text)
    if not saved:
        sys.exit("No image in the answer.")
    print("saved", ", ".join(saved))


if __name__ == "__main__":
    main()
