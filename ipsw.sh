#!/bin/bash

if ! [ "$(uname)" = Darwin ]; then
	echo "This script is currently only compatible with OS X."
	exit 1
fi

if [ $# -eq 0 ]
then
	echo "Usage: ./ipsw.sh <restore ipsw> <dualboot ipsw>"
	exit 1
fi

function available {
	if ! [ -s "$1" ]; then
		echo "$1 no such file or directory."
		exit 1
	fi
}

available "$1"

available "$2"

bundlename=${2%.ipsw*}.bundle

function buddy {
	/usr/libexec/PlistBuddy -c "Print :Firmware\ Files:${1}" FirmwareBundles/"$bundlename"/Info.plist
}

if ! [ -d FirmwareBundles ]; then
	echo "FirmwareBundles folder not found"
	exit 1
fi

available xpwntool

command -v bspatch >/dev/null 2>&1 || { echo "bspatch is not installed. Install it"; exit 1; }
command -v unzip >/dev/null 2>&1 || { echo "unzip is not installed. Install it"; exit 1; }
command -v zip >/dev/null 2>&1 || { echo "zip is not installed. Install it"; exit 1; }
command -v /usr/libexec/PlistBuddy 2>&1 || { echo "You're not running OS X 10.5 or higher with XCode"; exit 1; }

echo "Checking Bundles"

available FirmwareBundles/"$bundlename"/Info.plist

echo "Info file found"

echo "Gathering File information"



LLB=$(buddy LLB:File)
iBoot=$(buddy iBoot:File)
DeviceTree=$(buddy DeviceTree:File)
manifest=$(buddy manifest:File)

LLB_iv=$(buddy LLB:IV)
LLB_k=$(buddy LLB:Key)

iBoot_iv=$(buddy iBoot:IV)
iBoot_k=$(buddy iBoot:Key)

DeviceTree_iv=$(buddy DeviceTree:IV)
DeviceTree_k=$(buddy DeviceTree:Key)

LLB_patch=$(buddy LLB:Patch)
iBoot_patch=$(buddy iBoot:Patch)
DeviceTree_patch=$(buddy DeviceTree:Patch)

FirmwarePath=$(/usr/libexec/PlistBuddy -c 'Print :All_flash\ Path' FirmwareBundles/"$bundlename"/Info.plist)

echo "Unzipping Files"

unzip "$2" "${LLB}" >/dev/null
unzip "$2" "${iBoot}" >/dev/null
unzip "$2" "${DeviceTree}" >/dev/null
unzip "$2" "${manifest}" >/dev/null

echo "Decrypting Files"

./xpwntool "${LLB}" "${LLB}.dec" -iv "${LLB_iv}" -k "${LLB_k}" -decrypt >/dev/null
./xpwntool "${iBoot}" "${iBoot}.dec" -iv "${iBoot_iv}" -k "${iBoot_k}" -decrypt >/dev/null
./xpwntool "${DeviceTree}" "${DeviceTree}.dec" -iv "${DeviceTree_iv}" -k "${DeviceTree_k}" -decrypt >/dev/null

echo "Removing original files"

rm -f "$LLB" "$iBoot" "$DeviceTree"

echo "Patching Files"

bspatch "${LLB}.dec" "${FirmwarePath}LLB.img3" "${LLB_patch}"
bspatch "${iBoot}.dec" "${FirmwarePath}iBoot.img3" "${iBoot_patch}"
bspatch "${DeviceTree}.dec" "${FirmwarePath}DeviceTree.img3" "${DeviceTree_patch}"

echo "Editing manifest"

cat >>"${manifest}" <<EOL
"LLB.img3"
"iBoot.img3"
"DeviceTree.img3"
EOL

echo "Cleaning up"

rm -f "${FirmwarePath}*.dec"

read -n1 -r -p "Do you want to copy the original ipsw? [y/n]: " choice

if [[ $choice = "y" ]]; then
	mkdir original_ipsw
	cp "$1" original_ipsw/
fi

echo "Rezipping Files"

zip "$1" "${FirmwarePath}*" >/dev/null
rm -rf Firmware/
echo "Done"
