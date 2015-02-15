#!/bin/bash
# SVN pre-commit hook to make sure that checked in SSL certs and keys 
# match up.  This is due to some stupidity in Apache wherein it will blow up
# if you load a mismatched SSL key/cert combo for any vhost.
export PATH=/sbin:/bin:/usr/sbin:/usr/bin
REPO="$1"
TXN="$2"
tmpkey=$(mktemp) || exit 1
tmpcert=$(mktemp) || exit 1
export HOME=/
SVNLOOK=/usr/bin/svnlook
FAILCOUNT=0

# get list of changed certs/keys
CHANGES=$( $SVNLOOK changed -t "$TXN" "$REPO" | awk '/^[^D].*\.(key|crt)$/ {print $2}' )
# if a key and cert ended up changing, filter the duplicate out
CHANGES=$( echo "$CHANGES" | sed 's/\.\(key\|crt\)$//' | sort | uniq )

if [ -n "$CHANGES" ] ; then
    while read -r filebasename ; do
        keyfile="${filebasename}.key"
        certfile="${filebasename}.crt"

        # I don't know a good way to see if a file exists in a repo from here
        # so just try to "svnlook cat" it.  If that blows up, I guess it 
        # doesn't?
        $SVNLOOK cat -t "$TXN" "$REPO" "$certfile" > "${tmpcert}" || continue

        $SVNLOOK cat -t "$TXN" "$REPO" "$keyfile" > "${tmpkey}" || continue

        diff <( openssl x509 -noout -modulus -in "${tmpcert}" ) \
             <( openssl rsa -noout -modulus -in "${tmpkey}" ) >/dev/null

        if [ $? -ne 0 ] ; then
            echo "$keyfile and $certfile don't match up" >&2
            FAILCOUNT=$(( FAILCOUNT + 1 ))
        fi
    done < <( echo "$CHANGES" )
fi

rm "${tmpkey}"
rm "${tmpcert}"

exit ${FAILCOUNT}
