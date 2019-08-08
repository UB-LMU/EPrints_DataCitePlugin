=head1 NAME

EPrints::Plugin::Export::DataCite

=head1 DESCRIPTION

=cut

# Author: Volker Schallehn, Universitätsbibliothek der LMU München, Germany
# Exports Metadata via OAI-PMH using the DataCite Metadata Schema 4.1
# Version: 1.0 / 7. May 2018
# Version: 1.1 / 18. October 2018
#	- relatedIdentifier added


package EPrints::Plugin::Export::DataCite;

use EPrints v3.3.0;
use EPrints::Plugin::Export::XMLFile;

@ISA = ( "EPrints::Plugin::Export::XMLFile" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "DataCite";
	$self->{accept} = [ 'dataobj/eprint' ];
	$self->{visible} = "all";

	$self->{metadataPrefix} = "datacite";
	$self->{xmlns} = "http://www.w3.org/2001/XMLSchema-instance",
	$self->{schemaLocation} = "http://datacite.org/schema/kernel-4 http://schema.datacite.org/meta/kernel-4.1/metadata.xsd";

	return $self;
}



sub xml_dataobj
{
	my( $plugin, $dataobj, $prefix ) = @_;

	my $session = $plugin->{ session };

	my $dataset = $dataobj->get_dataset;

	my $resource = $session->make_element(
		"resource",
		"xmlns" => "http://datacite.org/schema/kernel-4",
		"xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
		"xsi:schemaLocation" => "http://datacite.org/schema/kernel-4 http://schema.datacite.org/meta/kernel-4.1/metadata.xsd",
	);

	# DOI
	$resource->appendChild( _make_doi( $session, $dataset, $dataobj ));
	
	# Full-Publication-URLs
	$resource->appendChild( _make_full_data_url( $session, $dataset, $dataobj ));
	
	# title
	$resource->appendChild( _make_title( $session, $dataset, $dataobj ));

	# creators
	$resource->appendChild( _make_creators( $session, $dataset, $dataobj ));

	# abstract
	$resource->appendChild( _make_abstract( $session, $dataset, $dataobj ));

	# subjects
	$resource->appendChild( _make_subjects( $session, $dataset, $dataobj ));
	
	# date_issue
	$resource->appendChild( _make_issue_date( $session, $dataset, $dataobj ));

	# publisher
	$resource->appendChild( _make_publisher( $session, $dataset, $dataobj ));
	

	return $resource;
}

sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $xml = $plugin->xml_dataobj( $dataobj );

	return EPrints::XML::to_string( $xml );
}

sub _make_creators
{
	my( $session, $dataset, $dataobj ) = @_;
	
	# creators is obligatory, even if it is empty
	my $creators = undef;
	my $creators_tag = $session->make_element( "creators" );
	
	if ( $dataobj->exists_and_set( "creators_name" ) )
	{
		$creators = $dataobj->get_value( "creators_name" );
		
		foreach my $creator ( @{$creators} )
		{	
			next if !defined $creator;
			$creators_tag->appendChild( my $creator_tag = $session->make_element( "creator" ));
			
			$creator_tag->appendChild(my $name = $session->make_element( "creatorName", "nameType" => "Personal" ));
			$creator_tag->appendChild(my $given = $session->make_element( "givenName" ));
			$creator_tag->appendChild(my $family = $session->make_element( "familyName" ));
			
			my $forename = $creator->{'given'};
			my $surname = $creator->{'family'};
			
			$name->appendChild( $session->make_text( EPrints::Utils::make_name_string( $creator )));
			$given->appendChild( $session->make_text( $forename ));
			$family->appendChild( $session->make_text( $surname ));
		}
	}
	# in case there is no creator
	else {
		my $creator_tag = $session->make_element( "creator" );
		$creators_tag->appendChild( my $creator_tag = $session->make_element( "creator" ));
		$creator_tag->appendChild(my $name = $session->make_element( "creatorName", "nameType" => "Personal" ));
		$name->appendChild( $session->make_text( "none supplied" ));
	}
	return $creators_tag;
}

sub _make_title
{
	my( $session, $dataset, $dataobj ) = @_;

	return $session->make_doc_fragment unless $dataset->has_field( "title" );
	my $val = $dataobj->get_value( "title" );
	return $session->make_doc_fragment unless defined $val;
	
	my $titleInfo = $session->make_element( "titles" );
	$titleInfo->appendChild( my $title = $session->make_element( "title" ));
	$title->appendChild( $session->make_text( $val ));
	
	return $titleInfo;
}

# For "Open Data LMU", the abstract field is a compound field with the subfields "name" and "lang".
# For repositories with a simple abstract field the following commented out "sub _make_abstract" should do it.


# sub _make_abstract
# {
	# my( $session, $dataset, $dataobj ) = @_;

	# return $session->make_doc_fragment unless $dataset->has_field( "abstract" );
	# my $val = $dataobj->get_value( "abstract" );
	# return $session->make_doc_fragment unless defined $val;
	
	# my $descriptions = $session->make_element( "descriptions" );
	# $descriptions->appendChild( my $description = $session->make_element( "description", "descriptionType" => "Abstract" ));
	# $description->appendChild( $session->make_text( $val ));
	
	# return $descriptions;
# }


sub _make_abstract
{
	my( $session, $dataset, $dataobj ) = @_;

	my $descriptions = $session->make_element( "descriptions" );
	return $session->make_doc_fragment unless $dataset->has_field( "abstract" );
	my $abstracts = $dataobj->get_value( "abstract_name" );
	return $session->make_doc_fragment unless defined $abstracts;

	foreach my $abstract ( @{$abstracts} )
	{	
		next if !defined $abstract;
		$descriptions->appendChild( my $description = $session->make_element( "description", "descriptionType" => "Abstract" ));
		$description->appendChild( $session->make_text( $abstract ));
	}
	return $descriptions;
}

sub _make_doi
{
	my( $session, $dataset, $dataobj ) = @_;

	return $session->make_doc_fragment unless $dataset->has_field( "doi" );
	my $val = $dataobj->get_value( "doi" );
	$val =~ s/^doi:(.*)$/$1/;
	return $session->make_doc_fragment unless defined $val;
	
	my $identifier = $session->make_element( "identifier", "identifierType" => "DOI"  );
	$identifier->appendChild( $session->make_text( $val ));
	
	return $identifier;
}

sub _make_full_data_url
{
	my( $session, $dataset, $dataobj ) = @_;

	my $frag = $session->make_element( "relatedIdentifiers" );
	my @documents = $dataobj->get_all_documents();
	foreach my $doc ( @documents )
	{
		my %files = $doc->files;
		if( defined $files{$doc->get_main} )
		{
			my $fileurl = $doc->get_url;
			my $relatedIdentifier = $session->make_element( "relatedIdentifier", 'relatedIdentifierType'=>"URL", 'relationType'=>"IsIdenticalTo" );
			$relatedIdentifier->appendChild( $session->make_text(  $fileurl ));
			$frag->appendChild( $relatedIdentifier );
		}
	}
	return $frag;
}


# In case of "Open Data LMU" the DDC (Dewey) as part of the subjects is exported
sub _make_subjects
{
	my( $session, $dataset, $dataobj ) = @_;
	
	my $frag = $session->make_element( "subjects" );
	
	my $subjects = $dataset->has_field("ddc") ?
		$dataobj->get_value("ddc") :
		undef;
	return $frag unless EPrints::Utils::is_set( $subjects );
	
	foreach my $val (@$subjects)
	{
		my $subject = EPrints::DataObj::Subject->new( $session, $val );
		next unless defined $subject;
		$frag->appendChild( my $classification = $session->make_element( "subject",	"schemeURI" => "http://dewey.info/", "subjectScheme" => "dewey"));
		$classification->appendChild( $session->make_text( EPrints::XML::to_string($subject->render_description)));
	}
	
	return $frag;
}

sub _make_issue_date
{
	my( $session, $dataset, $dataobj ) = @_;
	
	return $session->make_doc_fragment unless $dataset->has_field( "date" );
	my $val = $dataobj->get_value( "date" );
	return $session->make_doc_fragment unless defined $val;
	
	$val =~ s/(-0+)+$//;
	# Deletes month and year
	$val =~ s/^(\d{4}).*$/$1/;
	my $publicationYear = $session->make_element( "publicationYear" );
	$publicationYear->appendChild( $session->make_text( $val ));
	
	return $publicationYear;
}

sub _make_publisher
{
	my( $session, $dataset, $dataobj ) = @_;
	my $publisher = $session->make_element( "publisher" );
	$publisher->appendChild( $session->make_text( "Universitätsbibliothek der Ludwig-Maximilians-Universität München" ));
	return $publisher;
}


1;

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2011 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

