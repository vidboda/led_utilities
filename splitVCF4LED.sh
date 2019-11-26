#!/usr/bin/bash



###########################################################################
#########                                                       ###########
#########               splitVCF4LED                              ###########
######### @uthor : D Baux       david.baux<at>inserm.fr         ###########
######### Date : 10/09/2018                                     ###########
#########                                                       ###########
###########################################################################





#specific script to treat data beofre LED input
#we will get sample IDs then
#create smaller vcfs (1 sample each)
#then prepare indvidual file



VERSION=1.0
USAGE="
Program: 576totreat
Version: ${VERSION}
Contact: Baux David <david.baux@inserm.fr>

Usage: bash 576toTreat.sh -i input.vcf -n numberOfSampleForSplitting [-b /path/to/bcftools -g <hg19|hg38> ]
default bcftools: /usr/local/bin/bcftools
"


if [ "$#" -eq 0 ]; then
	echo "${USAGE}"
	echo "Error Message : No arguments provided"
	echo ""
	exit 1
fi
#default
BCFTOOLS="/usr/local/bin/bcftools"
GENOME="hg19"
while [[ "$#" -gt 0 ]]
do
KEY="$1"
case "${KEY}" in
	-i|--input)					#mandatory
	VCF="$2"
	shift
	;;
	-n|--number)
	SAMPLE_NUM="$2"
	shift
	;;
	-b|--bcftools)
	BCFTOOLS="$2"
	shift
	;;
	-g|--genome)
	GENOME="$2"
	shift
	;;
	-h|--help)
	echo "${USAGE}"
	exit 1
	;;
	*)
	echo "Error Message : Unknown option ${KEY}" 	# unknown option
	exit
	;;
esac
shift
done


RED='\033[0;31m'
LIGHTRED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# -- Log functions got from cww.sh -- simplified here

error() { log "[${RED}error${NC}]" "$1" ; }
warning() { log "[${YELLOW}warn${NC}]" "$1" ; }
info() { log "[${BLUE}info${NC}]" "$1" ; }
debug() { log "[${LIGHTRED}debug${NC}]" "$1" ; }

# -- Print log 

echoerr() { echo -e "$@" 1>&2 ; }

log() {
echoerr "[`date +'%Y-%m-%d %H:%M:%S'`] $1 - 576toTreat version : ${VERSION} - $2"
}


treat_samples() {
	#"${BEGIN}" "${SAMPLE_COUNT}" "${FILENAME}" "${VCF}"  "${BCFTOOLS}" "${SAMPLE}"
	info "creating splited VCF: splitted_vcf/$1_$2/$3.$1_$2.vcf"
	mkdir "splitted_vcf/$1_$2"
	#"${BCFTOOLS}" view -c1 -Ov -s$( IFS=$',';echo "${SAMPLES[*]}") -o "splitted_vcf/${FILENAME}.${SAMPLE_COUNT}.vcf" "${VCF}" 
	#info "$6 view -c1 -Ov -s$( IFS=$',';echo $4) -o splitted_vcf/$1_$2/$3.$1_$2.vcf $5" 
	"$5" view -c1 -Ov -s$( IFS=$',';echo "${SAMPLES[*]}" ) -o "splitted_vcf/$1_$2/$3.$1_$2.vcf" "$4" 
	cp "disease.txt" "splitted_vcf/$1_$2"
	cp "captainAchab_inputs.json" "splitted_vcf/$1_$2"
	echo "$1_$2:${SAMPLES[*]}" >> sample_location.txt
	sed -i.bak -e "s/\(  \"captainAchab.sampleID\": \"\).*/\1$1_$2\",/" \
	 -e "s/\(  \"captainAchab.inputVcf\": \"\/RS_IURC\/data\/MobiDL\/captainAchab\/Todo\/\).*/\1$1_$2\/$3.$1_$2.vcf\",/" \
	 -e "s/\(  \"captainAchab.customVCF\":\"\).*/\1\/RS_IURC\/data\/MobiDL\/captainAchab\/Example\/DSD\/db.vcf\",/" \
	 -e "s/\(  \"captainAchab.fastaGenome\":\"\/usr\/local\/share\/refData\/genome\/\).*/\1${GENOME}\/${GENOME}.fa\",/" \
	 -e "s/\(  \"captainAchab.diseaseFile\": \"\/RS_IURC\/data\/MobiDL\/captainAchab\/Todo\/\).*/\1$1_$2\/disease.txt\",/" "splitted_vcf/$1_$2/captainAchab_inputs.json"
	rm "splitted_vcf/$1_$2/captainAchab_inputs.json.bak"
}

if [ ! -f "${BCFTOOLS}" ];then
	error "bcftools not found"
fi

info "VCF file is ${VCF} and Sample Number in new VCFs will be ${SAMPLE_NUM}"
END=$((SAMPLE_NUM-1))

if [ -f "${VCF}" ];then
	VCFNAME=$(basename -- "${VCF}")
	FILEEXT="${VCFNAME##*.}"
	FILENAME="${VCFNAME%.*}"
	if [ "${FILEEXT}" == "vcf" ];then
		info "${VCF} exists and will be treated"
		mkdir splitted_vcf
		touch sample_location.txt
		SAMPLE_COUNT=0
		INTERMEDIATE=0
		BEGIN=0
		#SAMPLES=$(${BCFTOOLS} query -l ${VCF} | cut -f 1- | awk '{print}')
		for SAMPLE in `"${BCFTOOLS}" query -l "${VCF}"`; do
			SAMPLES[${INTERMEDIATE}]=${SAMPLE}
			if [ ${#SAMPLES[@]} -gt ${END} ];then
				treat_samples "${BEGIN}" "${SAMPLE_COUNT}" "${FILENAME}" "${VCF}" "${BCFTOOLS}" "${SAMPLE}"
				((SAMPLE_COUNT++))
				INTERMEDIATE=0
				unset SAMPLES
				BEGIN=${SAMPLE_COUNT}
			else
				((SAMPLE_COUNT++))
				((INTERMEDIATE++))
			fi
		done
		treat_samples "${BEGIN}" "${SAMPLE_COUNT}" "${FILENAME}" "${VCF}" "${BCFTOOLS}" "${SAMPLE}"
		info "${SAMPLE_COUNT} samples processed"
	else
		error "${VCF} does not appear to have a .vcf extension"
	fi
fi


