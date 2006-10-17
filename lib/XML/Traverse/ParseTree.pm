package XML::Traverse::ParseTree;
use strict;
use warnings;
use Carp;

our $VERSION = "0.01";

=head1 NAME

XML::Traverse::ParseTree - iterators and getters for xml-access

=head1 SYNOPSIS

    my $xml = XML::Parser->new(Style => "Tree")->parse($xmlcont);
    my $h   = XML::Traverse::ParseTree->new();

    my $a1  = $h->get_at($xml,'document','section','entries');
    my $i   = $h->get_cld_element_iterator($a1);
    while (my $e = $i->()) {
        ...
        $attr = $h->get_at($e,'another-child-element','@attribute-name');
        $text = $h->get_at($e,'#TEXT');
    }
    ...
    my $filter = sub { ... }
    my $i   = $h->filter_cld_iterator($xml,$filter);
    while (my $e = $i->()) {
        ...
    }

=head1 DESCRIPTION

XML::Traverse::ParseTree supplies iterators and getters for accessing
the contents of a xml content. The xml content must be already parsed
using XML::Parser (tree-style)

=cut

sub new {
    my ( $pkg, @params ) = @_;
    $pkg = ref($pkg) if ref($pkg);
    my $self = {@params};
    return bless $self, $pkg;
}

# Erzeugt eine Struktur aus dem Element und allen Unterelementen
sub element_to_object {
    my ( $pkg, $o ) = @_;
    my $r = {};

    $r->{_name} = $pkg->get_element_name($o);
    $r->{_attr} = $pkg->get_element_attrs($o);
    $r->{_text} = $pkg->get_element_text($o);

    my $i = $pkg->cld_element_iterator($o);
    while ( my $ce = $i->() ) {
        my $cr = $pkg->element_to_object($ce);
        my $cn = $pkg->get_element_name($ce);
        if ( exists( $r->{$cn} ) ) {
            if ( ref( $r->{$cn} ) =~ /array/i ) {
                push( @{ $r->{$cn} }, $cr );
            }
            else {

                # Umwandeln zu einem Array
                my $temp = $r->{$cn};
                $r->{$cn} = [ $temp, $cr ];
            }
        }
        else {
            $r->{$cn} = $cr;
        }
    }
    $r;
}

# Liefert den Inhalt der Textnodes des akt. Elements (ohne subs)
sub get_element_text {
    my ( $pkg, $e ) = @_;

    carp "Wrong context! Arrayref expected!"
      unless ref($e) =~ /array/i && !ref( $e->[0] ) && $e->[0] ne "0";

    # [ elemname, [ {}, 0, 'Text' ]}

    $e->[1]->[2];
}

sub get_element_name {
    my ( $pkg, $e ) = @_;

# e muss ein Arrayref sein, das erste Element muss ein String und zwar nicht "0" sein.
    return $e->[0] if ref($e) =~ /array/i && !ref( $e->[0] ) && $e->[0] ne "0";

    carp "Wrong context! Arrayref expected!";
    undef;
}

# returns the attributes (hashref) of the given element
sub get_element_attrs {
    my ( $pkg, $e ) = @_;

    carp "Wrong context! Arrayref expected!"
      unless ref($e) =~ /array/i
      && !ref( $e->[0] )
      && defined( $e->[0] )
      && $e->[0] ne "0";
    $e->[1]->[0];
}

# returns an iterator over all child elements
sub cld_element_iterator {
    my ( $pkg, $e ) = @_;

    carp "Wrong context! Arrayref expected!" unless ref($e) =~ /array/i;

    my $i =
      _array_iterator( $e->[1] )
      ;    # e->[0] is element name, e->[1] is element content
    $i->();    # skip attributes
    my $ce = $i->();

    sub {
        while ( defined($ce) ) {
            if ( $ce eq "0" ) {    # skip textnode
                $i->();
                $ce = $i->();
                next;
            }
            my $ceInhalt = $i->();
            croak "Error in the structure... $ce"
              unless ref($ceInhalt) =~ /array/i;
            my $r = [ $ce, $ceInhalt ];
            $ce = $i->();
            return $r;
        }
        undef;
      }
}

#
# High-Level Funktion, es können Elemente, Attribute oder der Elementtext
# abgefragt werden
#
# getAt($e, "sub1","sub1sub1") - liefert das Element subsub1 welches ein Unterelement von sub1,
#                            welches wiederum ein Unterelement vom geg. Element sein muß.
#                            undef, wenn nichts gefunden
# getAt($e, "sub1","sub1sub1",'@a') - liefert den Inhalt des Attributes a vom Element sub1/sub1sub1
#
# getAt($e, "sub1","sub1sub1","#TEXT") - liefert den Text des Elementes sub1/sub1sub1
#
#
sub get_at {
    my ( $pkg, $e, @path ) = @_;
    my $ctx = shift(@path);

    if ( !defined($ctx) ) {
        return $e;
    }
    if ( $ctx eq "#TEXT" ) {
        return $pkg->get_element_text($e);
    }
    if ( $ctx =~ /^@(.*)$/ ) {
        my $attrname = $1;
        my $attrs    = $pkg->get_element_attrs($e);
        return $attrs->{$attrname};
    }

    # walk through childs recursively
    my $i = $pkg->clds_by_name( $e, $ctx );
    my $ce = $i->();
    if ( defined($ce) ) {
        return $pkg->get_at( $ce, @path );
    }
    undef;
}

sub filter_cld_iterator {
    my ( $pkg, $e, $filter ) = @_;
    croak "Wrong Params!" unless ref($filter) =~ /code/i;

    my $i  = $pkg->cld_element_iterator($e);
    my $ce = $i->();
    sub {
        my $re;
        while ( defined($ce) ) {
            $re = $ce;
            $ce = $i->();
            if ( $filter->($re) ) {
                return $re;
            }
        }
        undef;
    };
}

sub clds_by_name {
    my ( $pkg, $e, $name ) = @_;
    my $filter = sub {
        my ($ce) = @_;
        my $ceName = $pkg->get_element_name($ce);
        return $ceName eq $name;
    };
    $pkg->filter_cld_iterator( $e, $filter );
}

sub _array_iterator {
    my $array = shift;
    my $idx   = -1;

    return sub {
        $idx++;
        return $array->[$idx] if $idx < scalar(@$array);
        $array = undef;
        undef;
      }
}

1;

__END__

=head1 METHODS

=over

=item new()

Creates an instance of XML::Traverse::ParseTree. Currently, this instance does not have
an intrinsic state. Although it could be used in a static way, this is not recommended.
(Possible extention: support for different character encodings)

=item get_at($parse_tree,access_path [,access_path ...])

Returns an Element (position in the parse tree) or an attribute value or the contents of
a text node, depending on the params.

Access path may consist of one or more entries. The last one specifies if a attribute
value is requested (prefix @) or the text (special value of #TEXT) or an element (position
in the parse tree). Examples:

    $h->get_at($current,'@id') - returns the value of the attribute "id" of the current element
    $h->get_at($current,'a-child') - returns the first child element named "a-child"
    $h->get_at($current,'#TEXT') - returns the text node of the current element

More than one entry in the access path means more hierarchy levels, e.g.:

    $h->get_at($current,'document','sections','section','@id')

Returns the value of the attribute "id" of the element "section" which is a child
element of an element "sections", which in turn is a child element of an element
named "document", the "document" element is a child of the current element.
(xpath-style: document/sections/section/@id)

    $h->get_at($current,'document','#TEXT')

Returns the text of the element document, which is a child element of current.
INFO: At present, the *first* text node is returned. E.g. 

    <current><document>abc<sub/>def</document></current>

Then only "abc" will be returned. This will be modified soon.

TODO:
- return all text nodes of the current element
- implement a way to retrieve the text of the current node and all childs
- return all attributes if @* is specified
- return an interator if an element is qualified by "[*]" (e.g. "document","sections[*]")

=back

=item get_element_name($current)

Returns the element name of the  current element.

=item get_element_attrs($current)

Return all attributes of the current element.

=item get_element_text($current)

Returns the text of the current element.

=item element_to_object($current)

Creates a hashref with the contens of the current element
(experimental)

=item clds_by_name($current,$name)

Returns an iterator over all child elements with the given name.
(direct childs)

=item filter_cld_iterator($current,$filter)

Returns an iterator over all child elements for which the filter (code-ref)
evaluates to true.
(direct childs)

=item cld_element_iterator($current)

Returns an iterator over all child elements
(direct childs)

=head1 BUGS

None known.

=head1 SEE ALSO

  Concerning the concepts of iterators using closures/anonymous subs: 
  http://hop.perl.plover.com/

=head1 AUTHOR

  Martin Busik <martin.busik@busik.de>

=cut
