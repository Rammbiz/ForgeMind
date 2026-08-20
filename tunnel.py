"""The public HTTPS address the Mini App is opened from.

Telegram loads a Mini App in its own browser, so the page has to be
reachable from the internet with a valid certificate. The bot lives
on a workshop PC behind a router, so cloudflared holds an outbound
connection to Cloudflare and they hand the traffic back down it —
no port forwarding, no fixed IP, and nothing else on this machine
becomes reachable.

Three ways to run it, tried in this order:

* a fixed address in FORGEMIND_PUBLIC_URL, for a named tunnel bound
  to your own domain. Nothing is started here.
* a tunnel already running on this machine — the copy in the
  startup folder — whose address is read out of its own log and
  checked by asking it for the page. Started at logon and outliving
  every restart of the bot, which is what keeps buttons alive.
* one started here, as a child of the bot, which is what happens
  when neither of the above is there. Its address dies with it.

A quick tunnel gets a fresh trycloudflare.com address whenever it
starts, so what makes an address last is not restarting the tunnel,
not who owns it.
"""

import logging
import os
import re
import subprocess
import threading
import time
import urllib.request


log = logging.getLogger("forgemind.tunnel")


CLOUDFLARED = [
    r"C:\Program Files (x86)\cloudflared\cloudflared.exe",
    r"C:\Program Files\cloudflared\cloudflared.exe"
]

# cloudflared announces the address in its own log, in a box drawn
# out of plus signs; this is the only line that matters.
ADDRESS = re.compile(r"https://[a-z0-9-]+\.trycloudflare\.com")

# Where the copy started at logon keeps its log.
LOG_FILE = r"C:\ForgeMind\files\tunnel.log"

STARTUP_TIMEOUT = 45

# A quick tunnel is not a promise. Cloudflare rotates them, the
# process can be restarted at logon, and either way the address
# goes with it — so the address is re-checked rather than trusted
# from startup, or every button minted after a rotation is born
# dead and nothing notices.
CHECK_TIMEOUT = 6

# Cloudflare's bot protection sits in front of the named tunnel and
# answers 403 to the stock Python user agent, so a health check made
# with it would report the tunnel dead and pull the button.
CHECK_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/126.0.0.0 Safari/537.36 ForgeMind/1.0"
)

NO_WINDOW = getattr(subprocess, "CREATE_NO_WINDOW", 0)


def executable():

    for path in CLOUDFLARED:

        if os.path.exists(path):
            return path

    return None


class Tunnel:
    """Keeps a public address pointing at the local viewer server."""

    def __init__(self, port):

        self.port = port
        self.url = None

        self.process = None
        self.reader = None

    def start(self):
        """Returns the public address, or None if there is no tunnel."""

        fixed = os.environ.get("FORGEMIND_PUBLIC_URL")

        if fixed:

            self.url = fixed.rstrip("/")

            log.info("Using fixed public address: %s", self.url)

            return self.url

        running = self.adopt()

        if running:

            self.url = running

            log.info("Adopted the running tunnel: %s", self.url)

            return self.url

        binary = executable()

        if binary is None:

            log.warning(
                "cloudflared is not installed, so the 3D viewer "
                "button will not be offered."
            )

            return None

        self.process = subprocess.Popen(
            [
                binary,
                "tunnel",
                "--no-autoupdate",
                "--url",
                "http://127.0.0.1:{}".format(self.port)
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
            creationflags=NO_WINDOW
        )

        self.reader = threading.Thread(target=self._read, daemon=True)
        self.reader.start()

        deadline = time.time() + STARTUP_TIMEOUT

        while time.time() < deadline and self.url is None:

            if self.process.poll() is not None:
                log.error("cloudflared exited before giving an address.")
                return None

            time.sleep(0.4)

        if self.url is None:
            log.error("cloudflared gave no address in time.")
        else:
            log.info("Public address: %s", self.url)

        return self.url

    def answers(self, url):
        """Whether that address still reaches this machine's viewer."""

        try:

            request = urllib.request.Request(
                url + "/",
                method="HEAD",
                headers={"User-Agent": CHECK_AGENT}
            )

            with urllib.request.urlopen(
                request,
                timeout=CHECK_TIMEOUT
            ) as answer:

                return answer.status == 200

        except Exception:
            return False

    def adopt(self):
        """The address of a tunnel already running, if it answers.

        The one in the startup folder writes its address into its
        own log. Asking that address for the viewer page is what
        proves it is this machine's tunnel and still up — an old
        line in the log otherwise sends every button nowhere.
        """

        try:

            with open(LOG_FILE, "r", encoding="utf-8", errors="replace") as f:
                found = ADDRESS.findall(f.read())

        except OSError:
            return None

        # A tunnel that restarts appends its new address, so the
        # last one written is the only one worth trying.
        if not found:
            return None

        url = found[-1]

        return url if self.answers(url) else None

    def refresh(self):
        """The address as it is now, which is not always as it was."""

        fixed = os.environ.get("FORGEMIND_PUBLIC_URL")

        if fixed:

            # A named tunnel keeps its address, but not necessarily
            # its connection: if it is down the button is better
            # withdrawn than left opening on an error page.
            self.url = fixed.rstrip("/") if self.answers(
                fixed.rstrip("/")
            ) else None

            return self.url

        found = self.adopt()

        if found:

            if found != self.url:
                log.info("Tunnel address changed to %s", found)

            self.url = found

            return self.url

        # Our own child writes to a pipe, not to the log file, so it
        # is asked directly.
        alive = (
            self.process is not None
            and self.process.poll() is None
            and self.url
            and self.answers(self.url)
        )

        if alive:
            return self.url

        if self.url:
            log.warning(
                "The tunnel is gone; the 3D button is off until "
                "it is back."
            )

        self.url = None

        return None

    def _read(self):
        """Watches the tunnel's own log for the address and for death."""

        for line in self.process.stdout:

            found = ADDRESS.search(line)

            if found and self.url is None:
                self.url = found.group(0)

        log.warning("cloudflared has stopped; the viewer is offline.")

        self.url = None

    def stop(self):

        if self.process is not None and self.process.poll() is None:

            self.process.terminate()

            self.process = None

        self.url = None
