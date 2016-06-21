#!/bin/sh
gconftool-2 -s /desktop/gnome/url-handlers/iceball/command "$(pwd)/iceball-gl -c %s" --type String
gconftool-2 -s /desktop/gnome/url-handlers/iceball/enabled --type Boolean true
gconftool-2 -s /desktop/gnome/url-handlers/iceball/needs-terminal --type Boolean true

