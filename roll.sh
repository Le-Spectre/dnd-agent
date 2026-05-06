#!/bin/bash
# D&D 5e Dice Roller
#
# Standard notation:
#   ./roll.sh 3d8          # 3d8
#   ./roll.sh 2d6+2        # 2d6+2
#   ./roll.sh 4d6kh3       # 4d6 keep highest 3
#   ./roll.sh 2d20kh+5     # advantage +5
#   ./roll.sh 5d6dl1+2     # drop lowest 1 +2
#   ./roll.sh 2d8+2d6+4    # multi-group (firebolt etc.)
#   ./roll.sh 1d20+1d8+3   # multi-group with modifier
#
# Legacy notation (still supported):
#   ./roll.sh 2 20 kh 1 +5
#   ./roll.sh 4 6 kh 3

set -euo pipefail

# --- Globals ---
ALL_RESULTS=()        # all individual die results (in order)
GROUP_LABELS=()       # e.g. "2d8", "2d6"
GROUP_RESULTS=()      # parallel: sum of each group
GROUP_DETAIL=()       # parallel: "(3,5)" style per group
TOTAL_MODIFIER=0
KD_TYPE=""            # kh/kl/dh/dl (only first group)
KD_NUM=""             # keep/drop count

parse_group() {
    # Parse "NdM[kh|kl|dh|dl[N]]" -> sets _GC _GF _GKD _GKDN
    local s="$1"
    if [[ "$s" =~ ^([0-9]+)d([0-9]+)(kh|kl|dh|dl)?([0-9])?$ ]]; then
        _GC="${BASH_REMATCH[1]}"
        _GF="${BASH_REMATCH[2]}"
        _GKD="${BASH_REMATCH[3]:-}"
        _GKDN="${BASH_REMATCH[4]:-}"
        return 0
    fi
    return 1
}

roll_group() {
    local count=$1 faces=$2
    for (( i=0; i<count; i++ )); do
        ALL_RESULTS+=( $(( (RANDOM % faces) + 1 )) )
    done
}

# --- Parse input ---

if [ $# -ge 1 ] && [[ "$1" =~ ^[0-9]+d[0-9] ]]; then
    INPUT="$1"

    # Detect multi-group: contains + or - between two dice patterns
    IS_MULTI=false
    if [[ "$INPUT" =~ [dD][0-9]+[+-][0-9]+[dD] ]]; then
        IS_MULTI=true
    fi

    # Tokenize: split on +/- but keep the signs
    # We walk the string extracting tokens
    remaining="$INPUT"
    FIRST=true
    while [[ -n "$remaining" ]]; do
        # Try to match a dice group at the start
        if [[ "$FIRST" = true ]] && [[ "$remaining" =~ ^([0-9]+d[0-9]+(kh|kl|dh|dl)?[0-9]?)(.*) ]]; then
            local_grp="${BASH_REMATCH[1]}"
            remaining="${BASH_REMATCH[3]}"
            if ! parse_group "$local_grp"; then
                echo "Error: invalid dice notation '$INPUT'"
                exit 1
            fi
            KD_TYPE="$_GKD"
            KD_NUM="$_GKDN"
            roll_group "$_GC" "$_GF"
            GROUP_LABELS+=("$_GC""d""$_GF")
            FIRST=false
        elif [[ "$remaining" =~ ^\+([0-9]+d[0-9]+)(.*) ]]; then
            local_grp="${BASH_REMATCH[1]}"
            remaining="${BASH_REMATCH[2]}"
            if ! parse_group "$local_grp"; then
                echo "Error: invalid dice group '$local_grp'"
                exit 1
            fi
            roll_group "$_GC" "$_GF"
            GROUP_LABELS+=("$_GC""d""$_GF")
        elif [[ "$remaining" =~ ^-([0-9]+d[0-9]+)(.*) ]]; then
            local_grp="${BASH_REMATCH[1]}"
            remaining="${BASH_REMATCH[2]}"
            if ! parse_group "$local_grp"; then
                echo "Error: invalid dice group '$local_grp'"
                exit 1
            fi
            # Roll but store as negative values
            neg_before=${#ALL_RESULTS[@]}
            roll_group "$_GC" "$_GF"
            for (( i=neg_before; i<${#ALL_RESULTS[@]}; i++ )); do
                ALL_RESULTS[$i]=$(( -ALL_RESULTS[$i] ))
            done
            GROUP_LABELS+=("-""$_GC""d""$_GF")
        elif [[ "$remaining" =~ ^([+-])([0-9]+)(.*) ]]; then
            sign="${BASH_REMATCH[1]}"
            num="${BASH_REMATCH[2]}"
            remaining="${BASH_REMATCH[3]}"
            if [ "$sign" = "+" ]; then
                TOTAL_MODIFIER=$(( TOTAL_MODIFIER + num ))
            else
                TOTAL_MODIFIER=$(( TOTAL_MODIFIER - num ))
            fi
        else
            echo "Error: cannot parse '$remaining' in '$INPUT'"
            exit 1
        fi
    done

    # Build per-group details
    idx=0
    for gi in "${!GROUP_LABELS[@]}"; do
        g_label="${GROUP_LABELS[$gi]}"
        # Strip leading - for counting
        g_clean="${g_label#-}"
        g_count="${g_clean%%d*}"
        g_count="${g_count%%[khd]*}"  # strip kh/dh etc
        # Extract faces: everything after d up to first non-digit or end
        g_after_d="${g_clean#*d}"
        g_faces="${g_after_d%%[^0-9]*}"

        is_negative=false
        if [[ "$g_label" == -* ]]; then
            is_negative=true
        fi

        g_sum=0
        g_detail=""
        for (( i=0; i<g_count; i++ )); do
            val=${ALL_RESULTS[$((idx+i))]}
            abs_val=${val#-}  # absolute value
            if [ $i -eq 0 ]; then
                g_detail="$abs_val"
            else
                g_detail="$g_detail, $abs_val"
            fi
            g_sum=$(( g_sum + val ))
        done
        GROUP_RESULTS+=("$g_sum")
        GROUP_DETAIL+=("($g_detail)")
        idx=$(( idx + g_count ))
    done

    # Default KD_NUM based context: 4 dice + keep highest -> 3 (ability scores), else -> 1
    if [ -n "$KD_TYPE" ] && [ -z "$KD_NUM" ]; then
        if [ "$KD_TYPE" = "kh" ] && [ "${#ALL_RESULTS[@]}" -eq 4 ]; then
            KD_NUM=3
        else
            KD_NUM=1
        fi
    fi

elif [ $# -ge 2 ]; then
    # Legacy notation
    COUNT=$1
    FACES=$2
    shift 2
    IS_MULTI=false

    while [ $# -gt 0 ]; do
        case "$1" in
            kh|KH) KD_NUM="${2:-1}"; KD_TYPE="kh"; shift; [ $# -gt 0 ] && shift || shift ;;
            kl|KL) KD_NUM="${2:-1}"; KD_TYPE="kl"; shift; [ $# -gt 0 ] && shift || shift ;;
            dh|DH) KD_NUM="${2:-1}"; KD_TYPE="dh"; shift; [ $# -gt 0 ] && shift || shift ;;
            dl|DL) KD_NUM="${2:-1}"; KD_TYPE="dl"; shift; [ $# -gt 0 ] && shift || shift ;;
            +*|-*|[0-9]*) TOTAL_MODIFIER="${1#+}"; shift ;;
            *) echo "Error: unknown argument '$1'"; exit 1 ;;
        esac
    done

    GROUP_LABELS=("${COUNT}d${FACES}")
    GROUP_RESULTS=()
    GROUP_DETAIL=()
    roll_group "$COUNT" "$FACES"

    g_sum=0
    g_detail=""
    for (( i=0; i<COUNT; i++ )); do
        val=${ALL_RESULTS[$i]}
        if [ $i -eq 0 ]; then
            g_detail="$val"
        else
            g_detail="$g_detail, $val"
        fi
        g_sum=$(( g_sum + val ))
    done
    GROUP_RESULTS+=("$g_sum")
    GROUP_DETAIL+=("($g_detail)")
else
    echo "Usage: $0 <dice_notation>"
    echo "  Examples:"
    echo "    3d8            # roll 3d8"
    echo "    2d6+2          # roll 2d6+2"
    echo "    4d6kh3         # roll 4d6 keep highest 3"
    echo "    2d20kh+5       # advantage +5"
    echo "    5d6dl1+2       # drop lowest 1 +2"
    echo "    2d8+2d6+4      # multi-group (e.g. firebolt)"
    echo "    1d20+1d8+3     # multi-group with modifier"
    exit 1
fi

# --- Compute total ---
TOTAL=0
for r in "${ALL_RESULTS[@]}"; do
    TOTAL=$(( TOTAL + r ))
done
TOTAL=$(( TOTAL + TOTAL_MODIFIER ))

# --- Apply keep/drop (only for single-group rolls with kd) ---
if [ -n "$KD_TYPE" ] && [ -n "$KD_NUM" ]; then
    # Only positive dice for keep/drop (multi-group with negatives doesn't make sense with kd)
    POS_RESULTS=()
    for r in "${ALL_RESULTS[@]}"; do
        if [ "$r" -gt 0 ]; then
            POS_RESULTS+=("$r")
        fi
    done
    N_DICE=${#POS_RESULTS[@]}
    N_KEEP=$KD_NUM

    case "$KD_TYPE" in
        kh)
            if [ "$N_KEEP" -ge "$N_DICE" ]; then
                echo "Error: cannot keep $N_KEEP from $N_DICE dice"
                exit 1
            fi
            SORTED=($(for r in "${POS_RESULTS[@]}"; do echo $r; done | sort -rn))
            KEPT=("${SORTED[@]:0:$N_KEEP}")
            ;;
        kl)
            if [ "$N_KEEP" -ge "$N_DICE" ]; then
                echo "Error: cannot keep $N_KEEP from $N_DICE dice"
                exit 1
            fi
            SORTED=($(for r in "${POS_RESULTS[@]}"; do echo $r; done | sort -n))
            KEPT=("${SORTED[@]:0:$N_KEEP}")
            ;;
        dh)
            if [ "$N_KEEP" -ge "$N_DICE" ]; then
                echo "Error: cannot drop $N_KEEP from $N_DICE dice"
                exit 1
            fi
            SORTED=($(for r in "${POS_RESULTS[@]}"; do echo $r; done | sort -rn))
            KEPT=("${SORTED[@]:$N_KEEP}")
            ;;
        dl)
            if [ "$N_KEEP" -ge "$N_DICE" ]; then
                echo "Error: cannot drop $N_KEEP from $N_DICE dice"
                exit 1
            fi
            SORTED=($(for r in "${POS_RESULTS[@]}"; do echo $r; done | sort -n))
            KEPT=("${SORTED[@]:$N_KEEP}")
            ;;
    esac

    # Rebuild group detail for kept dice
    KEPT_SUM=0
    for r in "${KEPT[@]}"; do
        KEPT_SUM=$(( KEPT_SUM + r ))
    done

    # Build display strings
    join_arr() {
        local IFS=", "
        echo "$*"
    }
    ALL_STR=$(join_arr "${ALL_RESULTS[@]}")
    KEPT_STR=$(join_arr "${KEPT[@]}")

    # Determine dropped
    declare -A KEPT_COUNTS=()
    for r in "${KEPT[@]}"; do
        KEPT_COUNTS[$r]=$(( ${KEPT_COUNTS[$r]:-0} + 1 ))
    done
    DROPPED=()
    for r in "${POS_RESULTS[@]}"; do
        if [ "${KEPT_COUNTS[$r]:-0}" -gt 0 ]; then
            KEPT_COUNTS[$r]=$(( KEPT_COUNTS[$r] - 1 ))
        else
            DROPPED+=("$r")
        fi
    done
    DROPPED_STR=$(join_arr "${DROPPED[@]}")

    # Label
    kd_n="${KD_NUM:-1}"
    LABEL="${KD_TYPE}${kd_n}"
    MOD_STR=""
    if [ "$TOTAL_MODIFIER" -gt 0 ]; then
        MOD_STR="+${TOTAL_MODIFIER}"
    elif [ "$TOTAL_MODIFIER" -lt 0 ]; then
        MOD_STR="${TOTAL_MODIFIER}"
    fi

    TOTAL=$(( KEPT_SUM + TOTAL_MODIFIER ))

    echo "[${GROUP_LABELS[0]}${LABEL}${MOD_STR}: rolls=(${ALL_STR}) kept=(${KEPT_STR}) dropped=(${DROPPED_STR})${MOD_STR:+ $MOD_STR} = ${TOTAL}]"
elif [ "$IS_MULTI" = true ]; then
    # Multi-group output
    join_arr() {
        local IFS=", "
        echo "$*"
    }

    MOD_STR=""
    if [ "$TOTAL_MODIFIER" -gt 0 ]; then
        MOD_STR="+${TOTAL_MODIFIER}"
    elif [ "$TOTAL_MODIFIER" -lt 0 ]; then
        MOD_STR="${TOTAL_MODIFIER}"
    fi

    # Build label from groups (handle negative groups: 2d8-2d6, not 2d8+-2d6)
    LABEL=""
    for gi in "${!GROUP_LABELS[@]}"; do
        if [ "$gi" -gt 0 ]; then
            case "${GROUP_LABELS[$gi]}" in
                -*) LABEL="${LABEL}${GROUP_LABELS[$gi]}" ;;
                *)  LABEL="${LABEL}+${GROUP_LABELS[$gi]}" ;;
            esac
        else
            LABEL="${GROUP_LABELS[$gi]}"
        fi
    done

    # Build details
    DETAIL=""
    for gi in "${!GROUP_LABELS[@]}"; do
        if [ "$gi" -gt 0 ]; then
            case "${GROUP_RESULTS[$gi]}" in
                -*) DETAIL="${DETAIL}${GROUP_RESULTS[$gi]}${GROUP_DETAIL[$gi]}" ;;
                *)  DETAIL="${DETAIL}+${GROUP_RESULTS[$gi]}${GROUP_DETAIL[$gi]}" ;;
            esac
        else
            DETAIL="${GROUP_RESULTS[$gi]}${GROUP_DETAIL[$gi]}"
        fi
    done
    DETAIL="${DETAIL}${MOD_STR:+ $MOD_STR}"

    echo "[${LABEL}${MOD_STR}: ${DETAIL} = ${TOTAL}]"
else
    # Simple single-group roll
    join_arr() {
        local IFS=", "
        echo "$*"
    }

    MOD_STR=""
    if [ "$TOTAL_MODIFIER" -gt 0 ]; then
        MOD_STR="+${TOTAL_MODIFIER}"
    elif [ "$TOTAL_MODIFIER" -lt 0 ]; then
        MOD_STR="${TOTAL_MODIFIER}"
    fi

    ALL_STR=$(join_arr "${ALL_RESULTS[@]}")
    ROLL_SUM=${GROUP_RESULTS[0]}

    if [ ${#ALL_RESULTS[@]} -eq 1 ]; then
        echo "[d${GROUP_LABELS[0]#*d}${MOD_STR}: ${ALL_RESULTS[0]}${MOD_STR:+ $MOD_STR} = ${TOTAL}]"
    else
        echo "[${GROUP_LABELS[0]}${MOD_STR}: rolls=(${ALL_STR}) sum=${ROLL_SUM}${MOD_STR:+ $MOD_STR} = ${TOTAL}]"
    fi
fi
