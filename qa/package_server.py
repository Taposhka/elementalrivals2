from pathlib import Path
import io
import tokenize
import zipfile

p = Path(__file__).resolve().parent.parent
failures = []
count = 0
for f in p.rglob("*.gd"):
    if ".godot" in f.parts:
        continue
    count += 1
    quote = ""
    escaped = False
    for number, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
        for char in line:
            if escaped:
                escaped = False
            elif quote:
                if char == "\\":
                    escaped = True
                elif char == quote:
                    quote = ""
            elif char in ('"', "'"):
                quote = char
            elif char == "#":
                failures.append(f"{f.name}:{number}")
                break
for f in p.rglob("*.py"):
    count += 1
    for token in tokenize.generate_tokens(io.StringIO(f.read_text(encoding="utf-8")).readline):
        if token.type == tokenize.COMMENT:
            failures.append(f"{f.name}:{token.start[0]}")
assert not failures, failures
print(f"Comment audit: {count} files, 0 comments")
notes = p / "UPGRADE_NOTES.md"
s = notes.read_text(encoding="utf-8-sig")
s = s.replace("using minimal_arena.gd.", "using matchmaking_arena.gd.")
s = s.replace("| Fire | 54 | 34 damage, narrow slash, 0.14 s cooldown |", "| Fire | 96 | 34 damage on dash contact, 0.12 s dash, 0.24 s cooldown, 18 energy |")
s = s.replace("Network protocol version is 9", "Network protocol version is 10")
marker = "## Internet matchmaking and damaging fire dash"
if marker not in s:
    s += """

## Internet matchmaking and damaging fire dash

Online now opens an automatic queue without IP entry or manual host/join controls.
The included authoritative server creates independent rooms, starts at four players immediately
or with two after five seconds, and fills remaining slots with bots. Cancellation removes the
queued connection. A disconnected fighter is controlled by a bot.

The client and server have been tested together locally with multiple real game clients.
The public endpoint is deliberately empty until a hosting account is connected and the server
is deployed. Railway/Docker deployment files and a source archive are included. See server/README.md.
No permanent public service has been deployed yet.

Fire's basic attack is now a 96-unit dash that damages enemies along its actual movement path.
There is no separate cone attack or projectile. Each enemy, guard or shield can be hit once per
dash; teammates and invulnerable enemies are excluded. A stopped dash cannot deal ghost damage.
The flame trail is replicated to online clients. Movement/collision checks use swept segments.

Verification: verify_fire_dash.gd, verify_matchmaking.gd, verify_online_screen.gd,
verify_roles.gd, verify_minimal.gd and verify_upgrade.gd. All source comments remain removed.
Pre-change backup: before-matchmaking.zip.
"""
notes.write_text(s, encoding="utf-8")
allowed = {".gd", ".uid", ".tscn", ".tres", ".png", ".jpg", ".jpeg", ".svg", ".webp", ".wav", ".ogg", ".ttf", ".otf", ".import", ".md", ".json"}
names = {"Dockerfile", ".dockerignore", "railway.json", "project.godot", "online.cfg"}
target = p / "server-deploy.zip"
files = []
with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for f in p.rglob("*"):
        relative = f.relative_to(p)
        if not f.is_file() or any(part in {".godot", ".git", "qa"} for part in relative.parts):
            continue
        if f.name.startswith("verify_"):
            continue
        if f.suffix.lower() not in allowed and f.name not in names:
            continue
        archive.write(f, relative.as_posix())
        files.append(relative.as_posix())
for required in ["Dockerfile", "project.godot", "server/matchmaker.gd", "server/room_arena.gd", "matchmaking_arena.gd", "online.cfg"]:
    assert required in files, required
print(f"Server deployment source: {len(files)} files, {target.stat().st_size} bytes")
