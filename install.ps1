# Copies game and content folders from this repository into the appropriate location in your Steam installation.

# I wanted to do something with symlinks instead, but ran into the following problems and gave up:
## 1. Dota 2 expects the expanded path of its assets to be inside its own directory, so that it can do some path mangling.
## 2. Dota 2 locks the files of addons it has loaded.
## 3. Git on Windows can't follow symlinks.

# Requires Windows Powershell (installed by default on all Windows machines). To allow running of scripts, you may need to do something like:
# Set-ExecutionPolicy Unrestricted
# or
# Set-ExecutionPolicy RemoteSigned # (This is a little safer, perhaps.)

# Requires the DOTA2_FOLDER parameter (this is usually something like "<<path-to-steam>>/steamapps/common/dota 2", but sometimes ends in "dota 2 beta" instead).
# For example, on my machine I run the following from inside Powershell:
# ./install.ps1 "C:\Games\Steam\steamapps\common\dota 2 beta"

# I also found I had to run the Powershell console as admin - this will depend on the permissions applying to your Steam install.

param([String] $DOTA2_FOLDER);

if (-not $DOTA2_FOLDER) {
    Throw "Must specify the location of the Dota 2 directory";
}

if (-not (Test-Path($DOTA2_FOLDER))) {
    Throw "Could not find Dota 2 directory ${DOTA2_FOLDER}";
}

$CUSTOM_GAME = "card-draft";

$GAME = "${DOTA2_FOLDER}\game\dota_addons\${CUSTOM_GAME}";
$CONTENT = "${DOTA2_FOLDER}\content\dota_addons\${CUSTOM_GAME}";

$GAME_ORIGIN = "${PWD}\game\dota_addons\${CUSTOM_GAME}";
$CONTENT_ORIGIN = "${PWD}\content\dota_addons\${CUSTOM_GAME}";

if (-not (Test-Path($GAME_ORIGIN))) {
    Throw "Could not find \game\dota_addons\${CUSTOM_GAME} at ${GAME_ORIGIN}";
}

if (-not (Test-Path($CONTENT_ORIGIN))) {
    Throw "Could not find \content\dota_addons\${CUSTOM_GAME} at ${CONTENT_ORIGIN}";
}

rm -Recurse -Force "${GAME}";
rm -Recurse -Force "${CONTENT}";

cp "${GAME_ORIGIN}" "${GAME}";
cp "${CONTENT_ORIGIN}" "${CONTENT}";
