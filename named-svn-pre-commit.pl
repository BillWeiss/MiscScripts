#!/usr/bin/perl
# SVN pre-commit hook to sanity check DNS changes
# Does one thing now:
# 1) If a db.* file is checked in, make sure it changes the serial number
# Todo:
# 2) If a vanity* file is checked in, make sure the serial of 
#    db.backstopsolutions{,.com} is incremented
# 3) If servermappings.txt is checked in, db.backstopsolutions serial number
#    needs to increment
# 4) CNAMEs should either be to local names (no periods) or end in a .
# 5) Use named-checkzone, maybe?  It knows a lot about what a zone file
#    should look like, though we need to derive the zone name somehow
#
# Some of that is pretty specific to my site, but may be useful to someone else

use strict;
use warnings;

my $repo = $ARGV[0];
my $txn = $ARGV[1];
my $svnlook = "/usr/bin/svnlook";
my $failcount = 0;
my $svndiffopts = "--no-diff-deleted --no-diff-added";

# There's probably a clever way to parameterize this and the next function
# I'll try another day
sub findOldSerial {
    my $difflines = shift;
    $difflines =~ /-\s+(\d+)\s+; Serial\s+/;
    my $serial = $1;
    return $serial;
}

sub findNewSerial {
    my $difflines = shift;
    $difflines =~ /\+\s+(\d+)\s+; Serial\s+/;
    my $serial = $1;
    return $serial;
}
    

# Get list of changed files in this commit
my @changedfiles = `$svnlook changed -t "$txn" "$repo"`;
# only care about the files that were updated, not added or deleted
@changedfiles = grep /^U/, @changedfiles;
# remove the leading "U(whitespace)" and the trailing line
@changedfiles = map {local $_ = $_; s/^U\W+(.*)\n/$1/; $_} @changedfiles;

# stupid svnlook diff puts extra crud in the diff.  Do it the hard way!
# I'm especially proud of having to shell out to bash -c since `` uses sh
# which doesn't have my <( ) I need
foreach my $file ( @changedfiles ) {
    my $diff = `/bin/bash -c '/usr/bin/diff -u <( $svnlook cat "$repo" "$file" ) <( $svnlook cat -t "$txn" "$repo" "$file" )'`;

    ## test 1: make sure serial was incremented, not decremented
    if ( $file =~ /^db\./ ) {
        my $oldSerial = findOldSerial($diff);
        my $newSerial = findNewSerial($diff);
        if ( not $oldSerial or not $newSerial ) {
            print STDERR "Didn't find a changed serial number in $file!\n";
            $failcount++;
            next;
        }

        if ( int($oldSerial) >= int($newSerial) ) {
            print STDERR "In $file, old serial ($oldSerial) >= new serial ($newSerial)!\n";
            $failcount++;
            next;
        }
    }
}

exit $failcount;

