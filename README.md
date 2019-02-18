# README #

Utilities to populate LED database

### Set up ###

* Clone the repos
* modify login/password for LED connection in import_vcf.pl

### Run ###

* put vcf files and corresponding text files (see import_batch_led.sh -h for format details)
* run import_batch_led.sh

### splitVCF4LED ###

* Example

```bash
bash splitVCF4LED.sh -i /RS_IURC/data/MobiDL/captainAchab/Example/ND/LED/LED-19-10-2018/ATX1289.final.vcf -s .final
```

* to generate a sample file with custom info

```bash
bash splitVCF4LED.sh -i /RS_IURC/data/MobiDL/captainAchab/Example/ND/LED/LED-19-10-2018/ATX1289.final.vcf -af -f S1376 -e medehome -t SENSORINEURAL
```