#!/bin/bash
#
# Quick check to make sure all the listed nameservers for a given domain
# serve up data for that domain.  Later will have an option to make sure
# all nameservers have the same serial number for the domain (difficult
# given propagation time) and check for a specific record
#
# Output formatted for use as a Nagios plugin

DIG=/usr/bin/dig
checktype=soa

if [[ -z "$1" ]] ; then
    echo "UNKNOWN: Usage: $0 domain-to-check"
    exit 3
fi

hosttocheck="$1"

# Get the list of nameservers for the domain
nslist=$( ${DIG} ${hosttocheck} ns +short )
if [[ -z "${nslist}" ]] ; then
    echo "CRITICAL: No NS records found for ${hosttocheck}"
    exit 2
fi

errorcount=0
errormessage=""

for nameserver in ${nslist} ; do
    lookup=$( ${DIG} @${nameserver} ${hosttocheck} ${checktype} +short )
    if [[ -z "${lookup}" ]] ; then
        $errorcount++
        errormessage="${errormessage}${nameserver} had no records for ${hosttocheck}\n"
    fi
done

if [[ ${errorcount} -gt 0 ]] ; then
    echo "CRITICAL: Not all nameservers for ${hosttocheck} had a ${checktype}"
    echo $'${errormessage}'
    exit 2
fi

echo "OK: All nameservers listed a ${checktype} for ${hosttocheck}"
exit 0
