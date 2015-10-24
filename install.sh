#!/bin/bash

# Fail if attempting to use a variable which hasn't been set.
set -u;
# Stop on first error.
set -e;

# Copies game and content folders from this repository into the appropriate location in your Steam installation.

# Requires a Unix-like environment (try Git bash).
# Requires the DOTA2_FOLDER environment variable to have been set (this is usually something like "<<path-to-steam>>/steamapps/common/dota 2", but sometimes ends in "dota 2 beta" instead).
# For example, on my machine I run the following from inside Powershell:
# DOTA2_FOLDER="C:/Games/Steam/steamapps/common/dota 2 beta" ./install.sh;

# You may need to run this as admin depending on the permissions of your Dota 2 folder.

test -d "${DOTA2_FOLDER}";

CUSTOM_GAME="card-draft";

GAME="${DOTA2_FOLDER}/game/dota_addons/${CUSTOM_GAME}";
CONTENT="${DOTA2_FOLDER}/content/dota_addons/${CUSTOM_GAME}";

GAME_ORIGIN="${PWD}/game/dota_addons/${CUSTOM_GAME}";
CONTENT_ORIGIN="${PWD}/content/dota_addons/${CUSTOM_GAME}";

test -d "${GAME_ORIGIN}";
test -d "${CONTENT_ORIGIN}";

rm -rf "${GAME}";
rm -rf "${CONTENT}";

cp -r "${GAME_ORIGIN}" "${GAME}";
cp -r "${CONTENT_ORIGIN}" "${CONTENT}";
