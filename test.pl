# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..1\n"; }
END {print "not ok 1\n" unless $loaded;}
use Lingua::Rhyme;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

my $filesbad=0;
print "-e Rhyme/dict/EN/words.txt.......";
if (-e 'Rhyme/dict/EN/words.txt'){
	print "ok\n";
} else {
	print "not ok\n";
	$filesbad++;
}
print "-e Rhyme/dict/EN/rhymes.txt......";
if (-e 'Rhyme/dict/EN/rhymes.txt'){
	print "ok\n";
} else {
	print "not ok\n";
	$filesbad++
}
die "\nThe dictionary files did not install.\n------------------------------------\n" if $filesbad>0;
