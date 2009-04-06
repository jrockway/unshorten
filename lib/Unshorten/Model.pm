use MooseX::Declare;

class Unshorten::Model extends KiokuX::Model {
    use Moose::Util::TypeConstraints;
    use MooseX::Types::URI qw(Uri);

    use AnyEvent::HTTP qw(http_head);

    method unshorten(Uri $url) {
        return $self->_lookup_or_cache($url, sub {
            $self->_lookup(@_),
        });
    }

    method _lookup(Uri $url) {
        my $done = AnyEvent->condvar;

        http_head $url, sub {
            my ($data, $headers) = @_;
            my $long_url = eval { URI->new($headers->{URL}) };
            confess 'Failed to get a URL' unless $url;
            $done->send($long_url);
        };

        return $done->recv;
    }

    method _lookup_or_cache(Uri $url, CodeRef $shortener) {
        my $scope = $self->new_scope;
        my $shortened = $self->lookup("$url");
        return $shortened if $shortened;

        $shortened = $shortener->($url);

        # "Unknown reason" because the shortener should die if it knows
        # the reason
        confess "Unable to shorten '$url': Unknown reason"
          unless $shortened;

        $self->store("$url" => $shortened);

        return $shortened;
    }

};
