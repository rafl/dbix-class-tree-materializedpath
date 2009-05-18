use strict;
use warnings;

package DBIx::Class::Tree::MaterializedPath;

use parent 'DBIx::Class';
use Sub::Install 'install_sub';
use Carp 'confess';

use namespace::autoclean;

__PACKAGE__->mk_classdata( _materialized_path_columns => {} );

sub materialized_path_columns {
    my ($class, $args) = @_;

    if ($args) {
        $args = {
            parent_rel   => 'parent',
            parents_rel  => 'parents',
            children_rel => 'children',
            siblings_rel => 'siblings',
            %{ $args },
        };

        my ($path, $id) = @{ $args }{qw/path_column id_column/};

        install_sub({
            into => $class,
            as   => $args->{parent_rel},
            code => sub {
                my ($self) = @_;
                my $parent_id = (split('\.', $self->$path))[-2];
                return unless defined $parent_id;
                return $self->result_source->resultset->find({ $id => $parent_id });
            },
        });

        install_sub({
            into => $class,
            as   => $args->{parents_rel},
            code => sub {
                my ($self) = @_;
                my @path = split('\.', $self->path);
                return $self->result_source->resultset->search_rs({
                    $id => { -in => [@path[0 .. $#path - 1]] },
                });
            },
        });

        install_sub({
            into => $class,
            as   => $args->{children_rel},
            code => sub {
                my ($self) = @_;

                return $self->result_source->resultset->search_rs({
                    $path => { -like => $self->$path . '.%' },
                });
            },
        });

        install_sub({
            into => $class,
            as   => 'attach_' . $args->{children_rel},
            code => sub {
                my ($self, @children) = @_;

                $self->result_source->schema->txn_do(sub {
                    for my $child (@children) {
                        $child->insert_or_update;
                        $child->update({ $path => $self->$path . '.' . $child->$id });
                    }
                });
                return;
            },
        });

        install_sub({
            into => $class,
            as   => $args->{siblings_rel},
            code => sub {
                my ($self) = @_;

                my @path = split('\.', $self->$path);
                my $parent_path = join '.' => @path[0 .. $#path - 1];

                return $self->result_source->resultset->search_rs({
                    -and => [
                        $path => { -like     => $parent_path . '.%'   },
                        $path => { -not_like => $parent_path . '.%.%' },
                    ],
                    id => { '!=' => $self->$id },
                });
            },
        });

        install_sub({
            into => $class,
            as   => 'attach_' . $args->{siblings_rel},
            code => sub {
                my ($self, @siblings) = @_;
                confess "Can't attach siblings to root node"
                    if $self->is_root;

                my @path = split('\.', $self->$path);
                my $parent_path = join '.' => @path[0 .. $#path - 1];

                $self->result_source->schema->txn_do(sub {
                    for my $sib (@siblings) {
                        $sib->insert_or_update;
                        $sib->update({ $path => $parent_path . '.' . $sib->$id });
                    }
                });
                return;
            },
        });

        $class->_materialized_path_columns($args);
    }

    return $class->_materialized_path_columns;
}

sub is_root {
    my ($self) = @_;
    my ($id, $path) = @{ $self->materialized_path_columns }{qw/id_column path_column/};
    return $self->id eq $self->path;
}

sub is_leaf {
    my ($self) = @_;
    my $children = $self->_materialized_path_columns->{children_rel};
    return !$self->$children->count;
}

sub is_branch {
    my ($self) = @_;
    return !($self->is_leaf or $self->is_root);
}

sub insert {
    my ($self, @args) = @_;
    my ($id, $path) = @{ $self->materialized_path_columns }{qw/id_column path_column/};

    return $self->next::method(@args)
        if $self->$path;

    my $row;
    my $next = $self->next::can;
    $self->result_source->schema->txn_do(sub {
        $self->set_column($path => 'fake');
        $row = $self->$next(@args);
        $row->update({ $path => $row->$id });
    });

    return $row;
}

1;
