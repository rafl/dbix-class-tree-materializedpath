use strict;
use warnings;
use Test::More tests => 49;
use Test::Exception;
use DBICx::TestDatabase;

use FindBin;
use lib "$FindBin::Bin/lib";

BEGIN { use_ok('TestSchema') }

my $schema = DBICx::TestDatabase->new('TestSchema');
isa_ok($schema, 'DBIx::Class::Schema');

my $affe = $schema->resultset('Affe');
isa_ok($affe, 'DBIx::Class::ResultSet');

my @roots = map { $affe->create({ content => $_ }) } qw/foo bar/;

for my $root (@roots) {
    isa_ok($root, 'DBIx::Class::Row');
    is($root->path, $root->id, 'root nodes have their pk as path');

    ok($root->is_root, 'is_root on root nodes');
    ok(!$root->is_branch, 'root node is not a branch');
    ok($root->is_leaf, 'root nodes without children are leafs');

    can_ok($root, 'parent');
    is($root->parent, undef, 'root nodes have no direct parent');

    can_ok($root, 'parents');
    is($root->parents->count, 0, 'root nodes have no parents');

    can_ok($root, 'siblings');
    is($root->siblings->count, 0, 'root nodes have no siblings');

    throws_ok(sub {
        $root->attach_siblings;
    }, qr/siblings to root/);
}

=pod

- foo
-- child 0
--- child 1
---- child 3
---- child 5
-- child 2
--- child 4
- bar

=cut

my @childs = map { $affe->new_result({ content => $_ }) } 0 .. 5;
$roots[0]->attach_children($childs[0]);
$childs[0]->attach_children($childs[1]);
$childs[0]->attach_siblings($childs[2]);
$childs[1]->attach_children($childs[3]);
$childs[2]->attach_children($childs[4]);
$childs[3]->attach_siblings($childs[5]);

ok($roots[1]->is_root);
ok($roots[1]->is_leaf);
ok(!$roots[1]->is_branch);
is($roots[1]->parent, undef);
is($roots[1]->parents->count, 0);
is($roots[1]->siblings->count, 0);
is($roots[1]->children->count, 0);

ok($roots[0]->is_root);
ok(!$roots[0]->is_leaf);
ok(!$roots[0]->is_branch);
is($roots[0]->parent, undef);
is($roots[0]->parents->count, 0);
is($roots[0]->siblings->count, 0);
is($roots[0]->children->count, 6);

is_deeply([sort map { $_->content } $childs[2]->children->all], [4]);
is_deeply([sort map { $_->content } $childs[2]->siblings->all], [0]);
is_deeply([sort map { $_->content } $childs[2]->parents->all], ['foo']);
is($childs[2]->parent->content, 'foo');

is_deeply([sort map { $_->content } $childs[0]->children->all], [1, 3, 5]);
is_deeply([sort map { $_->content } $childs[0]->siblings->all], [2]);
is_deeply([sort map { $_->content } $childs[0]->parents->all], ['foo']);
is($childs[0]->parent->content, 'foo');
