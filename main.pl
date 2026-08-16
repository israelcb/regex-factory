#!/usr/bin/perl
use v5.34.1;
use warnings;
use experimental qw[ try ];

use constant EXT_ALL_CLEAR => 0;
use constant EXT_USAGE_ERR => 64;
use constant EXT_NOT_FOUND => 66;

use Term::ANSIColor;
use Data::Dump qw[ dd ];
use List::Util qw[ uniq ];

our $VERSION = 'v0.0.1';

# v0.0.1
# $file $regex
# Lê e passa a regex no arquivo, validando a expressão
# e retornando os grupos de captura.

# v0.0.2
# --version
# --scan|s $file [$regex]
# --build|b [$regex] [$file]

# v0.0.3
# [--help]
# --library|l [$file]

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
    } catch ($e) { report_error $file, @$e }
}

my ($regex, $flags, $global);
INIT {
    try {
        ($regex = shift) =~ /^
            (?<s_begin>\/?)
            (?<body>.+?)
            (?<esc_end>[\\]*)
            (?:
                (?<s_end>\/)
                (?<flags>[^\/]*)
            )?
        $/x;
        my %r = %{^CAPTURE};

        unless (
            defined $r{s_end}
            and length($r{esc_end}) % 2 == 0
        ) {
            $r{s_end} = '';
            $r{flags} = ''
        }

        if ($r{s_begin} ne $r{s_end}) {
            my $pos = $r{s_begin} ? 'end' : 'start';
            die "{Missing slash at the $pos of the expression}"
        }

        if ($r{flags} =~ /([^gimsx])/) {
            die "{Unknown regexp modifier \"/$&\"}"
        }

        eval qq"'' =~ /$r{body}/$r{flags}; 1" or die $!;
        $regex = qr/$r{body}/;
        
        $flags = $r{flags};
        $global = $flags =~ /g/;
            
    } catch ($e) {
        report_error $regex, $e, EXT_USAGE_ERR
    }
}


open my $fh, '<', $file or die;

my @matches;
while (my $line = <$fh>) {
    push @matches, eval "\$line =~ /$regex/$flags";
    last unless !@matches or $global
}

close $fh;


dd @matches;

1
