#!/usr/bin/env bash
# =============================================================
#  Flag Theme — Country detection + tmux color generation
#  Usage:
#    flag-theme.sh              # Auto-detect country
#    flag-theme.sh US           # Force specific country
#    flag-theme.sh --generate   # Auto-detect + write tmux.conf
#    flag-theme.sh US --generate # Force country + write tmux.conf
# =============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Source the flag color database
source "$REPO_DIR/themes/flags.sh"

# -----------------------------------------------------------
#  Country Detection
# -----------------------------------------------------------
detect_country() {
    local country=""

    # macOS: read system locale
    if [[ "$(uname)" == "Darwin" ]]; then
        local locale
        locale=$(defaults read NSGlobalDomain AppleLocale 2>/dev/null || echo "")
        # AppleLocale is like "en_IL", "en_US", "de_DE"
        if [[ "$locale" =~ _([A-Z]{2}) ]]; then
            country="${BASH_REMATCH[1]}"
        fi
    fi

    # Linux: parse LANG or LC_ALL
    if [[ -z "$country" ]]; then
        local lang="${LC_ALL:-${LANG:-}}"
        # LANG is like "en_US.UTF-8", "de_DE.UTF-8"
        if [[ "$lang" =~ _([A-Z]{2}) ]]; then
            country="${BASH_REMATCH[1]}"
        fi
    fi

    # Linux fallback: timezone-based guess
    if [[ -z "$country" ]] && command -v timedatectl &>/dev/null; then
        local tz
        tz=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "")
        case "$tz" in
            America/New_York|America/Chicago|America/Denver|America/Los_Angeles|US/*) country="US" ;;
            Europe/London)    country="GB" ;;
            Europe/Berlin)    country="DE" ;;
            Europe/Paris)     country="FR" ;;
            Europe/Rome)      country="IT" ;;
            Europe/Madrid)    country="ES" ;;
            Europe/Amsterdam) country="NL" ;;
            Europe/Warsaw)    country="PL" ;;
            Europe/Kiev|Europe/Kyiv) country="UA" ;;
            Europe/Stockholm) country="SE" ;;
            Europe/Oslo)      country="NO" ;;
            Europe/Helsinki)  country="FI" ;;
            Europe/Zurich)    country="CH" ;;
            Europe/Vienna)    country="AT" ;;
            Europe/Brussels)  country="BE" ;;
            Europe/Lisbon)    country="PT" ;;
            Europe/Prague)    country="CZ" ;;
            Europe/Bucharest) country="RO" ;;
            Europe/Athens)    country="GR" ;;
            Europe/Dublin)    country="IE" ;;
            Europe/Copenhagen) country="DK" ;;
            Asia/Jerusalem|Asia/Tel_Aviv) country="IL" ;;
            Asia/Tokyo)       country="JP" ;;
            Asia/Seoul)       country="KR" ;;
            Asia/Shanghai|Asia/Hong_Kong) country="CN" ;;
            Asia/Kolkata|Asia/Calcutta) country="IN" ;;
            Asia/Singapore)   country="SG" ;;
            Asia/Taipei)      country="TW" ;;
            Asia/Bangkok)     country="TH" ;;
            Asia/Manila)      country="PH" ;;
            Asia/Ho_Chi_Minh) country="VN" ;;
            Asia/Jakarta)     country="ID" ;;
            Asia/Kuala_Lumpur) country="MY" ;;
            Asia/Istanbul)    country="TR" ;;
            Asia/Dubai)       country="AE" ;;
            Asia/Riyadh)      country="SA" ;;
            Africa/Cairo)     country="EG" ;;
            Africa/Johannesburg) country="ZA" ;;
            Africa/Lagos)     country="NG" ;;
            Africa/Nairobi)   country="KE" ;;
            Africa/Addis_Ababa) country="ET" ;;
            Australia/Sydney|Australia/Melbourne) country="AU" ;;
            Pacific/Auckland) country="NZ" ;;
            America/Sao_Paulo) country="BR" ;;
            America/Mexico_City) country="MX" ;;
            America/Argentina/Buenos_Aires) country="AR" ;;
            America/Bogota)   country="CO" ;;
            America/Santiago) country="CL" ;;
            America/Lima)     country="PE" ;;
            America/Toronto|America/Vancouver) country="CA" ;;
        esac
    fi

    # Another fallback: TZ file on Linux
    if [[ -z "$country" ]] && [[ -f /etc/timezone ]]; then
        local tz
        tz=$(cat /etc/timezone 2>/dev/null)
        case "$tz" in
            America/*) country="US" ;;
            Europe/London) country="GB" ;;
            Europe/Berlin) country="DE" ;;
            Asia/Jerusalem) country="IL" ;;
            *) country="" ;;
        esac
    fi

    echo "${country:-INTL}"
}

# -----------------------------------------------------------
#  Generate themed tmux.conf from template
# -----------------------------------------------------------
generate_tmux_conf() {
    local country="$1"
    local colors
    colors=$(get_flag_colors "$country")
    read -r primary secondary light accent emoji <<< "$colors"

    local template="$REPO_DIR/config/tmux.conf.template"
    local output="$HOME/.tmux.conf"

    if [[ ! -f "$template" ]]; then
        echo "Error: Template not found at $template" >&2
        return 1
    fi

    # Replace placeholders
    sed \
        -e "s/{{PRIMARY}}/$primary/g" \
        -e "s/{{SECONDARY}}/$secondary/g" \
        -e "s/{{LIGHT}}/$light/g" \
        -e "s/{{ACCENT}}/$accent/g" \
        "$template" > "$output"

    echo "Generated $output with $emoji $country theme (colours: $primary/$secondary/$light/$accent)"
}

# -----------------------------------------------------------
#  Preview colors without writing
# -----------------------------------------------------------
preview_theme() {
    local country="$1"
    local colors
    colors=$(get_flag_colors "$country")
    read -r primary secondary light accent emoji <<< "$colors"

    echo "$emoji $country Theme"
    echo "  Primary:   colour$primary"
    echo "  Secondary: colour$secondary"
    echo "  Light:     colour$light"
    echo "  Accent:    colour$accent"
}

# -----------------------------------------------------------
#  Main
# -----------------------------------------------------------
COUNTRY=""
GENERATE=false

for arg in "$@"; do
    case "$arg" in
        --generate) GENERATE=true ;;
        --preview)  ;;  # default behavior
        *)          COUNTRY="$arg" ;;
    esac
done

if [[ -z "$COUNTRY" ]]; then
    COUNTRY=$(detect_country)
fi

COUNTRY=$(echo "$COUNTRY" | tr '[:lower:]' '[:upper:]')

if [[ "$GENERATE" == true ]]; then
    generate_tmux_conf "$COUNTRY"
else
    preview_theme "$COUNTRY"
fi
