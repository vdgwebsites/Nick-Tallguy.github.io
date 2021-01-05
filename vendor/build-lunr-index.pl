#!/usr/bin/perl -w

my $dir = shift;
my $dh;
my $fh;

if ($dir) {
    die "$dir is not a directory" unless -d $dir;
    opendir $dh, $dir or die "cannot open $dir";
    # iterate over all files except those starting with '.' and excluding drafts
    my @allfiles = grep ! /^(\.|draft)/, readdir $dh;
    closedir $dh;

    print STDOUT "[";
    my $virgin = 1;
    foreach $fh (@allfiles) {
        open (FH, "$dir/$fh") or die "cannot open $dir/$fh";
        my $valid = 0;
        my $link;
        my $body;
        while (<FH>) {
            if ($valid == 0) { # not yet seen the header
                if (/---/) {
                    $valid = 1;
                }
            }
            elsif ($valid == 1) { # we're in the header and store the page url for further reference
                if (m@permalink: ([^!#\n]*)@) {
                    $link = $1;
                    $link =~ s/ *$//;
                    if ($body) {
                        print STDOUT ", " unless $virgin;
                        print STDOUT "{\"link\": \"$link","@@@@","$body\"}";
                        $virgin = 0;
                    }
                }
                if (m@title: ([^!#\n]*)@) {
                    $body = $1;
                    $body =~ s/"/\\"/g;
                    $body =~ s/\\-/-/g;
                    if ($link) {
                        print STDOUT ", " unless $virgin;
                        print STDOUT "{\"link\": \"$link","@@@@","$body\"}";
                        $virgin = 0;
                    }
                }
                if (/---/) {
                    $valid = 2;
                }
            }
            elsif ($valid == 2) { # now scan the text proper for headings
                if (m@^##[# ]*([^!#\n]*)@) {
                    $body = $1;
                    # escape quotes
                    $body =~ s/"/\\"/g;
                    # escape ampersands
                    $body =~ s/&/&amp;/g;
                    # anchor magic: we inspect markdown files but the code will run on html
                    # pages. Markdown creates anchors for all headings which we can address
                    # if the user selects one of those search results. So let us create those
                    # anchors in hopefully the same way as markdown does.
                    $body =~ s/\\-/-/g;
                    my $anchor = lc $body;
                    $anchor =~ s/ +/-/g;
                    $anchor =~ s/-$//;
                    $anchor = "#$anchor";
                    # We must code the heading text in the link because lunr does not
                    # store it on its own. But we need the text to display it to the user.
                    print STDOUT ", " unless $virgin;
                    print STDOUT "{\"link\": \"$link$anchor","@@@@","$body\"}";
                    $virgin = 0;
                }
            }
        }
        close FH;
    }
    print STDOUT "]";
}
