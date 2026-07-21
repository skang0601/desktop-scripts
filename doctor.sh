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

# Not a module: these are the facts every module's checks assume about the host.
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
    # The empty field is CHECK_GROUP: these rows belong to the module itself.
    print("\x1f".join((status, mod, "", label, detail, fix)))

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

count() { awk -F'\x1f' -v s="$1" '$1==s' "$CHECK_RESULTS" | wc -l; }
N_OK="$(count ok)"; N_WARN="$(count warn)"; N_FAIL="$(count fail)"
N_BLOCKED="$(count blocked)"

# < is escaped too: the JSON is embedded in a <script> block in the report
# template, where a literal </script> inside a string would end the element.
json_escape() {
  local s="$1"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//</\\u003c}"
  printf '%s' "$s"
}
html_escape() {
  local s="$1"
  s="${s//&/&amp;}"; s="${s//</&lt;}"; s="${s//>/&gt;}"; s="${s//\"/&quot;}"
  printf '%s' "$s"
}

render_json() {
  printf '{\n  "host": "%s",\n' "$(json_escape "$(hostname)")"
  printf '  "generated": "%s",\n' "$(date -Is)"
  printf '  "summary": { "ok": %s, "warn": %s, "fail": %s, "blocked": %s },\n' \
    "$N_OK" "$N_WARN" "$N_FAIL" "$N_BLOCKED"
  printf '  "checks": [\n'
  local first=1 status module group label detail fix
  while IFS="$FS" read -r status module group label detail fix; do
    (( first )) || printf ',\n'
    first=0
    printf '    { "status": "%s", "module": "%s", "group": "%s", "label": "%s", "detail": "%s", "fix": "%s" }' \
      "$(json_escape "$status")" "$(json_escape "$module")" "$(json_escape "$group")" \
      "$(json_escape "$label")" "$(json_escape "$detail")" "$(json_escape "$fix")"
  done <"$CHECK_RESULTS"
  printf '\n  ]\n}\n'
}

render_text() {
  local status module group label detail fix m
  for m in "${RAN[@]}"; do
    grep -q "^[a-z]*$FS$m$FS" "$CHECK_RESULTS" || continue
    printf '\n==> %s\n' "$m"
    while IFS="$FS" read -r status module group label detail fix; do
      [[ "$module" == "$m" ]] || continue
      local tag="$status"
      [[ "$status" == fail ]] && tag=FAIL
      printf '  %-7s %-26s %s\n' "$tag" "$label" "$detail"
      if [[ -n "$fix" ]]; then
        local verb=fix
        [[ "$status" == blocked ]] && verb=track
        printf '  %-7s %-26s %s: %s\n' "" "" "$verb" "$fix"
      fi
    done <"$CHECK_RESULTS"
  done

  printf '\n%s ok, %s warning(s), %s failed' "$N_OK" "$N_WARN" "$N_FAIL"
  (( N_BLOCKED )) && printf ', %s blocked' "$N_BLOCKED"
  printf '\n'
  (( N_FAIL )) && printf 're-run the module installer for anything failed above\n'
  return 0
}

# The page itself lives in lib/report.html; this only injects the data. Keeping
# the markup out of the shell is what makes the report editable as markup rather
# than as quoting, and the injected payload is exactly what --json prints, so
# there is one description of a check and not two.
render_html() {
  local template="$REPO/lib/report.html"
  if [[ ! -f "$template" ]]; then
    warn "missing $template"
    return 1
  fi
  # Split on the placeholder's own line so the JSON never passes through a
  # regex engine -- paths in it contain characters sed would treat as syntax.
  local line
  while IFS= read -r line; do
    if [[ "$line" == *'{{DATA}}'* ]]; then
      printf '%s' "${line%%'{{DATA}}'*}"
      render_json
      printf '%s\n' "${line#*'{{DATA}}'}"
    else
      printf '%s\n' "$line"
    fi
  done <"$template"
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
