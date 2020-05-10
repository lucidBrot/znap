#!/bin/bash
# (c) LucidBrot 2020
set -e

# --- Customizable Options
ZNAPLOGFILE='/opt/znap/messages.txt'            # where the logs are stored
SUFFIX='@'`date +\%y\%m\%d\%H\%M`               # see `man date` for format or provide any other suffix
DEFAULT_DATASET='tank/ds1'                      # set to target dataset to take snapshot of
RECURSIVE=1                                     # set to 0 if you want a non-recursive snapshot

# --- Functions ---

usage(){
# cat << EOF  means that cat sould stop reading when EOF is detected
cat << EOF
Usage:
    znap -t tank/DATASET -m "COMMIT_MESSAGE"        creates a snapshot
        [-q]                                        quiet
EOF
}

# ---- Parsing ----

if [ -z "$1" ];
then
    usage
    exit 1
fi

verbosity=1
while getopts ":t:hm:q" arg; do
    case $arg in
        t)
            target=${OPTARG}
            ;;
        m)
            commit_message=${OPTARG}
            ;;
        q)
            verbosity=0
            ;;
        h | *)
            usage
            exit 0
            ;;
    esac
done

if [ -z "$target" ] || [ -z "$commit_message" ]; then
    if [[ -z "$target" && ! -z "$commit_message" ]]; then
        echo "You failed to specify a -t target."
    fi
    if [[ ! -z "$target" && -z "$commit_message" ]]; then
        echo "You failed to specify a -m message."
    fi

    usage
    exit 1
fi

# create log dir
sudo mkdir -p 
# --- Snapshot Creation ---
if [[ $verbosity > 0 ]] ; then
    echo -e "commit message:\t$commit_message"
    echo -e "target:\t\t$target"
fi

sudo zfs snapshot 
