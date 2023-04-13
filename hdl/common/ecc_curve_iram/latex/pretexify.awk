BEGIN {
}

{
	if ($1 ~ /NNCLR/) {
		printf "\t%s\t\t\t%s\n", $1, $2
	} else if ($1 ~ /NNMOV/){
		printf "\t%s\t%s\t\t%s\n", $1, $2, $3
	} else if ($1 ~ /NNADD/){
		printf "\t%s\t%s\t%s\t%s\n", $1, $2, $3, $4
	} else if ($1 ~ /NNSUB/){
		printf "\t%s\t%s\t%s\t%s\n", $1, $2, $3, $4
	} else if ($1 ~ /FPREDC/){
		printf "\t%s\t%s\t%s\t%s\n", $1, $2, $3, $4
	} else if ($1 ~ /NNXOR/){
		printf "\t%s\t%s\t%s\t%s\n", $1, $2, $3, $4
	} else if ( ($1 ~ /NNSRLs/) || ($1 ~ /NNSRLf/) ) {
		printf "\t%s\t%s\t%s\t%s\n", $1, $2, $3, $4
	} else if ( ($1 ~ /NNSRL/) || ($1 ~ /NNSRL,X/ ) ) {
		printf "\t%s\t%s\t\t%s\n", $1, $2, $3
	} else if ( ($1 ~ /NNSLL/) || ($1 ~ /NNSLL,X/ ) ) {
		printf "\t%s\t%s\t\t%s\n", $1, $2, $3
	} else if ( ($1 ~ /NNRNDs/) || ($1 ~ /NNRNDf/) ) {
		printf "\t%s\t\t%s\t%s\n", $1, $2, $3
	} else if ( ($1 ~ /NNs/) || ($1 ~ /NNRNDf/) ) {
		printf "\t%s\t\t%s\t%s\n", $1, $2, $3
	} else if ( ($1 ~ /NNRND/ || ($1 ~ /NNRNDm/) )) {
		printf "\t%s\t\t\t%s\n", $1, $2
	} else if ($1 ~ /NNDIV2/) {
		printf "\t%s\t%s\t\t%s\n", $1, $2, $3
	} else if ($1 ~ /TESTPARs/) {
		printf "\t%s\t%s\t%s\t%s\n", $1, $2, $3, $4
	} else if ($1 ~ /TESTPAR/) {
		printf "\t%s\t%s\t\t%s\n", $1, $2, $3
	} else if ($1 ~ /NOP/){
		printf "\t%s\n", $1
	} else if ($1 ~ /STOP/){
		printf "\t%s\n", $1
	} else if ($1 ~ /BARRIER/){
		printf "\t%s\n", $1
	} else if ($1 ~ /RET/){
		printf "\t%s\n", $1
	} else if ($1 ~ /J/){
		printf "\t%s\t%s\n", $1, $2
	} else {
		print $0
	}
}
