#!/bin/sh
set -e

if [ -n "$LAMP_SERVER_URL" ]; then
    /usr/libexec/PlistBuddy -c "Set :LampServerURL $LAMP_SERVER_URL" "$CI_PRIMARY_REPOSITORY_PATH/Apple/DJDX/Info.plist"
fi
