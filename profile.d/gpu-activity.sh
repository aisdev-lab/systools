# Track activity in interactive Bash shells connected over SSH.
if [[ $- == *i* && -n ${SSH_CONNECTION:-} && -n ${BASH_VERSION:-} ]]; then
    _gpu_activity_file="/run/gpu-power-monitor/ssh-${BASHPID}"

    _gpu_update_activity() {
        printf '%s\n' "$(date +%s)" > "$_gpu_activity_file"
    }

    # Preserve existing PROMPT_COMMAND entries, including Bash arrays.
    if [[ $(declare -p PROMPT_COMMAND 2>/dev/null) == "declare -a"* ]]; then
        PROMPT_COMMAND+=('_gpu_update_activity')
    else
        PROMPT_COMMAND="${PROMPT_COMMAND:+${PROMPT_COMMAND}; }_gpu_update_activity"
    fi

    _gpu_update_activity

    _gpu_cleanup_activity() {
        rm -f "$_gpu_activity_file"
    }

    trap _gpu_cleanup_activity EXIT
fi

