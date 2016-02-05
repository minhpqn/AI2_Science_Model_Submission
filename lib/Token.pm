package Token;
use Lingua::Stem::Snowball;
use base qw/Class::Accessor/;
use Carp qw/confess/;
use strict;
use warnings;
use utf8;

sub new {
    my ($classname, $args) = @_;
    if ( ref $classname ) {
        confess "Class name is needed\n";
    }
    my $self = bless( {}, $classname );

    my @args = qw(word lemma pos);
    __PACKAGE__->mk_ro_accessors(@args);
    __PACKAGE__->mk_ro_accessors(qw(stem));

    if ( !defined $args || ref $args ne 'HASH' ) {
        confess "argument must be HASH reference\n";
    }

    for my $arg ( @args ) {
        if ( !exists $args->{$arg} ) {
            confess "$arg is missing\n";
        }
        $self->{$arg} = $args->{$arg};
    }

    my $stemmer = Lingua::Stem::Snowball->new( lang => 'en' );
    $self->{stem} = $stemmer->stem( $self->{word} ); 

    return $self;
}

sub is_noun {
    my ($self) = @_;

    return 1 if ( $self->pos =~ /^NN/ );
    return 0;
}

sub is_verb {
    my ($self) = @_;

    return 1 if ( $self->pos =~ /^VB/ );
    return 0;
}

sub is_adj {
    my ($self) = @_;

    return 1 if ( $self->pos =~ /^JJ/ );
    return 0;
}

sub is_adv {
    my ($self) = @_;

    return 1 if ( $self->pos =~ /^RB/ );
    return 0;
}

1;

