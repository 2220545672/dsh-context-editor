#!/usr/bin/env bash
#
# Compatibility test for this plugin against a real dsh-docker image.
#
#   scripts/compat-image.sh [image] [plugin-spec]
#
# Defaults: image `ghcr.io/meixu6693/dsh:latest`, plugin `dsh-context-editor@latest`.
#
# plugin-spec is whatever `dsh plugin add` accepts: a version range
# (`dsh-context-editor@0.2.0`), a tarball path (so CI can test an unpacked
# commit before it is published), or a git URL.
#
# Why the image and not just a bare DSH install: the image is the environment a
# user actually runs. It owns the node version, the pnpm the plugin manager
# shells out to, the DSH profile layout under /data/dsh, and the boot path
# (entrypoint -> cordis) that has to survive a plugin installed after first
# boot. A test that installed into a plain temp DSH_HOME would miss all of that.
#
# What is asserted:
#   1. the image boots and /healthz answers;
#   2. `dsh plugin add` succeeds with the image's own pnpm, as uid 1000;
#   3. after a normal container restart the plugin is in the client bundle graph
#      served by /plugins/events — that is what the browser needs to load it;
#   4. the app still answers afterwards, i.e. the plugin did not break startup;
#   5. the container log has no "did not activate" entry.
#
# Environment:
#   COMPAT_PORT       host port to publish (default: random 18090-19089)
#   COMPAT_KEEP=1     leave the container running for inspection
#   GITHUB_OUTPUT     when set, `dsh_version=<version>` is appended for CI
set -Eeuo pipefail

IMAGE="${1:-ghcr.io/meixu6693/dsh:latest}"
PLUGIN_SPEC="${2:-dsh-context-editor@latest}"
PORT="${COMPAT_PORT:-$((18090 + RANDOM % 1000))}"
NAME="dsh-compat-$$"
WORKDIR="$(mktemp -d)"
FAILURES=0

cleanup() {
    if [[ "${COMPAT_KEEP:-0}" == "1" ]]; then
        printf 'COMPAT_KEEP=1: leaving container %s on port %s (data in %s)\n' \
            "${NAME}" "${PORT}" "${WORKDIR}"
        return
    fi
    docker rm -f "${NAME}" >/dev/null 2>&1 || true
    # The container hands bind mounts to PUID:PGID (1000:1000), which the runner
    # user is not, so the plain rm can fail; try sudo before giving up.
    rm -rf "${WORKDIR}" 2>/dev/null || sudo rm -rf "${WORKDIR}" 2>/dev/null || true
}
trap cleanup EXIT

pass() { printf 'ok   %s\n' "$*"; }
fail() { printf 'FAIL %s\n' "$*"; FAILURES=$((FAILURES + 1)); }

mkdir -p "${WORKDIR}/data" "${WORKDIR}/workspace"

printf 'image:  %s\n' "${IMAGE}"
printf 'plugin: %s\n' "${PLUGIN_SPEC}"

# The DSH version is baked into the image, so it is only knowable from inside.
DSH_VERSION="$(docker run --rm --entrypoint dsh "${IMAGE}" --version 2>/dev/null | head -n1 || true)"
if [[ -n "${DSH_VERSION}" ]]; then
    printf 'dsh:    %s (from the image)\n' "${DSH_VERSION}"
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        echo "dsh_version=${DSH_VERSION}" >> "${GITHUB_OUTPUT}"
    fi
else
    printf 'warning: could not read the DSH version from the image\n' >&2
    DSH_VERSION='unknown'
fi

printf 'starting the container\n'
docker run --detach --name "${NAME}" \
    --env 'ALLOWED_CLIENTS=127.0.0.1,172.16.0.0/12' \
    --env 'AUTH_MODE=none' \
    --publish "127.0.0.1:${PORT}:8080" \
    --security-opt seccomp=unconfined \
    --security-opt systempaths=unconfined \
    --volume "${WORKDIR}/data:/data" \
    --volume "${WORKDIR}/workspace:/workspace" \
    "${IMAGE}" >/dev/null

wait_ready() {
    local ready=0
    for _ in $(seq 1 90); do
        if curl --silent --fail --max-time 3 "http://127.0.0.1:${PORT}/healthz" >/dev/null 2>&1; then
            ready=1
            break
        fi
        if [[ "$(docker inspect --format '{{.State.Running}}' "${NAME}" 2>/dev/null)" != "true" ]]; then
            printf 'container exited before /healthz answered\n' >&2
            docker logs "${NAME}" >&2 || true
            return 1
        fi
        sleep 2
    done
    if [[ "${ready}" != "1" ]]; then
        printf '/healthz never answered\n' >&2
        docker logs "${NAME}" >&2 || true
        return 1
    fi
}

wait_ready
pass 'the image boots and /healthz answers'

# A tarball built on the runner is not inside the container; copy it in so the
# same code path (dsh plugin add <path>) works for both a published version and
# an unpublished commit.
if [[ -f "${PLUGIN_SPEC}" ]]; then
    inside="/tmp/$(basename "${PLUGIN_SPEC}")"
    printf 'copying %s into the container as %s\n' "${PLUGIN_SPEC}" "${inside}"
    docker cp "${PLUGIN_SPEC}" "${NAME}:${inside}" >/dev/null
    PLUGIN_SPEC="${inside}"
fi

printf 'installing %s with the image pnpm\n' "${PLUGIN_SPEC}"
if docker exec --user 1000:1000 \
    --env HOME=/home/node \
    --env DSH_HOME=/data/dsh \
    "${NAME}" \
    dsh plugin --profile web add "${PLUGIN_SPEC}" >"${WORKDIR}/plugin-install.log" 2>&1; then
    pass "dsh plugin add ${PLUGIN_SPEC} succeeded"
else
    fail 'dsh plugin add failed'
    cat "${WORKDIR}/plugin-install.log" >&2
    docker logs "${NAME}" >&2 || true
fi

# Restart through the normal entrypoint: the plugin manager records the bundle in
# the profile, and this proves a plugin installed after first boot survives the
# same startup path a user gets on the next restart.
printf 'restarting the container to exercise the normal boot path\n'
docker restart "${NAME}" >/dev/null
wait_ready
pass 'the container is healthy after the restart'

body=''
for _ in $(seq 1 60); do
    body="$(curl --silent --show-error --max-time 3 \
        "http://127.0.0.1:${PORT}/plugins/events" 2>/dev/null || true)"
    if grep --quiet 'dsh-context-editor' <<<"${body}"; then
        break
    fi
    sleep 2
done

if grep --quiet 'dsh-context-editor' <<<"${body}"; then
    pass 'dsh-context-editor is in the client bundle graph'
else
    fail 'dsh-context-editor never appeared in /plugins/events'
    docker logs "${NAME}" >&2 || true
fi

# A plugin that shows up in the event stream but breaks startup would still be
# broken; assert the app answers after everything above.
code="$(curl --silent --output /dev/null --write-out '%{http_code}' --max-time 5 \
    "http://127.0.0.1:${PORT}/healthz" || true)"
if [[ "${code}" == "200" ]]; then
    pass 'the app still answers after the plugin install and restart'
else
    fail "healthz returned ${code} at the end"
fi

# Surface a startup error even when the bundle graph assertion passed: a plugin
# whose component fails to activate still ships its entry in some cases.
if docker logs "${NAME}" 2>&1 | grep --quiet 'did not activate'; then
    fail 'the container log reports a component that did not activate'
    docker logs "${NAME}" 2>&1 | grep 'did not activate' >&2 || true
else
    pass 'no "did not activate" in the container log'
fi

if [[ "${FAILURES}" -ne 0 ]]; then
    printf '\n%d assertion(s) failed\n' "${FAILURES}" >&2
    exit 1
fi

printf '\nok: %s works inside %s (DSH %s)\n' \
    "${PLUGIN_SPEC}" "${IMAGE}" "${DSH_VERSION}"
