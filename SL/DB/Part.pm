package SL::DB::Part;

use strict;

use Carp;
use SL::DBUtils;
use SL::DB::MetaSetup::Part;
use SL::DB::Manager::Part;

__PACKAGE__->meta->add_relationships(
  unit_obj                     => {
    type         => 'one to one',
    class        => 'SL::DB::Unit',
    column_map   => { unit => 'name' },
  },
  assemblies                     => {
    type         => 'one to many',
    class        => 'SL::DB::Assembly',
    column_map   => { id => 'id' },
  },
);

__PACKAGE__->meta->initialize;

sub is_type {
  my $self = shift;
  my $type  = lc(shift || '');
  die 'invalid type' unless $type =~ /^(?:part|service|assembly)$/;

  return $self->type eq $type ? 1 : 0;
}

sub is_part     { $_[0]->is_type('part') }
sub is_assembly { $_[0]->is_type('assembly') }
sub is_service  { $_[0]->is_type('service') }

sub type {
  my ($self, $type) = @_;
  if (@_ > 1) {
    die 'invalid type' unless $type =~ /^(?:part|service|assembly)$/;
    $self->assembly(          $type eq 'assembly' ? 1 : 0);
    $self->inventory_accno_id($type ne 'service'  ? 1 : undef);
  }

  return 'assembly' if $self->assembly;
  return 'part'     if $self->inventory_accno_id;
  return 'service';
}

sub new_part {
  my ($class, %params) = @_;
  $class->new(%params, type => 'part');
}

sub new_assembly {
  my ($class, %params) = @_;
  $class->new(%params, type => 'assembly');
}

sub new_service {
  my ($class, %params) = @_;
  $class->new(%params, type => 'service');
}

sub orphaned {
  my ($self) = @_;
  die 'not an accessor' if @_ > 1;

  my @relations = qw(
    SL::DB::InvoiceItem
    SL::DB::OrderItem
    SL::DB::Inventory
    SL::DB::RMAItem
  );

  for my $class (@relations) {
    eval "require $class";
    return 0 if $class->_get_manager_class->get_all_count(query => [ parts_id => $self->id ]);
  }
  return 1;
}

sub get_sellprice_info {
  my $self   = shift;
  my %params = @_;

  confess "Missing part id" unless $self->id;

  my $object = $self->load;

  return { sellprice       => $object->sellprice,
           price_factor_id => $object->price_factor_id };
}

sub get_ordered_qty {
  my $self   = shift;
  my %result = SL::DB::Manager::Part->get_ordered_qty($self->id);

  return $result{ $self->id };
}

sub available_units {
  shift->unit_obj->convertible_units;
}

1;

__END__

=pod

=head1 NAME

SL::DB::Part: Model for the 'parts' table

=head1 SYNOPSIS

This is a standard Rose::DB::Object based model and can be used as one.

=head1 TYPES

Although the base class is called C<Part> we usually talk about C<Articles> if
we mean instances of this class. This is because articles come in three
flavours called:

=over 4

=item Part     - a single part

=item Service  - a part without onhand, and without inventory accounting

=item Assembly - a collection of both parts and services

=back

These types are sadly represented by data inside the class and cannot be
migrated into a flag. To work around this, each C<Part> object knows what type
it currently is. Since the type ist data driven, there ist no explicit setting
method for it, but you can construct them explicitly with C<new_part>,
C<new_service>, and C<new_assembly>. A Buchungsgruppe should be supplied in this
case, but it will use the default Buchungsgruppe if you don't.

Matching these there are assorted helper methods dealing with type:

=head2 new_part PARAMS

=head2 new_service PARAMS

=head2 new_assembly PARAMS

Will set the appropriate data fields so that the resulting instance will be of
tthe requested type. Since part of the distinction are accounting targets,
providing a C<Buchungsgruppe> is recommended. If none is given the constructor
will load a default one and set the accounting targets from it.

=head2 type

Returns the type as a string. Can be one of C<part>, C<service>, C<assembly>.

=head2 is_type TYPE

Tests if the current object is a part, a service or an
assembly. C<$type> must be one of the words 'part', 'service' or
'assembly' (their plurals are ok, too).

Returns 1 if the requested type matches, 0 if it doesn't and
C<confess>es if an unknown C<$type> parameter is encountered.

=head2 is_part

=head2 is_service

=head2 is_assembly

Shorthand for is_type('part') etc.

=head1 FUNCTIONS

=head2 get_sellprice_info %params

Retrieves the C<sellprice> and C<price_factor_id> for a part under
different conditions and returns a hash reference with those two keys.

If C<%params> contains a key C<project_id> then a project price list
will be consulted if one exists for that project. In this case the
parameter C<country_id> is evaluated as well: if a price list entry
has been created for this country then it will be used. Otherwise an
entry without a country set will be used.

If none of the above conditions is met then the information from
C<$self> is used.

=head2 get_ordered_qty %params

Retrieves the quantity that has been ordered from a vendor but that
has not been delivered yet. Only open purchase orders are considered.

=head2 orphaned

Checks if this articke is used in orders, invoices, delivery orders or
assemblies.

=head2 buchungsgruppe BUCHUNGSGRUPPE

Used to set the accounting informations from a L<SL:DB::Buchungsgruppe> object.
Please note, that this is a write only accessor, the original Buchungsgruppe can
not be retrieved from an article once set.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
