setup_audio() {
    local audio_stack;
    local pkgs=();

    audio_stack="${AUDIO_STACK:-pipewire}";

    case "${audio_stack}" in
        pipewire)
            pkgs+=(
                pipewire
                pipewire-pulse
                pipewire-alsa
                pipewire-jack
                wireplumber

                alsa-utils
                pavucontrol
                rtkit
            )
            ;;

        pulseaudio)
            pkgs+=(
                pulseaudio
                pulseaudio-alsa

                alsa-utils
                pavucontrol
            )
            ;;

        none)
            return 0
            ;;
    esac

    printf '[*] Installing audio packages...\n';

    if ! pacman -S \
        --noconfirm \
        --needed \
        "${pkgs[@]}"; then

        printf '[*] Failed to install audio packages.\n' >&2;
        return 1;
    fi
}