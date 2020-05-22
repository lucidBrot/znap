#!/bin/bash
# (c) LucidBrot 2020
set -e

# --- Customizable Options ---
ZNAPLOGFILEDIR='./'                             # where the logs are stored (directory)
ZNAPLOGFILE='.znap_log'                         # where the logs are stored (file)
                                                # ==> they will be stored at directory/file
SUFFIX='@'`date +\%y\%m\%d\%H\%M`               # see `man date` for format or provide any other suffix
DEFAULT_DATASET='tank/ds1'                      # set to target dataset to take snapshot of when no -t is given

# --- Programming Options ---
# set to sudo when used on a platform that has sudo
# TODO: let sudo be sudo
sudo=''
SEP='\t'
LINESEP='\n'
BIGSEP='\n'
MSGWIDTH=52

# --- Functions ---

usage(){
# cat << EOF  means that cat sould stop reading when EOF is detected
cat << EOF

Usage:
    znap [-t tank/DATASET] -m "COMMIT_MESSAGE"       creates a snapshot
         [-q]                                        quiet
         [-r/-R]                                     recursive (default) / not recursive
         [-f tank/DATASET@today]                     full snapshot name. Replaces -t and the suffix
         [-i SOMETHING]                              infix ==> tank/DATASET@SOMETHING200522
                                                     i.e. target@infix+suffix
                                                     cannot be used with -f

    znap log                                         outputs stored commit messages
EOF
}

# $1: The target dataset full path including suffix
# $2: The message
# 
# The stored output is for viewing with `column -t -s$'\t' <.znap_log`
znaplog(){
    the_message=$2
    # split the message on user-set newlines so that they will remain. Prefix each of them with a tab character.
    # That includes the first line, so we will later have to remove that again.
    splitted_msg_with_initial_tab=$(echo "$the_message" | tr '\n' '\0' | xargs -0 -n1 echo $'\t')
    splitted_msg=${splitted_msg_with_initial_tab#?}
    msg_as_lines=$(echo "$splitted_msg" | sed -r "s/(.{$MSGWIDTH})/\1$LINESEP$SEP/g")
    echo -e "$1$SEP$msg_as_lines$BIGSEP" | $sudo tee -a "${ZNAPLOGFILE}" >/dev/null
}

# $1: list of paths like this:
#     parts=("/etc", "znap", "file/")
merge_paths(){
    args=("$@")
    ret="$(printf '%s/' "${args[@]%/}")"
    # https://unix.stackexchange.com/a/23213/66736
    # if this magic is not cool, you could also just add a slash between each input part.
    # Because /etc/znap/file/ and /etch//znap/////file are the same.
    # What this magic does is use printf to remove any trailing slashes from each part,
    # then append one.

    # remove last trailing slash
    echo "${ret%/}"
}

read_log(){
    logfile=$(merge_paths "$ZNAPLOGFILEDIR" "$ZNAPLOGFILE")
    column -t -s$'\t' <"${logfile}"
    # could use -L flag to keep empty lines.
}

# if called without argument, equivalent to read_log
# otherwise the first argument is a regular expression to filter the affected datasets
read_advanced_log(){
    if [[ -z $1 ]]; then
        read_log
        return
    fi
    
    # there is an argument.
    # We shall only output what matches the regexp
    full_log=$(read_log)
    while IFS= read -r line; do
        # if line begins with whitespace
        if printf '%s' "$line" | grep -Eq "^\s"; then echo "$line"; fi;
            # TODO: skip the lines that we don't want
        done < <(printf '%s' "$full_log")

}

# ---- Parsing ----

if [ -z "$1" ];
then
    usage
    exit 1
fi

if [[ "x$1" = "xlog" ]]; then
    read_advanced_log $2
    exit 0
fi

verbosity=2
recursiveness=1
while getopts "t:m:f:i:qrRh" arg; do
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
        f)
            fullpath=${OPTARG}
            ;;
        i)
            infix=${OPTARG}
            ;;
        h | *)
            usage
            exit 1
            ;;
    esac
done

# if fullpath is set, don't allow clashing flags
if [[ ! -z "$fullpath" ]]; then
    if [[ ! -z "$target" ]]; then
        echo "You can't use -t when already using -f."
        usage
        exit 1
    fi
    if [[ ! -z "$infix" ]]; then
        echo "You can't use -i when already using -f."
        usage
        exit 1
    fi
fi

# set target and suffix based on fullpath so that the remaining code flows don't need to be modified
if [[ ! -z "$fullpath" ]]; then
    target="$fullpath"
    SUFFIX=""
fi

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

# if -i set an infix, we want to plant that at the start of the SUFFIX, right after the '@'
if [[ ! -z "$infix" ]]; then
    SUFFIX="@$infix${SUFFIX#'@'}"
fi

# --- Snapshot Creation ---
# store the commit messages first, so that they will be part of the snapshots
# create log dir 
$sudo mkdir -p "${ZNAPLOGFILEDIR}"
$sudo touch "${ZNAPLOGFILE}"
snapshotpath="$target$SUFFIX"
logfilepath=$(merge_paths "$ZNAPLOGFILEDIR" "$ZNAPLOGFILE")

# log a few things to stdout
if [[ $verbosity > 0 ]] ; then
    echo -e "message:\t$commit_message"
    echo -e "target:\t\t$target"
    echo -e "suffix:\t\t$SUFFIX"
fi
if [[ $verbosity > 1 ]] ; then
    echo -e "logfile:\t$logfilepath"
fi

# store the commit message to file
znaplog "$snapshotpath" "$commit_message"

# actually perform the snapshot
# recursively, if that is not explicitly disallowed by the user
r_flag='-r'
if [[ recursiveness = 0 ]]; then
    r_flag=''
fi
$sudo zfs snapshot $r_flag $snapshotpath
#TODO: see log of only one dataset.
#TODO: handle case when snapshot already exists.
