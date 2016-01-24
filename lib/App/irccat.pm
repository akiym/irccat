package App::irccat;
use 5.008001;
use strict;
use warnings;
use Carp ();
use Getopt::Long ();
use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::IRC::Client;

our $VERSION = "0.01";

sub new {
    my ($class, %args) = @_;
    return bless {
        host => undef,
        port => 6667,
        nick => $class->random_nick(),
        %args,
    }, $class;
}

sub run {
    my ($self, @args) = @_;

    my $p = Getopt::Long::Parser->new(
        config => [qw/no_ignore_case pass_through/],
    );
    $p->getoptionsfromarray(
        \@args,
        'host=s'     => \$self->{host},
        'port=s'     => \$self->{port},
        'nick=s'     => \$self->{nick},
        'user=s'     => \$self->{user},
        'password=s' => \$self->{password},
        'channel=s'  => \$self->{channel},
        'v|verbose'  => \$self->{verbose},
        'h|help'     => \$self->{help},
    );

    if ($self->{help}) {
        return $self->help();
    }

    for my $key (qw/host channel/) {
        unless (defined $self->{$key}) {
            Carp::croak("Missing $key parameter");
        }
    }
    if (length $self->{nick} > 9) {
        Carp::croak("Maximum nickname length is 9");
    }
    unless ($self->{channel} =~ /^#/) {
        $self->{channel} = '#' . $self->{channel};
    }

    $self->handle();

    return 0;
}

sub handle {
    my $self = shift;

    my $cv = AE::cv;

    my $hdl; $hdl = AnyEvent::Handle->new(
        fh       => \*STDIN,
        on_error => sub {
            my ($hdl, $fatal, $msg) = @_;
            AE::log(error => $msg);
            $hdl->destroy;
            $cv->send;
        },
    );

    my $con = AnyEvent::IRC::Client->new();
    $con->reg_cb(connect => sub {
        my ($con, $err) = @_;
        if ($err) {
            warn "Connection error: $err\n";
            $cv->send;
        } else {
            if ($self->{verbose}) {
                warn "Joining $self->{channel} channel...\n";
            }
            $con->send_srv(JOIN => $self->{channel});
        }
    });
    $con->reg_cb(join => sub {
        my ($con, $nick, $channel, $is_myself) = @_;
        if ($is_myself) {
            if ($self->{verbose}) {
                warn "Joined.\n";
            }
            $hdl->on_read(sub {
                my ($hdl) = @_;
                $hdl->push_read(line => sub {
                    my ($hdl, $line) = @_;
                    $con->send_chan($self->{channel}, 'NOTICE', $self->{channel}, $line);
                });
            });
        }
    });

    if ($self->{verbose}) {
        warn "Connecting $self->{host}:$self->{port} (nick: $self->{nick})\n";
    }
    $con->connect($self->{host}, $self->{port}, {
        nick => $self->{nick},
        (exists $self->{user} ?
            (user => $self->{user}) : ()),
        (exists $self->{password} ?
            (password => $self->{password}) : ()),
    });

    $cv->recv;
}

sub help {
    print <<'...';
Usage: irccat --channel=#channel --host=127.0.0.1 [--port=6667] [--nick=irccat] [--user=user] [--password=password]

Example:
    % irccat --channel=#test --host=127.0.0.1 <<< 'hello~'

    % tail -f /var/log/messages | irccat --channel=#test --host=127.0.0.1
...

    return 1;
}

sub random_nick {
    my $class = shift;
    my @chars = ('0'..'9', 'a'..'z');
    my $random = '';
    for my $i (1..2) {
        $random .= $chars[int rand @chars];
    }
    return 'irccat_' . $random;
}

1;
__END__

=encoding utf-8

=head1 NAME

App::irccat - Redirect Pipe to IRC Channel

=head1 SYNOPSIS

    use App::irccat;
    exit(App::irccat->new->run(@ARGV));

=head1 DESCRIPTION

App::irccat is ...

=head1 LICENSE

Copyright (C) Takumi Akiyama.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Takumi Akiyama E<lt>t.akiym@gmail.comE<gt>

=cut
