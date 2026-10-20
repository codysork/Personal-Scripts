#!/bin/sh
# @file install.sh
# @author Cody Sork <codysork@gmail.com>
# @created 2026-10-20
# @modified 2026-10-20
# @description Uninstalls all scripts in this directory

#------------------------------------------------------------------------------#
#                             Script Variables                                 #
#------------------------------------------------------------------------------#

DRY_RUN=0

#------------------------------------------------------------------------------#
#                                Functions                                     #
#------------------------------------------------------------------------------#

#------------------------------------------------------------------------------#
#                                  Main                                        #
#------------------------------------------------------------------------------#


# Command line options
for i in "$@"
do
case $i in
    --dry-run)
        DRY_RUN=1
        shift
        ;;
    -h|--help)
        echo "Usage: ./uninstall.sh"
        exit 0
        ;;
    *)
        echo "Invalid option $i"
        exit 1
        ;;
esac
done

# Require root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root"
    exit 1
fi


# Get file from all nested directories in this directory
for directory in $(ls -d */); do
    for file in $(ls $directory); do
        if [ "$file" != "uninstall.sh" ]; then
            if [ "$DRY_RUN" -eq 0 ]; then
                echo "Uninstalling $file"
                rm $directory/$file
            else
                echo "Would uninstall $file"
            fi
        fi
    done
done
