#!/usr/bin/perl -w 
use strict;
use Cwd 'abs_path';
use File::Basename qw(basename);
use FindBin qw($Bin);
use Getopt::Long;
my ($ss,$OutDir,$genome,$trim,$q,$DNAdepth,$RNAdepth,$posdir,$editLevel,$mq,$ploidy,$help,$samtools,$blat,$phred,$goodRead,$readType,$pvalue,$Bayesian_Posterior_Probability,$P_value_DNA_Heterozygosis,$FDR_DNA_Heterozygosis,$Non_Ref_BaseCount,$Non_Ref_BaseRatio,$config,$knownSNP,$rmdup,$extremeLevel,$junctionCoordinate,$run);
$ss ||=1;
$trim ||="6,6";
$q ||= 30;
$mq ||= 20;
$DNAdepth ||= 10;
$RNAdepth ||= 3;
$editLevel ||= 0.05;
$extremeLevel ||= 0;
$ploidy ||= 2;
$phred ||="33,33";
$goodRead ||= 1;
$readType ||= 3;
my $editDepth ||= 3;
$pvalue ||= 0.05;
my $method ||= "Bayesian";
my $HomoPrior ||= 0.99;
my $rate ||= 2; #the rate of transition over transversion
$Bayesian_Posterior_Probability ||= 0.95;
$P_value_DNA_Heterozygosis ||= 0.05;
$FDR_DNA_Heterozygosis ||= 0.05;
$Non_Ref_BaseCount ||= 0;
$Non_Ref_BaseRatio ||= 0;
$rmdup ||= 1;
my $paralogous_R ||= 0;
my $paralogous_D ||= 0;
my $homopolymer ||= 0;
my $intronic ||=6;
my $refined ||= 1;
my $bestHitRatio ||= 0.6;
my $uniqTag ||= 0;

GetOptions(
		"config:s"=>\$config,
		"out:s"=>\$OutDir,
		"genome:s"=>\$genome,
		"ss:s"=>\$ss,
		"trim:s"=>\$trim,
		"q:s"=>\$q,
		"mq:s"=>\$mq,
		"phred:s"=>\$phred,
		"DNAdepth:s"=>\$DNAdepth,
		"RNAdepth:s"=>\$RNAdepth,
		"readType:s"=>\$readType,
		"editDepth:s"=>\$editDepth,
		"refined:s"=>\$refined,
		"refinedDepth:s"=>\$goodRead,
		"posdir:s"=>\$posdir,
		"editLevel:s"=>\$editLevel,
		"extremeLevel:s"=>\$extremeLevel,
		"editPvalue:s"=>\$pvalue,
		"ploidy:s"=>\$ploidy,
		"samtools:s"=>\$samtools,
		"blat:s"=>\$blat,
		"method:s"=>\$method,
		"HomoPrior:s"=>\$HomoPrior,
		"rate:s"=>\$rate,
		"Bayesian_P:s"=>\$Bayesian_Posterior_Probability,
		"Binomial_P:s"=>\$P_value_DNA_Heterozygosis,
		"Binomial_FDR:s"=>\$FDR_DNA_Heterozygosis,
		"Frequency_N:s"=>\$Non_Ref_BaseCount,
		"Frequency_R:s"=>\$Non_Ref_BaseRatio,
		"paralogous_R:s"=>\$paralogous_R,
		"paralogous_D:s"=>\$paralogous_D,
		"homopolymer:s"=>\$homopolymer,
		"intronic:s"=>\$intronic,
		"knownSNP:s"=>\$knownSNP,
		"rmdup:s"=>\$rmdup,
		"junctionCoordinate:s"=>\$junctionCoordinate,
		"bestHitRatio:s"=>\$bestHitRatio,
		"uniqTag"=>\$uniqTag,
		"run"=>\$run,
		"help"=>\$help,
		);

if( !$config || !$OutDir || !$genome || !$samtools || $help){
	print <<"Usage End.";
Description:
	RNA editing identification pipline.

Options:
		--config        FILE    Tab-Delimited configuration file with three columns.
		                        Format:
		                           1) sampleID, which mustbe unique for each line;
		                           2) absolute path of bam file for DNA data alignment;
		                           3) absolute path of bam file for RNA data alignment.
		--out           STR     The output directory.
		--genome        FILE    Reference genome.
		--ss            NUM     Strand-specific RNA-Seq data, 1 for yes, 0 for no. 
		                        Note: Only strand-specific RNA-Seq library generated by the dUTP protocol is supported currently. [1]
		--trim          INT     The number of bases solf-clipped at "5'end,3'end" of a read. [6,6]
		--q             NUM     Phred-scaled base quality score cutoff. [30]
		--mq            NUM     Mapping quality score cutoff [20]
		--phred         NUM     The Phred base quality for query QUALity of DNA.bam and RNA.bam files respectively, default DNA_ASCII-33,RNA_ASCII-33. [33,33]
		--DNAdepth      INT     The minimum depth of DNA reads required by a candidate editing site. 
		                        A genomic site covered by less than this depth will be filtered. [10]
		--RNAdepth      INT     The minimum depth of RNA reads required by a candidate editing site.
		                        A genomic site covered by less than this depth will be filtered. [3]
		--posdir        STR     Set the directory of genomic feature pos files. The name of genomic feature pos files 
		                        in the directory should be given as 'FeatureName.pos' (e.g. 5UTR.pos, CDS.pos, intron.pos, 
		                        3UTR.pos, ncRNA.pos, repeat.pos, and so on). If the file with name of 'CDS.pos' is provided, 
		                        the function of inferring the codon and amino acid change after RNA editing is activated. [null]
		--editLevel     Float   The minimum editing level required by a candidate editing site, ranging from 0 to 1. [0.05]
		--extremeLevel  NUM     Exclude polymorphic sites with extreme degree of variation (100%) or not. 1 for yes, 0 for not. [0]
		--editDepth     INT     The minimum number of RNA reads supporting editing for a candidate editing site. [3]
		--refined       NUM     Whether refined the number of RNA reads supporting candidate editing sites. 1 for yes, 0 for no. [1];
		--refinedDepth  INT     The minimum number of RNA reads in the middle of its length supporting editing for a candidate editing site.
		                        (e.g. from positions 23~68 of a 90-bp read). [1]
		--junctionCoordinate FILE The file with name of "junctionFlankSequenceRegion.txt" created by RES-Scanner_alignment '--junction' option,
		                          applicable only for the input reference genome including exonic sequences surrounding splicing junctions. [null]
		--readType      INT     The minimum number of unique RNA reads supporting editing for a candidate editing site. [3]						
		--editPvalue    Float   The cutoff of binomial test FDR for candidate editing sites. [0.05]
		--ploidy        INT     Ploidy level of the samples, 1 for monoploid , 2 for diploid, 3 for triploid, 
		                        4 for tetraploid, and so on. [2].
		--paralogous_R  NUM     Remove candidate editing sites from those regions that are similar to other parts of the genome 
		                        by BLAT alignment. 1 for yes, 0 for not. Note: force --blat. [0] 
		--paralogous_D  NUM 	Discard candidate editing sites with DNA reads depth of more than 
		                        twice the genome-wide peak or mean depth. 1 for yes, 0 for not. [0]
		--homopolymer   NUM     Remove candidate editing sites in homopolymer runs of >= 5 base pairs. 1 for yes, 0 for not. [0]
		--intronic      NUM     Remove intronic candidate editing sites occurring within n bases of a splice site. [6]
		--knownSNP      FILE    The known SNPs file with gff format. [null]
		--rmdup         NUM     Remove PCR duplicates for BAM file. 1 for yes, 0 for not. [1]
		--bestHitRatio  Float   The proportion of qualified reads over all BLAT re-aligned reads. [0.6]
		--uniqTag       NUM     Whether identify the unique mapping and no suboptimal hits reads in BAM file with the tags 
		                        "XT:A:U" & "X0:i:1" & "X1:i:0". 1 for YES , 0 for NO. [0] 
		                        Note: If the BAM file was generated by RES-Scanner_alignment pipeline, 
		                              please set '--uniqTag 1' to infer unique mapping alignment.
		--samtools      FILE    The absolute path of pre-installed SAMtools software. (required)
		--blat          FILE    The absolute path of pre-installed BLAT software. (optional)
		--run                   Run the jobs directly with serial working mode.
		--help                  Show the help information.
	Parameters for homozygous genotype calling:
		--method        STR     Method for calling homozygous genotypes: Bayesian, Binomial and Frequency. [Bayesian]
		--HomoPrior     Float   The prior probability for a genomic position to be homozygous (force --method Bayesian). [0.99]
		--rate          NUM     The rate of transitions over transversions of the genome (force --method Bayesian). [2]
		--Bayesian_P    Float   The minimum Bayesian Posterior Probability cutoff for calling a homozygous genotype, 
		                        range from 0 to 1, the bigger the better. (force --method Bayesian) [0.95]
		--Binomial_P    Float   The maximum P-value cutoff of Binomial test for calling a homozygous genotype, 
		                        range from 0 to 1, the smaller the better. (force --method Binomial) [0.05]
		--Binomial_FDR  Float   The maximum FDR cutoff of Binomial test for calling a homozygous genotype, 
		                        range from 0 to 1, the smaller the better. (force --method Binomial) [0.05]
		--Frequency_N   NUM     The maximum count of the alternative allele presented in the DNA-Seq data for 
		                        a candidate editing site. (force --method Frequency) [0]
		--Frequency_R   Float   The maximum frequency of the alternative allele presented in the DNA-Seq data for 
		                        a candidate editing site, range from 0 to 1. (force --method Frequency) [0]
		
Usage:
	1.	For strand-specific RNA-Seq data:
		perl $0 --config config.file --out ./outdir/ --genome reference.fa --ss 1 --samtools /absolute_path/samtools --blat /absolute_path/blat
	2.	For non-strand-specific RNA-Seq data:
		perl $0 --config config.file --out ./outdir/ --genome reference.fa  --ss 0 --samtools /absolute_path/samtools --blat /absolute_path/blat

Usage End.
		exit;
}

foreach my $software ($samtools){
	die "Error: $software is not existent!\n" unless -e $software;
}
$samtools=abs_path $samtools;

if(defined $blat){
	die "Error: $blat is not existent!\n" unless -e $blat;
	$blat=abs_path $blat;
}

my $bestUniq="$Bin/bin/bestUniqForSam.pl";
my $sam2base="$Bin/bin/sam2base.pl";
my $GetAlignmentErrorsID="$Bin/bin/GetAlignmentErrorsID.pl";
my $filter_abnormal_alignment_forBWA="$Bin/bin/filter_abnormal_alignment_forBWA.pl";
my $Bam2FaQuery="$Bin/bin/Bam2FaQuery.pl";
my $sam2base_statistic="$Bin/bin/sam2base_statistic.pl";
my $RNA_edit_site_table = "$Bin/bin/RNA_edit_site_table.pl";
my $classify_RNA_reads="$Bin/bin/classify_RNA_reads.pl";
my $type2pos = "$Bin/bin/site2pos.pl";
my $findOverlap = "$Bin/bin/findOverlap.pl";
my $addFeature2RNAediting = "$Bin/bin/addFeature2RNAediting.pl";
my $filter_edit_site_table = "$Bin/bin/filter_edit_site_table.pl";
my $bigTable = "$Bin/bin/bigTable.pl";
my $GetCodonInf = "$Bin/bin/GetCodonInf.pl";
my $Amino_acid_change = "$Bin/bin/Amino_acid_change.pl";
my $substring_bilateral_sequence_of_site = "$Bin/bin/substring_bilateral_sequence_of_site.pl";
my $filter_sites_in_paralogous_regions = "$Bin/bin/filter_sites_in_paralogous_regions.pl";
my $filter_knownSNPs = "$Bin/bin/filter_knownSNPs.pl";
my $remove_conflict_editType = "$Bin/bin/remove_conflict_editType.pl";
my $src_utils_pslScore_pslScore = "$Bin/bin/src_utils_pslScore_pslScore.pl";
my $pslScore2editSite = "$Bin/bin/pslScore2editSite.pl";

foreach my $perl_script ($bestUniq,$sam2base,$GetAlignmentErrorsID,$filter_abnormal_alignment_forBWA,$Bam2FaQuery,$sam2base_statistic,$RNA_edit_site_table,$type2pos,$findOverlap,$addFeature2RNAediting,$filter_edit_site_table,$bigTable,$GetCodonInf,$Amino_acid_change,$substring_bilateral_sequence_of_site,$filter_sites_in_paralogous_regions,$filter_knownSNPs,$remove_conflict_editType, $src_utils_pslScore_pslScore, $pslScore2editSite ){
	die "Error: $perl_script is not existent!\n" unless -e $perl_script;
}

if(defined $junctionCoordinate){
	$junctionCoordinate=abs_path $junctionCoordinate;
	die "Error: $junctionCoordinate is not existent!" unless -e $junctionCoordinate;
}



if($trim!~/^\d+,\d+$/){
	die "Error: --trim option should be two numbers separated by a comma, i.e. '6,6'.\n";
}

mkdir $OutDir unless -e $OutDir;
$OutDir = abs_path ($OutDir);
$genome=abs_path $genome;
my @posfile;
if(defined $posdir){
	$posdir=abs_path $posdir;
	@posfile=glob "$posdir/*.pos";
	if(@posfile==0){
		die "Error: There is no *.pos file in $posdir\n";
	}
}

open STEP1RE,">$OutDir/RES_step1.sh" or die $!;
open STEP2RE,">$OutDir/RES_step2.sh" or die $!;
open STEP3RE,">$OutDir/RES_step3.sh" or die $!;
open STEP4RE,">$OutDir/RES_step4.sh" or die $!;
open TABLE,">$OutDir/bigTable.config" or die $!;

my @STEP3LOG;

open IN,"$config" or die $!;
while(<IN>){
	chomp;
	my ($sampleID,$dnaBamfile,$rnaBamfile)=split /\s+/;
	my $outdir="$OutDir/$sampleID";
	mkdir $outdir unless -e $outdir;

	$dnaBamfile=abs_path $dnaBamfile;
	$rnaBamfile=abs_path $rnaBamfile;
	my $DNAfilename=basename($dnaBamfile);
	my $RNAfilename=basename($rnaBamfile);
	print TABLE "$sampleID\t$outdir\n";

#DNA shell beg
	open STEP1DNA,">$outdir/step1_DNA.sh" or die $!;
	print STEP1DNA "$samtools sort $dnaBamfile $outdir/$DNAfilename.DNA.sort\n";
	if($rmdup){
		print STEP1DNA "$samtools rmdup $outdir/$DNAfilename.DNA.sort.bam $outdir/$DNAfilename.DNA.sort.rmdup.bam 2>$outdir/$DNAfilename.DNA.sort.rmdup.bam.log\n";
	}else{
		print STEP1DNA "ln -s $outdir/$DNAfilename.DNA.sort.bam $outdir/$DNAfilename.DNA.sort.rmdup.bam\n";
	}
	print STEP1DNA "perl $bestUniq $outdir/$DNAfilename.DNA.sort.rmdup.bam $outdir $samtools --mq $mq --ss 0 --rmdup $rmdup --DNA --uniqTag $uniqTag\n";
	print STEP1DNA "perl $sam2base --trim $trim $genome $outdir/$DNAfilename.DNA.sort.rmdup.bam.best.bam $outdir/$DNAfilename.best.DNA.sam2base.gz --samtools $samtools\n";
	print STEP1DNA "perl $sam2base_statistic $genome $outdir/$DNAfilename.best.DNA.sam2base.gz > $outdir/$RNAfilename.best.DNA.sam2base.stat\n";
	print STEP1DNA "echo $sampleID DNA step1 is completed! > $outdir/step1_DNA.log\n";
	print STEP1DNA "echo $sampleID DNA step1 is completed!\n";
	close STEP1DNA;
#DNA shell end	
	print STEP1RE "sh $outdir/step1_DNA.sh\n";
#RNA shell beg
	open STEP1RNA,">$outdir/step1_RNA.sh" or die $!;
	print STEP1RNA "$samtools sort $rnaBamfile $outdir/$RNAfilename.RNA.sort\n";
	if($rmdup){
		print STEP1RNA "$samtools rmdup $outdir/$RNAfilename.RNA.sort.bam $outdir/$RNAfilename.RNA.sort.rmdup.bam 2>$outdir/$RNAfilename.RNA.sort.rmdup.bam.log\n";
	}else{
		print STEP1RNA "ln -s $outdir/$RNAfilename.RNA.sort.bam $outdir/$RNAfilename.RNA.sort.rmdup.bam\n";
	}
	print STEP1RNA "perl $bestUniq $outdir/$RNAfilename.RNA.sort.rmdup.bam $outdir $samtools --mq $mq --ss $ss --rmdup $rmdup --RNA --uniqTag $uniqTag\n";
	print STEP1RNA "echo $sampleID RNA step1 is completed! > $outdir/step1_RNA.log\n";
	print STEP1RNA "echo $sampleID RNA step1 is completed!\n";
	close STEP1RNA;
	print STEP1RE "sh $outdir/step1_RNA.sh\n";
	if($ss){
		open STEP2RNAPOS,">$outdir/step2_RNA_positive.sh" or die $!;
		open STEP2RNANEG,">$outdir/step2_RNA_negative.sh" or die $!;
		open STEP3POS,">$outdir/step3_positive.sh" or die $!;
		open STEP3NEG,">$outdir/step3_negative.sh" or die $!;
		print STEP2RNAPOS "if [ ! -f \"$outdir/step1_RNA.log\" ];then echo \"Warning: $outdir/step1_RNA.sh work is not completed! as $outdir/step1_RNA.log is not existent\"\nexit 0\nfi\n";
		print STEP2RNANEG "if [ ! -f \"$outdir/step1_RNA.log\" ];then echo \"Warning: $outdir/step1_RNA.sh work is not completed! as $outdir/step1_RNA.log is not existent\"\nexit 0\nfi\n";
		print STEP3POS "if [ ! -f \"$outdir/step2_RNA_pos.log\" ];then echo \"Warning: $outdir/step2_RNA_positive.sh work is not completed! as $outdir/step2_RNA_pos.log is not existent\"\nexit 0\nfi\n";
		print STEP3NEG "if [ ! -f \"$outdir/step2_RNA_neg.log\" ];then echo \"Warning: $outdir/step2_RNA_negative.sh work is not completed! as $outdir/step2_RNA_neg.log is not existent\"\nexit 0\nfi\n";
		print STEP3POS "if [ ! -f \"$outdir/step1_DNA.log\" ];then echo \"Warning: $outdir/step1_DNA.sh work is not completed! as $outdir/step2_RNA_pos.log is not existent\"\nexit 0\nfi\n";
		print STEP3NEG "if [ ! -f \"$outdir/step1_DNA.log\" ];then echo \"Warning: $outdir/step1_DNA.sh work is not completed! as $outdir/step2_RNA_neg.log is not existent\"\nexit 0\nfi\n";
	}else{
		open STEP2RNA,">$outdir/step2_RNA.sh" or die $!;
		open STEP3,">$outdir/step3.sh" or die $!;
		print STEP2RNA "if [ ! -f \"$outdir/step1_RNA.log\" ];then echo \"Warning: $outdir/step1_RNA.sh work is not completed! as $outdir/step1_RNA.log is not existent\"\nexit 0\nfi\n";
		print STEP3 "if [ ! -f \"$outdir/step2_RNA.log\" ];then echo \"Warning: $outdir/step2_RNA.sh work is not completed! as $outdir/step2_RNA.log is not existent\"\nexit 0\nfi\n";
	}
	if($ss){
		print STEP2RNAPOS "perl $sam2base --trim $trim $genome $outdir/$RNAfilename.RNA.sort.rmdup.bam.positive.bam $outdir/$RNAfilename.positive.RNA.sam2base.gz --samtools $samtools\n";
		print STEP2RNANEG "perl $sam2base --trim $trim $genome $outdir/$RNAfilename.RNA.sort.rmdup.bam.negative.bam $outdir/$RNAfilename.negative.RNA.sam2base.gz --samtools $samtools\n";
		print STEP2RNAPOS "perl $sam2base_statistic $genome $outdir/$RNAfilename.positive.RNA.sam2base.gz > $outdir/$RNAfilename.positive.RNA.sam2base.stat\n";
		print STEP2RNANEG "perl $sam2base_statistic $genome $outdir/$RNAfilename.negative.RNA.sam2base.gz > $outdir/$RNAfilename.negative.RNA.sam2base.stat\n";

		my ($method_options,$filter_options);
		if($method eq "Bayesian"){
			$method_options="--method $method --HomoPrior $HomoPrior --rate $rate";
			$filter_options="--method $method --Bayesian_P $Bayesian_Posterior_Probability";
		}elsif($method eq "Binomial"){
			$method_options="--method $method";
			$filter_options="--method $method --Binomial_P $P_value_DNA_Heterozygosis --Binomial_FDR $FDR_DNA_Heterozygosis";
		}elsif($method eq "Frequency"){
			$method_options="--method $method";
			$filter_options="--method $method --Frequency_N $Non_Ref_BaseCount --Frequency_R $Non_Ref_BaseRatio";
		}else{
			die "Error: unknown --Method $method";
		}
		print STEP3POS "perl $RNA_edit_site_table --RNA_singleBase $outdir/$RNAfilename.positive.RNA.sam2base.gz --DNA_singleBase $outdir/$DNAfilename.best.DNA.sam2base.gz --genome $genome --phred $phred --qual_cutoff $q --strand + --ploidy $ploidy $method_options --samtools $samtools | gzip > $outdir/$RNAfilename.positive.RNA.sam2base.homo.gz\n";
		print STEP3NEG "perl $RNA_edit_site_table --RNA_singleBase $outdir/$RNAfilename.negative.RNA.sam2base.gz --DNA_singleBase $outdir/$DNAfilename.best.DNA.sam2base.gz --genome $genome --phred $phred --qual_cutoff $q --strand - --ploidy $ploidy $method_options --samtools $samtools | gzip > $outdir/$RNAfilename.negative.RNA.sam2base.homo.gz\n";
		if(defined $knownSNP && -e $knownSNP){
			print STEP3POS "perl $filter_knownSNPs $outdir/$RNAfilename.positive.RNA.sam2base.homo.gz $knownSNP | gzip > $outdir/$RNAfilename.positive.RNA.sam2base.homo.noknownSNP.gz\n";
			print STEP3POS "mv -f $outdir/$RNAfilename.positive.RNA.sam2base.homo.noknownSNP.gz $outdir/$RNAfilename.positive.RNA.sam2base.homo.gz\n";
			print STEP3NEG "perl $filter_knownSNPs $outdir/$RNAfilename.negative.RNA.sam2base.homo.gz $knownSNP | gzip > $outdir/$RNAfilename.negative.RNA.sam2base.homo.noknownSNP.gz\n";
			print STEP3NEG "mv -f $outdir/$RNAfilename.negative.RNA.sam2base.homo.noknownSNP.gz $outdir/$RNAfilename.negative.RNA.sam2base.homo.gz\n";
		}
		print STEP3POS "perl $filter_edit_site_table --input $outdir/$RNAfilename.positive.RNA.sam2base.homo.gz --DNAdepth $DNAdepth --RNAdepth $RNAdepth --editLevel $editLevel --extremeLevel $extremeLevel --editDepth $editDepth --editPvalue $pvalue $filter_options | gzip > $outdir/$RNAfilename.positive.RNA.sam2base.homo.filter.gz\n";
		print STEP3NEG "perl $filter_edit_site_table --input $outdir/$RNAfilename.negative.RNA.sam2base.homo.gz --DNAdepth $DNAdepth --RNAdepth $RNAdepth --editLevel $editLevel --extremeLevel $extremeLevel --editDepth $editDepth --editPvalue $pvalue $filter_options | gzip > $outdir/$RNAfilename.negative.RNA.sam2base.homo.filter.gz\n";
		if($refined || $paralogous_R){
		print STEP3POS "perl $classify_RNA_reads --editTable $outdir/$RNAfilename.positive.RNA.sam2base.homo.filter.gz --RNA_bam $outdir/$RNAfilename.RNA.sort.rmdup.bam.positive.bam --refined $refined --paralogous_R $paralogous_R --readType $readType --refinedDepth $goodRead --samtools $samtools --phred $phred --qual_cutoff $q --trim $trim --outdir $outdir\n";
		print STEP3NEG "perl $classify_RNA_reads --editTable $outdir/$RNAfilename.negative.RNA.sam2base.homo.filter.gz --RNA_bam $outdir/$RNAfilename.RNA.sort.rmdup.bam.negative.bam --refined $refined --paralogous_R $paralogous_R --readType $readType --refinedDepth $goodRead --samtools $samtools --phred $phred --qual_cutoff $q --trim $trim --outdir $outdir\n";
		if($refined){
		print STEP3POS "mv -f $outdir/temp.$RNAfilename.positive.RNA.sam2base.homo.filter.gz $outdir/$RNAfilename.positive.RNA.sam2base.homo.filter.gz\n";
		print STEP3NEG "mv -f $outdir/temp.$RNAfilename.negative.RNA.sam2base.homo.filter.gz $outdir/$RNAfilename.negative.RNA.sam2base.homo.filter.gz\n";
		}
		if($paralogous_R){
			print STEP3POS "$blat $genome $outdir/$RNAfilename.RNA.sort.rmdup.bam.positive.bam.editRead.fa $outdir/$RNAfilename.RNA.sort.rmdup.bam.positive.bam.editRead.fa.psl -t=dna -q=dna -minIdentity=95 -noHead\n";
			print STEP3NEG "$blat $genome $outdir/$RNAfilename.RNA.sort.rmdup.bam.negative.bam.editRead.fa $outdir/$RNAfilename.RNA.sort.rmdup.bam.negative.bam.editRead.fa.psl -t=dna -q=dna -minIdentity=95 -noHead\n";
			print STEP3POS "perl $src_utils_pslScore_pslScore $outdir/$RNAfilename.RNA.sort.rmdup.bam.positive.bam.editRead.fa.psl > $outdir/$RNAfilename.RNA.sort.rmdup.bam.positive.bam.editRead.fa.psl.score\n";
			print STEP3NEG "perl $src_utils_pslScore_pslScore $outdir/$RNAfilename.RNA.sort.rmdup.bam.negative.bam.editRead.fa.psl > $outdir/$RNAfilename.RNA.sort.rmdup.bam.negative.bam.editRead.fa.psl.score\n";
			if($junctionCoordinate){
			print STEP3POS "perl $pslScore2editSite --pslScore $outdir/$RNAfilename.RNA.sort.rmdup.bam.positive.bam.editRead.fa.psl.score --junctionCoordinate $junctionCoordinate --editTable $outdir/$RNAfilename.positive.RNA.sam2base.homo.filter.gz --editDepth $editDepth --bestHitRatio $bestHitRatio | gzip > $outdir/temp.$RNAfilename.positive.RNA.sam2base.homo.filter.gz\n";
			print STEP3NEG "perl $pslScore2editSite --pslScore $outdir/$RNAfilename.RNA.sort.rmdup.bam.negative.bam.editRead.fa.psl.score --junctionCoordinate $junctionCoordinate --editTable $outdir/$RNAfilename.negative.RNA.sam2base.homo.filter.gz --editDepth $editDepth --bestHitRatio $bestHitRatio | gzip > $outdir/temp.$RNAfilename.negative.RNA.sam2base.homo.filter.gz\n";
			}else{
			print STEP3POS "perl $pslScore2editSite --pslScore $outdir/$RNAfilename.RNA.sort.rmdup.bam.positive.bam.editRead.fa.psl.score --editTable $outdir/$RNAfilename.positive.RNA.sam2base.homo.filter.gz --editDepth $editDepth --bestHitRatio $bestHitRatio | gzip > $outdir/temp.$RNAfilename.positive.RNA.sam2base.homo.filter.gz\n";
			print STEP3NEG "perl $pslScore2editSite --pslScore $outdir/$RNAfilename.RNA.sort.rmdup.bam.negative.bam.editRead.fa.psl.score --editTable $outdir/$RNAfilename.negative.RNA.sam2base.homo.filter.gz --editDepth $editDepth --bestHitRatio $bestHitRatio | gzip > $outdir/temp.$RNAfilename.negative.RNA.sam2base.homo.filter.gz\n";
			}
			print STEP3POS "mv -f $outdir/temp.$RNAfilename.positive.RNA.sam2base.homo.filter.gz $outdir/$RNAfilename.positive.RNA.sam2base.homo.filter.gz\n";
			print STEP3NEG "mv -f $outdir/temp.$RNAfilename.negative.RNA.sam2base.homo.filter.gz $outdir/$RNAfilename.negative.RNA.sam2base.homo.filter.gz\n";
		}
		}
	}else{
		print STEP2RNA "perl $sam2base --trim $trim $genome $outdir/$RNAfilename.RNA.sort.rmdup.bam.best.bam $outdir/$RNAfilename.best.RNA.sam2base.gz --samtools $samtools\n";
		print STEP2RNA "perl $sam2base_statistic $genome $outdir/$RNAfilename.best.RNA.sam2base.gz > $outdir/$RNAfilename.best.RNA.sam2base.stat\n";
		my ($method_options,$filter_options);
		if($method eq "Bayesian"){
			$method_options="--method $method --HomoPrior $HomoPrior --rate $rate";
			$filter_options="--method $method --Bayesian_P $Bayesian_Posterior_Probability";
		}elsif($method eq "Binomial"){
			$method_options="--method $method";
			$filter_options="--method $method --Binomial_P $P_value_DNA_Heterozygosis --Binomial_FDR $FDR_DNA_Heterozygosis";
		}elsif($method eq "Frequency"){
			$method_options="--method $method";
			$filter_options="--method $method --Frequency_N $Non_Ref_BaseCount --Frequency_R $Non_Ref_BaseRatio";
		}else{
			die "Error: unknown --Method $method";
		}
		print STEP3 "perl $RNA_edit_site_table --RNA_singleBase $outdir/$RNAfilename.best.RNA.sam2base.gz --DNA_singleBase $outdir/$DNAfilename.best.DNA.sam2base.gz --RNA_bam $outdir/$RNAfilename.RNA.sort.rmdup.bam.best.bam --genome $genome --phred $phred --qual_cutoff $q --strand unknown --ploidy $ploidy $method_options --samtools $samtools | gzip > $outdir/$RNAfilename.best.RNA.sam2base.homo.gz\n";
		if(defined $knownSNP && -e $knownSNP){
			print STEP3 "perl $filter_knownSNPs $outdir/$RNAfilename.best.RNA.sam2base.homo.gz $knownSNP | gzip > $outdir/$RNAfilename.best.RNA.sam2base.homo.noknownSNP.gz\n";
			print STEP3 "mv -f $outdir/$RNAfilename.best.RNA.sam2base.homo.noknownSNP.gz $outdir/$RNAfilename.best.RNA.sam2base.homo.gz\n";
		}
		print STEP3 "perl $filter_edit_site_table --input $outdir/$RNAfilename.best.RNA.sam2base.homo.gz --DNAdepth $DNAdepth --RNAdepth $RNAdepth --editLevel $editLevel --extremeLevel $extremeLevel --editDepth $editDepth --goodRead $goodRead --editPvalue $pvalue $filter_options | gzip > $outdir/$RNAfilename.best.RNA.sam2base.homo.filter.gz\n";
		print STEP3 "perl $classify_RNA_reads --editTable $outdir/$RNAfilename.best.RNA.sam2base.homo.filter.gz --RNA_bam $outdir/$RNAfilename.RNA.sort.rmdup.bam.best.bam --refined $refined --paralogous_R $paralogous_R --readType $readType --refinedDepth $goodRead --samtools $samtools --phred $phred --qual_cutoff $q --trim $trim --outdir $outdir\n";
		if($refined){
		print STEP3 "mv -f $outdir/temp.$RNAfilename.best.RNA.sam2base.homo.filter.gz $outdir/$RNAfilename.best.RNA.sam2base.homo.filter.gz\n";
		}
##a
        if($paralogous_R){
	        print STEP3 "$blat $genome $outdir/$RNAfilename.RNA.sort.rmdup.bam.best.bam.editRead.fa $outdir/$RNAfilename.RNA.sort.rmdup.bam.best.bam.editRead.fa.psl -t=dna -q=dna -minIdentity=95 -noHead\n";
			print STEP3 "perl $src_utils_pslScore_pslScore $outdir/$RNAfilename.RNA.sort.rmdup.bam.best.bam.editRead.fa.psl > $outdir/$RNAfilename.RNA.sort.rmdup.bam.best.bam.editRead.fa.psl.score\n";
			if($junctionCoordinate){
			print STEP3 "perl $pslScore2editSite --pslScore $outdir/$RNAfilename.RNA.sort.rmdup.bam.best.bam.editRead.fa.psl.score --junctionCoordinate $junctionCoordinate --editTable $outdir/$RNAfilename.best.RNA.sam2base.homo.filter.gz --editDepth $editDepth --bestHitRatio $bestHitRatio | gzip > $outdir/temp.$RNAfilename.best.RNA.sam2base.homo.filter.gz\n";
		    }else{
			print STEP3 "perl $pslScore2editSite --pslScore $outdir/$RNAfilename.RNA.sort.rmdup.bam.best.bam.editRead.fa.psl.score --editTable $outdir/$RNAfilename.best.RNA.sam2base.homo.filter.gz --editDepth $editDepth --bestHitRatio $bestHitRatio | gzip > $outdir/temp.$RNAfilename.best.RNA.sam2base.homo.filter.gz\n";
			}
		    print STEP3 "mv -f $outdir/temp.$RNAfilename.best.RNA.sam2base.homo.filter.gz $outdir/$RNAfilename.best.RNA.sam2base.homo.filter.gz\n";
		}
##a		
	}
	if($ss){
		print STEP2RNAPOS "echo $sampleID positive strand of step2 work is completed! > $outdir/step2_RNA_pos.log\n";
		print STEP3POS "echo $sampleID positive strand of step3 work is completed! > $outdir/step3pos.log\n";
		print STEP2RNANEG "echo $sampleID negative strand of step2 work is completed! > $outdir/step2_RNA_neg.log\n";
		print STEP3NEG "echo $sampleID negative strand of step3 work is completed! > $outdir/step3neg.log\n";
		print STEP2RNAPOS "echo $sampleID positive strand of step2 work is completed!\n";
		print STEP3POS "echo $sampleID positive strand of step3 work is completed!\n";
		print STEP2RNANEG "echo $sampleID negative strand of step2 work is completed!\n";
		print STEP3NEG "echo $sampleID negative strand of step3 work is completed!\n";
		push @STEP3LOG,"$outdir/step3pos.log","$outdir/step3neg.log";

		close STEP2RNAPOS;
		close STEP3POS;
		close STEP2RNANEG;
		close STEP3NEG;
		print STEP2RE "sh $outdir/step2_RNA_positive.sh\n";
		print STEP2RE "sh $outdir/step2_RNA_negative.sh\n";
		print STEP3RE "sh $outdir/step3_positive.sh\n";
		print STEP3RE "sh $outdir/step3_negative.sh\n";
	}else{
		print STEP2RNA "echo $sampleID step2 work is completed! > $outdir/step2_RNA.log\n";
		print STEP3 "echo $sampleID step3 work is completed! > $outdir/step3.log\n";
		print STEP2RNA "echo $sampleID step2 work is completed!\n";
		print STEP3 "echo $sampleID step3 work is completed!\n";
		push @STEP3LOG,"$outdir/step3.log";

		close STEP2RNA;
		close STEP3;
		print STEP2RE "sh $outdir/step2_RNA.sh\n";
		print STEP3RE "sh $outdir/step3.sh\n";
	}
#RNA shell end

}
close IN;
close STEP1RE;
close STEP2RE;
close STEP3RE;
close TABLE;


foreach my $logfile (@STEP3LOG){
	print STEP4RE "if [ ! -f \"$logfile\" ];then echo \"Warning: step3 work is not completed! as $logfile is not existent\"\nexit 0\nfi\n";
}


if(defined $posdir){
	my $intron="$posdir/intron.pos";
	if(-e $intron){
		if($method eq "Bayesian"){
			print STEP4RE "perl $bigTable --config $OutDir/bigTable.config --genome $genome --phred $phred --qual_cutoff $q --method $method --HomoPrior $HomoPrior --rate $rate --ploidy $ploidy --DNAdepth $DNAdepth --RNAdepth $RNAdepth --intron $intron --Bayesian_P $Bayesian_Posterior_Probability --paralogous_D $paralogous_D --homopolymer $homopolymer --intronic $intronic > $OutDir/RES_final_result.txt\n";
		}elsif($method eq "Binomial"){
			print STEP4RE "perl $bigTable --config $OutDir/bigTable.config --genome $genome --phred $phred --qual_cutoff $q --method $method --ploidy $ploidy --DNAdepth $DNAdepth --RNAdepth $RNAdepth --intron $intron --Binomial_FDR $FDR_DNA_Heterozygosis --paralogous_D $paralogous_D --homopolymer $homopolymer --intronic $intronic  > $OutDir/RES_final_result.txt\n";
		}elsif($method eq "Frequency"){
			print STEP4RE "perl $bigTable --config $OutDir/bigTable.config --genome $genome --phred $phred --qual_cutoff $q --method $method --ploidy $ploidy --DNAdepth $DNAdepth --RNAdepth $RNAdepth --intron $intron --Frequency_N $Non_Ref_BaseCount --paralogous_D $paralogous_D --homopolymer $homopolymer --intronic $intronic  > $OutDir/RES_final_result.txt\n";
		}
	}else{
		if($method eq "Bayesian"){
			print STEP4RE "perl $bigTable --config $OutDir/bigTable.config --genome $genome --phred $phred --qual_cutoff $q --method $method --HomoPrior $HomoPrior --rate $rate --ploidy $ploidy --DNAdepth $DNAdepth --RNAdepth $RNAdepth --Bayesian_P $Bayesian_Posterior_Probability --paralogous_D $paralogous_D --homopolymer $homopolymer > $OutDir/RES_final_result.txt\n";
		}elsif($method eq "Binomial"){
			print STEP4RE "perl $bigTable --config $OutDir/bigTable.config --genome $genome --phred $phred --qual_cutoff $q --method $method --ploidy $ploidy --DNAdepth $DNAdepth --RNAdepth $RNAdepth --Binomial_FDR $FDR_DNA_Heterozygosis --paralogous_D $paralogous_D --homopolymer $homopolymer  > $OutDir/RES_final_result.txt\n";
		}elsif($method eq "Frequency"){
			print STEP4RE "perl $bigTable --config $OutDir/bigTable.config --genome $genome --phred $phred --qual_cutoff $q --method $method --ploidy $ploidy --DNAdepth $DNAdepth --RNAdepth $RNAdepth  --Frequency_N $Non_Ref_BaseCount --paralogous_D $paralogous_D --homopolymer $homopolymer  > $OutDir/RES_final_result.txt\n";
		}	
	}
	print STEP4RE "perl $remove_conflict_editType $OutDir/RES_final_result.txt > $OutDir/RES_final_result.txt.temp\n";
	print STEP4RE "mv -f $OutDir/RES_final_result.txt.temp $OutDir/RES_final_result.txt\n";
	print STEP4RE "perl $type2pos $OutDir/RES_final_result.txt > $OutDir/RES_final_result.txt.pos\n";
	my $find_dir = "$OutDir/findoverlap_dir";
	print STEP4RE "mkdir -p $find_dir\n";
	foreach my $pos_file (@posfile){ 
		my $pos_filename=basename $pos_file;
		my ($ele)=$pos_filename=~/^(\S+)\.pos$/;
		print STEP4RE "perl $findOverlap $OutDir/RES_final_result.txt.pos $pos_file > $find_dir/RES_final_result.txt.pos-${ele}.overlap\n";
	}
	print STEP4RE "perl $addFeature2RNAediting $find_dir $OutDir/RES_final_result.txt  > $OutDir/RES_final_result.annotation\n";
	print STEP4RE "rm -rf $find_dir\n";

	if(-e "$posdir/CDS.pos"){
		print STEP4RE "perl $GetCodonInf $posdir/CDS.pos $genome > $OutDir/codon.database\n";
		print STEP4RE "perl $Amino_acid_change $OutDir/RES_final_result.annotation $OutDir/codon.database > $OutDir/RES_final_result.annotation.temp\n";
		print STEP4RE "mv -f $OutDir/RES_final_result.annotation.temp $OutDir/RES_final_result.annotation\n";
	}
	print STEP4RE "echo step4 work is completed! > $OutDir/step4.log\n";
	print STEP4RE "echo step4 work is completed!\n";
	print STEP4RE "echo File '$OutDir/RES_final_result.annotation' is the final result! >> $OutDir/step4.log\n";
	print STEP4RE "echo File '$OutDir/RES_final_result.annotation' is the final result!\n";
}else{
	if($method eq "Bayesian"){
		print STEP4RE "perl $bigTable --config $OutDir/bigTable.config --genome $genome --phred $phred --qual_cutoff $q --method $method --HomoPrior $HomoPrior --rate $rate --ploidy $ploidy --DNAdepth $DNAdepth --RNAdepth $RNAdepth --Bayesian_P $Bayesian_Posterior_Probability --paralogous_D $paralogous_D --homopolymer $homopolymer > $OutDir/RES_final_result.txt\n";
	}elsif($method eq "Binomial"){
		print STEP4RE "perl $bigTable --config $OutDir/bigTable.config --genome $genome --phred $phred --qual_cutoff $q --method $method --ploidy $ploidy --DNAdepth $DNAdepth --RNAdepth $RNAdepth --Binomial_FDR $FDR_DNA_Heterozygosis --paralogous_D $paralogous_D --homopolymer $homopolymer > $OutDir/RES_final_result.txt\n";
	}elsif($method eq "Frequency"){
		print STEP4RE "perl $bigTable --config $OutDir/bigTable.config --genome $genome --phred $phred --qual_cutoff $q --method $method --ploidy $ploidy --DNAdepth $DNAdepth --RNAdepth $RNAdepth --Frequency_N $Non_Ref_BaseCount --paralogous_D $paralogous_D --homopolymer $homopolymer > $OutDir/RES_final_result.txt\n";	
	}
	print STEP4RE "echo step4 work is completed! > $OutDir/step4.log\n";
	print STEP4RE "echo step4 work is completed!\n";
	print STEP4RE "echo File '$OutDir/RES_final_result.txt' is the final result! >> $OutDir/step4.log\n";
	print STEP4RE "echo File '$OutDir/RES_final_result.txt' is the final result!\n";
}
close STEP4RE;

open RESSCANNER,">$OutDir/RES-Scanner_identification.sh" or die $!;
print RESSCANNER "sh $OutDir/RES_step1.sh\n";
print RESSCANNER "sh $OutDir/RES_step2.sh\n";
print RESSCANNER "sh $OutDir/RES_step3.sh\n";
print RESSCANNER "sh $OutDir/RES_step4.sh\n";
close RESSCANNER;

if($run){
	print STDERR "BEGIN...\n";
	system "sh $OutDir/RES-Scanner_identification.sh";
	print STDERR "DONE!\n";
}else{
print STDERR "####################################################################################################\n";
print STDERR "Please execute the following command to finish RES-Scanner identification job: 
sh $OutDir/RES-Scanner_identification.sh 
";
print STDERR "####################################################################################################\n";
}

