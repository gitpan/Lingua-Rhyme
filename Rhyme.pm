#! perl -w
package Lingua::Rhyme;
our $VERSION = 0.05;

use strict;
use warnings;
use DBI();

=head1 NAME

Lingua::Rhyme - MySQL-based rhyme-lookups.

=head1 SYNOPSIS

First time:

	use Lingua::Rhyme;
	$Lingua::Rhyme::chat=1;
	build;

Thereafter:

	use Lingua::Rhyme;
	my @rhymes_for_house = @{ Lingua::Rhyme::simplefind('house') };

	my @rhymes_for_tomAto = @{ Lingua::Rhyme::simplefind('tomato') };

	warn "Test if 'house' rhymes with 'mouse'....\n";
	if (simplematch("house","mouse")){
		warn "They rhyme.\n";
	} else {
		warn "They don't rhyme!";
	}

	warn syllable("contrary");


	__END__


=head1 DESCRIPTION

This module uses an SQL database of rhyming words to find words that rhyme. See L<the &build function|"&build"> for further information.

This is actually Text::Rhyme version 0.04, but rhyming is now considered a linguist, rather than a textual, operation.

=head1 INSTALLATION

See the enclosed file, C<INSTALL>.

=head1 PREREQUISITES

	MySQL
	DBI.pm

=head1 CLASS VARIABLES

=item $chat

You can set this for real-time chat on what's up, leave as C<undef> for silent operation.

=item $database

The name of the rhyming dictionary database that will be created. Defaults to C<rhymedict>.

=item $driver

The DBI::* driver, defaults to C<mysql>.

The following variables must be set by the user to access the database.

=item $hostname

=item $port

=item $user

=item $password

=cut

our $chat;

our $database = "rhymedict";
our $hostname = "localhost";
our $port = "3306";
our $user = "Administrator";
our $password = "shalom3761";
our $driver = "mysql";

our $_connected;


=head1 FUNCTIONS

=head2 &build

Running this function will create a MySQL database of two tables from the two supplied textfiles, C<words.txt> and C<rhymes.txt>, which should be in the same sub-directory Rhyme/dict/EN/.  If these tables exist, they will be dropped.

Calling with a parameter will provide some minimal chat on what's going on.

The process can be as slow as your system: YMMV.

=cut

sub build {
	local (*WORDS,*RHYMES);
	if (defined $_[0]){ my $chat=1 }
	die "Please read the POD and edit the source code to set the database-access variables."
		if (not defined $user and not defined $password);
	die "Could not find words.txt from which to build db!"
		if not -e "Rhyme/dict/EN/words.txt";
	die "Could not find rhymes.txt from which to build db!"
		if not -e "Rhyme/dict/EN/rhymes.txt";
	die "Could not find multiple.txt from which to build db!"
		if not -e "Rhyme/dict/EN/multiple.txt";

	warn "Setting up db connection...\n" if $chat;
	our $dsn = "DBI:$driver:database=$database;host=$hostname;port=$port";
	our $dbh = DBI->connect($dsn, $user, $password);
	DBI->install_driver("mysql");

	#
	# Create a new tables: **words**
	#
	warn "Building table words...\n" if $chat;
	$dbh->do("DROP TABLE IF EXISTS words");
	$dbh->do("CREATE TABLE words "
			."("
				. "word	char(255) NOT NULL, "
				. "idx	char(10) NOT NULL, "
				. "syllables int NOT NULL, "
				. "PRIMARY KEY(word) "
			. ")"
	);

	open WORDS,"Rhyme/dict/EN/words.txt" or die "Couldn't find words.txt from which to build db table!";
	while (<WORDS>){
		my ($word, $idx, $syllables) = split /\s/,$_;
		$dbh->do("INSERT INTO words (word,idx,syllables) VALUES ( " .$dbh->quote($word).",".$dbh->quote($idx).",$syllables)");
	}
	close WORDS;

	#
	# Create a new tables: **rhymes**
	#
	warn "Building table rhymes...\n" if $chat;
	$dbh->do("DROP TABLE IF EXISTS rhymes");
	$dbh->do("CREATE TABLE rhymes "
			."("
				. "idx	char(10) NOT NULL, "
				. "rhymes text NOT NULL, "
				. "PRIMARY KEY(idx) "
			. ")"
	);

	open RHYMES,"Rhyme/dict/EN/rhymes.txt" or die "Couldn't find rhymes.txt from which to build db table!";
	while (<RHYMES>){
		my ($idx, $rhymes) = split /\s/,$_,2;
		$dbh->do("INSERT INTO rhymes (idx,rhymes) VALUES ( " .$dbh->quote($idx).",".$dbh->quote($rhymes).")");
	}
	close WORDS;


	#
	# Create a new tables: **multiple**
	#
	warn "Building table multiple...\n" if $chat;
	$dbh->do("DROP TABLE IF EXISTS multiple");
	$dbh->do("CREATE TABLE multiple "
			."("
				. "word	char(255) NOT NULL, "
				. "multiples text NOT NULL, "
				. "PRIMARY KEY(word) "
			. ")"
	);

	open MULTIPLE,"Rhyme/dict/EN/multiple.txt" or die "Couldn't find multiple.txt from which to build db table!";
	while (<MULTIPLE>){
		my ($word, $multiples) = split /\s/,$_,2;
		$dbh->do("INSERT INTO multiple (word,multiples) VALUES ( " .$dbh->quote($word).",".$dbh->quote($multiples).")");
	}
	close WORDS;

	warn "All built without problems, disconnecting...\n" if $chat;
	$dbh->disconnect();
	warn "...disconnected from db.\n";
} # End sub build




#
# Private subroutine _connect just sets up the dbh is not already done so
# stores in global $_connected
#
sub _connect {
	if (defined $_connected) { warn "Already connected to db.\n"; return $_connected }
	die "Please read the POD and edit the source code to set the database-access variables."
		if (not defined $user and not defined $password);
	warn "Connecting to db...\n" if $chat;
	my $dsn = "DBI:$driver:database=$database;host=$hostname;port=$port";
	my $dbh = DBI->connect($dsn, $user, $password);
	DBI->install_driver("mysql");
	$_connected = $dbh;
	return $dbh;
}

#
# Private subroutine _disconnect disconnects the global connection if it exists, otherwise
# can disconnect a specific dbh if passed.
#
sub _disconnect {
	warn "Disconnecting from db.\n" if $chat;
	if (defined $_connected) { $_connected->disconnect() }
	else { $_[0]->disconnect() }
}


=head2 SIMPLE LOOK UPS

Functions begining with the word C<simple> will not take into account multiple pronunciations, for which use functions ending with the word C<all>.

=head2 &simplefind ($word_to_match)

Accepts B<a scalar> of one word to lookup, and returns a B<reference to an array> of rhyming words, or C<undef> if the word isn't in the dictionary.

=cut

sub simplefind { my ($lookup) = (uc shift);
	unless (defined $lookup) {
		warn "&simplefind requires a scalar to lookup as its sole argument.";
		return undef;
	}
	$_ = _simplefind(_connect,$lookup);
	_disconnect;
	return $_;
}


#
# Privaet sub _simplefind same as public simplefind but doesn't connect/disconnect
# Accepts: dbh ref, scalar for word to lookup
# Returns: ref to array
#
sub _simplefind { my ($dbh,$lookup) = (shift,shift);
	my $sth;
	my $rhymes_ref;
	warn "Looking up '$lookup' ... \n" if $chat;
	$sth = $dbh->prepare("SELECT idx FROM words WHERE word = '$lookup'");
	$sth->execute();
	my $idx_ref = $sth->fetchrow_arrayref();
	warn "... and got @$idx_ref\n" if defined $idx_ref and $chat;
	$sth->finish();
	if (defined $idx_ref){
		warn "Looking up index '@$idx_ref' ...\n"  if $chat;
		$sth = $dbh->prepare("SELECT rhymes FROM rhymes WHERE idx = '@$idx_ref'");
		$sth->execute();
		if  ($rhymes_ref = $sth->fetchrow_arrayref() ) {
			chomp @$rhymes_ref;
			warn "... and got '@$rhymes_ref'\n"  if $chat;
		} else {
			warn "... and got nothing!\n"  if $chat;
		}
		$sth->finish();
		@$rhymes_ref[0] =~ s/\(\d+\)//g;	# Remove number refs
		@_ = split' ',@$rhymes_ref[0];
	} else {
		@_ = ();
		warn "Got nothing from db for '$lookup'.\n" if $chat
	}
	return \@_;
}




=head2 &finall ($word_to_lookup)

Accepts a scalar as a word to look up, and returns a reference to an array containing all the matches for all pronunciations of the word.

=cut

sub findall { my ($lookup) = (uc shift);
	unless (defined $lookup) {
		warn "&findall requires a scalar to lookup as its sole argument.";
		return undef;
	}
	my @found = ();
	my $sth;
	my $dbh = _connect;

	warn "Looking up '$lookup' in multiple db  ... \n" if $chat;
	$sth = $dbh->prepare("SELECT multiples FROM multiple WHERE word = '$lookup'");
	$sth->execute();
	my $lookup_ref = $sth->fetchrow_arrayref();
	warn "... and got @$lookup_ref\n" if $chat and defined $lookup_ref;
	$sth->finish();

	# Not in mulitple table, try words table by setting the value explicitly
	$lookup_ref = [$lookup] if (not defined $lookup_ref);

	foreach my $lookup (split' ',@$lookup_ref[0]){
		push @found, @{_simplefind($dbh, $lookup)};
	}

	_disconnect();

	# Remove duplicates
	my %dropdupes = map { $_ => 1 } @found;
	@found = sort keys %dropdupes;

	return \@found;
}



=head2 &simplematch ($word1,$word2)

Returns C<1> if C<$word1> rhymes with C<$word2>, otherwise returns C<undef>.

=cut

sub simplematch { my ($lookup,$against) = (uc shift, uc shift);
	unless (defined $lookup or not defined $against) {
		warn "&lookup requires a scalar to lookup, and a scalar to match against as its two arguments.";
		return undef;
	}
	foreach (@{&simplefind($lookup)}) {
		return 1 if $_ eq $against;
	}
	return undef;
}


=head2 &syllable ($word_to_lookup)

Accepts a word to look up, and returns the number of syllables in the word supplied, or C<undef> if the word isn't in the dictionary.

=cut

sub syllable { my ($lookup) = (uc shift);
	$_ = _syllable(_connect,$lookup);
	_disconnect;
}



#
# Private sub _syllable
# Accepts dbh and word to lookup
# Returns number of syllables id'ed in db for word to lookup, or undef
#
sub _syllable { my ($dbh,$lookup) = (shift,shift);
	my $sth;
	my $rhymes_ref;
	warn "Looking up '$lookup' ... \n" if $chat;
	$sth = $dbh->prepare("SELECT syllables FROM words WHERE word = '$lookup'");
	$sth->execute();
	my $syl_ref = $sth->fetchrow_arrayref();
	warn "... and got @$syl_ref[0] syllable\n" if defined $syl_ref and $chat;
	@$syl_ref[0] = undef if not defined $syl_ref;
	return @$syl_ref[0];
}





1;
__END__




=head1 CAVEATS

There appear to be duplicate entires in the DB:

	DBD::mysql::db do failed: Duplicate entry '#?2,M+?*.+' for key 1 at E:\Src\Pl\Text\Rhyme\build.pl line 53, <WORDS> line 13570.
	DBD::mysql::db do failed: Duplicate entry '7*?7\.?/.N' for key 1 at E:\Src\Pl\Text\Rhyme\build.pl line 53, <WORDS> line 16070.
	DBD::mysql::db do failed: Duplicate entry 'E,[' for key 1 at E:\Src\Pl\Text\Rhyme\build.pl line 53, <WORDS> line 20111.
	DBD::mysql::db do failed: Duplicate entry 'E1=' for key 1 at E:\Src\Pl\Text\Rhyme\build.pl line 53, <WORDS> line 20397.
	DBD::mysql::db do failed: Duplicate entry '02)?#D/.?2' for key 1 at E:\Src\Pl\Text\Rhyme\build.pl line 53, <WORDS> line 20623.
	DBD::mysql::db do failed: Duplicate entry 'e,:' for key 1 at E:\Src\Pl\Text\Rhyme\build.pl line 53, <WORDS> line 25587.
	DBD::mysql::db do failed: Duplicate entry 'E)@' for key 1 at E:\Src\Pl\Text\Rhyme\build.pl line 53, <WORDS> line 25605.
	DBD::mysql::db do failed: Duplicate entry 'e):' for key 1 at E:\Src\Pl\Text\Rhyme\build.pl line 53, <WORDS> line 30844.
	DBD::mysql::db do failed: Duplicate entry 'e2:' for key 1 at E:\Src\Pl\Text\Rhyme\build.pl line 53, <WORDS> line 30983.
	DBD::mysql::db do failed: Duplicate entry 'e"[' for key 1 at E:\Src\Pl\Text\Rhyme\build.pl line 53, <WORDS> line 34284.
	DBD::mysql::db do failed: Duplicate entry 'E#,U' for key 1 at E:\Src\Pl\Text\Rhyme\build.pl line 53, <WORDS> line 34545.
	DBD::mysql::db do failed: Duplicate entry 'e4:' for key 1 at E:\Src\Pl\Text\Rhyme\build.pl line 53, <WORDS> line 34637.
	DBD::mysql::db do failed: Duplicate entry '-T2,M+?*.+' for key 1 at E:\Src\Pl\Text\Rhyme\build.pl line 53, <WORDS> line 36221.
	DBD::mysql::db do failed: Duplicate entry '/B+,=' for key 1 at E:\Src\Pl\Text\Rhyme\build.pl line 53, <WORDS> line 41578.
	DBD::mysql::db do failed: Duplicate entry '4T2)A#?/.N' for key 1 at E:\Src\Pl\Text\Rhyme\build.pl line 53, <WORDS> line 41821.

=head1 TODO

=item Languages

If I can find dictionaries for German and Yiddish (or others), I'll add those too.

=head1 SEE ALSO

L<DBI>;
L<MySQL|http://www.mysql.com>;
L<The Rhyming Dictionary|http://rhyme.sourceforge.net/index.html>;
L<Carnegie Mellon University Pronouncing Dictionary|http://www.speech.cs.cmu.edu/cgi-bin/cmudict>;
perl(1).

=head1 ACKNOWLEDGMENTS

A thousand thanks to Brian "tuffy" Langenberger for the database files used in his L<Rhyming Dictionary|http://rhyme.sourceforge.net/index.html>.  Brain writes that his 'work is based wholly on the work of the L<Carnegie Mellon University Pronouncing Dictionary|http://www.speech.cs.cmu.edu/cgi-bin/cmudict>'.

=head1 AUTHOR

Lee Goddard <lgoddard@cpan.org>

=head1 CHANGES

Revision history for Perl extension Text::Rhyme.

0.05  Thu May 31 13:13:00 2001
	- added multiple.txt db
	- added new functions and renamed old functions

0.04  Wed May 30 19:01:25 2001
	- completely rewritten - now uses a MySQL DB.
	- moved namespace, as rhyming is now a linguist, not textual, operation
	  (if it ever was).

0.03  Tue May 29 13:35:12 2001
	- ACTUALLY text-rhyme-0.03
	- added parsing of final consenants. Still I can't spell.

0.02  Tue May 29 12:32:00 2001
	- ACTUALLY text-rhyme-0.02
	- damn, got the module name wrong!

0.01  Tue May 29 12:18:12 2001
	- ACTUALLY text-rhyme-0.01
	- original version; created by h2xs 1.20 with options
		-Xcfn Text::Rhyme




=head1 COPYRIGHT

Copyright (C) Lee Goddard, 30/05/2001 ff.

This is free software, and can be used/modified under the same terms as Perl itself.

=cut
