#!/usr/bin/env bash
set -e
PROGNAME=$0

usage() {
    cat << EOF >&2
    Usage: $PROGNAME [-r <ref_name>] [-c <chromSize_file>] [-R <restrict_sites>] [-b <bam_file>] [-o <output_dir>] 
                     [-Q <min_mapq>] [-G <max_inter_align_gap>] [-O <offset_restriction_site>] [-M <max_ligation_size>]
                     [-d <drop>] [-D <intermediate_dir>] [-t <threads>] 
    
    Dependency: pairtools pbgzip

    This script will use pairtools to parse the BAM alignments to interaction read pairs in .pairs format, and apply
    de-duplication and filtering.

    -r : Reference assembly name, such as "hg38"
    -c : Chromosome size file.
    -R : DNA restriction enzyme digestion sites bed file.
    -b : BAM file generated by "bwa mem -SP5M" mapping of iMARGI data.
    -o : Output directoy
    -Q : Min MAPQ value, default 1.
    -G : Max inter align gap for pairtools parsing. Default 20. It will allow R1 5' end clipping.
    -O : Max mis-offset bases for filtering pairs based on R2 5' end positions to restriction sites. Default 0.
    -M : Max size of ligation fragment for sequencing. It's used for filtering unligated DNA sequence.
    -d : Flag of dropping. Default is false, i.e., output all the intermediate results.
    -D : Directory for intermediate results. Works when -d false. Default is a sub-folder "intermediate_results" 
         in output directory.
    -t : Max CPU threads for parallelized processing, at least 4. (Default 8)
    -h : Show usage help
EOF
    exit 1
}

while getopts :r:c:R:b:o:Q:G:O:M:d:D:t:h opt; do
    case $opt in
        r) ref_name=${OPTARG};;
        c) chromsize=${OPTARG};;
        R) rsites=${OPTARG};;
        b) bamfile=${OPTARG};;
        o) output_dir=${OPTARG};;
        Q) mapq=${OPTARG};;
        G) gap=${OPTARG};;
        O) offset=${OPTARG};;
        M) max_ligation_size=${OPTARG};;
        d) dflag=${OPTARG};;
        D) inter_dir=${OPTARG};;
        t) threads=${OPTARG};;
        h) usage;;
    esac
done

# threshold of: (#paired_unique_mapping + #single_side_unique_mapping) / #total_read_pairs
pass_mapping=0.25
warn_mapping=0.5
# threshold of: #final_valid_pairs / #paired_unique_mapping
pass_valid=0.25
warn_valid=0.5

[ -z "$ref_name" ] && echo "Error!! Please provide reference genome name with -r" && usage
[ ! -f "$chromsize" ] && echo "Error!! Chomosome size file not exist: "$chromsize && usage
[ ! -f "$rsites" ] && echo "Error!! Resitriction sites file not exist: "$rsites && usage
[ ! -f "$bamfile" ] && echo "Error!! BAM file not exist: "$bamfile && usage
[ ! -d "$output_dir" ] && echo "Error!! Output directory not exist: "$output_dir && usage

[  -z "$mapq" ] && echo "Use default min mapq for pairtools parsing." && mapq=20
if ! [[ "$mapq" =~ ^[0-9]+$ ]]; then
    echo "Error!! Only integer number is acceptable for -g" && usage 
fi

[  -z "$gap" ] && echo "Use default max inter align gap for pairtools parsing." && gap=20
if ! [[ "$gap" =~ ^[0-9]+$ ]]; then
    echo "Error!! Only integer number is acceptable for -g" && usage 
fi

[  -z "$offset" ] && echo "Use default offset 0'." && offset=0
if ! [[ "$offset" =~ ^[0-9]+$ ]]; then
    echo "Error!! Only integer number is acceptable for -O" && usage 
fi

[  -z "$max_ligation_size" ] && echo "Use default max ligation size 1000'." && max_ligation_size=1000
if ! [[ "$max_ligation_size" =~ ^[0-9]+$ ]]; then
    echo "Error!! Only integer number is acceptable for -M" && usage 
fi

[  -z "$dflag" ] && echo "Use default setting '-d false'." && dflag="false"
if [[ "$dflag" != "false" ]] && [[ "$dflag" != "true" ]]; then
    echo "Error!! Only true or false is acceptable for -d." && usage
fi

if [[ "$dflag" == "false" ]] ; then
    [  -z "$inter_dir" ] && \
        echo "Use default directory for intermediate result files: "$output_dir"/intermediate_results" && \
        inter_dir="$output_dir/intermediate_results" && mkdir $inter_dir
    [ ! -d "$inter_dir" ] && echo "Error!! Directory for intermediate result files not exist: "$inter_dir && usage
else
    inter_dir=$output_dir"/inter_bam2pairs_"$RANDOM""$RANDOM
    mkdir $inter_dir
fi

[  -z "$threads" ] && echo "Use default thread number 8'." && threads=8
if ! [[ "$threads" =~ ^[0-9]+$ ]]; then
    echo "Error!! Only integer number is acceptable for -t" && usage 
fi

filebase=$(basename ${bamfile%.*})
all_pairs=$inter_dir"/all_"$filebase".pairs.gz"
sorted_all_pairs=$inter_dir"/sorted_all_"$filebase".pairs.gz"
dedup_pairs=$inter_dir"/dedup_"$filebase".pairs.gz"
ummapped_pairs=$inter_dir"/unmapped_"$filebase".pairs.gz"
duplication_pairs=$inter_dir"/duplication_"$filebase".pairs.gz"
final_pairs=$output_dir"/final_"$filebase".pairs.gz"
drop_pairs=$inter_dir"/drop_"$filebase".pairs.gz"
stats=$inter_dir"/stats_final_"$filebase".txt"
# ummapped_pairsam=$inter_dir"/unmapped_"$filebase".pairsam.gz"
# duplication_pairs=$inter_dir"/duplication_"$filebase".pairs.gz"
# dedup_pairsam=$inter_dir"/dedup_"$filebase".pairsam.gz"
# dedup_bam=$inter_dir"/dedup_"$filebase".bam"
# final_pairs=$output_dir"/final_"$filebase".pairs.gz"
# final_bam=$output_dir"/final_"$filebase".bam"
# drop_pairsam=$inter_dir"/drop_"$filebase".pairsam.gz"
# stats=$output_dir"/stats_final_"$filebase".txt"
# tmp_dir=$inter_dir"/"$RANDOM
# mkdir $tmp_dir

date
echo "Start parsing ..."

pairtools parse -c $chromsize \
    --assembly $ref_name \
    --add-columns mapq,cigar \
    --no-flip \
    --min-mapq $mapq \
    --max-inter-align-gap $gap \
    --drop-sam \
    --report-alignment-end 5 \
    --walks-policy 5any \
    --nproc-in $(($threads/3+1)) \
    --nproc-out $(($threads-$threads/3-1)) \
    --output $all_pairs \
    $bamfile 

date
echo "Start sort ..."
pairtools sort \
    --nproc $(($threads/2 + 1)) \
    --tmpdir $inter_dir \
    --nproc-in $(($threads/3+1)) \
    --nproc-out $(($threads-$threads/3-1)) \
    --output $sorted_all_pairs \
    $all_pairs

date
echo "Start de-duplication ..."

pairtools dedup \
    --mark-dups \
    --nproc-in $(($threads/3+1)) \
    --output-stats $inter_dir"/stats_dedup_"$filebase".txt" \
    --output-dups  $duplication_pairs \
    --output-unmapped $ummapped_pairs \
    $sorted_all_pairs |\
    imargi_restrict.py \
    --frags $rsites \
    --output $dedup_pairs \
    --nproc-out $(($threads-$threads/3-1))

date 
echo "Start filtering ... "

select_str="regex_match(pair_type, \"[UuR][UuR]\") and \
    dist2_rsite != \"!\" and \
    (abs(int(dist2_rsite)) <= "$offset") and \
    (not (chrom1 == chrom2 and \
        abs(int(dist1_rsite)) <= "$offset" and \
        strand1 != strand2 and \
        ((strand1 == \"+\" and strand2 == \"-\" and int(frag1_start) <= int(frag2_start) and \
            abs(int(frag2_end) - int(frag1_start)) <= "$max_ligation_size") or \
         (strand1 == \"-\" and strand2 == \"+\" and int(frag1_start) >= int(frag2_start) and \
            abs(int(frag1_end) - int(frag2_start)) <= "$max_ligation_size"))))"  

# echo $select_str

pairtools select "$select_str" \
    --chrom-subset $chromsize \
    --output-rest $drop_pairs \
    --nproc-in $(($threads/3+1)) \
    --nproc-out $(($threads-$threads/3-1)) \
    --output $final_pairs \
    $dedup_pairs

pairix -f $final_pairs

date 
echo "Generating final stats ... "

pairtools stats \
    --nproc-in $(($threads/3+1)) \
    --nproc-out $(($threads-$threads/3-1)) \
    --output $stats \
    $final_pairs

rm $all_pairs

awk -v pass_mapping=$pass_mapping -v warn_mapping=$warn_mapping \
    -v pass_valid=$pass_valid -v warn_valid=$warn_valid \
    'BEGIN{
        FS="\t"; OFS="\t"
    }FNR==NR{
        if(FNR<7){count_raw[$1]=$2};
    }FNR!=NR{
        if(FNR<9){count[$1]=$2}else{exit};
    }END{
        qc_mapping=(count_raw["total_single_sided_mapped"] + count_raw["total_mapped"])/count_raw["total"];
        qc_valid=count["total"]/count_raw["total_nodups"];
        if(qc_mapping >= pass_mapping && qc_valid >= pass_valid){
            warn_message="";
            if(qc_mapping < warn_mapping || qc_valid < warn_valid){
                warn_message=" (The sequence mapping rates are lower than average. Experimental repetition or improvements are recommended.)"
            };
            print "Sequence mapping QC\tpassed"warn_message;
        }else{print "Sequence mapping QC\tfailed"};
        print "(#unique_mapped_pairs + #single_side_unique_mapped)/#total_read_pairs", qc_mapping;
        print "#total_valid_interactions/#nondup_unique_mapped_pairs", qc_valid;
        print "total_read_pairs", count_raw["total"];
        print "single_side_unique_mapped", count_raw["total_single_sided_mapped"];
        print "unique_mapped_pairs", count_raw["total_mapped"];
        print "nondup_unique_mapped_pairs", count_raw["total_nodups"];
        print "total_valid_interactions", count["total"];
        print "inter_chr", count["trans"];
        print "intra_chr", count["cis"];
    }'  $inter_dir/stats_dedup_$filebase.txt $stats > $output_dir/pipelineStats_$filebase.log

date
echo "Parsing and filtering finished."

if [[ "$dflag" == "true" ]]; then
    rm -rf $inter_dir
fi
