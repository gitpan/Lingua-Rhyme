#! perl -w
package Lingua::Rhyme;
our $VERSION = 0.04;

use strict;
use warnings;
use DBI();

=head1 NAME

Lingua::Rhyme - MySQL-based rhyme-lookups.

=head1 SYNOPSIS

	use Lingua::Rhyme;
	my @rhymes_for_house = @{ Lingua::Rhyme::find('house') };

	warn "Test if 'house' rhymes with 'mouse'....\n";
	if (Lingua::Rhyme::match("house","mouse")){
		warn "They rhyme.\n";
	} else {
		warn "They don't rhyme!";
	}

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

The following variables must be set by the user to access the database.

=item $database

The name of the rhyming dictionary database that will be created. Defaults to C<rhymedict>.

=item $hostname
=item $port
=item $user
=item $password

You can set C<$chat> for real-time chat on what's up.

=cut

our $chat;

our $database = "rhymedict";
our $hostname = "localhost";
our $port = "3306";
our $user;
our $password;

our $driver = "mysql";



=head1 FUNCTIONS

=head2 &build

Running this function will create a MySQL database of two tables from the two supplied textfiles, C<words.txt> and C<rhymes.txt>, which should be in the same sub-directory Rhyme/dict/EN/.  If these tables exist, they will be dropped.

=cut

sub build {
	local (*WORDS,*RHYMES);

	die "Please read the POD and edit the source code to set the database-access variables."
		if (not defined $user and not defined $password);


	warn "Setting up db connection...\n" if $chat;
	our $dsn = "DBI:$driver:database=$database;host=$hostname;port=$port";
	our $dbh = DBI->connect($dsn, $user, $password);
	DBI->install_driver("mysql");

	# Create a new tables: **words**
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

	# Create a new tables: **rhymes**
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

	$dbh->disconnect();
} # End sub build




=head2 &find ($word_to_match)

Accepts B<a scalar> of one word to lookup, and returns a B<reference to an array> of rhyming words, or C<undef> on failure.

=cut

sub find { my ($lookup) = (uc shift);

	die "Please read the POD and edit the source code to set the database-access variables."
		if (not defined $user and not defined $password);

	unless (defined $lookup) {
		warn "&find requires a scalar to lookup as its sole argument.";
		return undef;
	}
	my $sth;

	warn "Setting up connection...\n" if $chat;
	our $dsn = "DBI:$driver:database=$database;host=$hostname;port=$port";
	our $dbh = DBI->connect($dsn, $user, $password);
	DBI->install_driver("mysql");

	warn "Looking up '$lookup' ... \n" if $chat;
	$sth = $dbh->prepare("SELECT idx FROM words WHERE word = '$lookup'");
	$sth->execute();
	my $idx_ref = $sth->fetchrow_arrayref();
	warn "... and got @$idx_ref\n" if $chat;
	$sth->finish();

	warn "Looking up '@$idx_ref' ...\n"  if $chat;
	$sth = $dbh->prepare("SELECT rhymes FROM rhymes WHERE idx = '@$idx_ref'");
	$sth->execute();
	my $rhymes_ref;
	if  ($rhymes_ref = $sth->fetchrow_arrayref() ) {
		chomp @$rhymes_ref;
		warn "... and got '@$rhymes_ref'\n"  if $chat;
	} else {
		warn "... and got nothing!\n"  if $chat;
	}
	$sth->finish();
	$dbh->disconnect();
	# Stored all matches as one field, so...
	@_ = split' ',@$rhymes_ref[0];
	return \@_;
}



=head2 &match ($word1,$word2)

Returns C<1> if C<$word1> rhymes with C<$word2>, otherwise returns C<undef>.

=cut

sub match { my ($lookup,$against) = (uc shift, uc shift);
	unless (defined $lookup or not defined $against) {
		warn "&lookup requires a scalar to lookup, and a scalar to match against as its two arguments.";
		return undef;
	}
	foreach (@{&find($lookup)}) {
		return 1 if $_ eq $against;
	}
	return undef;
}



1;
__END__
;



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

=item Multiples

Multiple pronounciations are available but not yet implimented.

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

=head1 COPYRIGHT

Copyright (C) Lee Goddard, 30/05/2001 ff.

This is free software, and can be used/modified under the same terms as Perl itself.

=cut
