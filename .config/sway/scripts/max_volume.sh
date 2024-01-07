#!/bin/bash

max_volume_pc=$1
current_volume_pc=$(pactl list sinks \
    | grep '<Your system language word that means "volume">' \
    | head -n $(( $SINK + 1 )) \
    | tail -n 1 \
    | sed -e 's,.* \([0-9][0-9]*\)%.*,\1,')

if (($(echo -n $current_volume_pc | wc -m) == 0)); then
    current_volume_pc=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ \
        | sed -e 's,.* \([0-9][0-9]*\),\1,' \
        | awk '{print $1 * 100}')
fi

if (($current_volume_pc < $max_volume_pc-5)) ; then
    pactl set-sink-volume @DEFAULT_SINK@ +5% && $refresh_i3status
else
    a=$(($max_volume_pc - $current_volume_pc))
    pactl set-sink-volume @DEFAULT_SINK@ +$a% && $refresh_i3status
fi
