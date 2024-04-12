#!/bin/bash

download_latest() {
    local repo_name=$1
    local file_name=$2
    local file_extension=$3

    local url="https://api.github.com/repos/$repo_name/releases/latest"
    local response=$(curl --silent "$url")

    local tag_name=$(echo "$response" | jq -r '.tag_name')
    local cli_tag=${tag_name#v}

    local download_url="https://github.com/$repo_name/releases/download/$tag_name/$file_name-$cli_tag$file_extension"

    echo "$file_name$file_extension: $tag_name"
    echo "url: $download_url"

    curl -L -o "$file_name$file_extension" "$download_url"
}

download_latest_single() {
    local repo_name=$1
    local file_name=$2

    local url="https://api.github.com/repos/$repo_name/releases/latest"
    local response=$(curl --silent "$url")

    local tag_name=$(echo "$response" | jq -r '.tag_name')
    local cli_tag=${tag_name#v}

    local download_url=$(echo "$response" | jq -r '.assets[].browser_download_url')

    echo "$file_name: $tag_name"

    echo "$response" | jq -r '.assets[].browser_download_url' | while read -r line; do
        echo "url: $line"
        local url_filename=$(basename "$line")
        local target_filename="$file_name"_"$url_filename"
        curl -L -o "$target_filename"  "$line"
    done
}

mkdir build_temp
cd build_temp

download_latest "ReVanced/revanced-integrations" "revanced-integrations" ".apk"
download_latest "ReVanced/revanced-patches" "revanced-patches" ".jar"
download_latest "ReVanced/revanced-cli" "revanced-cli" "-all.jar"

youtube_latest_url="https://api.revanced.app/v2/patches/latest"
video_ads_versions=$(curl -s "$youtube_latest_url" | jq -r '.patches[] | select(.name == "Video ads") | .compatiblePackages[].versions[]')
sorted_versions=$(echo "$video_ads_versions" | sort -rV)
latest_version=$(echo "$sorted_versions" | head -n1)

echo "Latest youtube supported: $latest_version"

youtube_download_url=$(curl "https://apkpure.net/youtube/com.google.android.youtube/download/$latest_version" | \
    grep -o 'href="[^"]*"' | \
    grep 'APK/com.google.android.youtube' | \
    awk -F'"' 'NR==2 {print $2}')
curl -L -o "youtube-original.apk" "$youtube_download_url"

java -jar revanced-cli-all.jar \
patch youtube-original.apk --patch-bundle revanced-patches.jar \
--merge revanced-integrations.apk \
--purge \
--out youtube.apk

cp youtube.apk ../

cd ..

rm -r build_temp

download_latest_single "ReVanced/GmsCore" "microg"

zip youtube-revanced.zip youtube.apk microg*

rm -f youtube.apk microg*
