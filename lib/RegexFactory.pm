package RegexFactory;
use base 'Exporter';
use experimental qw[ signatures ];

use Data::Dump qw[ dd ];
use RegexFactory::Colors qw[ :all ];

our @EXPORT_OK = qw[
    style_regex
    report_error
    number_format
    match_counter
    matches_list
    verify_odd_escapes
];

our %EXPORT_TAGS = (
    all => \@EXPORT_OK,
);

my $r_whole_group = qr/^(?:
    \\Q(?:[^\\]*(?:\\[^E]|))*\\E
    |\{(?:[^\}]*(?:[^\\]\\\}|))*\}
)$/x;

sub report_error :prototype($@) {
    my $file = shift;

    # Todo:
    # Test and treat user input containing ' at ',
    # or find a way of show the pure error, without
    # printing the path.
    chomp( my $error = shift );
    $error =~ s/\n.+?$//;
    $error =~ s/^([^{].+?) at .+?$/$1/;
    $error =~ s/^{([^}]+?)}.*$/$1/;
    
    print red $file;
    print " - $error\n";

    my $ext_code = shift;
    exit $ext_code
}

sub verify_odd_escapes :prototype($) {
    length(shift) % 2 == 1
}

sub number_format :prototype($) {
    my $number = shift;

    1 while $number =~ s/
        (\d)(\d{3})(\s|$)
    /$1 $2$3/x;
    
    $number
}

# https://www.pcre.org/original/doc/html/pcrepattern.html
sub style_regex :prototype($) {
    my $r = shift;
    my ($fmt, $prev, $grp, $meta, $c);

    while ((my $chr, $r) = $r =~ /(.)(.*)/) {
        (my $first, $fmt) = (defined $fmt)
        ? (0, $fmt . clr $c // 'wht', $chr)
        : (1, '');

        unless (defined $prev or $first) {
            undef $grp;
            next
        }

        $prev = ($prev // '') . $chr;

        if (defined $grp) {
            $prev =~ /$r_whole_group/
            ? redo ($chr, $prev, $c) = ($prev, undef, 'ylw')
            : next
        }

        next $grp = $prev . $chr
            if $prev =~ /\\Q|{/;

        next $meta = $c = 'cyn'
            if $prev =~ /^\\[dhsvw]$/i;

        next $c = 'ylw'
            if $prev =~ /^\\[bBefFnGNrRtT\\]$/;

        redo $c = 'bbl' if
            $prev eq '^'
            or !$r and $chr eq '$'
            or $prev =~ /^\\[AzZ]$/;

        next $c = $meta
            if $chr =~ /[\+\*\?]/;

        next $c = 'cyn'
            if $chr =~ /[\.\|]/
    }

    join bld '/', '', $fmt, ''
}

sub match_counter :prototype($$) {
    my $header = shift;
    my $count  = shift;

    sprintf "\n%s %s\n"
    , $header
    , bld number_format $count
}

sub matches_list :prototype(&$@) {
    my $fmt   = shift;
    my $limit = shift;
    my @output;

    while (my $m = shift) {
        push @output, &$fmt(
            (ylw "'$$m[0]'")
            , (number_format $$m[1])
        );

        next unless @output == $limit;
        push @output, '[...]'; last
    }

    join "\n", @output
}

1
