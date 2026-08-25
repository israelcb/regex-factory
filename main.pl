#!/usr/bin/perl
use v5.34.1;
use warnings;
use experimental qw[ try ];

use constant EXT_ALL_CLEAR => 0;
use constant EXT_USAGE_ERR => 64;
use constant EXT_NOT_FOUND => 66;

use Term::ANSIColor;
use Data::Dump  qw[ dd ];
use Time::HiRes qw[ sleep ];
use List::Util  qw[ first uniq min ];

our $VERSION = 'v0.0.1';

BEGIN {
    sub bld   ($) { colored shift, 'bold' }
    sub b_red ($) { colored shift, 'bold bright_red' }

    sub wht ($) { shift }
    sub red ($) { colored shift, 'bright_red' }
    sub cyn ($) { colored shift, 'bright_cyan' }
    sub ylw ($) { colored shift, 'bright_yellow' }
    sub mgt ($) { colored shift, 'bright_magenta' }

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
        
        print red $file;
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

    # https://www.pcre.org/original/doc/html/pcrepattern.html
    sub style_regex () {
        my ($grp, $chr, $fmt);

        while (1) {
            last unless s/^(.)//;
            (my $prev, $chr) = ($chr // '', @{^CAPTURE});

            my $clr = \&wht;

            unless ($prev or $chr ne '^') {
                $clr = \&b_red

            } elsif ($grp) {
                $chr = $prev . $chr;

                next unless $chr =~ /^(?:
                    \\A(?:[^\\]*(?:\\[^Z]|))*\\Z
                    |\\Q(?:[^\\]*(?:\\[^E]|))*\\E
                    |\\a(?:[^\\]*(?:\\[^z]|))*\\z
                    |\((?:[^\)]*(?:[^\\]\\\)|))*\)
                    |\{(?:[^\}]*(?:[^\\]\\\}|))*\}
                    |\[(?:[^\]]*(?:[^\\]\\\]|))*\]
                )$/x;

                undef $grp;
                ($prev) = $chr =~ /(.)$/;
                $clr = \&ylw

            } elsif ($prev eq '\\') {
                if ($chr =~ /[aAQ]/) {
                    $grp = '\\' . $&;
                    next
                }

                $clr = \&cyn if $chr =~ /[dw]/i;
                $clr = \&ylw if $chr =~ /[efFnNrRtT\\]/

            } elsif ($chr =~ /[\[\(\{]/) {
                $grp = $chr;
                next

            } elsif ($chr =~ /[\+\.\*\?]/) {
                $clr = \&cyn
            }

            $fmt .= &$clr($chr)
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
        # - Modularize
        # - Write tests

        # Todo:
        # Improve regex metacharacters highlighting:
        # (...)             - group must not interfere in the content matching
        # (?:...)           - no colors for '(?:' or ')'
        # \w*, \w+, \w?     - \+ must have the same color of 'w'
        # *?, +?            - special colors when preceded by a group closing
        # \w*?, \w+?        - \+?* must have the same color of 'w'
        # \n, \t, \r, \f... - \ must have the same color of n, t, r...
        # [^...]            - must be distinct of [...], possibly in red

        # Todo:
        # Improve group highlighting (phase 1):
        # ln 1: (...) - openning and closing must have an 'unique' color
        # ln 2: ^...^ - that 'unique' color must be also displayed bellow

        # Todo:
        # Improve group highlighting (phase 2):
        # ln 1:   (?<foo>...(...))...(?:...)...(...)...(?<bar>...)
        # ln 2:   ^1........^2..^^.............^3..^...^4........^
        # ...
        # ln x:   Group 1    Group 2    Group 3    Group 4
        # ln x+1: [.....]    [.....]    [.....]    [.....]

        # Todo:
        # Improve group highlighting (phase 3):
        # ln 1:   (?<foo>...(...))...(?:...)...(...)...(?<bar>...)
        # ln 2:   ^..foo....^1..^^.............^2..^...^..bar....^
        # ...
        # ln x:   Group foo    Group bar    Group 1    Group 2
        # ln x+1: [.......]    [.......]    [.....]    [.....]

        print colored "'$raw_input'", 'bright_yellow';
        print colored ' :: ', 'bright_magenta';
        print style_regex for $body;

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
