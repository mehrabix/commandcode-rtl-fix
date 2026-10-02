#!/usr/bin/env perl
#
# Injects the RTL fix <link>/<script> tags into a Command Code renderer
# index.html. Idempotent: running it twice does not duplicate the tags.
#
# Usage: perl inject.pl /path/to/out/renderer/index.html
#
use strict;
use warnings;

my $file = $ARGV[0] or die "usage: inject.pl <index.html>\n";
open(my $in, '<', $file) or die "cannot open $file: $!\n";
local $/;
my $html = <$in>;
close $in;

if (index($html, './rtl-fix.css') < 0) {
	$html =~ s{</head>}{<link rel="stylesheet" href="./rtl-fix.css" />\n</head>}i
		or die "could not find </head> in $file\n";
}

if (index($html, './rtl-fix.js') < 0) {
	$html =~ s{</body>}{<script src="./rtl-fix.js"></script>\n</body>}i
		or die "could not find </body> in $file\n";
}

open(my $out, '>', $file) or die "cannot write $file: $!\n";
print $out $html;
close $out;

print "patched $file\n";
