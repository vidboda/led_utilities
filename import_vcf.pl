#! /usr/bin/perl -w

use strict;
use DBI;
use Getopt::Std;

$Getopt::Std::STANDARD_HELP_VERSION = 1;

##########################################################################################################
##	Script to import vcf files into lgm_ex								##
##	david baux 04/2016										##
##	david.baux@inserm.fr										##
##########################################################################################################


my (%opts, $pat_file, $vcf, $login, $passwd);
getopts('i:s:c:l:p:', \%opts);

if ((not exists $opts{'i'}) || ($opts{'i'} !~ /\.vcf/o) || (not exists $opts{'s'}) || ($opts{'s'} !~ /\.txt/o || (not exists $opts{'l'}) || (not exists $opts{'p'}))) {
	&HELP_MESSAGE();
	exit
}
if ($opts{'i'} =~ /(.+\.vcf)$/o) {$vcf = $1}
if ($opts{'s'} =~ /(.+\.txt)$/o) {$pat_file = $1}
if ($opts{'c'}) {
	open(F, $vcf) or die $!;
	my ($i, $warning) = (0, 'f');
	while (<F>) {
		chomp;
		$i++;
		#print "$i\n";
		if (/^#/o) {next}
		elsif (/^[^c]/o) {print "\nCheck line $i in $vcf\nAborting $pat_file\n";$warning = 't';}
	}
	if ($warning eq 't') {exit}
}
if ($opts{'l'} =~ /^(.+)$/o) {$login = $1}
if ($opts{'p'} =~ /^(.+)$/o) {$passwd = $1}

my $dbh = DBI->connect(    "DBI:Pg:database=lgm_ex;host=/var/run/postgresql;",
                        $login,
                        $passwd,
                        {'RaiseError' => 1}
                ) or die $DBI::errstr;


#########	get patient info from file			#########
my $patient;
open(F, $pat_file) or die $!;

while (<F>) {
	if (/^#/o) {next}
	chomp;
	my @info = split(/:/, $_);
	$patient->{pop @info} = pop @info;
}

close F;

#foreach my $key (keys(%{$patient})) {
#	print "$key:$patient->{$key}\n"
#}

#my $output = $patient->{'patient_id'}."_".$patient->{'experiment_type'}.".sql";


#########	get date					#########

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my $month = ($mon+1);
if ($month < 10) {$month = "0$month"}
if ($mday < 10) {$mday = "0$mday"}
my $date =  (1900+$year)."-$month-".$mday;


my $sql = "INSERT INTO PATIENT (patient_id,family_id,gender,disease_name,team_name,visibility,creation,experiment_type) VALUES ('$patient->{'patient_id'}','$patient->{'family_id'}','$patient->{'gender'}','$patient->{'disease_name'}','$patient->{'team_name'}','$patient->{'visibility'}','$date','$patient->{'experiment_type'}');";
# print $sql;exit;
$dbh->do($sql);
my $query_patient = "SELECT id FROM Patient WHERE patient_id = '$patient->{'patient_id'}' AND family_id = '$patient->{'family_id'}' AND gender = '$patient->{'gender'}' AND disease_name = '$patient->{'disease_name'}' AND experiment_type = '$patient->{'experiment_type'}';";
my $res_patient = $dbh->selectrow_hashref($query_patient);
# print "$sql\n";

#########	get variant info from vcf			#########
my $genome;
my ($i, $j, $h) = (0, 0, 0);
open(F, $vcf) or die $!;

while (<F>) {
	chomp;
	$i++;
	if (/^#/o) {$h++}
	if (/^##reference=.+(hg\d{2})/o) {$genome = $1}
	elsif (/^##.+\/(hg\d{2})\.fa/o) {$genome = $1}
	elsif ((/^#CHROM/o) && (!$genome)) {print "\nFATAL: No reference genome found\n";exit 1;}
	elsif (/^chr/o || /^[\dXYM]{1,2}\s+/o) {
		my $genome_alt = $genome eq 'hg19' ? 'hg38'  : 'hg19';
		my @line = split(/\t/, $_);
		if ($line[9] !~ /^0\/0:/o) {
			my ($chr,$pos,$rs,$ref,$alt,$qual,$filter) = (shift(@line),shift(@line),shift(@line),shift(@line),shift(@line),shift(@line),shift(@line));
			# some cleaning
			if ($chr =~ /chr([\dXYM]{1,2})/o) {$chr = $1}
			if ($rs eq '.') {$rs = 'NULL'}
			elsif ($rs =~ /rs(\d+)/o) {$rs = "'$1'"}
			# variant already known?
			my $query = "SELECT id FROM Variant WHERE chr = '$chr' AND pos_$genome = '$pos' AND reference = '$ref' AND alternative = '$alt';";
			my $res = $dbh->selectrow_hashref($query);
			if (!$res) {
				# variant does not exists, should be created
				# liftover 
				my $chain_file = $genome eq 'hg19' ? 'hg19ToHg38.over.chain.gz' : 'hg38ToHg19.over.chain.gz';
				my $alt_genome_pos = liftover($pos, $chr, $chain_file);
				# print "LIFTOVER_RESULTS: $alt_genome_pos\n";
				if ($alt_genome_pos ne 'f') {
					$sql = "INSERT INTO Variant (chr,pos_$genome,pos_$genome_alt,reference,alternative,dbsnp_rs,creation) VALUES ('$chr','$pos','$alt_genome_pos','$ref','$alt',$rs,'$date');";
				}
				else {
					$sql = "INSERT INTO Variant (chr,pos_$genome,reference,alternative,dbsnp_rs,creation) VALUES ('$chr','$pos','$ref','$alt',$rs,'$date');";
				}
				# print "SQL: $sql\n";
				# exit 0;
				$dbh->do($sql);
				#print "$sql\n";
			}
			$query = "SELECT id FROM Variant WHERE chr = '$chr' AND pos_$genome = '$pos' AND reference = '$ref' AND alternative = '$alt';";
			$res = $dbh->selectrow_hashref($query);
			#we need status and doc
			my $status = 'heterozygous';
			if (($chr eq 'Y') || ($chr eq 'X' && $patient->{'gender'} eq 'm')) {$status = 'hemizygous'}
			if ($chr eq 'Y' && $patient->{'gender'} eq 'f') {next}

			#print $line[0];exit;
			elsif ($line[0] =~ /AF=1\.00;/o) {$status = 'homozygous'}
			my $doc = 0;
			if ($line[0] =~ /DP=(\d+);/o) {$doc = $1}
			elsif ($line[0] =~ /TC=(\d+);/o) {$doc = $1}
			if ($qual eq '.') {
				if ($line[0] =~ /VCQUAL=(\d+\.?\d?)/o) {$qual = $1}
				else {$qual = 0}
			}
			if ($doc eq '') {
				my @info = split(/:/, $line[1]);
				if ($info[2] =~ /^(\d+)$/o) {$doc = $1}
			}
			$sql = "INSERT INTO Variant2patient (variant_id,patient_id,status_type,filter,qual,doc) VALUES ('$res->{'id'}','$res_patient->{'id'}','$status','$filter','$qual','$doc')";
			$dbh->do($sql);
			$j++;
			#print "$sql\n";
			#TODO:check if annotations are complete in Variant table
		}
		#else {print $line[9]}
	}

}
print "\n".($i-$h)." lines in VCF $vcf and $j variants recorded\n";

sub HELP_MESSAGE {
	print "\nUsage: ./import_vcf.pl -i path/to/vcf/file.vcf -p path/to/patient/file.txt \nSupports --help or --version\n\n
### This script imports vcf files into lgm_ex
### -i vcf file from MSR, NENUFAAR ANNOVAR or NENUFAAR alone
### -s sample file
### -c check mode: checks vcf for unwanted \n (all lines must begin with # or c) prior to insertion. Abort if finds sthg
### -l database login
### -p database passwd
### contact: david.baux\@inserm.fr\n\n"
}

sub VERSION_MESSAGE {
	print "\nVersion 0.2 23/03/2023\n"
}

sub liftover {
	my ($pos, $chr, $chain) = @_;
	#liftover.py is 0-based
	$pos = $pos-1;
	if ($chr =~ /chr([\dXYM]{1,2})/o) {$chr = $1}
	my ($chr_tmp2, $s) = split(/,/, `/usr/bin/python2 liftover.py $chain "chr$chr" $pos`);
	# print "LIFTOVER: /usr/bin/python2 liftover.py $chain chr$chr $pos\n";
	$s =~ s/\)//g;
	$s =~ s/ //g;
	$s =~ s/'//g;
	if ($s =~ /^\d+$/o) {return $s+1}
	else {return 'f'}
}