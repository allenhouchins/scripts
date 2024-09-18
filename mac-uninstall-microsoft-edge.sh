#!/bin/sh
# This script removes Microsoft Edge for Mac and all it's related files

# Get currently logged in user
currentUser="$(/usr/bin/defaults read /Library/Preferences/com.apple.loginwindow.plist lastUserName)"

# Unload any related LaunchAgents or LaunchDaemons
launchagents_list=(
 "/Users/$currentUser/Library/LaunchAgents/com.microsoft.EdgeUpdater.update.plist"
 "/Users/$currentUser/Library/LaunchAgents/com.microsoft.EdgeUpdater.update-internal.*"
 "/Users/$currentUser/Library/LaunchAgents/com.microsoft.EdgeUpdater.wake.*"
)

for path in "${launchagents_list[@]}"; do
  if [ -e "$path" ]; then
    /bin/launchctl bootout system "$path"
    echo "Unloaded: $path"
  else
    echo "Agent not running: $path"
fi
done


# Delete all files and folders
delete_list=(
 "/Users/$currentUser/Library/Application Scripts/com.microsoft.edgemac.wdgExtension"
 "/Users/$currentUser/Library/Application Support/Microsoft Edge"
 "/Users/$currentUser/Library/Application Support/Microsoft/EdgeUpdater"
 "/Users/$currentUser/Library/Caches/com.microsoft.edgemac"
 "/Users/$currentUser/Library/Caches/com.microsoft.EdgeUpdater"
 "/Users/$currentUser/Library/Caches/Microsoft Edge"
 "/Users/$currentUser/Library/Containers/com.microsoft.edgemac.wdgExtension"
 "/Users/$currentUser/Library/HTTPStorages/com.microsoft.edgemac"
 "/Users/$currentUser/Library/HTTPStorages/com.microsoft.edgemac.binarycookies"
 "/Users/$currentUser/Library/HTTPStorages/com.microsoft.EdgeUpdater"
 "/Users/$currentUser/Library/LaunchAgents/com.microsoft.EdgeUpdater.update.plist"
 "/Users/$currentUser/Library/LaunchAgents/com.microsoft.EdgeUpdater.update-internal.*"
 "/Users/$currentUser/Library/LaunchAgents/com.microsoft.EdgeUpdater.wake.*"
 "/Users/$currentUser/Library/Microsoft/EdgeUpdater"
 "/Users/$currentUser/Library/Preferences/com.microsoft.edgemac.plist"
 "/Users/$currentUser/Library/Saved Application State/com.microsoft.edgemac.app.*"
 "/Users/$currentUser/Library/Saved Application State/com.microsoft.edgemac.savedState"
 "/Users/$currentUser/Library/WebKit/com.microsoft.edgemac"
 "/Library/Application Support/Microsoft"
 "/Applications/Microsoft Edge.app"
)

for path in "${delete_list[@]}"; do
  if [ -e "$path" ]; then
    /bin/rm -rf "$path"
    echo "Deleted: $path"
  else
    echo "File or folder not found: $path"
fi
done

# Forget package
/usr/sbin/pkgutil --forget com.microsoft.edgemac

exit 0