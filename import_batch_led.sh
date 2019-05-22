#/bin/bash


VERSION=1.0
USAGE="
Program: import_batch_led
Version: ${VERSION}
Contact: Baux David <david.baux<at>inserm.fr>

Usage: $(basename "$0") [options] -- program to import a batch of VCF and txt files into LED. Single VCF output for all samples.

Example:
sh import_batch_led.sh -d path/to/vcf/folder/ [-p '.final' ]

Arguments:

    -d,     --directory path to the directory containing the vcf and txt files
    -p,     --prefix    prefix to use to name vcf files see example below
    -l,	    --login	database login
    -pa,    --password	database password

Example text file:

#patient_id	less than 10 chars
#family_id	less than 10 chars
#gender		m/f
#disease_name	RP,DFNB,DFNA,USH,ATAXIA,MYOPATHY,HEALTHY,CF,CF-RD,CBAVD
#team_name	SENSORINEURAL,NEUROMUSCULAR,ATAXIA,MUCO
#visibility	0/1
#experiment	trusight_one,exome_ss_v6,cftr_complete
patient_id:1558
family_id:318
gender:f
disease_name:CF
team_name:MUCO
visibility:1
experiment_type:cftr_complete

name of txt file and of vcf file must match,
e.g.
1558.txt and 1558.vcf
unless -p is used

if you have 1558.txt and 1558.final.vcf use -p '.final'

"
IMPORT_SCRIPT=import_vcf.pl
DOS2UNIX=/usr/local/bin/dos2unix


##############		If no options are given, print help message	#################################

if [ $# -eq 0 ]; then
	echo "${USAGE}"
	echo "Error Message : No arguments provided"
	echo ""
	exit 1
fi


###############		Get arguments from command line			#################################

while [[ "$#" -gt 0 ]]
do
KEY="$1"
case "${KEY}" in
    -d|--directory)					#mandatory
    DIR="$2"
    shift
    ;;
    -p|--prefix)
    PREFIX="$2"
    shift
    ;;
    -l|--login)
    LOGIN="$2"
    shift
    ;;
    -pa|--password)
    PASSWORD="$2"
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

########	add / to INPUT_PATH if needed
if [[ "${DIR}" =~ .+[^\/]$ ]];then
	DIR="${DIR}/"
fi

######## check mandatory arguments
if [ ! "${DIR}" or ! "${LOGIN}" or ! "${PASSWORD}" ];then
	echo "${USAGE}"
	echo "Error Message : Missing argument"
	echo ""
	exit 1
fi

#get file list from $DIR
FILES=$(ls -l ${DIR} | grep -v '^d' | awk '{print $9}' | grep -e '.txt$')

for FILE in ${FILES}
do
    if [[ "${FILE}" =~ (.+)\.txt ]];then
        #for each text file we build the expected vcf name
        VCF="${BASH_REMATCH[1]}${PREFIX}.vcf"
        if [ -f "${DIR}/${VCF}" ];then
            #if name is ok
            #dos2unix conversion then launch import script
            ${DOS2UNIX} ${DIR}${FILE}
            if [ "$?" -eq 0 ];then
                ${DOS2UNIX} ${DIR}${VCF}
                if [ "$?" -eq 0 ];then
                    ./"${IMPORT_SCRIPT}" -p "${DIR}${FILE}" -i "${DIR}${VCF}" -l "${LOGIN}" -pa "${PASSWORD}" -c
                    if [ "$?" -eq 0 ];then
                        echo "${BASH_REMATCH[1]} done"
                    else
                        echo "pb with ${FILE}"
                    fi
                else
                    echo "Permissions pb with file ${DIR}${VCF}"
                fi
            else
                echo "Permissions pb with file ${DIR}${FILE}"
            fi
        else
            echo "No vcf file matching ${FILE}"
        fi
        
    fi
done

exit
