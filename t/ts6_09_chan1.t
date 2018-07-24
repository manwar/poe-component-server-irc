use strict;
use warnings;
use Test::More 'no_plan';
use POE qw[Filter::Stackable Filter::Line Filter::IRCD];
use POE::Component::Server::IRC;
use Test::POE::Client::TCP;
use IRC::Utils qw[BOLD YELLOW NORMAL];

my %servers = (
 'listen.server.irc'   => '1FU',
 'groucho.server.irc'  => '7UP',
 'harpo.server.irc'    => '9T9',
 'fake.server.irc'     => '4AK',
);

my $ts = time();

my $uidts;

my $pocosi = POE::Component::Server::IRC->spawn(
    auth         => 0,
    antiflood    => 0,
    plugin_debug => 1,
    config => { servername => 'listen.server.irc', sid => '1FU', anti_spam_exit_message_time => 0 },
);

POE::Session->create(
    package_states => [
        'main' => [qw(
            _start
            _shutdown
            _launch_client
            ircd_listener_add
            ircd_daemon_eob
            groucho_connected
            groucho_input
            groucho_disconnected
            harpo_connected
            harpo_input
            harpo_disconnected
            client_connected
            client_input
            client_disconnected
        )],
        'main' => {
            groucho_registered => 'testc_registered',
            harpo_registered   => 'testc_registered',
            client_registered  => 'testc_registered',
        },
    ],
    heap => {
      ircd  => $pocosi,
      eob   => 0,
      topic => 0,
    },
);

$poe_kernel->run();

sub _start {
    my ($kernel, $heap) = @_[KERNEL, HEAP];
    $heap->{ircd}->yield('register', 'all');
    $heap->{ircd}->add_listener();
    $kernel->delay('_shutdown', 60, 'timeout');
}

sub _shutdown {
    my $heap = $_[HEAP];
    if ( $_[ARG0] && $_[ARG0] eq 'timeout' ) {
      fail('We timed out');
    }
    exit;
    return;
}

sub ircd_listener_add {
    my ($heap, $port) = @_[HEAP, ARG0];
    pass("Started a listener on $port");
    $heap->{port} = $port;
    $heap->{ircd}->add_peer(
        name  => 'groucho.server.irc',
        pass  => 'foo',
        rpass => 'foo',
        type  => 'c',
        zip   => 1,
    );
    $heap->{ircd}->add_peer(
        name  => 'harpo.server.irc',
        pass  => 'foo',
        rpass => 'foo',
        type  => 'c',
        zip   => 1,
    );
    foreach my $tag ( qw[groucho harpo] ) {
      my $filter = POE::Filter::Stackable->new();
      $filter->push( POE::Filter::Line->new( InputRegexp => '\015?\012', OutputLiteral => "\015\012" ),
                POE::Filter::IRCD->new( debug => 0 ), );
      push @{ $heap->{testc} }, Test::POE::Client::TCP->spawn( alias => $tag, filter => $filter, address => '127.0.0.1', port => $port, prefix => $tag );
    }
    return;
}

sub _launch_client {
  my ($kernel,$heap) = @_[KERNEL,HEAP];
  my $filter = POE::Filter::Stackable->new();
  $filter->push( POE::Filter::Line->new( InputRegexp => '\015?\012', OutputLiteral => "\015\012" ),
             POE::Filter::IRCD->new( debug => 0 ), );
  my $tag = 'client';
  $heap->{client} = Test::POE::Client::TCP->spawn( alias => $tag, filter => $filter, address => '127.0.0.1', port => $heap->{port}, prefix => $tag );
  return;
}

sub testc_registered {
  my ($kernel,$sender) = @_[KERNEL,SENDER];
  pass($_[STATE]);
  $kernel->post( $sender, 'connect' );
  return;
}

sub client_connected {
  my ($kernel,$heap,$sender) = @_[KERNEL,HEAP,SENDER];
  pass($_[STATE]);
  $kernel->post( $sender, 'send_to_server', { command => 'NICK', params => [ 'bobbins' ], colonify => 0 } );
  $kernel->post( $sender, 'send_to_server', { command => 'USER', params => [ 'bobbins', '*', '*', 'bobbins along' ], colonify => 1 } );
  return;
}

sub groucho_connected {
  my ($kernel,$heap,$sender) = @_[KERNEL,HEAP,SENDER];
  pass($_[STATE]);
  $kernel->post( $sender, 'send_to_server', { command => 'PASS', params => [ 'foo', 'TS', '6', '7UP' ], } );
  $kernel->post( $sender, 'send_to_server', { command => 'CAPAB', params => [ 'KNOCK UNDLN DLN TBURST GLN ENCAP UNKLN KLN CHW IE EX HOPS SVS CLUSTER EOB QS' ], colonify => 1 } );
  $kernel->post( $sender, 'send_to_server', { command => 'SERVER', params => [ 'groucho.server.irc', '1', 'Open the door and come in!!!!!!' ], colonify => 1 } );
  $kernel->post( $sender, 'send_to_server', { command => 'SVINFO', params => [ '6', '6', '0', time() ], colonify => 1 } );
  $uidts = time() - 20;
  $kernel->post( $sender, 'send_to_server', { prefix => '7UP', command => 'SID', params => [ 'fake.server.irc', 2, '4AK', 'This is a fake server' ] } );
  #$kernel->post( $sender, 'send_to_server', { prefix => '7UP', command => 'UID', params => [ 'groucho', '1', $uidts, '+aiow', 'groucho', 'groucho.marx', '0', '7UPAAAAAA', '0', 'Groucho Marx' ], colonify => 1 } );
  $kernel->post( $sender, 'send_to_server', { command => 'EOB', prefix => '7UP' } );
  $kernel->post( $sender, 'send_to_server', { command => 'EOB', prefix => '4AK' } );
  $kernel->post( $sender, 'send_to_server', { command => 'PING', params => [ '7UP' ], colonify => 1 } );
  return;
}

sub harpo_connected {
  my ($kernel,$heap,$sender) = @_[KERNEL,HEAP,SENDER];
  pass($_[STATE]);
  $kernel->post( $sender, 'send_to_server', { command => 'PASS', params => [ 'foo', 'TS', '6', '9T9' ], } );
  $kernel->post( $sender, 'send_to_server', { command => 'CAPAB', params => [ 'KNOCK UNDLN DLN TBURST GLN ENCAP UNKLN KLN CHW IE EX HOPS SVS CLUSTER EOB QS' ], colonify => 1 } );
  $kernel->post( $sender, 'send_to_server', { command => 'SERVER', params => [ 'harpo.server.irc', '1', 'Open the door and come in!!!!!!' ], colonify => 1 } );
  $kernel->post( $sender, 'send_to_server', { command => 'SVINFO', params => [ '6', '6', '0', time() ], colonify => 1 } );
  $uidts = time() - 20;
  #$kernel->post( $sender, 'send_to_server', { prefix => '9T9', command => 'UID', params => [ 'harpo', '1', $uidts, '+aiow', 'harpo', 'harpo.marx', '0', '9T9AAAAAA', '0', 'Harpo Marx' ], colonify => 1 } );
  $kernel->post( $sender, 'send_to_server', { command => 'EOB', prefix => '9T9' } );
  $kernel->post( $sender, 'send_to_server', { command => 'PING', params => [ '9T9' ], colonify => 1 } );
  return;
}


sub client_input {
  my ($heap,$sender,$in) = @_[HEAP,SENDER,ARG0];
  #diag($in->{raw_line}, "\n");
  my $prefix = $in->{prefix};
  my $cmd    = $in->{command};
  my $params = $in->{params};
  if ( $cmd eq 'MODE' && $prefix =~ m'^bobbins' && $params->[1] eq '+i' ) {
    $poe_kernel->post( $sender, 'send_to_server', { command => 'JOIN', params => [ '#potato' ] } );
    return;
  }
  if ( $cmd eq 'ERROR' ) {
    pass($cmd);
    my $state = $heap->{ircd}{state};
    is( scalar keys %{ $state->{chans} }, 0, 'No channels' );
    is( scalar keys %{ $state->{conns} }, 2, 'Should only be 2 connections' );
    is( scalar keys %{ $state->{uids} }, 0, 'No UIDs' );
    is( scalar keys %{ $state->{users} }, 0, 'No users' );
    is( scalar keys %{ $state->{peers}{'LISTEN.SERVER.IRC'}{users} }, 0, 'No local users' );
    is( scalar keys %{ $state->{sids}{'1FU'}{uids} }, 0, 'No local UIDs' );
    $poe_kernel->post( $sender, 'shutdown' );
    $poe_kernel->post( 'harpo', 'terminate' );
    return;
  }
  if ( $cmd eq 'JOIN' ) {
    pass($cmd);
    is( $prefix, 'bobbins!~bobbins@listen.server.irc', 'It is I, bobbins' );
    is( $params->[0], '#potato', 'Channel is #potato' );

    my $state = $heap->{ircd}{state};
    is( scalar keys %{ $state->{chans} }, 1, 'Should be 1 channel' );
    is( scalar keys %{ $state->{conns} }, 3, 'Should be 3 connections' );
    is( scalar keys %{ $state->{uids} }, 1, 'One UID' );
    is( scalar keys %{ $state->{users} }, 1, 'One user' );
    is( scalar keys %{ $state->{peers}{'LISTEN.SERVER.IRC'}{users} }, 1, 'One local user' );
    is( scalar keys %{ $state->{sids}{'1FU'}{uids} }, 1, 'One local UID' );

    return;
  }
  if ( $cmd eq 'MODE' && $params->[1] eq '+nt' ) {
    pass($cmd);
    return;
  }
  if ( $cmd eq '353' ) {
    pass("IRC$cmd");
    is( $params->[0], 'bobbins', 'It is me, bobbins' );
    is( $params->[1], '=', 'Correct arg =' );
    is( $params->[2], '#potato', 'Channel name is #potato' );
    is( $params->[3], '@bobbins', 'I am chanop' );
    return;
  }
  if ( $cmd eq '366' ) {
    pass("IRC$cmd");
    is( $params->[0], 'bobbins', 'It is me, bobbins' );
    is( $params->[1], '#potato', 'Channel name is #potato' );
    is( $params->[2], 'End of NAMES list', 'End of NAMES list' );
    $poe_kernel->post( $sender, 'send_to_server', { command => 'MODE', params => [ '#potato' ] } );
    return;
  }
  if ( $cmd eq '324' ) {
    pass("IRC$cmd");
    is( $params->[0], 'bobbins', 'It is me, bobbins' );
    is( $params->[1], '#potato', 'Channel name is #potato' );
    is( $params->[2], '+nt', '+nt is the mode we expect' );
    return;
  }
  if ( $cmd eq '329' ) {
    pass("IRC$cmd");
    is( $params->[0], 'bobbins', 'It is me, bobbins' );
    is( $params->[1], '#potato', 'Channel name is #potato' );
    like( $params->[2], qr/\d+/, 'Looks like a timestamp' );
    $poe_kernel->post( $sender, 'send_to_server', { command => 'TOPIC', params => [ '#potato' ] } );
    return;
  }
  if ( $cmd eq '331' ) {
    $heap->{topic}++;
    pass("IRC$cmd");
    is( $params->[0], 'bobbins', 'It is me, bobbins' );
    is( $params->[1], '#potato', 'Channel name is #potato' );
    is( $params->[2], 'No topic is set', 'No topic is set' );
    if ( $heap->{topic} ) {
      $poe_kernel->post( $sender, 'send_to_server', { command => 'MODE', params => [ '#potato', '+c' ] } );
    }
    else {
      $poe_kernel->post( $sender, 'send_to_server', { command => 'TOPIC', params => [ '#potato', 'Here is what it is supposed to be!' ] } );
    }
    return;
  }
  if ( $cmd eq 'TOPIC' ) {
    pass($cmd);
    is( $prefix, 'bobbins!~bobbins@listen.server.irc', 'It is I, bobbins' );
    is( $params->[0], '#potato', 'Channel name is #potato' );
    is( $params->[1], 'Here is what it is supposed to be!', 'Here is what it is supposed to be!' );
    $poe_kernel->post( $sender, 'send_to_server', { command => 'TOPIC', params => [ '#potato' ] } );
    return;
  }
  if ( $cmd eq '332' ) {
    pass("IRC$cmd");
    is( $params->[0], 'bobbins', 'It is me, bobbins' );
    is( $params->[1], '#potato', 'Channel name is #potato' );
    is( $params->[2], 'Here is what it is supposed to be!', 'Here is what it is supposed to be!' );
    return;
  }
  if ( $cmd eq '333' ) {
    pass("IRC$cmd");
    is( $params->[0], 'bobbins', 'It is me, bobbins' );
    is( $params->[1], '#potato', 'Channel name is #potato' );
    is( $params->[2], 'bobbins!~bobbins@listen.server.irc', 'It was set by me' );
    like( $params->[3], qr/\d+/, 'Looks like a timestamp' );
    $poe_kernel->post( $sender, 'send_to_server', { command => 'TOPIC', params => [ '#potato', '' ] } );
    return;
  }
  if ( $cmd eq 'MODE' ) {
    pass($cmd);
    is( $prefix, 'bobbins!~bobbins@listen.server.irc', 'It is I, bobbins' );
    is( $params->[0], '#potato', 'Channel is #potato' );
    is( $params->[1], '+c', '+c is the mode we expect' );
    my $msg = 'This word is '.YELLOW.'yellow'.NORMAL.' while this word is'.BOLD.'bold'.BOLD;
    $poe_kernel->post( $sender, 'send_to_server', { command => 'PRIVMSG', params => [ '#potato', $msg ] } );
    return;
  }
  if ( $cmd eq '408' ) {
    pass("IRC$cmd");
    is( $params->[0], 'bobbins', 'It is me, bobbins' );
    is( $params->[1], '#potato', 'Channel name is #potato' );
    is( $params->[2], 'You cannot use control codes on this channel', 'You cannot use control codes on this channel' );
    $poe_kernel->post( $sender, 'send_to_server', { command => 'PART', params => [ '#potato', 'Suckers' ] } );
    return;
  }
  if ( $cmd eq 'PART' ) {
    pass($cmd);
    is( $prefix, 'bobbins!~bobbins@listen.server.irc', 'It is I, bobbins' );
    is( $params->[0], '#potato', 'Channel name is #potato' );
    is( $params->[1], 'Suckers', 'So long suckers' );
    $poe_kernel->post( $sender, 'send_to_server', { command => 'QUIT', params => [ 'Connection reset by fear' ] } );
    return;
  }
  return;
}

sub groucho_input {
  my ($heap,$sender,$in) = @_[HEAP,SENDER,ARG0];
  #diag($in->{raw_line}, "\n");
  my $prefix = $in->{prefix};
  my $cmd    = $in->{command};
  my $params = $in->{params};
  if ( $cmd eq 'SJOIN' ) {
    pass($cmd);
    is( $prefix, '1FU', 'Correct prefix: 1FU' );
    like( $params->[0], qr/\d+/, 'Looks like a timestamp' );
    is( $params->[1], '#potato', 'Channel is correct: #potato' );
    is( $params->[2], '+nt', 'Correct chanmodes applied: +nt' );
    is( $params->[3], '@1FUAAAAAA', 'Got a correct UID + status: @1FUAAAAAA' );
    return;
  }
  if ( $cmd eq 'TOPIC' ) {
    pass($cmd);
    is( $prefix, '1FUAAAAAA', 'Correct prefix: 1FUAAAAAAA' );
    is( $params->[0], '#potato', 'Channel is correct: #potato' );
    return;
  }
  if ( $cmd eq 'TMODE' ) {
    pass($cmd);
    is( $prefix, '1FUAAAAAA', 'Correct prefix: 1FUAAAAAAA' );
    like( $params->[0], qr/\d+/, 'Looks like a timestamp' );
    is( $params->[1], '#potato', 'Channel is correct: #potato' );
    is( $params->[2], '+c', 'Correct chanmodes applied: +c' );
    return;
  }
  if ( $cmd eq 'PART' ) {
    pass($cmd);
    is( $prefix, '1FUAAAAAA', 'Correct prefix: 1FUAAAAAAA' );
    is( $params->[0], '#potato', 'Channel is correct: #potato' );
    is( $params->[1], 'Suckers', 'There is a parting messge' );
    return;
  }
  if ( $cmd eq 'QUIT' ) {
    pass($cmd);
    is( $prefix, '1FUAAAAAA', 'Correct prefix: 1FUAAAAAAA' );
    is( $params->[0], q{Quit: "Connection reset by fear"}, 'Correct QUIT message' );
    return;
  }
  if ( $cmd eq 'SQUIT' ) {
    pass($cmd);
    is( $params->[0], '9T9', 'Correct SID: 9T9' );
    is( $params->[1], 'Remote host closed the connection', 'Remote host closed the connection' );
    $poe_kernel->post( $sender, 'terminate' );
    return;
  }
  return;
}

sub harpo_input {
  my ($heap,$in) = @_[HEAP,ARG0];
  #diag($in->{raw_line}, "\n");
  my $prefix = $in->{prefix};
  my $cmd    = $in->{command};
  my $params = $in->{params};
  if ( $cmd eq 'SJOIN' ) {
    pass($cmd);
    is( $prefix, '1FU', 'Correct prefix: 1FU' );
    like( $params->[0], qr/\d+/, 'Looks like a timestamp' );
    is( $params->[1], '#potato', 'Channel is correct: #potato' );
    is( $params->[2], '+nt', 'Correct chanmodes applied: +nt' );
    is( $params->[3], '@1FUAAAAAA', 'Got a correct UID + status: @1FUAAAAAA' );
    return;
  }
  if ( $cmd eq 'TOPIC' ) {
    pass($cmd);
    is( $prefix, '1FUAAAAAA', 'Correct prefix: 1FUAAAAAAA' );
    is( $params->[0], '#potato', 'Channel is correct: #potato' );
    return;
  }
  if ( $cmd eq 'TMODE' ) {
    pass($cmd);
    is( $prefix, '1FUAAAAAA', 'Correct prefix: 1FUAAAAAAA' );
    like( $params->[0], qr/\d+/, 'Looks like a timestamp' );
    is( $params->[1], '#potato', 'Channel is correct: #potato' );
    is( $params->[2], '+c', 'Correct chanmodes applied: +c' );
    return;
  }
  if ( $cmd eq 'PART' ) {
    pass($cmd);
    is( $prefix, '1FUAAAAAA', 'Correct prefix: 1FUAAAAAAA' );
    is( $params->[0], '#potato', 'Channel is correct: #potato' );
    is( $params->[1], 'Suckers', 'There is a parting messge' );
    return;
  }
  if ( $cmd eq 'QUIT' ) {
    pass($cmd);
    is( $prefix, '1FUAAAAAA', 'Correct prefix: 1FUAAAAAAA' );
    is( $params->[0], q{Quit: "Connection reset by fear"}, 'Correct QUIT message' );
    return;
  }
  return;
}

sub client_disconnected {
  my ($heap,$state,$sender) = @_[HEAP,STATE,SENDER];
  pass($state);
  return;
}

sub groucho_disconnected {
  my ($heap,$state,$sender) = @_[HEAP,STATE,SENDER];
  pass($state);
  $poe_kernel->call( $sender, 'shutdown' );
  $heap->{ircd}->yield('shutdown');
  $poe_kernel->delay('_shutdown');
  return;
}

sub harpo_disconnected {
  my ($heap,$state,$sender) = @_[HEAP,STATE,SENDER];
  pass($state);
  $poe_kernel->call( $sender, 'shutdown' );
  #$poe_kernel->post( 'groucho', 'terminate' );
  return;
}

sub ircd_daemon_eob {
  my ($kernel,$heap,$sender,@args) = @_[KERNEL,HEAP,SENDER,ARG0..$#_];
  $heap->{eob}++;
  pass($_[STATE]);
  if ( defined $servers{ $args[0] } ) {
    pass('Correct server name in EOB: ' . $args[0]);
    is( $args[1], $servers{ $args[0] }, 'Correct server ID in EOB: ' . $args[1] );
  }
  else {
    fail('No such server expected');
  }
  if ( $heap->{eob} >= 3 ) {
      $poe_kernel->yield('_launch_client');
  }
  return;
}
