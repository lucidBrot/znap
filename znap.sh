#!/bin/bash
# (c) LucidBrot 2020

usage(){
# cat << EOF  means that cat sould stop reading when EOF is detected
cat << EOF
Usage:
    znap -t tank/DATASET -m "COMMIT_MESSAGE"        creates a snapshot
EOF
}

if [ -z "$1" ];
then
    usage
    exit 1
fi

while getopts ":t:hm:" arg; do
    case $arg in
        t)
            target=${OPTARG}
            ;;
        m)
            commit_message=${OPTARG}
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
echo "commit message: $commit_message,\ntarget: $target\n"
