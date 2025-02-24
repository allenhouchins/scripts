# scripts
A collection of scripts that you should probably test at least 343 times before running in production.

<hr>

**create_local_file_from_okta_attributes.sh**
> Create a local plist file from attributes gathered through Okta's API. 

**find_casks_all.sh**
> Output a list of all homebrew casks and the URL they use for downloading packages.

**find_casks_pkg.sh**
> Output a list of all homebrew casks that use a URL that downloads a native macOS pkg. 

**get_app_version.sh**
> Output the latest version of an app based on homebrew data.

**get_latest_google_chrome_for_macos.sh**
> Output the latest version of Google Chrome. 

**get_latest_macos_n-1.sh**
> Retrives that latest available version for macOS (n-1).

**google_chrome_macos_policy_updater.sh**
> Automates updating a Fleet policy used to ensure Macs are running the latest version of Google Chrome.

**mac-uninstall-microsoft-edge.sh**
> This script removes Microsoft Edge for Mac and all it's related files.

**remove_jamf.sh**
> Removes Jamf from a macOS device.

**santactl-block-script.sh**
> A script that can be used to manage santa via santactl by simply adding additonal SHA-256 identifiers to the array.