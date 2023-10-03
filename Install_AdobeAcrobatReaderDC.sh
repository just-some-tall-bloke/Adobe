#!/bin/zsh

# Automatically download and install the latest Adobe Acrobat Reader

# Variables
currentVersion=$(curl -LSs "https://armmf.adobe.com/arm-manifests/mac/AcrobatDC/acrobat/current_version.txt" | sed 's/\.//g')
currentVersionShort=${currentVersion: -10}
appName="Adobe Acrobat Reader.app"
appPath="/Applications/${appName}"
appProcessName="AdobeReader"
dmgName="AcroRdrDC_${currentVersionShort}_MUI.dmg"
dmgVolumePath="/Volumes/AcroRdrDC_${currentVersionShort}_MUI"
downloadUrl="https://ardownload2.adobe.com/pub/adobe/reader/mac/AcrobatDC/${currentVersionShort}"
pkgName="AcroRdrDC_${currentVersionShort}_MUI.pkg"

# Function to clean up temporary files and unmount DMG
cleanup () {
  if [[ -f "${tmpDir}/${dmgName}" ]]; then
    rm -f "${tmpDir}/${dmgName}" && echo "Removed file ${tmpDir}/${dmgName}"
  fi
  if [[ -d "${tmpDir}" ]]; then
    rm -R "${tmpDir}" && echo "Removed directory ${tmpDir}"
  fi
  if [[ -d "${dmgVolumePath}" ]]; then
    hdiutil detach "${dmgVolumePath}" -quiet && echo "Unmounted DMG"
  fi
}

# Function to create a temporary directory if it doesn't exist
createTmpDir () {
  if [ -z ${tmpDir+x} ]; then
    tmpDir=$(mktemp -d)
    echo "Temp dir set to ${tmpDir}"
  fi
}

# Function to check if Adobe Reader process is running
processCheck () {
  if pgrep -x "${appProcessName}" > /dev/null; then
    echo "${appProcessName} is currently running"
    echo "Aborting install"
    cleanup
    exit 0
  else
    echo "${appProcessName} not currently running"
  fi
}

# Function to attempt downloading the DMG file
tryDownload () {
  if curl -Ss "${downloadUrl}/${dmgName}" -o "${tmpDir}/${dmgName}"; then
    echo "Download successful"
    tryDownloadState=1
  else
    echo "Download unsuccessful"
    tryDownloadCounter=$((tryDownloadCounter+1))
  fi
}

# Function to check the installed version of Adobe Reader
versionCheck () {
  if [[ -d "${appPath}" ]]; then
    echo "${appName} version is $(defaults read "${appPath}/Contents/Info.plist" CFBundleShortVersionString)"
    versionCheckStatus=1
  else
    echo "${appName} not installed"
    versionCheckStatus=0
  fi
}

# Start

# Validate currentVersion variable contains 10 digits.
echo "Current version: ${currentVersionShort}"
if [[ ! ${currentVersionShort} =~ ^[0-9]{10}$ ]]; then
  echo "Current version does not appear to match the 10-digit format expected"
  exit 1
fi

# List version
versionCheck

# Download DMG file into tmp dir (60 second timeout)
echo "Starting download"
tryDownloadState=0
tryDownloadCounter=0
while [[ ${tryDownloadState} -eq 0 && ${tryDownloadCounter} -le 60 ]]; do
  processCheck
  createTmpDir
  tryDownload
  sleep 1
done

# Check for successful download
if [[ ! -f "${tmpDir}/${dmgName}" ]]; then
  echo "Download unsuccessful"
  cleanup
  exit 1
fi

# Mount DMG file
if hdiutil attach "${tmpDir}/${dmgName}" -nobrowse -quiet; then
  echo "Mounted DMG"
else
  echo "Failed to mount DMG"
  cleanup
  exit 1
fi

# Check for expected DMG path
if [[ ! -d "${dmgVolumePath}" ]]; then
  echo "Could not locate ${dmgVolumePath}"
  cleanup
  exit 1
fi

# Install package
echo "Starting install"
installer -pkg "${dmgVolumePath}/${pkgName}" -target /

# Remove tmp dir and downloaded DMG file
cleanup

# List version and exit with an error code if not found
versionCheck
if [[ ${versionCheckStatus} -eq 0 ]]; then
  exit 1
fi
