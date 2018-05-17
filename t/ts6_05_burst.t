use strict;
use warnings;
use Test::More tests => 5;
use POE qw[Filter::Stackable Filter::Line Filter::IRCD];
use POE::Component::Server::IRC;
use Test::POE::Client::TCP;

my $ts = time();

my $pocosi = POE::Component::Server::IRC->spawn(
    servername   => 'listen.server.irc',
    auth         => 0,
    antiflood    => 0,
    plugin_debug => 1,
    config => { sid => '1FU' },
);

POE::Session->create(
    package_states => [
        'main' => [qw(
            _start
            _shutdown
            _terminate
            ircd_listener_add
            testc_registered
            testc_connected
            testc_input
            testc_disconnected
        )],
    ],
    heap => { ircd => $pocosi },
);

$poe_kernel->run();

sub _start {
    my ($kernel, $heap) = @_[KERNEL, HEAP];
    $heap->{ircd}->yield('register', 'all');
    $heap->{ircd}->add_listener();
    $kernel->delay('_shutdown', 60);
}

sub _shutdown {
    my $heap = $_[HEAP];
    $_[KERNEL]->delay('_shutdown');
    $heap->{ircd}->yield('shutdown');
    delete $heap->{ircd};
}

sub _terminate {
  my $heap = $_[HEAP];
  $heap->{testc}->terminate();
  return;
}

sub ircd_listener_add {
    my ($heap, $port) = @_[HEAP, ARG0];
    pass("Started a listener on $port");
    $heap->{port} = $port;
    $heap->{ircd}->add_peer(
        name  => 'connect.server.irc',
        pass  => 'foo',
        rpass => 'foo',
        type  => 'c',
        zip   => 1,
    );
    my $filter = POE::Filter::Stackable->new();
    $filter->push( POE::Filter::Line->new( InputRegexp => '\015?\012', OutputLiteral => "\015\012" ),
               POE::Filter::IRCD->new( debug => 0 ), );
    $heap->{testc} = Test::POE::Client::TCP->spawn( filter => $filter, address => '127.0.0.1', port => $port );
    return;
}

sub testc_registered {
  my ($kernel,$sender) = @_[KERNEL,SENDER];
  pass($_[STATE]);
  $kernel->post( $sender, 'connect' );
  return;
}

sub testc_connected {
  my ($kernel,$heap,$sender) = @_[KERNEL,HEAP,SENDER];
  pass($_[STATE]);
  $kernel->post( $sender, 'send_to_server', { command => 'PASS', params => [ 'foo', 'TS', '6', '6FU' ], } );
  $kernel->post( $sender, 'send_to_server', { command => 'CAPAB', params => [ 'KNOCK UNDLN DLN TBURST GLN ENCAP UNKLN KLN CHW IE EX HOPS SVS CLUSTER EOB QS' ], colonify => 1 } );
  $kernel->post( $sender, 'send_to_server', { command => 'SERVER', params => [ 'connect.server.irc', '1', 'Open the door and come in!!!!!!' ], colonify => 1 } );
  $kernel->post( $sender, 'send_to_server', { command => 'SVINFO', params => [ '6', '6', '0', time() ], colonify => 1 } );
  $kernel->post( $sender, 'send_to_server', { prefix => '6FU', command => 'UID', params => [ 'Bladger', '1', ( time() - 20 ), '+aiow', 'bladger', 'bladger.badger', '0', '6FUAAAAAA', '0', 'BladgerServ' ], colonify => 1 } );
  $kernel->post( $sender, 'send_to_server', { prefix => '6FU', command => 'SJOIN', params => [ ( time() -5 ), '#badgers', '+nt', '@6FUAAAAAA' ], colonify => 1 } );
  $kernel->post( $sender, 'send_to_server', { command => 'EOB', prefix => '6FU' } );
  $kernel->post( $sender, 'send_to_server', { command => 'PING', params => [ '6FU' ], colonify => 1 } );
  return;
}

sub testc_input {
  my ($heap,$input) = @_[HEAP,ARG0];
  return unless $input->{command} eq 'EOB';
  pass($input->{command});
  $poe_kernel->delay( _terminate => 5 );
  return;
}

sub testc_disconnected {
  my ($heap,$state) = @_[HEAP,STATE];
  pass($state);
  $heap->{testc}->shutdown();
  $heap->{ircd}->yield('shutdown');
  $poe_kernel->delay('_shutdown');
  return;
}