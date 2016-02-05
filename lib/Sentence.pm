package Sentence;
use base qw/Class::Accessor/;
use Token;
use Carp qw/confess/;
use strict;
use warnings;
use utf8;

sub new {
    my ($classname) = @_;
    
    if ( ref $classname ) {
        confess "Class name is needed\n";
    }
    my $self = bless( {}, $classname );

    $self->{tokens}   = [ ];
    $self->{triplets} = [ ];

    return $self;
}

# return string of the sentence
sub to_s {
    my ( $self ) = @_;
    my $str;
    if ( exists $self->{__to_s} ) {
        $str = $self->{__to_s};
    }
    else {
        $str = join(' ' => map { $_->word() } $self->tokens());
        $self->{__to_s} = $str;
    }
    return $str;
}

sub add_token {
    my ($self, $tok) = @_;

    push @{$self->{tokens}}, $tok;
}

# Add ARRAY of [$rel, $gov, $dep]
sub add_triplet {
    my ($self, $triplet) = @_;
    if ( !defined $triplet || ref $triplet ne 'ARRAY' ) {
        confess "Invalid input triplet\n";
    }

    push @{ $self->{triplets} }, $triplet;
}

# return token given real token's id (index starts from 1)
sub token_at {
    my ($self, $tid) = @_;
    return $self->tokens_ref->[$tid-1];
}

# return token given token's id in array (index starts from 0)
sub at {
    my ( $self, $i ) = @_;
    return $self->tokens_ref->[$i];
}

sub tokens {
    my ($self) = @_;
    return @{$self->{tokens}};
}

sub word_pos_pairs {
    my ( $self ) = @_;
    return map { join("/", $_->word, $_->pos ) } $self->tokens;
}

sub word_pos_pairs_string {
    my ( $self ) = @_;

    return join(" ", $self->word_pos_pairs);
}

sub POS_tags {
    my ( $self ) = @_;
    return map { $_->pos } $self->tokens;
}

sub tokens_ref {
    my ($self) = @_;
    return $self->{tokens};
}

sub num_token {
    my ( $self ) = @_;
    my $num_token = $self->tokens;

    return $num_token;
}

sub triplets {
    my ($self) = @_;
    return @{$self->{triplets}};
}

sub triplets_ref {
    my ($self) = @_;
    return $self->{triplets};
}

# return all dependency relations
# in the format: rel::gov::dep
sub lemma_dep_rels {
    my ($self, $args) = @_;
    my $no_relation = 0;
    $no_relation = 1 if (exists $args->{no_relation} && $args->{no_relation});
        
    my @res;
    for my $tp ( $self->triplets ) {
        my $gov = $tp->[1];
        my $dep = $tp->[2];

        my $gov_lemma = $gov == 0 ? 'ROOT' : $self->token_at($gov)->lemma;
        my $dep_lemma = $dep == 0 ? 'ROOT' : $self->token_at($dep)->lemma;
        
        my $drel;
        if ( $no_relation ) {
            $drel = join("||", $gov_lemma, $dep_lemma);
        }
        else {
            $drel = join("::", $tp->[0], $gov_lemma, $dep_lemma);
        }
        push @res, $drel;
    }
    return @res;
}

1;
