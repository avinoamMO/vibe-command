#!/usr/bin/env bash
# =============================================================
#  Sound Maps — abstract event names → filenames per pack
#
#  Usage: source this file, then call:
#    get_sound <pack> <event>           → returns filename (no ext)
#    get_sound_random <pack> <event>    → returns random from list
# =============================================================

# Maps: event → filename (no extension)
# Multiple options separated by space (for random selection)

_ra2_map() {
    local event="$1"
    case "$event" in
        startup)        echo "battle_control_online" ;;
        task_complete)  echo "construction_complete" ;;
        build_success)  echo "acknowledged" ;;
        build_fail)     echo "unable_to_comply" ;;
        tests_pass)     echo "affirmative" ;;
        tests_fail)     echo "unable_to_comply" ;;
        git_commit)     echo "yes_commander sir_yes_sir da" ;;
        git_push)       echo "moving_out" ;;
        git_push_fail)  echo "unable_to_comply" ;;
        deploy)         echo "building" ;;
        pkg_install)    echo "reinforcements_have_arrived" ;;
        subagent)       echo "kirov_reporting training unit_ready" ;;
        error)          echo "unable_to_comply" ;;
        session_stop)   echo "mission_accomplished" ;;
        notification)   echo "new_construction_options" ;;
        *)              echo "" ;;
    esac
}

_homm3_map() {
    local event="$1"
    case "$event" in
        startup)        echo "town_screen" ;;
        task_complete)  echo "spell_cast" ;;
        build_success)  echo "treasure" ;;
        build_fail)     echo "negative_luck" ;;
        tests_pass)     echo "positive_luck" ;;
        tests_fail)     echo "negative_luck" ;;
        git_commit)     echo "cavalry_move" ;;
        git_push)       echo "ship_move" ;;
        git_push_fail)  echo "negative_luck" ;;
        deploy)         echo "build" ;;
        pkg_install)    echo "recruit" ;;
        subagent)       echo "dragon_roar angel_summon phoenix_cast" ;;
        error)          echo "negative_luck" ;;
        session_stop)   echo "victory" ;;
        notification)   echo "quest_received" ;;
        *)              echo "" ;;
    esac
}

# Get sound filename(s) for an event
# Returns space-separated list (single item or multiple for random)
get_sound() {
    local pack="$1" event="$2"
    case "$pack" in
        ra2)    _ra2_map "$event" ;;
        homm3)  _homm3_map "$event" ;;
        *)      _ra2_map "$event" ;;  # fallback to RA2
    esac
}

# Get a single random sound for an event
get_sound_random() {
    local pack="$1" event="$2"
    local sounds
    sounds=$(get_sound "$pack" "$event")
    [[ -z "$sounds" ]] && return

    # Split into array and pick random
    local arr
    read -ra arr <<< "$sounds"
    local idx=$(( RANDOM % ${#arr[@]} ))
    echo "${arr[$idx]}"
}
