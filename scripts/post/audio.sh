setup_audio() {
    local audio_stack;
    local pkgs=();

    audio_stack="${AUDIO_STACK:-pipewire}";

    case "${audio_stack}" in
        pipewire)
            pkgs+=(
                pipewire
                pipewire-pulse
                wireplumber
                pavucontrol
            )
            ;;

        pulseaudio)
            pkgs+=(
                pulseaudio
                pulseaudio-alsa
                pavucontrol
            )
            ;;

        none)
            return 0
            ;;
    esac

    pacman -S \
        --noconfirm \
        --needed \
        "${pkgs[@]}"
}