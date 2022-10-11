#! /usr/bin/perl -w

use DBI;
use Getopt::Std;
use List::Util qw(max);

$Getopt::Std::STANDARD_HELP_VERSION = 1;

##########################################################################################################
##	Script to export vcf files from lgm_ex								##
##	david baux 02/2019										##
##	david.baux@inserm.fr										##
##########################################################################################################

my (%opts, $login, $passwd);
getopts('l:p:', \%opts);

if ((not exists $opts{'l'}) || (not exists $opts{'p'})) {
	&HELP_MESSAGE();
	exit
}
if ($opts{'l'} =~ /^(.+)$/o) {$login = $1} 
if ($opts{'p'} =~ /^(.+)$/o) {$passwd = $1}
my $dbh = DBI->connect(    "DBI:Pg:database=lgm_ex;host=/var/run/postgresql;",
                        $login,
                        $passwd,
                        {'RaiseError' => 1}
                ) or die $DBI::errstr;

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my $month = ($mon+1);
if ($month < 10) {$month = "0$month"}
if ($mday < 10) {$mday = "0$mday"}
my $date =  (1900+$year)."$month".$mday;

my $query = "SELECT a.chr, a.pos_hg19, a.reference, a.alternative, COUNT(DISTINCT(b.patient_id)) as num, b.status_type, a.id FROM variant a, variant2patient b WHERE a.id = b.variant_id GROUP BY b.status_type, a.chr, a.pos_hg19, a.reference, a.alternative , a.id ORDER BY a.chr, a.pos_hg19;";

my $hash;
my $content = "##fileformat=VCFv4.2\n##filedate=$date\n##source=LED2vcf.pl-https://github.com/beboche/led_utilities\n##INFO=<ID=HET,Number=1,Type=Integer>\n##INFO=<ID=HOM,Number=1,Type=Integer>\n##INFO=<ID=MAX,Number=1,Type=Integer>\n##INFO=<ID=LED_URL,Number=1,Type=String>\n##contig=<ID=chr1,length=249250621,assembly=hg19>\n##contig=<ID=chr2,length=243199373,assembly=hg19>\n##contig=<ID=chr3,length=198022430,assembly=hg19>\n##contig=<ID=chr4,length=191154276,assembly=hg19>\n##contig=<ID=chr5,length=180915260,assembly=hg19>\n##contig=<ID=chr6,length=171115067,assembly=hg19>\n##contig=<ID=chr7,length=159138663,assembly=hg19>\n##contig=<ID=chr8,length=146364022,assembly=hg19>\n##contig=<ID=chr9,length=141213431,assembly=hg19>\n##contig=<ID=chr10,length=135534747,assembly=hg19>\n##contig=<ID=chr11,length=135006516,assembly=hg19>\n##contig=<ID=chr12,length=133851895,assembly=hg19>\n##contig=<ID=chr13,length=115169878,assembly=hg19>\n##contig=<ID=chr14,length=107349540,assembly=hg19>\n##contig=<ID=chr15,length=102531392,assembly=hg19>\n##contig=<ID=chr16,length=90354753,assembly=hg19>\n##contig=<ID=chr17,length=81195210,assembly=hg19>\n##contig=<ID=chr18,length=78077248,assembly=hg19>\n##contig=<ID=chr19,length=59128983,assembly=hg19>\n##contig=<ID=chr20,length=63025520,assembly=hg19>\n##contig=<ID=chr21,length=48129895,assembly=hg19>\n##contig=<ID=chr22,length=51304566,assembly=hg19>\n##contig=<ID=chrX,length=155270560,assembly=hg19>\n##contig=<ID=chrY,length=59373566,assembly=hg19>\n##contig=<ID=chrM,length=16571,assembly=hg19>\n#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\n";

my $sth = $dbh->prepare($query);
my $res = $sth->execute();

while (my $result = $sth->fetchrow_hashref()) {
	$hash->{"$result->{'chr'}_$result->{'pos_hg19'}_$result->{'reference'}_$result->{'alternative'}_$result->{'id'}"}->{$result->{'status_type'}} = $result->{'num'} 
}

foreach my $key (sort keys(%{$hash})) {
	my ($chr, $pos, $ref, $alt, $id) = split(/_/, $key);
	if (! $hash->{$key}->{'heterozygous'}) {$hash->{$key}->{'heterozygous'} = 0}
	if (! $hash->{$key}->{'homozygous'}) {$hash->{$key}->{'homozygous'} = 0}
	if (! $hash->{$key}->{'hemizygous'}) {$hash->{$key}->{'hemizygous'} = 0}
	#print "$chr, $pos, $ref, $alt, $id, $hash->{$key}->{'heterozygous'}, $hash->{$key}\n";
	#$content .= "chr$chr\t$pos\t.\t$ref\t$alt\t.\t.\t\=\"HET=$hash->{$key}->{'heterozygous'};HOM=$hash->{$key}->{'homozygous'};LED_URL=\"&HYPERLINK(\"https://194.167.35.158/perl/led/variant.pl?var=$id\")\n";
	$content .= "chr$chr\t$pos\t.\t$ref\t$alt\t.\t.\tHET=$hash->{$key}->{'heterozygous'};HOM=$hash->{$key}->{'homozygous'};HEM=$hash->{$key}->{'hemizygous'};MAX=".max($hash->{$key}->{'heterozygous'}, $hash->{$key}->{'homozygous'}, $hash->{$key}->{'hemizygous'}).";LED_URL=https://ushvam.iurc.montp.inserm.fr/perl/led/variant.pl?var=$id\n";
}

open F, ">LED4ACHAB_$date.vcf";
print F $content;
close F;
#`bcftools sort -O v -o LED4ACHAB_$date.vcf LED4ACHAB.vcf`;
#`rm LED4ACHAB.vcf`;
exit;



sub HELP_MESSAGE {
	print "\nUsage: ./LED2vcf.pl -l login -p password \nSupports --help or --version\n\n
### This script creates a vcf files from the led database
### -l database login
### -p database passwd
### contact: david.baux\@inserm.fr\n\n"
}

sub VERSION_MESSAGE {
	print "\nVersion 0.1 18/02/2019\n"
}
