#!/bin/bash
PS3='Please enter your choice: '
options=("Single-player" "rakiru's server" "Lighting test" "Map editor" "PMF editor" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "Single-player")
            echo "Starting local server..."
            ./iceball -s 0 pkg/base pkg/maps/mesa.vxl
            ;;
        "rakiru's server")
            echo "Joining rakiru's server..."
            ./iceball -c aoswiki.rakiru.com 20737
            ;;
        "Lighting test")
            echo "Starting local server with lighting test..."
            ./iceball -s 0 pkg/iceball/radtest
            ;;
        "Map editor")
            echo "Starting map editor..."
            ./iceball -s 0 pkg/iceball/mapedit
            ;;
        "PMF editor")
            echo "Starting PMF editor..."
            ./iceball -s 0 pkg/iceball/pmfedit
            ;;
        "Quit")
            break
            ;;
        *) echo invalid option;;
    esac
done
