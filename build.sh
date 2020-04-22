#!/bin/bash

source /drone/src/config.sh

# Email for git
ci_repo=$(cat /drone/src/.git/config | grep url | sed 's|url = https://github.com/||' | sed 's|.git||')
git config --global user.email "$GITHUB_EMAIL"
git config --global user.name "$GITHUB_USER"

TELEGRAM_TOKEN=$(cat /tmp/tg_token)
TELEGRAM_CHAT=$(cat /tmp/tg_chat)
GITHUB_TOKEN=$(cat /tmp/gh_token)
DEVICE=$(cat /tmp/device)
OEM=$(cat /tmp/oem)

export TELEGRAM_TOKEN
export TELEGRAM_CHAT
export GITHUB_TOKEN
export DEVICE
export OEM

function trim_darwin() {
    cd .repo/manifests
    cat default.xml | grep -v darwin  >temp  && cat temp >default.xml  && rm temp
    git commit -a -m "Magic"
    cd ../
    cat manifest.xml | grep -v darwin  >temp  && cat temp >manifest.xml  && rm temp
    cd ../
}

export outdir="out/target/product/$DEVICE"
ci_url="$(echo "https://cloud.drone.io/"$ci_repo"/"$(cat /tmp/build_no)"/1/2" | tr -d " ")"

cd /home/ci

git clone https://"$GITHUB_USER":"${GITHUB_TOKEN}"@github.com/"$GITHUB_USER"/google-git-cookies.git >/dev/null  2>&1
if [ -e google-git-cookies ]; then
    cd google-git-cookies
    bash setup_cookies.sh
    cd ../
    rm -rf google-git-cookies
else
    echo "google-git-cookies repo not found on your account, see steps on README"
fi

mkdir "$ROM"
cd "$ROM"

repo init -u "$manifest_url" -b "$branch" --depth 1 >/dev/null  2>&1
echo "Sync started for "$manifest_url""
telegram -M "[[${DEVICE}]] Sync Started for ["$ROM"]("$manifest_url")"
SYNC_START=$(date +"%s")
trim_darwin >/dev/null  2>&1
repo sync --force-sync --no-clone-bundle -j$(nproc --all) 2>&1 >>logwe 2>&1
bash /drone/src/clone.sh
SYNC_END=$(date +"%s")
SYNC_DIFF=$((SYNC_END - SYNC_START))
if [ -e frameworks/base ]; then
    echo "Sync completed successfully in $((SYNC_DIFF / 60)) minute(s) and $((SYNC_DIFF % 60)) seconds"
    echo "Build Started"
    telegram -M "[[${DEVICE}]] Sync completed successfully in $((SYNC_DIFF / 60)) minute(s) and $((SYNC_DIFF % 60)) seconds

Build Started: [See Progress]("$ci_url")"

    BUILD_START=$(date +"%s")
    
    export CUSTOM_BUILD_TYPE=UNOFFICIAL
    . build/envsetup.sh
    source /drone/src/config.sh
    if [ -e device/"$OEM"/"$DEVICE" ]; then
        python3 /drone/src/dependency_cloner.py
    fi
    brunch "$rom_vendor_name"_"$DEVICE"-userdebug
    mka bacon | grep "$DEVICE"
    BUILD_END=$(date +"%s")
    BUILD_DIFF=$((BUILD_END - BUILD_START))

    export finalzip_path=$(ls "$outdir"/*202*.zip | tail -n -1)
    export zip_name=$(echo "$finalzip_path" | sed "s|"$outdir"/||")
    export tag=$( echo "$zip_name" | sed 's|.zip||')
    if [ -e "$finalzip_path" ]; then
        echo "Build completed successfully in $((BUILD_DIFF / 60)) minute(s) and $((BUILD_DIFF % 60)) seconds"

        echo "Uploading"

        github-release "$release_repo" "$tag" "master" ""$ROM" for "$DEVICE"

Date: $(env TZ="$timezone" date)" "$finalzip_path"

        echo "Uploaded"

        telegram -M "[[${DEVICE}]] Build completed successfully in $((BUILD_DIFF / 60)) minute(s) and $((BUILD_DIFF % 60)) seconds

Download: ["$zip_name"](https://github.com/"$release_repo"/releases/download/"$tag"/"$zip_name")"
        exit 0

    else
        echo "Build failed in $((BUILD_DIFF / 60)) minute(s) and $((BUILD_DIFF % 60)) seconds"
        telegram -N -M "[[${DEVICE}]] Build failed in $((BUILD_DIFF / 60)) minute(s) and $((BUILD_DIFF % 60)) seconds"
        exit 1
    fi
else
    echo "Sync failed in $((SYNC_DIFF / 60)) minute(s) and $((SYNC_DIFF % 60)) seconds"
    telegram -N -M "[[${DEVICE}]] Sync failed in $((SYNC_DIFF / 60)) minute(s) and $((SYNC_DIFF % 60)) seconds"
    exit 1
fi
