use strictures;

package make_map;

use feature 'state';
use IO::All -binary;
use Geo::Coder::Google;
use YAML 'Load';
use JSON qw'encode_json decode_json';
use DBIx::Simple;

run();

sub run {
    my %locations = map { $_->{location} => 1 } @{ Load( io( "../Perl_Companies.yaml" )->all ) };
    print scalar( keys %locations ) . "\n";

    my $db        = DBIx::Simple->new( "dbi:SQLite:dbname=geo.db" );
    my $geocoder  = Geo::Coder::Google->new( apiver => 3 );
    my @locations = map { get_coords( $geocoder, $db, $_ ) } keys %locations;

    my $json = encode_json( \@locations );
    io( "loc.js" )->print( "var locationArray = $json;" );

    return;
}

sub get_coords {
    my ( $geocoder, $db, $place ) = @_;
    return get_cached_coords( $db, $place ) || make_coords( $geocoder, $db, $place );
}

sub make_coords {
    my ( $geocoder, $db, $place ) = @_;

    eval {
        sleep 1;    # avoid query limits
        my $result = $geocoder->geocode( location => $place );
        my $coords = { %{ $result->{geometry}{location} }, name => $place };
        $db->insert( "places", $coords );
    };
    warn "failed on place '$place' with $@" if $@ and $@ !~ /ZERO_RESULTS/;

    return get_cached_coords( $db, $place );
}

sub get_cached_coords {
    my ( $db, $place ) = @_;
    my $coords = $db->select( "places", [qw(name lat lng)], { name => $place } )->hash;
    return $coords ? $coords : ();
}
