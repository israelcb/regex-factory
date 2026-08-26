package RegexFactory::Colors;
use base 'Exporter';
use Term::ANSIColor qw[ colored :constants ];

our @EXPORT_OK = qw[
    clr bld bbl brd bgr
    wht red cyn ylw mgt
];

our %EXPORT_TAGS = (
    all => \@EXPORT_OK,
);

sub clr { \&{( shift )} }
sub bld { colored shift, 'bold' }
sub brd { colored shift, 'bold bright_red' }
sub bbl { colored shift, 'bold bright_blue' }
sub bgr { colored shift, 'bold bright_green' }

sub wht { shift }
sub red { colored shift, 'bright_red' }
sub cyn { colored shift, 'bright_cyan' }
sub ylw { colored shift, 'bright_yellow' }
sub mgt { colored shift, 'bright_magenta' }

1
