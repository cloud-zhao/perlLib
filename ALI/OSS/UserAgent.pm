package ALI::OSS::UserAgent;
use Mojo::Base 'Mojo::EventEmitter';

use Mojo::IOLoop;
use Mojo::Util qw(monkey_patch term_escape);
use Mojo::UserAgent::CookieJar;
use Mojo::UserAgent::Proxy;
use Mojo::UserAgent::Server;
use Mojo::UserAgent::Transactor;
use Scalar::Util 'weaken';

use constant DEBUG => $ENV{MOJO_USERAGENT_DEBUG} || 0;

has ca              => sub { $ENV{MOJO_CA_FILE} };
has cert            => sub { $ENV{MOJO_CERT_FILE} };
has connect_timeout => sub { 30 };
has cookie_jar      => sub { Mojo::UserAgent::CookieJar->new };
has 'local_address';
has inactivity_timeout => sub { 30 };
has ioloop             => sub { Mojo::IOLoop->new };
has key                => sub { $ENV{MOJO_KEY_FILE} };
has max_connections    => 5;
has max_redirects => sub { $ENV{MOJO_MAX_REDIRECTS} || 0 };
has proxy => sub { Mojo::UserAgent::Proxy->new };
has request_timeout => sub { 180 };
has server => sub { Mojo::UserAgent::Server->new(ioloop => shift->ioloop) };
has transactor => sub { Mojo::UserAgent::Transactor->new };

# Common HTTP methods
sub send_request{
    my $self = shift;
    my $name=shift;
    my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
    return $self->start($self->build_tx($name, @_), $cb);
}

sub DESTROY { Mojo::Util::_global_destruction() or shift->_cleanup }

sub build_tx           { shift->transactor->tx(@_) }

sub start {
  my ($self, $tx, $cb) = @_;

  # Fork-safety
  $self->_cleanup->server->restart unless ($self->{pid} //= $$) eq $$;

  # Non-blocking
  if ($cb) {
    warn "-- Non-blocking request (@{[_url($tx)]})\n" if DEBUG;
    return $self->_start(1, $tx, $cb);
  }

  # Blocking
  warn "-- Blocking request (@{[_url($tx)]})\n" if DEBUG;
  $self->_start(0, $tx => sub { shift->ioloop->stop; $tx = shift });
  $self->ioloop->start;

  return $tx;
}

sub _cleanup {
  my $self = shift;

  # Clean up active connections (by closing them)
  delete $self->{pid};
  $self->_finish($_, 1) for keys %{$self->{connections} || {}};

  # Clean up keep-alive connections
  my $loop = $self->_loop(0);
  $loop->remove($_->[1]) for @{delete $self->{queue} || []};
  $loop = $self->_loop(1);
  $loop->remove($_->[1]) for @{delete $self->{nb_queue} || []};

  return $self;
}

sub _connect {
  my ($self, $nb, $peer, $tx, $handle, $cb) = @_;

  my $t = $self->transactor;
  my ($proto, $host, $port) = $peer ? $t->peer($tx) : $t->endpoint($tx);
  my %options
    = (address => $host, port => $port, timeout => $self->connect_timeout);
  if (my $local = $self->local_address) { $options{local_address} = $local }
  $options{handle} = $handle if $handle;

  # SOCKS
  if ($proto eq 'socks') {
    @options{qw(socks_address socks_port)} = @options{qw(address port)};
    ($proto, @options{qw(address port)}) = $t->endpoint($tx);
    my $req      = $tx->req;
    my $userinfo = $req->proxy->userinfo;
    $req->proxy(0);
    @options{qw(socks_user socks_pass)} = split ':', $userinfo if $userinfo;
  }

  # TLS
  map { $options{"tls_$_"} = $self->$_ } qw(ca cert key)
    if ($options{tls} = $proto eq 'https');

  weaken $self;
  my $id;
  return $id = $self->_loop($nb)->client(
    %options => sub {
      my ($loop, $err, $stream) = @_;

      # Connection error
      return unless $self;
      return $self->_error($id, $err) if $err;

      # Connection established
      $stream->on(timeout => sub { $self->_error($id, 'Inactivity timeout') });
      $stream->on(close => sub { $self && $self->_finish($id, 1) });
      $stream->on(error => sub { $self && $self->_error($id, pop) });
      $stream->on(read => sub { $self->_read($id, pop) });
      $self->$cb($id);
    }
  );
}

sub _connect_proxy {
  my ($self, $nb, $old, $cb) = @_;

  # Start CONNECT request
  return undef unless my $new = $self->transactor->proxy_connect($old);
  return $self->_start(
    ($nb, $new) => sub {
      my ($self, $tx) = @_;

      # CONNECT failed (connection needs to be kept alive)
      $old->res->error({message => 'Proxy connection failed'})
        and return $self->$cb($old)
        if $tx->error || !$tx->res->is_status_class(200) || !$tx->keep_alive;

      # Start real transaction
      $old->req->proxy(0);
      my $id = $tx->connection;
      return $self->_start($nb, $old->connection($id), $cb)
        unless $tx->req->url->protocol eq 'https';

      # TLS upgrade
      my $loop   = $self->_loop($nb);
      my $handle = $loop->stream($id)->steal_handle;
      $loop->remove($id);
      $id = $self->_connect($nb, 0, $old, $handle,
        sub { shift->_start($nb, $old->connection($id), $cb) });
      $self->{connections}{$id} = {cb => $cb, nb => $nb, tx => $old};
    }
  );
}

sub _connected {
  my ($self, $id) = @_;

  # Inactivity timeout
  my $c = $self->{connections}{$id};
  my $stream
    = $self->_loop($c->{nb})->stream($id)->timeout($self->inactivity_timeout);

  # Store connection information in transaction
  my $tx     = $c->{tx}->connection($id);
  my $handle = $stream->handle;
  $tx->local_address($handle->sockhost)->local_port($handle->sockport);
  $tx->remote_address($handle->peerhost)->remote_port($handle->peerport);

  # Start writing
  weaken $self;
  $tx->on(resume => sub { $self->_write($id) });
  $self->_write($id);
}

sub _connection {
  my ($self, $nb, $tx, $cb) = @_;

  # Reuse connection
  my ($proto, $host, $port) = $self->transactor->endpoint($tx);
  my $id = $tx->connection || $self->_dequeue($nb, "$proto:$host:$port", 1);
  if ($id) {
    warn "-- Reusing connection $id ($proto://$host:$port)\n" if DEBUG;
    $self->{connections}{$id} = {cb => $cb, nb => $nb, tx => $tx};
    $tx->kept_alive(1) unless $tx->connection;
    $self->_connected($id);
    return $id;
  }

  # CONNECT request to proxy required
  if (my $id = $self->_connect_proxy($nb, $tx, $cb)) { return $id }

  # Connect
  $id = $self->_connect($nb, 1, $tx, undef, \&_connected);
  warn "-- Connect $id ($proto://$host:$port)\n" if DEBUG;
  $self->{connections}{$id} = {cb => $cb, nb => $nb, tx => $tx};

  return $id;
}

sub _dequeue {
  my ($self, $nb, $name, $test) = @_;

  my $loop = $self->_loop($nb);
  my $old = $self->{$nb ? 'nb_queue' : 'queue'} ||= [];
  my ($found, @new);
  for my $queued (@$old) {
    push @new, $queued and next if $found || !grep { $_ eq $name } @$queued;

    # Search for id/name and sort out corrupted connections if necessary
    next unless my $stream = $loop->stream($queued->[1]);
    $test && $stream->is_readable ? $stream->close : ($found = $queued->[1]);
  }
  @$old = @new;

  return $found;
}

sub _enqueue {
  my ($self, $nb, $name, $id) = @_;

  # Enforce connection limit
  my $queue = $self->{$nb ? 'nb_queue' : 'queue'} ||= [];
  my $max = $self->max_connections;
  $self->_remove(shift(@$queue)->[1]) while @$queue && @$queue >= $max;
  $max ? push @$queue, [$name, $id] : $self->_loop($nb)->stream($id)->close;
}

sub _error {
  my ($self, $id, $err) = @_;
  my $tx = $self->{connections}{$id}{tx};
  $tx->res->error({message => $err}) if $tx;
  $self->_finish($id, 1);
}

sub _finish {
  my ($self, $id, $close) = @_;

  # Remove request timeout
  return unless my $c = $self->{connections}{$id};
  my $loop = $self->_loop($c->{nb});
  $loop->remove($c->{timeout}) if $c->{timeout};

  return $self->_remove($id, $close) unless my $old = $c->{tx};
  $old->client_close($close);

  # Finish WebSocket
  return $self->_remove($id, 1) if $old->is_websocket;

  if (my $jar = $self->cookie_jar) { $jar->collect($old) }

  # Upgrade connection to WebSocket
  if (my $new = $self->transactor->upgrade($old)) {
    weaken $self;
    $new->on(resume => sub { $self->_write($id) });
    $c->{cb}($self, $c->{tx} = $new);
    return $new->client_read($old->res->content->leftovers);
  }

  # Finish normal connection and handle redirects
  $self->_remove($id, $close);
  $c->{cb}($self, $old) unless $self->_redirect($c, $old);
}

sub _loop { $_[1] ? Mojo::IOLoop->singleton : $_[0]->ioloop }

sub _read {
  my ($self, $id, $chunk) = @_;

  # Corrupted connection
  return                     unless my $c  = $self->{connections}{$id};
  return $self->_remove($id) unless my $tx = $c->{tx};

  # Process incoming data
  warn term_escape "-- Client <<< Server (@{[_url($tx)]})\n$chunk\n" if DEBUG;
  $tx->client_read($chunk);
  if    ($tx->is_finished) { $self->_finish($id) }
  elsif ($tx->is_writing)  { $self->_write($id) }
}

sub _redirect {
  my ($self, $c, $old) = @_;
  return undef unless my $new = $self->transactor->redirect($old);
  return undef unless @{$old->redirects} < $self->max_redirects;
  return $self->_start($c->{nb}, $new, delete $c->{cb});
}

sub _remove {
  my ($self, $id, $close) = @_;

  # Close connection
  my $c = delete $self->{connections}{$id} || {};
  my $tx = $c->{tx};
  return map { $self->_dequeue($_, $id); $self->_loop($_)->remove($id) } 1, 0
    if $close || !$tx || !$tx->keep_alive || $tx->error;

  # Keep connection alive (CONNECT requests get upgraded)
  $self->_enqueue($c->{nb}, join(':', $self->transactor->endpoint($tx)), $id)
    unless uc $tx->req->method eq 'CONNECT';
}

sub _start {
  my ($self, $nb, $tx, $cb) = @_;

  # Application server
  my $url = $tx->req->url;
  unless ($url->is_abs) {
    my $base = $nb ? $self->server->nb_url : $self->server->url;
    $url->scheme($base->scheme)->authority($base->authority);
  }

  $_ && $_->prepare($tx) for $self->proxy, $self->cookie_jar;

  # Connect and add request timeout if necessary
  my $id = $self->emit(start => $tx)->_connection($nb, $tx, $cb);
  if (my $timeout = $self->request_timeout) {
    weaken $self;
    $self->{connections}{$id}{timeout} = $self->_loop($nb)
      ->timer($timeout => sub { $self->_error($id, 'Request timeout') });
  }

  return $id;
}

sub _url { shift->req->url->to_abs }

sub _write {
  my ($self, $id) = @_;

  # Get and write chunk
  return unless my $c  = $self->{connections}{$id};
  return unless my $tx = $c->{tx};
  return if !$tx->is_writing || $c->{writing}++;
  my $chunk = $tx->client_write;
  delete $c->{writing};
  warn term_escape "-- Client >>> Server (@{[_url($tx)]})\n$chunk\n" if DEBUG;
  my $stream = $self->_loop($c->{nb})->stream($id)->write($chunk);
  $self->_finish($id) if $tx->is_finished;

  # Continue writing
  return unless $tx->is_writing;
  weaken $self;
  $stream->write('' => sub { $self->_write($id) });
}

1;

