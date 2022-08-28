# Build PowerShell on macOS

Building PowerShell requires macOS 10.13 (High Sierra) or newer.
Both Apple Silicon (osx-arm64) and Intel (osx-x64) macs are supported using the same process detailed below.

The build process for macOS is almost identical to the [build process for Linux](./linux.md), documentation for Linux may be applicable to macOS.

## Environment

We use the [.NET Command-Line Interface](https://docs.microsoft.com/dotnet/core/tools/) (`dotnet`) to build PowerShell, this document covers building using the `Start-PSBuild` PowerShell function from our [PowerShell module](../../build.psm1).

With the exception of Git the entire toolchain installation is scripted using the `Start-PSBootstrap` function of the same module.

Required:

- [PowerShell](https://github.com/PowerShell/PowerShell)
- [.NET Core SDK](https://docs.microsoft.com/dotnet/core/sdk)
- [.NET Command-Line Interface](https://docs.microsoft.com/dotnet/core/tools/) (`dotnet`)
- [GNU WGet](https://github.com/gitGNU/gnu_wget)
- [OpenSSL](https://github.com/openssl/openssl)
- [Git](https://git-scm.com/downloads)

Recommended:

- [Homebrew](https://brew.sh/) or [MacPorts](https://www.macports.org/)
    - _These package managers are used to automate installing the toolchain, you may install packages manually_
    - _If you have MacPorts installed installing PowerShell manually is recommended, the included install script for PowerShell will install Homebrew if not found. This may cause a conflict._

### Git setup

Before building you must recursively clone the PowerShell repository and `cd` into that folder.

Refer to the [Working with the PowerShell Repository](../git/README.md),
[README](../../README.md), and [Contributing Guidelines](../../.github/CONTRIBUTING.md) for additional guidance on using Git.

### Toolchain setup

Installing the toolchain is as easy as running `Start-PSBootstrap` in PowerShell to automate the process using either [Homebrew](https://brew.sh/) or [MacPorts](https://www.macports.org/).
Of course, this requires a self-hosted copy of PowerShell on macOS.

#### Installing PowerShell

The `./tools/install-powershell.sh` script will install PowerShell using Homebrew or a cURL into `installer` if MacPorts is installed.
If neither Homebrew or MacPorts is installed the script will install Homebrew.

```sh
./tools/install-powershell.sh

pwsh
```

The argument `installide` will install [VS Code](https://github.com/microsoft/vscode) using Homebrew if it is installed.

For manual binary installaton assistance, reer to these [instructions](https://docs.microsoft.com/powershell/scripting/install/installing-powershell-on-macos?#binary-archives).

#### Installing the rest of the toolchain

Once PowerShell is installed, run `pwsh` to enter PowerShell and then:

```powershell
Import-Module ./build.psm1

Start-PSBootstrap
```

The `Start-PSBootstrap` function does the following:

- Uses `brew` or `port` to install OpenSSL, and GNU WGet
- Uninstalls any prior versions of .NET CLI
- Downloads and installs .NET Core SDK to `~/.dotnet`

If you want to use `dotnet` outside of `Start-PSBuild`,
add `~/.dotnet` to your `PATH` environment variable.

### Troubleshooting environment setup errors

#### error: Too many open files

Due to a [bug][809] in NuGet, the `dotnet restore` command will fail without the limit increased.
Run `ulimit -n 2048` to fix this in your session;
add it to your shell's profile to fix it permanently.

We cannot do this for you in the build module due to #[847][].

[809]: https://github.com/dotnet/cli/issues/809
[847]: https://github.com/PowerShell/PowerShell/issues/847

#### error: VERBOSE: Failed to restore

#### error MSB3073: The command "git describe --abbrev=60 --long" exited with code 128

Git is not properly configured or you are in the wrong directory.

You _must_ recursively clone the PowerShell repository.

```sh
git clone --recurse-submodules -j8 https://github.com/PowerShell/PowerShell.git --branch=master

cd ./PowerShell/
```

## Build using our module

If you've just ran `Start-PSBootstrap` you can immediately run `Start-PSBuild`.

Otherwise, start a PowerShell session by running `pwsh` and then:

```powershell
Import-Module ./build.psm1

Start-PSBuild
```

Congratulations! If everything went right, PowerShell is now built.

The `Start-PSBuild` script will output the location of the executable, this should be:

|Architecture|Location|
|-|-|
|arm64 (Apple Silicon)| `./src/powershell-unix/bin/Debug/net7.0/osx-arm64/publish/pwsh` |
|x64 (Intel)| `./src/powershell-unix/bin/Debug/net7.0/osx-x64/publish/pwsh` |

### Cross-Compiling

It is possible to cross-compile by setting the `-runtime` flag to the architecture you'd like to compile for.
For example, while on an arm64 (Apple Silicon) mac, running `Start-PSBuild -runtime osx-x64` will build PowerShell for Intel macs.
