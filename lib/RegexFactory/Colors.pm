package RegexFactory::Colors;
use base 'Exporter';
use experimental qw[ signatures ];
use Term::ANSIColor qw[ colored :constants ];

our @EXPORT_OK = qw[
    clr bld bbl brd bgr
    wht red cyn ylw mgt
];

our %EXPORT_TAGS = (
    all => \@EXPORT_OK,
);

sub clr :prototype($) { \&{( shift )} }
sub bld :prototype($) { colored shift, 'bold' }
sub brd :prototype($) { colored shift, 'bold bright_red' }
sub bbl :prototype($) { colored shift, 'bold bright_blue' }
sub bgr :prototype($) { colored shift, 'bold bright_green' }

sub wht :prototype($) { shift }
sub red :prototype($) { colored shift, 'bright_red' }
sub cyn :prototype($) { colored shift, 'bright_cyan' }
sub ylw :prototype($) { colored shift, 'bright_yellow' }
sub mgt :prototype($) { colored shift, 'bright_magenta' }

1
