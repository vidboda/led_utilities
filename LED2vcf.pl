#! /usr/bin/perl -wT

use DBI;
##########################################################################################################
##	Script to export vcf files from lgm_ex								##
##	david baux 02/2019										##
##	david.baux@inserm.fr										##
##########################################################################################################
my $dbh = DBI->connect(    "DBI:Pg:database=lgm_ex;host=localhost;",
                        'lgm',
                        'genetique1',
                        {'RaiseError' => 1}
                ) or die $DBI::errstr;


my $query = "SELECT a.chr, a.pos_hg19, a.reference, a.alternative, COUNT(DISTINCT(b.patient_id)) as num, b.status_type, a.id FROM variant a, variant2patient b WHERE a.id = b.variant_id AND b.status_type = 'heterozygous' GROUP BY b.status_type, a.chr, a.pos_hg19, a.reference, a.alternative , a.id ORDER BY a.chr, a.pos_hg19;";

my $hash;
my $content = '#CHROM POS     ID        REF    ALT     QUAL FILTER INFO';

my $sth = $dbh->prepare($query);
my $res = $sth->execute();

while (my $result = $sth->fetchrow_hashref()) {
	$hash->{"$result->{'chr'}_$result->{'pos_hg19'}_$result->{'reference'}_$result->{'alternative'}_$result->{'id'}"}->{$result->{'status_type'}} = $result->{'num'} 
}

foreach my $key (keys(%{$hash})) {
	my ($chr, $pos, $ref, $alt, $id) = split(/_/, $key);
	print "$chr, $pos, $ref, $alt, $id\n";
	$content .= "$chr	$pos	.	$ref	$alt	.	.	HET:$hash->{$key}->{'heterozygous'};HOM$hash->{$key}->{'homozygous'};LED_URL=https://194.167.35.158/perl/led/variant.pl?var=$id\n";
}

open F, '>LED4ACHAB.vcf';
print F $content;
close F;

exit;



