#!/bin/bash
# (c) LucidBrot 2020
set -e

# --- Customizable Options ---
ZNAPLOGFILE='.znap_log'                         # where the logs are stored
SUFFIX='@'`date +\%y\%m\%d\%H\%M`               # see `man date` for format or provide any other suffix
DEFAULT_DATASET='tank/ds1'                      # set to target dataset to take snapshot of

# --- Programming Options ---
# set to sudo when used on a platform that has sudo
sudo=''
SEP='\t'
BIGSEP='\n'

# --- Functions ---

usage(){
# cat << EOF  means that cat sould stop reading when EOF is detected
cat << EOF

Usage:
    znap [-t tank/DATASET] -m "COMMIT_MESSAGE"       creates a snapshot
         [-q]                                        quiet
         [-r/-R]                                     recursive (default) / not recursive
EOF
}

# $1: The target dataset full path
# $2: The message
znaplog(){
echo -e >>"${ZNAPLOGFILE}" "$1$SUFFIX$SEP$2$BIGSEP"
}

# ---- Parsing ----

if [ -z "$1" ];
then
    usage
    exit 1
fi

verbosity=2
recursiveness=1
while getopts ":t:hm:qrR" arg; do
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
        r)
            recursiveness=1
            set_r=1
            ;;
        R)
            recursiveness=0
            set_R=1
            ;;
        h | *)
            usage
            exit 0
            ;;
    esac
done

# verify that target and message are set
if [ -z "$target" ] || [ -z "$commit_message" ]; then
    if [[ -z "$target" && ! -z "$commit_message" ]]; then
        if [[ $verbosity > 0 ]] ; then
            echo "Defaulting to dataset ${DEFAULT_DATASET} because you did not specify a -t target."
        fi
        target=${DEFAULT_DATASET}
    fi
    if [[ ! -z "$target" && -z "$commit_message" ]]; then
        echo "You failed to specify a -m message."
        usage
        exit 1
    fi
fi

# verify that only one of -r -R are set
if [[ ! -z $set_r && ! -z $set_R ]]; then
    echo "You can only choose -r or -R, not both."
    usage
    exit 1
fi

# --- Snapshot Creation ---
if [[ $verbosity > 1 ]] ; then
    echo -e "message:\t$commit_message"
    echo -e "target:\t\t$target"
    echo -e "suffix:\t\t$SUFFIX"
fi

# store the commit messages first, so that they will be part of the snapshots
# create log dir # TODO: place the logs actually in the dataset roots
$sudo mkdir -p "./"
$sudo touch "${ZNAPLOGFILE}"
datasetpath="$target"
znaplog "$datasetpath" "$commit_message"


#sudo zfs snapshot 
#TODO: actually run the snapshot
