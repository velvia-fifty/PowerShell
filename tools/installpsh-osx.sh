#!/bin/bash

#Companion code for the blog https://cloudywindows.com
#call this code direction from the web with:
#bash <(wget -O - https://raw.githubusercontent.com/PowerShell/PowerShell/master/tools/installpsh-osx.sh) ARGUMENTS
#bash <(curl -s https://raw.githubusercontent.com/PowerShell/PowerShell/master/tools/installpsh-osx.sh) <ARGUMENTS>

#Usage - if you do not have the ability to run scripts directly from the web,
#        pull all files in this repo folder and execute, this script
#        automatically prefers local copies of sub-scripts

#Completely automated install requires a root account or sudo with a password requirement

#Switches
# -includeide         - installs vscode and vscode PowerShell extension (only relevant to machines with desktop environment)
# -interactivetesting - do a quick launch test of vscode (only relevant when used with -includeide)
# -preview            - installs the latest preview release of PowerShell side-by-side with any existing production releases

#gitrepo paths are overrideable to run from your own fork or branch for testing or private distribution


VERSION="1.1.3"
gitreposubpath="PowerShell/PowerShell/master"
gitreposcriptroot="https://raw.githubusercontent.com/$gitreposubpath/tools"
thisinstallerdistro=osx
repobased=true
gitscriptname="installpsh-osx.sh"
powershellpackageid=powershell

echo "*** PowerShell Development Environment Installer $VERSION for $thisinstallerdistro"
echo "***    Original script is at: $gitreposcriptroot/$gitscriptname"
echo "*** Arguments used: $*"

# Let's quit on interrupt of subcommands
trap '
  trap - INT # restore default INT handler
  echo "Interrupted"
  kill -s INT "$$"
' INT

#Verify The Installer Choice (for direct runs of this script)
lowercase(){
    echo "$1" | tr "[:upper:]" "[:lower:]"
}

OS=$(lowercase "$(uname)")
if [ "${OS}" == "windowsnt" ]; then
    OS=windows
    DistroBasedOn=windows
elif [ "${OS}" == "darwin" ]; then
    OS=osx
    DistroBasedOn=osx
else
    OS=$(uname)
    if [ "${OS}" == "SunOS" ] ; then
        OS=solaris
        DistroBasedOn=sunos
    elif [ "${OS}" == "AIX" ] ; then
        DistroBasedOn=aix
    elif [ "${OS}" == "Linux" ] ; then
        if [ -f /etc/redhat-release ] ; then
            DistroBasedOn='redhat'
        elif [ -f /etc/system-release ] ; then
            DIST=$(sed s/\ release.*// < /etc/system-release)
            if [[ $DIST == *"Amazon Linux"* ]] ; then
                DistroBasedOn='amazonlinux'
            else
                DistroBasedOn='redhat'
            fi
        elif [ -f /etc/SuSE-release ] ; then
            DistroBasedOn='suse'
        elif [ -f /etc/mandrake-release ] ; then
            DistroBasedOn='mandrake'
        elif [ -f /etc/debian_version ] ; then
            DistroBasedOn='debian'
        fi
        if [ -f /etc/UnitedLinux-release ] ; then
            DIST="${DIST}[$( (tr "\n" ' ' | sed s/VERSION.*//) < /etc/UnitedLinux-release )]"
            DistroBasedOn=unitedlinux
        fi
        OS=$(lowercase "$OS")
        DistroBasedOn=$(lowercase "$DistroBasedOn")
    fi
fi

if [ "$DistroBasedOn" != "$thisinstallerdistro" ]; then
  echo "*** This installer is only for $thisinstallerdistro and you are running $DistroBasedOn, please run \"$gitreposcriptroot\install-powershell.sh\" to see if your distro is supported AND to auto-select the appropriate installer if it is."
  exit 1
fi

## Check requirements and prerequisites

echo "*** Installing PowerShell for $DistroBasedOn..."

if [[ "'$*'" =~ preview ]] ; then
    echo
    echo "-preview was used, the latest preview release will be installed (side-by-side with your production release)"
    powershellpackageid=powershell-preview
fi

if ! hash brew 2>/dev/null; then
    if ! hash port >/dev/null; then
        echo "Neither Homebrew or MacPorts found, installing Homebrew..."
        ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" < /dev/null 2> /dev/null
    else
        echo "MacPorts is installed, skipping Homebrew install..."
        usemacports=1
else
    echo "Homebrew is already installed, skipping..."
fi

# check if MacPorts is installed before doing Homebrew specific things
if [ $usemacports != 1 ] ; then
    if ! hash brew 2>/dev/null; then
        echo "ERROR: brew did not install correctly, exiting..." >&2
        exit 3
    fi

    # Suppress output, it's very noisy on Azure DevOps
    echo "Refreshing Homebrew cache..."
    for count in {1..2}; do
        # Try the update twice if the first time fails
        brew update > /dev/null && break

        # If the update fails again after increasing the Git buffer size, exit with error.
        if [[ $count == 2 ]]; then
            echo "ERROR: Refreshing Homebrew cache failed..." >&2
            exit 2
        fi

        # The update failed for the first try. An error we see a lot in our CI is "RPC failed; curl 56 SSLRead() return error -36".
        # What 'brew update' does is to fetch the newest version of Homebrew from GitHub using git, and the error comes from git.
        # A potential solution is to increase the Git buffer size to a larger number, say 150 mb. The default buffer size is 1 mb.
        echo "First attempt of update failed. Increase Git buffer size and try again ..."
        git config --global http.postBuffer 157286400
        sleep 5
    done
fi

if ! hash pwsh 2>/dev/null; then
    echo "Installing PowerShell..."
    # Check if we're using Homebrew
    if [ $usemacports != 1 ] ; then
        if ! brew install ${powershellpackageid} --cask; then
            echo "ERROR: PowerShell failed to install! Cannot install powershell..." >&2
        fi
    else
        # We're using MacPorts, so we're going to curl the pkg
        if [ $powershellpackageid -eq powershell-preview ] ; then
            url="https://aka.ms/powershell-release?tag=preview"
        else
            url="https://aka.ms/powershell-release?tag=stable"
        fi
        redirect=$(curl -si $url | grep -i HTTP | head -1 | awk '{print $2}')
        if [[ $redirect -eq  "301" ]] || [[ $redirect -eq  "302" ]]
        then
            #next, follow the rabbit hole of redirects and get the resulting version-specific url
            urlr="$(curl -siL $url | grep -i location: | tail -1 | awk '{print $2}')"
            if [[ $(curl -siL $url | grep -i location: | tail -1 | awk '{print $2}' | cut -d "/" -f 8 | cut -c 1) -eq "v" ]]
            then
                ver=$(curl -siL $url | grep -i location: | tail -1 | awk '{print $2}' | cut -d "/" -f 8 | cut -d "v" -f 2 | sed 's/[[:cntrl:]]//g')
                #determine architecture
                if [[ $(uname -p) -eq "arm" ]]
                then
                    echo "Downloading Apple Silicon Installer"
                    dl=https://github.com/PowerShell/PowerShell/releases/download/v$ver/powershell-$ver-osx-arm64.pkg
                    curl -OsL $dl
                    #verify the download
                    if [[ -f powershell-$ver-osx-arm64.pkg ]]
                    then
                        #pull the hash, convert it to unix, then validate it
                        hashfile=https://github.com/PowerShell/PowerShell/releases/download/v$ver/hashes.sha256
                        curl -OsL $hashfile
                        awk '{ sub("\r$", ""); print }' hashes.sha256 > uhashes.sha256
                        rm hashes.sha256
                        echo "Validating SHA256 Hash"
                        shasum -a 256 --ignore-missing -c uhashes.sha256 -s
                        if [[ $? -eq 0 ]]
                        then
                            echo "$(tput setaf 2)Valid hash \n$(tput setaf 7)"
                            rm uhashes.sha256
                            installer -pkg powershell-$ver-osx-arm64.pkg -target /
                            rm powershell-$ver-osx-arm64.pkg
                        else
                            echo "$(tput setaf 1)\nInvalid hash"
                            shasum -a 256 --ignore-missing -c uhashes.sha256
                            echo "Consult the output above for more infomration"
                            echo "If the file exists as named it does not match what was uploaded by Microsoft"
                            exit 1
                        fi
                    else
                        echo "$(tput setaf 1)Something went wrong downloading the package"
                        echo "Verify $dl loads, you can simply install this package if it does"
                        exit 1
                    fi  
                else
                    echo "Downloading Intel Installer"
                    dl=https://github.com/PowerShell/PowerShell/releases/download/v$ver/powershell-$ver-osx-x64.pkg
                    curl -OsL $dl
                    if [[ -f powershell-$ver-osx-x64.pkg ]]
                    then
                        hashfile=https://github.com/PowerShell/PowerShell/releases/download/v$ver/hashes.sha256
                        curl -OsL $hashfile
                        awk '{ sub("\r$", ""); print }' hashes.sha256 > uhashes.sha256
                        rm hashes.sha256
                        echo "Validating SHA256 Hash"
                        shasum -a 256 --ignore-missing -c uhashes.sha256 -s
                        if [[ $? -eq 0 ]]
                        then
                            echo "$(tput setaf 2)Valid hash \n$(tput setaf 7)"
                            rm uhashes.sha256
                            installer -pkg powershell-$ver-osx-x64.pkg -target /
                            rm powershell-$ver-osx-arm64.pkg
                        else
                            echo "$(tput setaf 1)\nInvalid hash"
                            shasum -a 256 --ignore-missing -c uhashes.sha256
                            echo "Consult the output above for more infomration"
                            echo "If the file exists as named it does not match what was uploaded by Microsoft"
                            exit 1
                        fi
                    else
                        echo "$(tput setaf 1)Something went wrong downloading the package"
                        echo "Verify $dl loads, you can simply install this package if it does"
                        exit 1
                    fi  
                fi
            else
                echo "$(tput setaf 1)Something's wrong with $urlr"
                echo "Verify it ends in /v#.#.#"
                exit 1 
            fi
        else 
            echo "$(tput setaf 1)Something prevented loading $url"
            echo "Verify GitHub loads"
            exit 1
        fi
    fi
else
    echo "PowerShell is already installed, skipping..."
fi

# Check if we're using MacPorts, if so skip over VS Code
if [ $usemacports != 1 ] ; then
    if [[ "'$*'" =~ includeide ]] ; then
        echo "*** Installing VS Code PowerShell IDE..."
        if [[ ! -d $(brew --prefix visual-studio-code) ]]; then
            if ! brew install visual-studio-code --cask; then
                echo "ERROR: Visual Studio Code failed to install..." >&2
                exit 1
            fi
        else
            brew upgrade visual-studio-code
        fi

        echo "*** Installing VS Code PowerShell Extension"
        code --install-extension ms-vscode.PowerShell
        if [[ "'$*'" =~ -interactivetesting ]] ; then
            echo "*** Loading test code in VS Code"
            curl -O ./testpowershell.ps1 https://raw.githubusercontent.com/DarwinJS/CloudyWindowsAutomationCode/master/pshcoredevenv/testpowershell.ps1
            code ./testpowershell.ps1
        fi
    fi
fi

# shellcheck disable=SC2016
pwsh -noprofile -c '"Congratulations! PowerShell is installed at $PSHOME.
Run `"pwsh`" to start a PowerShell session."'

success=$?

if [[ "$success" != 0 ]]; then
    echo "ERROR: PowerShell failed to install!" >&2
    exit "$success"
fi

if [[ "$repobased" == true ]] ; then
  echo "*** NOTE: Run your regular package manager update cycle to update PowerShell"
fi
echo "*** Install Complete"
