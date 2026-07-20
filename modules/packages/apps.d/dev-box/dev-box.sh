APP_NAME=dev-box

# A Fedora toolbox holding the -devel packages that compiling against system
# libraries needs. They are build-time only, so layering them would carry
# headers on the host across every image update to produce binaries that never
# use them at runtime (ADR 0005).
BOX=dev

# Pinned to the host's Fedora release, because binaries built in here link the
# host's libraries when they run: matching releases is what makes the headers
# compiled against and the sonames loaded the same version.
box_image() {
  local version_id
  version_id="$(. /etc/os-release && printf '%s' "${VERSION_ID%%.*}")"
  printf 'registry.fedoraproject.org/fedora-toolbox:%s' "$version_id"
}

# systemd-devel carries libudev.pc, which hidapi needs and no Fedora Atomic
# image ships. gcc and pkgconf are what the -sys crates shell out to.
BOX_PACKAGES=(systemd-devel gcc pkgconf-pkg-config)

# distrobox mounts $HOME, and Homebrew lives outside it. Its bottles hardcode
# the prefix they were poured for, so the mount has to land on that same path
# rather than anywhere convenient -- which is also what puts rustup on PATH in
# here, through the shell module's fragment reading the shared ~/.bashrc.
brew_mount() {
  local prefix
  prefix="$(brew --prefix)"
  printf '%s:%s:rslave' "$(readlink -f "$prefix")" "$prefix"
}

in_box() { distrobox enter --name "$BOX" -- "$@"; }

# The box spends its life stopped, and entering it starts it. Anything that only
# reads should leave it as it found it.
box_stop_if() {
  [[ "$1" == running ]] || run distrobox stop "$BOX" --yes >/dev/null 2>&1 || true
}

# Static, so the gate every ./install.sh run passes through does not start a
# container. A box that exists but was provisioned badly shows up as a failed
# install at the time, and app_checks re-reads the real state afterwards.
app_check() {
  have distrobox || return 1
  distrobox_exists "$BOX" || return 1
  podman inspect --format '{{range .Mounts}}{{.Destination}} {{end}}' "$BOX" 2>/dev/null \
    | grep -q "$(brew --prefix 2>/dev/null || echo /nonexistent)"
}

app_install() {
  have distrobox || { warn "distrobox not available; it ships with Bazzite"; return 1; }

  if ! distrobox_exists "$BOX"; then
    say "creating the $BOX distrobox from $(box_image)"
    if have brew; then
      run distrobox create --name "$BOX" --image "$(box_image)" \
        --additional-flags "--volume $(brew_mount)" --yes
    else
      run distrobox create --name "$BOX" --image "$(box_image)" --yes
    fi
  fi

  say "installing build dependencies inside $BOX"
  run in_box sudo dnf install -y "${BOX_PACKAGES[@]}"

  # Nothing in here runs on its own: it is entered for a build and idle after.
  # distrobox enter starts it again on demand.
  say "stopping $BOX"
  run distrobox stop "$BOX" --yes

  say "build with: distrobox enter $BOX -- cargo build --release"
}

app_checks() {
  have distrobox || { check_warn "$BOX box" "distrobox not available"; return 0; }

  if ! distrobox_exists "$BOX"; then
    check_warn "$BOX box" "not created" "./modules/packages/install.sh dev-box"
    return 0
  fi

  # A box left behind by an earlier Fedora release still builds, against headers
  # a release out of step with the libraries the binaries will load on the host.
  local want got
  want="$(box_image)"
  got="$(podman inspect --format '{{.ImageName}}' "$BOX" 2>/dev/null)"
  if [[ "$got" == "$want" ]]; then
    check_ok "$BOX image" "$got"
  else
    check_warn "$BOX image" "built from $got, host is $want" \
      "distrobox rm $BOX --force && ./modules/packages/install.sh dev-box"
  fi

  # What is inside can only be read from inside, so this starts the box and puts
  # it back the way it was: reporting state is not a reason to leave one running.
  local was
  was="$(podman inspect --format '{{.State.Status}}' "$BOX" 2>/dev/null)"

  if in_box pkg-config --exists libudev >/dev/null 2>&1; then
    check_ok "$BOX build deps" "libudev headers present"
  else
    check_warn "$BOX build deps" "libudev headers missing" \
      "./modules/packages/install.sh dev-box"
  fi

  # Without the Homebrew mount the box has no toolchain at all: rustup is on the
  # host, outside the $HOME that distrobox shares.
  if in_box bash -lc 'command -v cargo' >/dev/null 2>&1; then
    check_ok "$BOX toolchain" "cargo resolves"
  else
    check_warn "$BOX toolchain" "no cargo; the Homebrew mount is missing" \
      "distrobox rm $BOX --force && ./modules/packages/install.sh dev-box"
  fi

  box_stop_if "$was"
}
