#!/usr/bin/perl -w

use strict;
use DBI;
use Getopt::Std;


#Script to update genomic positions from hg19 to hg38


my (%opts, $login, $passwd);
getopts('l:p:', \%opts);

if ((not exists $opts{'l'}) || (not exists $opts{'p'})) {
	&HELP_MESSAGE();
	exit
}

if ($opts{'l'} =~ /^(.+)$/o) {$login = $1}
if ($opts{'p'} =~ /^(.+)$/o) {$passwd = $1}

## Connect to led

my $dbh = DBI->connect(    "DBI:Pg:database=lgm_ex;host=/var/run/postgresql;",
                        $login,
                        $passwd,
                        {'RaiseError' => 1}
                ) or die $DBI::errstr;

my $get_g = "SELECT chr, pos_hg19 FROM variant WHERE chr <> 'M' AND pos_hg38 is NULL;";

my $sth = $dbh->prepare($get_g);
my $res = $sth->execute();
my $hg38_pos;
my $i = 1;
while (my $result = $sth->fetchrow_hashref()) {
	my ($chr, $pos_hg19) = ($result->{'chr'}, $result->{'pos_hg19'});
	my $hg38pos = '';
	$hg38pos = liftover($pos_hg19, $chr, '', 'hg19ToHg38.over.chain.gz');
	if ($hg38pos eq 'f') {print "No mapping for chr$chr:$pos_hg19\n";next}
	my $update = "UPDATE variant SET pos_hg38 = '$hg38pos' where chr = '$chr' AND pos_hg19 = '$pos_hg19';";
	$dbh->do($update);
	print "$update - #$i\n";
	$i++;
}
print "$res\n";


sub liftover {
	#my ($pos, $chr, $path, $way) = @_;
	my ($pos, $chr, $path, $chain) = @_;
	chop($path);
	#way =19238 or 38219
	#liftover.py is 0-based
	$pos = $pos-1;
	if ($chr =~ /chr([\dXYM]{1,2})/o) {$chr = $1}
	my ($chr_tmp2, $s) = split(/,/, `/usr/bin/python2 liftover.py $chain "chr$chr" $pos`);
	$s =~ s/\)//g;
	$s =~ s/ //g;
	$s =~ s/'//g;
	if ($s =~ /^\d+$/o) {return $s+1}
	else {return 'f'}
}

sub HELP_MESSAGE {
	print "\nUsage: ./import_vcf.pl -i path/to/vcf/file.vcf -p path/to/patient/file.txt \nSupports --help or --version\n\n
### This script remaps variants in LED fomr hg19 to hg38
### -l database login
### -p database passwd
### contact: david.baux\@inserm.fr\n\n"
}

sub VERSION_MESSAGE {
	print "\nVersion 0.1 13/03/2023\n"
}