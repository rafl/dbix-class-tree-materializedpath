use strict;
use warnings;

package TestSchema::Result::Affe;

use parent 'DBIx::Class';

__PACKAGE__->load_components(qw/Tree::MaterializedPath Core/);
__PACKAGE__->table('affe');

__PACKAGE__->add_columns(
    id => {
        data_type         => 'integer',
        is_auto_increment => 1,
    },
    content => { data_type => 'text' },
    path    => { data_type => 'varchar', is_nullable => 1 },
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->materialized_path_columns({
    id           => 'id',
    path         => 'path',
    parent_rel   => 'parent',
    parents_rel  => 'parents',
    children_rel => 'children',
    siblings_rel => 'siblings',
});

1;
