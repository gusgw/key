#! /bin/bash

# Thanks to . . .
# https://linuxconfig.org/how-to-backup-gpg-keys-on-paper
# https://www.jabberwocky.com/software/paperkey/

TYPE=$1
KEY=$2

UNKNOWN_KEY_TYPE=90
TRAPPED_SIGNAL=113

function set_stamp {
    # Store a stamp used to label files
    # and messages created in this script.
    export STAMP="$(date '+%Y%m%d'-$(hostnamectl hostname))"
    return 0
}

function cleanup {
    local rc=$1
    >&2 echo "${STAMP}: exiting cleanly with code ${rc}. . ."
    rm -f short.txt
    rm -f key.txt
    rm -f key.gpg
    rm -f key.asc
    rm -f key.png
    rm -f key-*
    rm -f *.aux
    rm -f *.log
    >&2 echo "${STAMP}: . . . all done with code ${rc}"
    exit $rc
}

function report {
    # Inform the user of a non-zero return
    # code, cleanup and exit if an exit
    # message is provided as a third argument
    local rc=$1
    local description=$2
    local exit_message=$3
    >&2 echo "${STAMP}: ${description} exited with code $rc"
    if [ -z "$exit_message" ]; then
        >&2 echo "${STAMP}: continuing . . ."
    else
        >&2 echo "${STAMP}: $exit_message"
        cleanup $rc
    fi
    return $rc
}

function generate_paper_rsa4096 {
    local keyid=$1

    local split_size=900

    echo '```' > short.txt
    gpg --list-secret-keys --fingerprint ${keyid} >> short.txt ||\
        report $? "get description of key" 
    echo '```' >> short.txt

    gpg --export-secret-key "$keyid" > key.gpg ||\
        report $? "export secret key"

    echo '```' > key.txt    
    paperkey --secret-key=key.gpg >> key.txt ||\
        report $? "save text version of key"
    echo '```' >> key.txt

    gpg --armor \
        --export-secret-key \
        --output key.asc \
        "${keyid}" ||\
        report $? "export secret key with ascii armor"

    split -C "${split_size}" key.asc key- ||\
        report $? "split key into chunks"

    for k in key-*; do 
        qrencode -o "${k}.png" < "${k}" ||\
            report $? "encode ${k}"
    done

    for k in key-*.png; do
        convert "${k}" "${k/png/pdf}" ||\
            report $? "convert ${k}"
    done

    quarto render rsa4096.qmd --to pdf ||\
        report $? "render paper version of key"

    mv rsa4096.pdf key.pdf ||\
        report $? "rename to key.pdf"

    return
}

function generate_paper_ed25519 {
    local keyid=$1

    local split_size=900

    echo '```' > short.txt
    gpg --list-secret-keys --fingerprint ${keyid} >> short.txt ||\
        report $? "get description of key" 
    echo '```' >> short.txt

    gpg --export-secret-key "$keyid" > key.gpg ||\
        report $? "export secret key"

    echo '```' > key.txt    
    paperkey --secret-key=key.gpg >> key.txt ||\
        report $? "save text version of key"
    echo '```' >> key.txt

    gpg --armor \
        --export-secret-key \
        --output key.asc \
        "${keyid}" ||\
        report $? "export secret key with ascii armor"

    qrencode -o key.png < key.asc ||\
        report $? "encode ${k}"

    convert key.png key.pdf

    quarto render ed25519.qmd --to pdf ||\
        report $? "render paper version of key"

    mv ed25519.pdf key.pdf ||\
        report $? "rename to key.pdf"

    return
}

function handle_signal {
    # cleanup and use error code if we trap a signal
    >&2 echo "${STAMP}: trapped signal during maintenance"
    cleanup "${TRAPPED_SIGNAL}"
}

# Start by setting a handler for signals that stop work
trap handle_signal 1 2 3 6

# Set a stamp for use in messages and file names
set_stamp

source ${CONDAETC}/profile.d/conda.sh
conda activate write

if [ "$TYPE" == 'rsa4096' ]; then
    generate_paper_rsa4096 "$KEY"    
else 
    if [ "$TYPE" == 'ed25519' ]; then
        generate_paper_ed25519 "$KEY"
    else
        cleanup "$UNKNOWN_KEY_TYPE"
    fi
fi

mv key.pdf "${KEY::10}.pdf" ||\
    report $? "rename the pdf of ${KEY}"

cleanup 0
