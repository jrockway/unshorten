use MooseX::Declare;
use Unshorten::Model;
use POE;
use HTTP::Engine::Role; # for type constraints
use feature 'say';

class Unshorten with MooseX::Getopt with MooseX::Runnable with HTTP::Engine::Role {
    has '_engine_type' => ( is => 'ro', default => 'POE' );

    has 'dsn' => (
        is            => 'ro',
        isa           => 'Str',
        required      => 1,
        default       => 'hash',
        documentation => 'DSN of the KiokuDB',
    );

    has 'model' => (
        traits     => ['NoGetopt'],
        is         => 'ro',
        isa        => 'Unshorten::Model',
        lazy_build => 1,
    );

    method _build_model() {
        return Unshorten::Model->new( dsn => $self->dsn );
    }

    method handle_request(HTTP::Engine::Request $req){

        my $short = URI->new(substr $req->uri->path, 1);

        my $long = eval { $self->model->unshorten($short) };
        if(!$long || $@){
            return HTTP::Engine::Response->new(
                code         => 500,
                content_type => 'text/plain',
                body         => "An error occurred while shortening '$short': $@",
            );
        }

        return HTTP::Engine::Response->new(
            content_type => 'text/plain',
            body         => $long,
        );
    }

    method run() {
        $self->engine->run;
        say "Starting server on port ". $self->port;
        POE::Kernel->run;
    }

};
