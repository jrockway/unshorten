use MooseX::Declare;

class Unshorten::Model extends KiokuX::Model {
    use Moose::Util::TypeConstraints;
    use MooseX::Types::URI qw(Uri);

    use AnyEvent::HTTP qw(http_head);

    method unshorten(Uri $url) {
        return $self->_resolve_or_cache($url, sub {
            $self->_resolve_url(@_),
        });
    }

    method _resolve_url(Uri $url) {
        my $done = AnyEvent->condvar;

        http_head $url, sub {
            my ($data, $headers) = @_;
            my $long_url = eval { URI->new($headers->{URL}) };
            confess 'Failed to get a URL' unless $long_url;
            $done->send($long_url);
        };

        return $done->recv;
    }

    method _resolve_or_cache(Uri $url, CodeRef $expander) {
        my $scope = $self->new_scope;
        my $expanded = $self->lookup("$url");
        return $expanded->{redirects_to} if $expanded;

        # needs to be expanded
        $expanded = $expander->($url);

        # "Unknown reason" because the shortener should die if it knows
        # the reason
        confess "Unable to shorten '$url': Unknown reason"
          unless $expanded;

        $self->insert("$url" => { redirects_to => $expanded });

        return $expanded;
    }

};
