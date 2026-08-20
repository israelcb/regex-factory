#!/usr/bin/perl
use v5.34.1;
use warnings;
use experimental qw[ try ];

use constant EXT_ALL_CLEAR => 0;
use constant EXT_USAGE_ERR => 64;
use constant EXT_NOT_FOUND => 66;

use Term::ANSIColor;
use Data::Dump qw[ dd ];
use List::Util qw[ first uniq min ];

our $VERSION = 'v0.0.1';

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

    sub style_regex ($) {
        my $regex = shift;
        
        my @regex = $regex =~ /./g;
        my $last = '';
        my $fmt = '';
        my @inside;

        # https://www.pcre.org/original/doc/html/pcrepattern.html
        while ((my $r, $regex) = $regex =~ /^(.)(.*)/) {
            if (
                !$fmt and $r eq '^'
                or !@inside and $r eq '$'
            ) {
                $fmt .= colored $r, 'bright_red';
                next
            }

            my $inside = $inside[$#inside] // '';
            if ($inside eq '\\Q') {
                $last .= $r;
                next;
            }

            if ($r eq '\\') {
                $last = $r;
                next;
            }

            if ($last ne '\\') {
                $fmt .= colored $r, 'bright_yellow'
            
            } else {
                $last .= $r;
                
                if ($last =~ /\\A|\\Q/) {
                    push @inside, $last
                    
                } elsif ($last =~ /\\Z|\\E/) {
                    $fmt .= colored $last, 'bright_yellow';
                    pop @inside
                    
                } elsif ($r !~ /[efnrt\\]/i) {
                    $fmt .= colored $last,
                        ($r =~ /[dhsvw]/i) ? 'bright_cyan'     :
                        ($r =~ /[az]/i)    ? 'bold bright_red' :
                        'bright_yellow'
                }
            }

            $last = $r
        }

        join colored('/', 'bold'), '', $fmt, ''
    }
}

INIT {
    return if @ARGV == 2;

    print colored('Usage:', 'bold');
    print " regex-factory <file> <regex>\n";
    exit EXT_USAGE_ERR
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
        ($input, $s_end, $flags) = $input =~ /(.+?)(?:(\/)([a-z]*)|)$/i;
        ($body, $escs_end)       = $input =~ /(.+?(\\*))$/;

        $flags //= '';
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
        print style_regex $body;

        print(
            ($flags)
            ? colored $flags, 'bold'
            : ' (no flags)'
        );

        print "\n";
            
    } catch ($e) {
        report_error $raw_input, $e, EXT_USAGE_ERR
    }
}

open my $fh, '<', $file or die;

my @matches;
my @u_matches;

my $global = $flags =~ /g/;
my $line_number = 0;

while (my $line = <$fh>) {
    $line_number++;
    
    my ($m) = eval "\$line =~ /$regex/$flags";
    next unless $m;

    my $m_data =
        first { $$_[0] eq $m }
        @u_matches;
    
    push @u_matches, ($m_data = [ $m, 0 ]) unless $m_data;
    push @matches, [$m, $line_number];

    $$m_data[1]++;
    last unless $global;
}

close $fh;

# Todo:
# - Display capture groups
# - Display named/unamed capture groups
my $n_matches = @matches;
@u_matches = sort { $$b[1] <=> $$a[1] } @u_matches;

if ($n_matches > 0 and !$global) {
    my $l = pop @{ $matches[0] };

    print colored
        "Found match beginning at line $l",
        'bold bright_green';
    
} elsif ($n_matches > 0) {
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

    if (@matches > 5) {
        print "[...]\n";
    }

    print colored "\n# Unique matches: ", 'bright_red';
    print colored number_format @u_matches, 'bold';

    $end = min 9, scalar(@u_matches) - 1;
    foreach my $u (@u_matches[0..$end]) {
        print "\n";
        print colored "'$$u[0]'", 'bright_yellow';
        print ' (' . number_format($$u[1]) . ')';
    }
    
    if (@u_matches > 10) {
        print "\n[...]";
    }
    
} else {
    print colored
        'No matches found!',
        'bold bright_red';
}

print "\n" x 2;

1
