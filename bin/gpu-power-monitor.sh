#!/usr/bin/env bash
set -Eeuo pipefail

# ==================== Configuration ====================

POWER_THRESHOLD=${POWER_THRESHOLD:-100}       # Watts
LOW_POWER_DURATION=3600   # Seconds: 60 minutes
CHECK_INTERVAL=5         # Seconds between checks

SSH_IDLE_LIMIT=30
SSH_ACTIVITY_DIR="/run/gpu-power-monitor"

# Monitoring time window, using local system time (24-hour format).
START_TIME="00:00"
END_TIME="23:59"

# GPU index to monitor
GPU_INDEX=0

RUN_DIR="/run/gpu-power-monitor"
RUN_CHECK_INTERVAL=30
last_run_check=0

# check if run_dir exists
[[ -d "$RUN_DIR" ]] || install -d -m 1777 "$RUN_DIR"

# Command to execute when the condition is met.
TRIGGER_COMMAND=(/usr/local/bin/safe-sleep -y)
#TRIGGER_COMMAND=(echo "execute command on: $(date)" '>' /tmp/gpu-power.log)

# =======================================================

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*"
}

low_power_since=0
triggered=false
was_in_window=false



check_running_commands() {
    local now pid file
    now=$(date +%s)

    # Only scan marker files every RUN_CHECK_INTERVAL seconds.
    if (( now - last_run_check < RUN_CHECK_INTERVAL )); then
        return
    fi
    last_run_check=$now

    shopt -s nullglob
    local files=("$RUN_DIR"/command-*)
    shopt -u nullglob

    for file in "${files[@]}"; do
        [[ -f "$file" ]] || continue

        # Extract the launcher PID from the filename.
        pid=${file##*/command-}

        if [[ ! "$pid" =~ ^[0-9]+$ ]] || ! kill -0 "$pid" 2>/dev/null; then
            log "Removing stale command marker: $file (PID $pid not running)"
            rm -f -- "$file"
        fi
    done
}

has_recent_ssh_activity() {
    local file timestamp now

    now=$(date +%s)

    shopt -s nullglob

    for file in "$SSH_ACTIVITY_DIR"/ssh-*; do
        [[ -f "$file" ]] || continue

        timestamp=$(<"$file")

        [[ "$timestamp" =~ ^[0-9]+$ ]] || continue

        if (( now - timestamp <= SSH_IDLE_LIMIT )); then
            shopt -u nullglob
            return 0
        fi
    done

    shopt -u nullglob
    return 1
}

# Return success if current local time is inside the configured window.
in_monitoring_window() {
    local current start end

    current=$(date +%H%M)
    start=${START_TIME//:/}
    end=${END_TIME//:/}

    # Equal start/end means monitoring all day.
    if [[ "$start" == "$end" ]]; then
        return 0
    fi

    # Ordinary window, e.g. 01:00-08:00.
    if (( 10#$start < 10#$end )); then
        (( 10#$current >= 10#$start && 10#$current < 10#$end ))
    else
        # Overnight window, e.g. 22:00-06:00.
        (( 10#$current >= 10#$start || 10#$current < 10#$end ))
    fi
}

get_gpu_power() {
    amd-smi metric -g "$GPU_INDEX" --power 2>/dev/null |
        awk '
            /SOCKET_POWER:/ {
                for (i = 1; i <= NF; i++) {
                    if ($i == "SOCKET_POWER:") {
                        value = $(i + 1)

                        if (value ~ /^[0-9]+([.][0-9]+)?$/) {
                            print value
                            exit
                        }
                    }
                }
            }
        '
}

log "GPU power monitor started"
log "GPU=$GPU_INDEX threshold=${POWER_THRESHOLD}W duration=${LOW_POWER_DURATION}s interval=${CHECK_INTERVAL}s"
log "Monitoring window: ${START_TIME}-${END_TIME} (local time)"

while true; do
    now=$(date +%s)

    if ! in_monitoring_window; then
        if [[ "$was_in_window" == true ]]; then
            log "Monitoring window ended; resetting timer"
        fi

        low_power_since=0
        triggered=false
        was_in_window=false

        sleep "$CHECK_INTERVAL"
        continue
    fi

	# check if there is process running to keep awake.
	check_running_commands
	if compgen -G "$RUN_DIR/command-*" > /dev/null; then
	    if (( low_power_since != 0 )); then
	        log "Long-running command detected; resetting low-power timer"
	    fi
	    low_power_since=0
	    triggered=false
	    sleep "$CHECK_INTERVAL"
	    continue
	fi

    if [[ "$was_in_window" == false ]]; then
        log "Monitoring window started"
        was_in_window=true
        low_power_since=0
        triggered=false
    fi

    if has_recent_ssh_activity; then
        if (( low_power_since != 0 )); then
            log "Recent SSH activity detected; resetting low-power timer"
        fi

        low_power_since=0
        triggered=false

        sleep "$CHECK_INTERVAL"
        continue
    fi

    if ! power=$(get_gpu_power) || [[ ! "$power" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        log "WARNING: Unable to read GPU power; resetting timer"
        low_power_since=0
        triggered=false
        sleep "$CHECK_INTERVAL"
        continue
    fi

#    log "GPU power: ${power}w"

    below_threshold=$(awk -v p="$power" -v t="$POWER_THRESHOLD" \
        'BEGIN { print (p < t) ? 1 : 0 }')

    if (( below_threshold )); then
        if (( low_power_since == 0 )); then
            low_power_since=$now
            triggered=false
            log "GPU power ${power}W: below threshold; timer started"
        fi

        elapsed=$((now - low_power_since))

        if (( elapsed >= LOW_POWER_DURATION )) && [[ "$triggered" == false ]]; then
            log "GPU power has remained below ${POWER_THRESHOLD}W for ${elapsed}s; executing command"

            if "${TRIGGER_COMMAND[@]}"; then
                log "Command completed successfully"
                triggered=true
            else
                rc=$?
                log "ERROR: Command failed with exit code ${rc}; will retry on the next check"
            fi
        fi
    else
        if (( low_power_since != 0 )); then
            log "GPU power ${power}W: threshold reached; resetting timer"
        fi

        low_power_since=0
        triggered=false
    fi

    sleep "$CHECK_INTERVAL"
done
