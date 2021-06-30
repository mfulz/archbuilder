## SYNOPSIS
  
__archbuilder__ is a wrapper for makepkg which uses [buildah](https://buildah.io/) containers
to run the working makepkg.
This will lead to a clean host system and reproduceble builds for the packages.

__archbuilder__ works great together with [aurutils](https://github.com/AladW/aurutils) to have 
a great [Arch User Repository](https://wiki.archlinux.org/index.php/Arch_User_Repository) toolset.
  
## INSTALLATION

Install the following packages:

* [`archbuilder`](https://aur.archlinux.org/packages/archbuilder)

and optional aurutils:
* [`aurutils`](https://aur.archlinux.org/packages/aurutils)

## CONFIGURATION

The base configuration file is located under /etc/archbuilder/archbuilder.env and includes the following settings:

* ARCHBUILDER_BASE_DIR="${HOME}/.archbuilder"
> This is the base dir, which will used by archbuilder to store working files
* ARCHBUILDER_IMAGE_NAME="archbuilder"
> The name of the buildah image to be used for building packages
* ARCHBUILDER_CACHE_REPO="${ARCHBUILDER_BASE_DIR}/crepo"
> The cache repository for the containers. This repository will be used
> by the containers to fetch the builded packages as dependencies.
> Every builded package by archbuilder will be added to this repository
* ARCHBUILDER_LOG_PATH="${ARCHBUILDER_BASE_DIR}/logs"
> Log directory. This is used to store logfiles when ARCH_BUILDER_LOG_TO_FILE is set.
* ARCHBUILDER_LOG_TO_FILE=1
> If logs should be written to files
* LOG_LEVEL_STDOUT="INFO"
> The log level to be used for stdout. Possible values are "DEBUG", "INFO", "WARNING", "SUCCESS", "ERROR"
* LOG_LEVEL_LOG="INFO"
> The log level to be used for logging to file. Possible values are "DEBUG", "INFO", "WARNING", "SUCCESS", "ERROR"

## USAGE

Basic usage will be just to run archbuilder inside a folder with a PKGBUILD file.
It will replace makepkg for the build process by using buildah.

    archbuilder
    
If you want to pass flags to makepkg from archbuilder just hand them over after two dashes:

    archbuilder -- --syncdeps

For a list of possible arguments just use the help flag:

    archbuilder --help
    
## SETUP WITH AURUTILS

Create a user or grant your user the permissions to run buildah via subuid and subgid for a more detailed documentation check the [wiki](https://wiki.archlinux.org/title/Buildah):

    /etc/subuid
    youruser:100000:65536
    
    /etc/subgid
    youruser:100000:65536
    
Create a repository, that is owned by this user for using [aurutils](https://github.com/AladW/aurutils):

    mkdir /var/cache/pacman/myrepo
    chown -R youruser: /var/cache/pacman/myrepo
    sudo -u youruser repo-add /var/cache/pacman/myrepo/myrepo.db.tar.gz
    
    /etc/pacman.d/myrepo:
    [myrepo]
    SigLevel = Optional TrustAll
    Server = file:///var/cache/pacman/myrepo
    
    /etc/pacman.conf
    Include = /etc/pacman.d/myrepo
    
    pacman -Sy
    
To use now archbuilder as building backend inside aurutils, just add the following to your shell:

    export MAKEPKG="/usr/bin/archbuilderwrap"
    
This script will wrap everything correct to archbuilder and run the makepkg inside the buildah container.

You can add custom parameters to the wrapper script by setting the variable ARCHBUILDER_FLAGS.