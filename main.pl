#!/usr/bin/perl
use v5.34.1;
use warnings;
use experimental qw[ try ];

use constant EXT_ALL_CLEAR => 0;
use constant EXT_USAGE_ERR => 64;
use constant EXT_NOT_FOUND => 66;

use Term::ANSIColor;
use Data::Dump  qw[ dd ];
use List::Util  qw[ first uniq min ];

our $VERSION = 'v0.0.1';

# v0.0.1
# $file $regex
# --test|t $f $regex
# ...--global|g
# ...--insensitive|i
# ...--multiline|m
# ...--single-line|s
# ...--extended|x

# v0.0.?
# --replace|r $file $regex $replacement [-o $output]

# v0.0.?
# -r $source $rx $rp [-o $out]
# -t $source $rx

# v0.0.?
# --history|h [ls]
# --t $sr $index|$rx
# --r $source $index|$rx $rp [-o $out]

# v0.0.?
# -h off
# -h clear-all
# -h drop $index
# ...--no-keep|n

# v0.0.?
# ...--keep|k $alias
# --keep|k $alias $index|$regex
# --blueprints|b [ls]

# v0.0.?
# -b edit $alias
# -b drop $alias

# v0.0.?
# -t $sr $alias|$id|$rx
# -r $sr $alias|$id|$rx $rp [-o $out]

# v0.0.?
# -r $sr [$al|$id|$rx] [$rp] [-o $out]

# v0.0.?
# -r $sr [$al|$id|$rx] [$rp] > -r [$al|$id|$rx] [$rp] > [...]

# v0.0.?
# [--help|h]
# --version|v

# v0.0.?
# [-h] [$alias|$index|$regex]
# [--explain|e] [$alias|$index|$regex]

# v0.1.0
# --assemble|a [$alias]

BEGIN {
    sub report_error ($@) {
        my $file     = shift;
        my $error    = shift;
        my $ext_code = shift;

        # Todo:
        # Test and treat user input containing ' at ',
        # or find a way of show the pure error, without
        # printing the path.
        chomp $error;
        $error =~ s/\n.+?$//;
        $error =~ s/^([^{].+?) at .+?$/$1/;
        $error =~ s/^{([^}]+?)}.*$/$1/;
        
        print colored $file, 'red';
        print " - $error\n";
        exit $ext_code
    }

    sub verify_odd_escapes ($) {
        length(shift) % 2 == 1
    }

    sub number_format ($) {
        my $number = shift;
        1 while $number =~ s/
            (\d)(\d{3})(\s|$)
        /$1 $2$3/x;
        
        $number
    }
}

INIT {
    return if @ARGV == 2;

    print colored('Usage:', 'bold');
    print " regex-factory <file> <regex>\n";
    exit EXT_USAGE_ERR;
}

my $file;
INIT {
    $file = shift;

    try {
        die ['{File not found}', EXT_NOT_FOUND]
            unless -e $file;
        
        die ['{File is not readable}', EXT_NOT_FOUND]
            unless -r $file;
        
        die ['{Path leads to a directory}', EXT_USAGE_ERR]
            unless -e $file;
    } catch ($e) {
        report_error $file, @$e
    }
}

my ($regex, $flags);
INIT {
    my $raw_input = shift;
    
    try {
        my $input  = $raw_input;
        
        my ($s_begin, $body, $escs_end, $s_end);
        ($s_begin, $input)       = $input =~ /^(\/|)(.+)/;
        ($input, $s_end, $flags) = $input =~ /(.+?)(\/|)([a-z]*)$/i;
        ($body, $escs_end)       = $input =~ /(.+?(\\*))$/;

        if (defined $s_end and verify_odd_escapes $escs_end) {
            $body .= "/$flags";
            $flags = ''
            
        } elsif ($flags =~ /([^gimsx])/) {
            die "{Unknown regexp modifier \"/$&\"}"
        }

        $body =~ s/(\\*\/)/
            (verify_odd_escapes $1) ? "\\$1" : $1
        /eg;

        eval qq"'' =~ /$body/$flags; 1" or die $!;
        $regex = qr/$body/;

        # Todo:
        # Recognize and highlight regex metacharacters
        print colored "'$raw_input'", 'bright_yellow';
        print colored ' :: ', 'bright_magenta';
        print colored '/', 'bold';
        print colored $body, 'bright_yellow';
        print colored '/', 'bold';

        print(
            ($flags)
            ? colored $flags, 'bold'
            : ' (no flags)'
        );

        print "\n"
            
    } catch ($e) {
        report_error $raw_input, $e, EXT_USAGE_ERR
    }
}

open my $fh, '<', $file or die;

my @matches;
my @uniq_matches;

my $global = $flags =~ /g/;
my $line_number = 0;

while (my $line = <$fh>) {
    $line_number++;
    my ($m) = eval "\$line =~ /$regex/$flags";
    
    next unless $m;
    push @matches, [$m, $line_number];

    my $m_data =
        first { $$_[0] eq $m }
        @uniq_matches;

    push @uniq_matches, ($m_data = [ $m, 0 ])
        unless $m_data;

    $$m_data[1]++;
    last unless $global
}

close $fh;

# Todo:
# - Display capture groups
if (@matches > 0) {
    my $n_matches = @matches;
    
    print "\n";
    print colored "# Total matches: ", 'bright_magenta';
    print colored number_format $n_matches, 'bold';
    print "\n";

    my $end = min 4, $n_matches - 1;
    foreach my $m (@matches[0..$end]) {
        print ":$$m[1]";
        print colored " '$$m[0]'", 'bright_yellow';
        print "\n";
    }

    print colored "\n# Unique matches: ", 'bright_red';
    print colored number_format @uniq_matches, 'bold';

    foreach my $u (@uniq_matches) {
        print "\n";
        print colored "'$$u[0]'", 'bright_yellow';
        print ' (' . (number_format $$u[1]) . ')';
    }
    
} else {
    print colored
        'No matches found!',
        'bold bright_red';
}

print "\n" x 2;

1
