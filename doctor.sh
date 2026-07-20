#!/usr/bin/env bash
# Report what is actually installed, as opposed to what the installers believe.
#
#   ./doctor.sh                     # modules from hosts/$(hostname).modules, or all
#   ./doctor.sh keybindings         # specific modules
#   ./doctor.sh --host bazzite      # use a named profile
#   ./doctor.sh --json              # machine-readable; the other views render this
#   ./doctor.sh --html              # self-contained page, opened in a browser
#   ./doctor.sh --html > state.html # ... or captured to a file instead
#
# Read-only throughout, so there is no --dry-run. Exits nonzero if any check
# failed, which makes it usable as a post-install gate.
#
# A module opts in by adding checks.sh defining module_checks(); there is no
# list here to update, matching how modules/ works for install.sh.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$REPO/lib/common.sh"
source "$REPO/lib/checks.sh"

available() { find "$REPO/modules" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort; }

enabled() {
  if [[ -f "$HOSTFILE" ]]; then
    sed -e 's/#.*//' -e '/^[[:space:]]*$/d' -e 's/[[:space:]]//g' "$HOSTFILE"
  else
    available
  fi
}

ARGS=()
HOST=""
FORMAT=text
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) FORMAT=json ;;
    --html) FORMAT=html ;;
    --host) HOST="${2:?--host needs a name}"; shift ;;
    --host=*) HOST="${1#*=}" ;;
    -*) warn "unknown option: $1"; exit 2 ;;
    *) ARGS+=("$1") ;;
  esac
  shift
done

HOSTFILE="$REPO/hosts/${HOST:-$(hostname)}.modules"

if [[ ${#ARGS[@]} -gt 0 ]]; then
  MODULES=("${ARGS[@]}")
else
  mapfile -t MODULES < <(enabled)
fi

CHECK_RESULTS="$(mktemp)"
export CHECK_RESULTS
trap 'rm -f "$CHECK_RESULTS"' EXIT

# --- system: not a module, but the ground every module stands on -------------

system_checks() {
  if ! is_atomic; then
    check_ok "system type" "traditional (dnf)"
    return 0
  fi

  check_ok "system type" "atomic (ostree/bootc)"

  # Via a file rather than argv: the status blob runs to tens of kilobytes and
  # overruns ARG_MAX, which fails the exec without failing this function.
  local json
  json="$(mktemp)"
  rpm-ostree status --json >"$json" 2>/dev/null || true
  if [[ ! -s "$json" ]]; then
    rm -f "$json"
    check_warn "deployment" "rpm-ostree status unavailable"
    return 0
  fi

  # requested-packages is what the origin asks for; packages is what actually
  # had to be layered. A name in the first but not the second is now provided by
  # the base image, so the request is dead weight carried across every upgrade.
  python3 - "$json" <<'PY' >>"$CHECK_RESULTS"
import json, os, sys

with open(sys.argv[1]) as fh:
    dep = next((d for d in json.load(fh)["deployments"] if d.get("booted")), None)
mod = os.environ.get("CHECK_MODULE", "system")

def row(status, label, detail="", fix=""):
    print("\t".join((status, mod, label, detail, fix)))

if dep is None:
    row("warn", "deployment", "no booted deployment reported")
    sys.exit()

row("ok", "base image", str(dep.get("origin") or dep.get("container-image-reference", "?")))
row("ok", "version", str(dep.get("version", "?")))

requested = set(dep.get("requested-packages") or [])
layered = set(dep.get("packages") or [])
if layered:
    row("ok", "layered packages", ", ".join(sorted(layered)))
else:
    row("ok", "layered packages", "none")

for pkg in sorted(requested - layered):
    row("warn", f"{pkg} redundant",
        "requested but the base image now provides it",
        f"sudo rpm-ostree uninstall {pkg}")
PY
  rm -f "$json"
}

# --- run ---------------------------------------------------------------------

RAN=()
for m in system "${MODULES[@]}"; do
  if [[ "$m" == system ]]; then
    RAN+=(system)
    ( CHECK_MODULE=system; export CHECK_MODULE; system_checks ) || true
    continue
  fi

  script="$REPO/modules/$m/checks.sh"
  [[ -f "$script" ]] || continue
  RAN+=("$m")
  # errexit off around the module, then back on inside it: a subshell on the
  # left of `||` runs with errexit suppressed, which would let a check fail
  # silently and report whatever the last one happened to return.
  set +e
  (
    set -e
    CHECK_MODULE="$m"
    export CHECK_MODULE
    MODULE="$REPO/modules/$m"
    # shellcheck source=/dev/null
    source "$script"
    module_checks
  )
  rc=$?
  set -e
  # CHECK_MODULE is set for this call alone: it runs in the parent, where the
  # subshell's copy is out of scope and nounset would kill the whole run.
  (( rc == 0 )) \
    || CHECK_MODULE="$m" check_warn "checks aborted" "modules/$m/checks.sh exited early ($rc)"
done

# --- render ------------------------------------------------------------------

count() { awk -F'\t' -v s="$1" '$1==s' "$CHECK_RESULTS" | wc -l; }
N_OK="$(count ok)"; N_WARN="$(count warn)"; N_FAIL="$(count fail)"

json_escape() { local s="$1"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; printf '%s' "$s"; }
html_escape() {
  local s="$1"
  s="${s//&/&amp;}"; s="${s//</&lt;}"; s="${s//>/&gt;}"; s="${s//\"/&quot;}"
  printf '%s' "$s"
}

render_json() {
  printf '{\n  "host": "%s",\n' "$(json_escape "$(hostname)")"
  printf '  "generated": "%s",\n' "$(date -Is)"
  printf '  "summary": { "ok": %s, "warn": %s, "fail": %s },\n' "$N_OK" "$N_WARN" "$N_FAIL"
  printf '  "checks": [\n'
  local first=1 status module label detail fix
  while IFS=$'\t' read -r status module label detail fix; do
    (( first )) || printf ',\n'
    first=0
    printf '    { "status": "%s", "module": "%s", "label": "%s", "detail": "%s", "fix": "%s" }' \
      "$(json_escape "$status")" "$(json_escape "$module")" "$(json_escape "$label")" \
      "$(json_escape "$detail")" "$(json_escape "$fix")"
  done <"$CHECK_RESULTS"
  printf '\n  ]\n}\n'
}

render_text() {
  local status module label detail fix m
  for m in "${RAN[@]}"; do
    grep -q "^[a-z]*	$m	" "$CHECK_RESULTS" || continue
    printf '\n==> %s\n' "$m"
    while IFS=$'\t' read -r status module label detail fix; do
      [[ "$module" == "$m" ]] || continue
      case "$status" in
        ok)   printf '  ok    %-26s %s\n' "$label" "$detail" ;;
        warn) printf '  warn  %-26s %s\n' "$label" "$detail" ;;
        fail) printf '  FAIL  %-26s %s\n' "$label" "$detail" ;;
      esac
      [[ -n "$fix" ]] && printf '        %-26s fix: %s\n' "" "$fix"
    done <"$CHECK_RESULTS"
  done

  printf '\n%s ok, %s warning(s), %s failed\n' "$N_OK" "$N_WARN" "$N_FAIL"
  (( N_FAIL )) && printf 're-run the module installer for anything failed above\n'
  return 0
}

render_html() {
  cat <<HEAD
<!doctype html>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>desktop-scripts state -- $(html_escape "$(hostname)")</title>
<style>
  :root {
    color-scheme: light dark;
    --bg: #fbfbfa; --fg: #1a1a18; --muted: #6b6b66; --card: #fff; --line: #e5e5e1;
    --ok: #2f7d4f; --warn: #9a6b00; --fail: #b3261e;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg: #17171a; --fg: #e8e8e6; --muted: #9a9a95; --card: #1f1f23; --line: #2e2e34;
      --ok: #6fcf97; --warn: #e0b341; --fail: #f2836b;
    }
  }
  * { box-sizing: border-box; }
  body { margin: 0; padding: 2rem 1.25rem 4rem; background: var(--bg); color: var(--fg);
         font: 15px/1.55 ui-sans-serif, system-ui, -apple-system, "Segoe UI", sans-serif; }
  main { max-width: 60rem; margin: 0 auto; }
  h1 { font-size: 1.4rem; margin: 0 0 .25rem; }
  .sub { color: var(--muted); font-size: .875rem; margin-bottom: 1.5rem; }
  .tiles { display: flex; gap: .75rem; flex-wrap: wrap; margin-bottom: 2rem; }
  .tile { flex: 1 1 8rem; background: var(--card); border: 1px solid var(--line);
          border-radius: .6rem; padding: .85rem 1rem; }
  .tile b { display: block; font-size: 1.6rem; line-height: 1.1; font-variant-numeric: tabular-nums; }
  .tile span { color: var(--muted); font-size: .8rem; }
  section { background: var(--card); border: 1px solid var(--line); border-radius: .6rem;
            margin-bottom: 1rem; overflow: hidden; }
  h2 { font-size: .8rem; text-transform: uppercase; letter-spacing: .08em; color: var(--muted);
       margin: 0; padding: .7rem 1rem; border-bottom: 1px solid var(--line); }
  .row { display: grid; grid-template-columns: 4.5rem minmax(9rem, 14rem) 1fr;
         gap: .75rem; padding: .55rem 1rem; border-bottom: 1px solid var(--line);
         align-items: baseline; }
  .row:last-child { border-bottom: 0; }
  .badge { font-size: .7rem; font-weight: 600; letter-spacing: .06em; text-transform: uppercase; }
  .ok .badge { color: var(--ok); } .warn .badge { color: var(--warn); } .fail .badge { color: var(--fail); }
  .label { font-weight: 500; }
  .detail { color: var(--muted); overflow-wrap: anywhere; }
  .fix { grid-column: 2 / -1; margin-top: .3rem; font-size: .82rem; }
  .fix code { background: var(--bg); border: 1px solid var(--line); border-radius: .3rem;
              padding: .1rem .35rem; font-size: .95em; overflow-wrap: anywhere; }
  @media (max-width: 34rem) {
    .row { grid-template-columns: 4.5rem 1fr; }
    .fix { grid-column: 1 / -1; }
  }
</style>
<main>
<h1>desktop-scripts state</h1>
<div class="sub">$(html_escape "$(hostname)") &middot; $(html_escape "$(date '+%Y-%m-%d %H:%M %Z')")</div>
<div class="tiles">
  <div class="tile"><b>$N_FAIL</b><span>failed</span></div>
  <div class="tile"><b>$N_WARN</b><span>warnings</span></div>
  <div class="tile"><b>$N_OK</b><span>ok</span></div>
</div>
HEAD

  local status module label detail fix m
  for m in "${RAN[@]}"; do
    grep -q "^[a-z]*	$m	" "$CHECK_RESULTS" || continue
    printf '<section>\n<h2>%s</h2>\n' "$(html_escape "$m")"
    while IFS=$'\t' read -r status module label detail fix; do
      [[ "$module" == "$m" ]] || continue
      printf '<div class="row %s"><span class="badge">%s</span><span class="label">%s</span><span class="detail">%s</span>' \
        "$status" "$status" "$(html_escape "$label")" "$(html_escape "$detail")"
      [[ -n "$fix" ]] && printf '<div class="fix">fix: <code>%s</code></div>' "$(html_escape "$fix")"
      printf '</div>\n'
    done <"$CHECK_RESULTS"
    printf '</section>\n'
  done

  printf '</main>\n'
}

case "$FORMAT" in
  json) render_json ;;
  text) render_text ;;
  html)
    # Redirected output is someone capturing the page, so leave it on stdout and
    # open a browser only when there is nobody to read the HTML in a terminal.
    if [[ -t 1 ]]; then
      out="${XDG_RUNTIME_DIR:-/tmp}/desktop-scripts-state.html"
      render_html >"$out"
      say "wrote $out"
      if have xdg-open; then
        # The browser outlives this script, and its chatter is not our output.
        xdg-open "$out" >/dev/null 2>&1 &
        disown
      else
        warn "no xdg-open; open the file above yourself"
      fi
    else
      render_html
    fi
    ;;
esac

(( N_FAIL == 0 ))
