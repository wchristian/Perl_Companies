use strictures;

package make_map;

use IO::All -binary;
use Geo::Coder::Google;
use YAML::Syck 'Load';
use JSON qw'encode_json decode_json';
use DBIx::Simple;

run();

sub run {
    my @companies = @{ Load( io( "../Perl_Companies.yaml" )->all ) };
    my %locations = map { $_->{location} => 1 } @companies;
    print scalar( keys %locations ) . "\n";

    my $db       = DBIx::Simple->new( "dbi:SQLite:dbname=geo.db" );
    my $geocoder = Geo::Coder::Google->new( apiver => 3 );
    my %geocodes = map { $_->{name} => $_ } map { get_coords( $geocoder, $db, $_ ) } keys %locations;
    push @{ $geocodes{ $_->{location} }{companies} }, $_->{name} for grep { $geocodes{ $_->{location} } } @companies;

    my $json = encode_json( [ values %geocodes ] );
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
