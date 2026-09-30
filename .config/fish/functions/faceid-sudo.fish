function faceid-sudo --description 'Toggle howdy face unlock for sudo: faceid-sudo [on|off|status]'
    set -l pam /etc/pam.d/sudo
    set -l lines 'auth\s.*(pam_howdy\.so|linux-enable-ir-emitter)'

    set -l state off
    grep -qE "^$lines" $pam; and set state on

    set -l action $argv[1]
    if test -z "$action"
        test $state = on; and set action off; or set action on
    end

    switch $action
        case status
            echo "face unlock for sudo: $state"
            return
        case on
            sudo sed -i -E "s/^#($lines)/\1/" $pam
        case off
            sudo sed -i -E "s/^($lines)/#\1/" $pam
        case '*'
            echo "usage: faceid-sudo [on|off|status]" >&2
            return 1
    end
    and faceid-sudo status
end
