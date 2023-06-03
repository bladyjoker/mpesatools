preprocess() {
    PDF=$1;
    WORK=$2
    TXT_1=$(echo $WORK/txt_1);
    TXT=$(echo $WORK/mpesa.txt);

    pdftotext -raw -layout -nodiag -nopgbrk $PDF $TXT_1;

    CODE=$(cat $TXT_1 | egrep -n2 "^Page [0-9]+ of" | egrep -o "[0-9A-Z]{8}$" | sort -nu);

    cat $TXT_1 \
        | egrep -v "Disclaimer: This record is produced" \
        | egrep -v '^guidance.$' \
        | egrep -v "To verify the validity" \
        | egrep -v "and follow prompts to enter the code" \
        | egrep -v "For self-help dial" \
        | egrep -v "Statement Verification Code" \
        | egrep -v "Page [0-9]+ of " \
        | egrep -v $CODE > $TXT;
}
