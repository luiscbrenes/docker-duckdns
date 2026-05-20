#!/bin/sh
set -e

# ─── Helpers ────────────────────────────────────────────────────────────────

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log_file() {
    if [ "${LOG_FILE}" = "true" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> /config/duck.log
    fi
}

die() {
    log "ERROR: $*" >&2
    exit 1
}

# ─── Validation ─────────────────────────────────────────────────────────────

[ -z "${SUBDOMAINS}" ] && die "SUBDOMAINS environment variable is required."
[ -z "${TOKEN}" ]      && die "TOKEN environment variable is required."

# ─── PUID / PGID ────────────────────────────────────────────────────────────

PUID="${PUID:-911}"
PGID="${PGID:-911}"

if ! getent group abc > /dev/null 2>&1; then
    addgroup -g "${PGID}" abc 2>/dev/null || true
fi

if ! getent passwd abc > /dev/null 2>&1; then
    adduser -D -H -u "${PUID}" -G abc abc 2>/dev/null || true
fi

# ─── Timezone ───────────────────────────────────────────────────────────────

if [ -n "${TZ}" ]; then
    if [ -f "/usr/share/zoneinfo/${TZ}" ]; then
        cp "/usr/share/zoneinfo/${TZ}" /etc/localtime
        echo "${TZ}" > /etc/timezone
    else
        log "WARNING: Timezone '${TZ}' not found. Using UTC."
    fi
fi

# ─── Config directory ───────────────────────────────────────────────────────

mkdir -p /config
chown -R abc:abc /config 2>/dev/null || true

# ─── IP detection functions ─────────────────────────────────────────────────

get_internal_ipv4() {
    # Get the primary non-loopback IPv4 address (LAN)
    # "ip route get" output: "1.1.1.1 via x.x.x.x dev eth0 src 192.168.1.x ..."
    ip -4 route get 1.1.1.1 2>/dev/null \
        | sed -n 's/.*src \([0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\).*/\1/p' \
        | head -1
}

get_internal_ipv6() {
    # Get the primary non-loopback, non-link-local IPv6 address
    # "ip -6 addr show scope global" lines look like: "    inet6 fd00::1/64 scope global"
    ip -6 addr show scope global 2>/dev/null \
        | grep 'inet6' \
        | sed 's|.*inet6 \([0-9a-f:]*\)/.*|\1|' \
        | grep -v '^::1$' \
        | head -1
}

get_public_ipv4() {
    # Cloudflare trace returns lines like "ip=1.2.3.4"
    curl -sf --max-time 10 "https://1.1.1.1/cdn-cgi/trace" \
        | grep '^ip=' | cut -d'=' -f2 \
        || curl -sf --max-time 10 "https://api4.ipify.org" \
        || echo ""
}

get_public_ipv6() {
    curl -6sf --max-time 10 "https://1.1.1.1/cdn-cgi/trace" \
        | grep '^ip=' | cut -d'=' -f2 \
        || curl -6sf --max-time 10 "https://api6.ipify.org" \
        || echo ""
}

# ─── DuckDNS update function ────────────────────────────────────────────────

update_duckdns() {
    local ip4="$1"
    local ip6="$2"

    local url="https://www.duckdns.org/update?domains=${SUBDOMAINS}&token=${TOKEN}&verbose=true"

    [ -n "${ip4}" ] && url="${url}&ip=${ip4}"
    [ -n "${ip6}" ] && url="${url}&ipv6=${ip6}"

    local response
    response=$(curl -sf --max-time 10 "${url}" 2>&1) || {
        log "ERROR: Failed to reach DuckDNS API"
        log_file "ERROR: Failed to reach DuckDNS API"
        return 1
    }

    local result
    result=$(echo "${response}" | head -1)

    if [ "${result}" = "OK" ]; then
        local updated
        updated=$(echo "${response}" | sed -n '3p')
        if [ "${updated}" = "true" ]; then
            local msg="Updated"
            [ -n "${ip4}" ] && msg="${msg} IPv4=${ip4}"
            [ -n "${ip6}" ] && msg="${msg} IPv6=${ip6}"
            log "${msg}"
            log_file "${msg}"
        else
            log "No change detected (IPs already up to date)"
            log_file "No change detected (IPs already up to date)"
        fi
    else
        log "ERROR: DuckDNS returned: ${response}"
        log_file "ERROR: DuckDNS returned: ${response}"
    fi
}

# ─── Main update loop ────────────────────────────────────────────────────────

do_update() {
    local ip4=""
    local ip6=""

    case "${UPDATE_IP:-}" in
        ipv4)
            if [ "${USE_INTERNAL_IP}" = "true" ]; then
                ip4=$(get_internal_ipv4)
            else
                ip4=$(get_public_ipv4)
            fi
            ;;
        ipv6)
            if [ "${USE_INTERNAL_IP}" = "true" ]; then
                ip6=$(get_internal_ipv6)
            else
                ip6=$(get_public_ipv6)
            fi
            ;;
        both)
            if [ "${USE_INTERNAL_IP}" = "true" ]; then
                ip4=$(get_internal_ipv4)
                ip6=$(get_internal_ipv6)
            else
                ip4=$(get_public_ipv4)
                ip6=$(get_public_ipv6)
            fi
            ;;
        *)
            # Default: let DuckDNS auto-detect public IPv4 (empty ip param)
            ip4=""
            ip6=""
            ;;
    esac

    # Warn if expected IP wasn't found
    if [ "${UPDATE_IP}" = "ipv4" ] || [ "${UPDATE_IP}" = "both" ]; then
        [ -z "${ip4}" ] && log "WARNING: Could not detect IPv4 address"
    fi
    if [ "${UPDATE_IP}" = "ipv6" ] || [ "${UPDATE_IP}" = "both" ]; then
        [ -z "${ip6}" ] && log "WARNING: Could not detect IPv6 address"
    fi

    update_duckdns "${ip4}" "${ip6}"
}

# ─── Startup ────────────────────────────────────────────────────────────────

log "Starting DuckDNS updater"
log "  Subdomains : ${SUBDOMAINS}"
log "  Update IP  : ${UPDATE_IP:-auto (DuckDNS detects public IPv4)}"
log "  Internal IP: ${USE_INTERNAL_IP:-false}"
log "  Log file   : ${LOG_FILE:-false}"
log "  PUID/PGID  : ${PUID}/${PGID}"

# Run immediately on start, then every 5 minutes
do_update
while true; do
    sleep 300
    do_update
done
