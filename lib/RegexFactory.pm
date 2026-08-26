package RegexFactory;
use base 'Exporter';
use RegexFactory::Colors qw[ :all ];

our @EXPORT_OK = qw[
    style_regex
    report_error
    number_format
    verify_odd_escapes
];

our %EXPORT_TAGS = (
    all => \@EXPORT_OK,
);

sub report_error {
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

sub verify_odd_escapes {
    length(shift) % 2 == 1
}

sub number_format {
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

        my $c;

        unless (
            ($prev or $chr ne '^')
            and (/./ or $chr ne '$')
        ) {
            $c = 'bbl'

        } elsif ($grp) {
            $chr = $prev . $chr;

            next unless $chr =~ /^(?:
                \\Q(?:[^\\]*(?:\\[^E]|))*\\E
                |\((?:[^\)]*(?:[^\\]\\\)|))*\)
                |\{(?:[^\}]*(?:[^\\]\\\}|))*\}
                |\[(?:[^\]]*(?:[^\\]\\\]|))*\]
            )$/x;

            undef $grp;
            ($prev) = $chr =~ /(.)$/;
            $c = 'ylw'

        } elsif ($prev eq '\\') {
            if ($chr eq 'Q') {
                $grp = '\\' . $&;
                next
            }

            $c = 'bbl' if $chr =~ /[AzZ]/;
            $c = 'cyn' if $chr =~ /[dhsvw]/;
            $c = 'ylw' if $chr =~ /[bBefFnGNrRtT\\]/;

            if (defined $c) {
                $chr = $prev . $chr
            }

        } elsif ($chr eq '\\') {
            next

        } elsif ($chr =~ /[\[\(\{]/) {
            $grp = $chr;
            next

        } elsif ($chr =~ /[\+\.\*\?\|]/) {
            $c = 'cyn'
        }

        $c //= 'wht';
        $fmt .= &{clr $c}($chr)
    }

    join bld('/'), '', $fmt, ''
}

1
