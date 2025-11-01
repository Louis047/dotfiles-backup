#!/bin/bash

# Kill any existing wlogout instance
pkill wlogout

# Launch wlogout with your config & style
wlogout \
	--buttons-per-row 5 \
    --layout ~/.config/wlogout/layout \
    --css ~/.config/wlogout/style.css \
    --protocol layer-shell
