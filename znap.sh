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
# TODO: let sudo be sudo and zfs be zfs
sudo=''
zfs='echo'
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
    target_regex="$1"
    # We shall only output what matches the regexp
    full_log=$(read_log)
    user_wants_to_see_this_entry=false
    # implementation detail: https://stackoverflow.com/a/12919766/2550406
    #    According to the POSIX spec for the read command, it should return a nonzero status if "End-of-file was detected or an error occurred." Since EOF is detected as it reads the last "line", it sets $line and then returns an error status, and the error status prevents the loop from executing on that last "line". The solution is easy: make the loop execute if the read command succeeds OR if anything was read into $line.
    # that's why I have that "|| [ -n "$line" ]" part in the loop condition
    while IFS= read -r line || [ -n "$line" ]; do
        # if line begins with whitespace, it is part of the current line
        # if it doesn't begin with whitespace, it is a new entry
        
        # if line begins with whitespace, print it iff we are currently in an entry the user wants to see
        if grep -Eq "^\s" < <(printf '%s' "$line"); then 
            if $user_wants_to_see_this_entry; then echo "$line"; fi
        else
            # in this case the line is the start of a new entry
            user_wants_to_see_this_entry=false
            if grep -Eq "$target_regex" < <(printf '%s' "$line"); then
                user_wants_to_see_this_entry=true
                echo "$line"
            fi
        fi
    done < <(printf '%s' "$full_log")
}

# $1: snapshot like "tank/ds1@beforeDefcon123"
# returns 0 if snapshot exists, otherwise 1
zfs_snapshot_exists(){
    if $zfs get compression "$1"; then
        return 0
    else
        return 1
    fi
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
            set_r=1
            ;;
        R)
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
        if [[ $verbosity -gt 0 ]] ; then
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

# store the commit messages first, so that they will be part of the snapshots
# create log dir 
$sudo mkdir -p "${ZNAPLOGFILEDIR}"
$sudo touch "${ZNAPLOGFILE}"
snapshotpath="$target$SUFFIX"
logfilepath=$(merge_paths "$ZNAPLOGFILEDIR" "$ZNAPLOGFILE")

# log a few things to stdout
if [[ $verbosity -gt 0 ]] ; then
    echo -e "message:\t$commit_message"
    echo -e "target:\t\t$target"
    echo -e "suffix:\t\t$SUFFIX"
fi
if [[ $verbosity -gt 1 ]] ; then
    echo -e "logfile:\t$logfilepath"
fi

# verify that the snapshot does not exist yet
if zfs_snapshot_exists "$snapshotpath"; then
    echo -e "snapshot $snapshotpath already exists! Aborting!"
    exit 3
fi

# store the commit message to file
znaplog "$snapshotpath" "$commit_message"

# actually perform the snapshot
# recursively, if that is not explicitly disallowed by the user
r_flag='-r'
if $set_R ; then
    r_flag=''
fi
succ=$sudo $zfs snapshot "$r_flag" "$snapshotpath"

if ! $succ; then
    echo -e "something went wrong while calling zfs to actually create the snapshot."
    echo -e "The commit message was stored in the logfile. But no guarantees about the zfs state!"
fi
