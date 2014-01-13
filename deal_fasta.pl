#!/usr/bin/env perl
## #!/usr/bin/perl 
### Author email : hs738@cornell.edu or biosunhh@gmail.com
###    Deal with fasta file, learn from fasta.pl done by fanwei.
###version 1.0  2006-7-12
###      copy the function -cut in fasta.pl written by fanwei.
###      add a function for picking out sequences according to annotations.
###      add a function sample picking transfered from fasta.pl.
###version 1.1  2006-7-13
###      add a function to pick out fragment from a single sequence.From fasta.pl
###      add a funcionn to change letters to capital or lower.Copy from fasta.pl
###version 1.1.1  2006-7-24
###      add a parameter -nres to regexps.
###      add the function get_attribute() from fasta.pl. It is very useful.
###      2006-7-25 change the way to read in fasta to fit multi files reading.And to fit STDIN for pipeline procedure.
###version 1.1.2  2006-7-27
###      begin to add a function to locate a site(a special sequence) to a database sequence.
###version 1.1.3  2006-12-27 16:12
###      change the method to calculate GC content, exclude runs of 25 Ns region.
### 2007-1-9 9:43 add a reverse complemented strand fragment pick.
### 2007-06-27 add a para "cut_dir" for cut funtion, to define which dir to write to.
### 2007-07-18 edit qual and frag func; add a new parsing method for para; 
### 2007-08-02 add a para for calc N50;
### 2007-08-03 add a function to chop key's unexpected words.
### 2007-8-31 9:19 Here i have updated the computing method for function get_attribute(), it is really a new test for me! Well, it can save very much more time when calculating large number of sequences; And i give out a fuction get_fasta_seq(), which should be added to other functions; Well, I love it! So i want to give a version to this perl script. 
### 2007-9-10 16:16 edit N50 subroutine. 
### 2007-9-11 11:29 ������һЩ������д��, ����cut_fasta, �÷��ϻ���ౣ��, ������cut_prefix����, �������Զ������ļ�����ʽ, ֧��STDIN����; 
### 2007-9-11 16:00 �˴θ��½���; 
### 2007-9-28 edit sub rcSeq; 
### 2007-11-29 add a output for qual_c
### 2008-1-4 13:01:38 edit get_fasta_seq subroutine to correct error when the former sequence is empty. 
### 2009-1-12 edit sub rootine "frag" to abtain para like "-10--5"
### 2011-1-18 add more annotation for rcseq subroutine. 
### 2013-08-01 Default of "-listNum" changed to "min". 
### 2013-10-30 Edit &siteList to return also match sequence. 
### 2013-10-30 Add functions : mask_seq_by_list ; extract_seq_by_list ; 
### 2013-11-01 Add function : extract_seq_by_list; And edit some small bug in mask_seq_by_list() with warnings. 
### 2013-11-01 Edit sub openFH() to deal with .gz/.bz2 files. 

use strict;
use warnings; 
use File::Spec; # File::Spec->catfile("","",...); 
use Getopt::Long;
my %opts;

sub usage {
	my $version = 'v1.0'; 
	$version = 'v1.1'; 
	$version = 'v1.2'; ### 2007-10-30 10:42:44 edit sub site_list(), add a output value "Match length". 
	$version = 'v1.3'; ### 2008-1-4 13:01:38 edit get_fasta_seq subroutine to correct error when the former sequence is empty. And add a little function to move out repeat sequences according to key of them. 2008-1-4 13:15:51 
	$version = 'v1.4'; ### 2009-1-12 edit sub rootine "frag" to abtain para like "-10--5"
	$version = 'v1.5'; ### Merge tableSeq.pl and extractSeq.pl functions. 
	my $last_time = '2013-11-01'; 
	print STDOUT <<HELP; 
#******* Instruction of this program *********#

Introduction:Deal with fasta format file, learn from fasta.pl done by fanwei.Should be used in Linux ENV.

Last modified: $last_time 
Version: $version

Usage: $0  <fasta_file | STDIN>
  -help               output help information;
  
  -cut<num>           cut fasta file with the specified number of sequences in each subfile.Cited from fasta.pl.
                      A little change to fit different input directory type;
  -cut_prefix         prefix for cutted files; Default 'pre'; 
  -cut_dir            cutted files in this dir if given.
  
  -res<regexps>       pick out sequences whose annotations(key+definition) match the regular expression.Output to STDOUT;
  -nres<regexps>      opposite to -res.
  -uniqSeq            boolean. remove repeat sequences according to their keys. 
  
  -sample<num-num>    output sequences according to sequence order.0 for 1st or last one;
  
  -frag<start-end>  output a fragment of the squence in single sequence fasta file;Start position is 1; May be s1-e1:s2-e2...
  -frag_width<num>  number of characters each line when output;
  -frag_head        whether print out the title of the sequences;
  -frag_c           give out complemented strand;
  -frag_r           give out reverse strand;
  
  -upper/lower        upperize/lowerize charaters of all the sequences;
  
  -table              If given,this program will only give out annotations of the output sequences, with '|'
                      transfered to "\\t"; not so useful; 
  -max_num<num>       max record numbers output for every file. No effection to -cut function;At least one.
  
  -attribute<item>    head:seq:key:len:GC:mask:AG, output atrribution of sequences. 
  -GC_excln<num>      when calculating CG content, it will calculate total length excluding runs of <num>
                      Ns or more. Default 25. We only exclude Ns, no dealing with Xs!
  
  -listSite<sequence>     a sequence for searcing.
  -listNum                [Min|Max]
  -listBoth               Both strands.
  
  -N50                calc N50;
  -chopKey            'expr'
  -startCodonDist     calc input CDSs\' start codon usage distribution;
  -comma3             output only a comma separated list (no spaces) of atg, gtg, ttg start proportions, in that order
  
  -maskByList         [Boolean] A trigger for masking .fasta sequences by list. 
  -maskList           [Filename] regions to be masked, in format: [seqID Start End]
  -maskType           [X/N/uc/lc] Telling how to modify regions listed. 
                        X/N   - Changed to X/N; 
                        uc/lc - Changed to upcase/lowercase; 
  -elseMask           [Boolean] Mask region not listed instead. 

  -drawByList         [Boolean] A trigger for extracting .fasta sequences by list. 
  -drawList           [Filename] regions to be extracted, in format: [RawSeqID Start End Strand(+/-) NewSeqID]
  -drawLcol           [String] Give the columns to use. Cols(RawSeqID,Start,End,Strand,NewSeqID). 
                        Default "0,1,2,3,4" 
  -drawIDmatch        [Boolean] Seqs whose IDs contain RawSeqID from drawList will be extracted. 
  -drawWhole          [Boolean] Ignore position (and strand) information if given. Retrieve the whole sequence. 
  -dropMatch          [Boolean] Drop seqs with matching ID. Only useful with -drawWhole . 


#******* Instruction of this program *********#
HELP
	exit (1); 
}

GetOptions(\%opts,"help!","cut:i","details!","cut_dir:s","cut_prefix:s", 
				"max_num:i",
				"res:s","nres:s","table!",
				"attribute:s","GC_excln:i",
				"sample:s",
				"frag:s","frag_width:i","frag_head!","frag_c!","frag_r!",
				"qual:s","qual_width:i","qual_r!","qual_head!",
				"listSite:s","listNum:s","listBoth!",
				"N50!",
				"chopKey:s","startCodonDist!","comma3!",
				"uniqSeq!", 
				"upper!","lower!", 
				"maskByList!", "maskList:s", "maskType:s", "elseMask!", 
				"drawByList!", "drawList:s", "drawLcol:s", "drawWhole!", "drawIDmatch!", "dropMatch!"
	);
&usage if ($opts{"help"}); 
!@ARGV and -t and &usage; 
(keys %opts) == 0 and &usage; 


#****************************************************************#
#--------------Main-----Function-----Start-----------------------#
#****************************************************************#

# Making File handles for reading; 
our @InFp = () ; # 2007-8-29 16:07 ȫ�ֱ���! 
if ( !@ARGV ) 
{
	@InFp = (\*STDIN); 
}
else
{
	for (@ARGV) {
		push( @InFp, &openFH($_,'<') ); 
	}
}


## Global settings 
my %goodStr = qw(
	+       F
	1       F
	f       F
	F       F
	plus    F
	forward F
	-       R
 -1       R
	r       R
	minus   R
	reverse R
	R       R
); 



&cut_fasta() if(exists $opts{cut} && $opts{cut} );
&res_match_seqs() if( (defined $opts{res} and $opts{res} ne '') || (defined $opts{nres} and $opts{nres} ne '') );
&get_sample() if(defined $opts{"sample"} and $opts{sample} ne '');
&frag() if(defined $opts{frag} and $opts{frag} ne '');
&upper_lower() if($opts{upper} || $opts{lower});
&get_attribute() if(defined $opts{attribute} and $opts{attribute} ne '');
&site_list() if(exists $opts{listSite});
&qual() if (defined $opts{qual} and $opts{qual} ne '');
&N50() if ($opts{N50});
&editkey() if ( exists $opts{chopKey} );
&startCodonDist() if ( defined $opts{startCodonDist} and $opts{startCodonDist} );
&uniqSeq() if ( $opts{uniqSeq} ) ; 
&mask_seq_by_list() if ( $opts{maskByList} ); 
&extract_seq_by_list() if ( $opts{drawByList} ); 

for (@InFp) {
	close ($_); 
}

#test
#test




#****************************************************************#
#--------------Subprogram------------Start-----------------------#
#****************************************************************#

# 2013-10-30 �����б�, ��ȡ�б�������
# Related parameters:  "drawByList!", "drawList:s", "drawLcol:s", "drawWhole!", "drawIDmatch!", "dropMatch!"
sub extract_seq_by_list {
	# Parameters. 
	defined $opts{drawLcol} or $opts{drawLcol} = "0,1,2,3,4"; 
	my ($cRID, $cS, $cE, $cStr, $cNID) = &parseCol( $opts{drawLcol} ); 
	$cRID = int($cRID); 
	# (defined $cRID and $cRID ne '') or die "[Err]At least to assign column number for key(ID).\n"; 
	($cS, $cE, $cStr, $cNID) = map { (defined $_ and $_ ne '') ? $_ : 'U'; } ($cS, $cE, $cStr, $cNID); 
	warn "[Msg]-drawLcol set as [$cRID,$cS,$cE,$cStr,$cNID]\n"; 
	
	
	
	# Read in list file. 
	my %dRegion; 
	my @Keys; 
	my $lisFh = &openFH($opts{drawList},'<'); 
	while (<$lisFh>) {
		chomp; 
		my @ta = split(/\t/, $_); 
		defined $ta[$cRID] or next; 
		$ta[$cRID] =~ /^\s*$/ and next; 
		
		defined $dRegion{ $ta[$cRID] } or push( @Keys, $ta[$cRID] ); 
		my @tadd; 
		for my $tid ( $cS,$cE,$cStr,$cNID ) {
			push( @tadd, ($tid eq 'U') ? undef() : $ta[$tid] ); 
		}
		push(@{ $dRegion{ $ta[$cRID] } }, [ @tadd ]); 
	}
	close($lisFh); 
	
	# Read in and draw from sequence file. 
	my %is_get; 
	my $seq_num = 0; 
	for my $fh (@InFp) {
		for ( my ($relHR, $get) = &get_fasta_seq($fh); defined $relHR; ($relHR, $get) = &get_fasta_seq($fh) ) {
			my $is_match = 0; # if this sequence ID matches. 
			$seq_num ++; 
			$seq_num % 5e3 == 1 and print STDERR "[Msg] $seq_num sequences.\n"; 
			
			if ($opts{drawIDmatch}) {
				FIND: foreach my $tt ( @Keys ) {
					if (index($relHR->{key}, $tt) != -1) {
						# This sequence matches the list. 
						$is_match = 1; 
						# output sequence if not -dropMatch . 
						$opts{dropMatch} or &outDrawnSeq( $relHR, \%dRegion, $tt, $opts{drawWhole} ); 
						
						last FIND; 
					}#End if the key matches. 
				}#End FIND:foreach 
			} elsif (defined $dRegion{ $relHR->{key} }) {
				# This sequence matches the list. 
				$is_match = 1; 
				$opts{dropMatch} or &outDrawnSeq( $relHR, \%dRegion, $relHR->{key}, $opts{drawWhole} ); 
			} else {
				# Nothing happens. 
				; 
			}#End if ( checking if this sequence matches the list)
			
			# Output sequence if this not matching and -dropMatch assigned. 
			( $opts{dropMatch} and $is_match == 0 ) and &outDrawnSeq( $relHR ); 
		}# End for sequence retrieval 
	}#End for file. 
}# End sub extract_seq_by_list

# Inner function for sub extract_seq_by_list() 
# &outDrawnSeq( $relHR, \%dRegion, $tt, $opts{drawWhole} ); 
sub outDrawnSeq ($$$$) {
	my ($faR, $drR, $drK, $opts_drawWhole) = @_; 

	unless ( defined $drR and scalar( keys %$drR ) > 0 ) {
		print STDOUT ">$faR->{head}\n$faR->{seq}\n"; 
		return (0); 
	}

	defined $opts_drawWhole or $opts_drawWhole = 0; 
	$opts_drawWhole = scalar( $opts_drawWhole ); 
	$opts_drawWhole == 0 or $opts_drawWhole == 1 or do { warn "[Err]opts_drawWhole:$opts_drawWhole not known. changed to 0.\n"; $opts_drawWhole = 0; }; 
	if ($opts_drawWhole == 0) {
		( my $rawSeq = $faR->{seq} ) =~ s/\s+//g ; 
		for my $tr1 ( @{ $drR->{$drK} } ) {
			my ($tS, $tE, $tStr, $tNID) = @$tr1; 

			defined $tStr or $tStr = 'F'; 
			defined $goodStr{lc($tStr)} or do { warn "[Err]Unknown strand information [$tStr]. Changed to [Forward]\n"; $tStr='F'; }; 
			$tStr = $goodStr{ lc($tStr) }; 
			
			(defined $tS and $tS ne '') or $tS = 1; 
			(defined $tE and $tE ne '') or $tE = length($rawSeq); 
			
			my $oNID = "$faR->{key}:$tS\-$tE:$tStr"; 
			defined $tNID and $tNID ne '' and $oNID = "$tNID [$oNID]"; 
			$oNID = "$oNID$faR->{definition}"; 
			
			my $oseq = substr( $rawSeq, $tS-1, $tE-$tS+1 ); 
			$tStr eq 'R' and &rcSeq(\$oseq, 'rc'); 
			
			print STDOUT ">$oNID\n$oseq\n"; 
			########## Edit here. 
		}
	} elsif ($opts_drawWhole == 1) {
		my ($tS, $tE, $tStr, $tNID) = @{$drR->{ $drK }[0]}; 
		my $oNID = "$faR->{key}"; 
		defined $tNID and $tNID ne '' and $oNID = "$tNID [$oNID]"; 
		$oNID = "$oNID$faR->{definition}"; 
		
		print STDOUT ">$oNID\n$faR->{seq}\n"; 
	} else {
		warn "[Err]unknown opts_drawWhole:$opts_drawWhole . NEXT\n"; 
	}
	return 0; 
}#End sub outDrawnSeq



# 2013-10-30 ���������б�, ���˶������ļ�����mask; 
# Region list format : [seqID Start END]
sub mask_seq_by_list {
	my %useType=qw(
		X   1
		N   2
		uc  3
		lc  4 
	); 
	defined $opts{maskType} or $opts{maskType} = 'X'; 
	unless ( defined $useType{ $opts{maskType} } ) {
		my @useTypeArr = sort keys %useType; 
		die "[Err] -maskType not known.\nShould be one of the following [" . join("|",@useTypeArr) . "]\n"; 
	}
	
	# Read in list file. 
	my $lFh = &openFH($opts{maskList},'<'); 
	my %mask_region; 
	while (<$lFh>) {
		chomp; 
		my @ta = split(/\t/, $_); 
		my ($id, $ss, $ee) = @ta[0,1,2]; 
		$ss <= $ee or ($ss,$ee) = ($ee, $ss); 
		push(@{$mask_region{$id}}, [$ss, $ee]); 
	}
	close($lFh); 
	
	# join and sort the blocks. 
	for my $tk ( keys %mask_region ) {
		my @blks; 
		for my $tr1 ( sort { $a->[0]<=>$b->[0] || $a->[1] <=> $b->[1] } @{$mask_region{$tk}} ) {
			my ($ss, $ee) = @{$tr1}; 
			if (scalar(@blks) == 0) {
				push(@blks, [$ss, $ee]); 
			} elsif ( $blks[-1][1]+1 >= $ss ) {
				$blks[-1][1] < $ee and $blks[-1][1] = $ee; 
			} else {
				push(@blks, [$ss, $ee]); 
			}
		}
		$mask_region{$tk} = \@blks; 
	}
	
	
	# Read in sequence file and do the masking. 
	for my $fh (@InFp) {
		for ( my ($relHR, $get) = &get_fasta_seq($fh); defined $relHR; ($relHR, $get) = &get_fasta_seq($fh) ) {
			# $relHR->{seq} =~ /^\s*$/ and next; 
			$relHR->{seq} =~ s/\s//g; 
			if ( defined $mask_region{ $relHR->{key} } ) {
				for (my $i=0; $i<@{ $mask_region{ $relHR->{key} } }; $i++) {
					my ($cs, $ce) = @{ $mask_region{ $relHR->{key} }[$i] }; 
					if ($opts{elseMask}) {
						# mask un-listed region. 
						if ($i==0) {
							$cs > 1 and substr( $relHR->{seq}, 0, $cs-1 ) = &mskSeq( substr( $relHR->{seq}, 0, $cs-1 ), $opts{maskType} ); 
						}else{
							my ($ps, $pe) = @{ $mask_region{ $relHR->{key} }[$i-1] }; 
							substr( $relHR->{seq}, $pe, $cs-1-$pe ) = &mskSeq( substr( $relHR->{seq}, $pe, $cs-1-$pe ), $opts{maskType} ); 
							if ($i==scalar( @{ $mask_region{ $relHR->{key} } } )-1) {
								my $seqL = length( $relHR->{seq} ); 
								$ce < $seqL and substr( $relHR->{seq}, $ce, $seqL-$ce ) = &mskSeq( substr( $relHR->{seq}, $ce, $seqL-$ce ), $opts{maskType} ); 
							}
						}
					}else{
						# mask listed region. 
						substr($relHR->{seq}, $cs-1, $ce-$cs+1) = &mskSeq( substr($relHR->{seq}, $cs-1, $ce-$cs+1), $opts{maskType} ); 
					}
				}
			}else{
				if ($opts{elseMask}) {
					$relHR->{seq} = &mskSeq( $relHR->{seq}, $opts{maskType} ); 
				}
			}# End if defined 
			print STDOUT ">$relHR->{head}\n$relHR->{seq}\n"; 
		}# End for (relHR)
	}# End for my $fh 
}# End sub 

# input  : sequence string , N/X/uc/lc
# output : Masked sequence string. 
sub mskSeq {
	my ($tseq, $ttype) = @_; 
	defined $ttype or $ttype = 'X'; 
	my $ret_seq; 
	my $keepSite = '[Nn]+'; 
	if ($ttype eq 'X' or $ttype eq 'N') {
		$ret_seq = $ttype x length($tseq); 
		map { substr($ret_seq, $_->[0]-1, $_->[1]-$_->[0]+1) = $_->[2]; } &siteList( \$keepSite, \$tseq, 'Min' ); 
	} elsif ( $ttype eq 'uc' ) {
		$ret_seq = uc($tseq); 
	} elsif ( $ttype eq 'lc' ) {
		$ret_seq = lc($tseq); 
	} else {
		die "[Err]Unknown mask type $ttype\n"; 
	}
	return($ret_seq); 
}#End mskSeq 


# 2008-1-4 13:05:22 ��fasta�ļ���ͬһ�����д�Ŷ��ʱ, ��ȥ��seqΪ�յ�����, ��������key��Ψһ��, ����ԭ˳��ÿ��key��Ӧ���н����һ��. 
sub uniqSeq {
	my %k; 
	
	for my $fh (@InFp) {
		for ( my ($relHR, $get) = &get_fasta_seq($fh); defined $relHR; ($relHR, $get) = &get_fasta_seq($fh) ) {
			$relHR->{seq} =~ /^\s*$/ and next; 
			unless (defined $k{ $relHR->{key} }) {
				$k{ $relHR->{key} } = 1; 
				print STDOUT ">$relHR->{head}\n$relHR->{seq}\n"; 
			}
		}
	}
}# end uniqSeq

sub startCodonDist { 
  my %codons; my $total = 0; my @Comma3 = qw/atg gtg ttg/;
  my $ret = $/; 
  
  for my $fh (@InFp) {
  	
  	READS: 
  	for ( my ($relHR, $get) = &get_fasta_seq($fh); defined $relHR; ($relHR, $get) = &get_fasta_seq($fh) ) {
  		my ($sc) = ($relHR->{seq} =~ /^((?:\S\s*){3})/); 
  		defined $sc or do { warn "[Err]There are wrong sequences."; next READS; }; 
  		$sc =~ s/\s+//g; $sc = lc($sc); 
  		$codons{$sc} ++; $total ++; 
  	}
  }
  
  if ($opts{comma3}) {
    my $tt3 = 0; my @Dist3 = ();
    for (@Comma3) {
      defined $codons{$_} or $codons{$_} = 0;
      $tt3 += $codons{$_};
    }
    $tt3 == 0 and do { print "0.000,0.000,0.000\n"; exit 0; };
    for (@Comma3) {
      #my $dis = (defined $codons{$_})? $codons{$_}/$total3 : 0 ;
      push(@Dist3, sprintf("%4.3f",$codons{$_}/$tt3));
    }
    print join(",",@Dist3).$ret;
  }else{
    my (@oC,@oP) = ();
    $total == 0 and do { print "No Start Condon Found.\n"; exit 0;};
    @oC = sort keys %codons;
    print STDOUT '#'x50,"\n";
    for (@oC) {
      push( @oP, sprintf("%4.3f",$codons{$_}/$total) );
      printf STDOUT (" %s  %7ld   %3.1f%%\n",$_,$codons{$_},100*$codons{$_}/$total);
    }
    printf STDOUT ("Total:%7ld\n",$total);
    print STDOUT '>'x50,"\n";
    printf STDOUT ("Codons=\t%s\n",join(",",@oC));
    printf STDOUT ("Prop  =\t%s\n",join(",",@oP));
  }
}# end sub startCodonDist 2007-9-11 9:22 edit 

sub editkey {
  my $expr = $opts{chopKey}; 
  $expr = qr/$expr/; 
  for my $fh (@InFp) {
  	for (my ($relHR, $get) = &get_fasta_seq($fh); defined $relHR; ($relHR, $get) = &get_fasta_seq($fh) ) {
  		substr( $relHR->{head}, 0, length($relHR->{key}) ) =~ s/$expr//; 
  		print STDOUT ">$relHR->{head}\n$relHR->{seq}\n"; 
  	}
  }
}# end editkey, ����ȥ��key�в���Ҫ�Ĳ���; 2007-9-10 16:31 

sub N50 {
  my @Length = (); my $totalLen = 0; 
  for my $fh (@InFp) {
  	
  	for ( my ($relHR, $get) = &get_fasta_seq($fh); defined $relHR; ($relHR, $get) = &get_fasta_seq($fh) ) {
  		$relHR->{seq} =~ s/\s+//g; push(@Length, length($relHR->{seq})); $totalLen += $Length[-1]; 
  	}
  }# read in all seq. 
 	my $tL = $totalLen/2; 
 	my $tc = 0; 
	for (sort { $a<=>$b; } @Length ) {
		$tc += $_;
		$tc >= $tL and do { print "Total [",$#Length+1,"] sequences.\nTotal [$totalLen] bps.\nN50 = [$_]\n"; last; };
	}
}# edit 2007-9-10 16:16 

# 
sub site_list {
	print STDOUT "Key\tLength\tMatchStart\tMatchEnd\tMatchLen\n"; 
	
	for my $fh (@InFp) {
		for ( my ($relHR, $get) = &get_fasta_seq($fh); defined $relHR; ($relHR, $get) = &get_fasta_seq($fh) ) {
			$relHR->{seq} =~ s/\s+//g; 
			my $len = length ($relHR->{seq}); 
			map { print STDOUT join("\t", $relHR->{key}, $len, $_->[0], $_->[1], $_->[1]-$_->[0]+1, $_->[2])."\n"; } &siteList(\$opts{listSite}, \$relHR->{seq}, $opts{listNum}); 
			if ($opts{listBoth}) {
				my $rcseq = $relHR->{seq}; &rcSeq(\$rcseq, 'rc'); 
				map { print STDOUT join("\t", $relHR->{key}, $len, $len-$_->[0]+1, $len-$_->[1]+1, $_->[1]-$_->[0]+1, &rcSeq(\$_->[2], 'rc'))."\n"; } &siteList(\$opts{listSite},\$rcseq,$opts{listNum});
			}# ���ӷ��򻥲����н��; 
		}# end for; 
	}
}# end site_list 2007-9-11 10:08 

#cut fasta file, can't accept STDIN
# fit STDIN; 2007-9-11 11:28 
############################################################
sub cut_fasta{
	my $total_seq_num = 0; 
	my $num2cut = $opts{cut}; $num2cut > 0 or do { print "\n-cut not available!\n\n"; &usage(); }; 
	my $out_pre = 'pre'; defined $opts{cut_prefix} and $out_pre = $opts{cut_prefix}; 
	my $out_dir = "${out_pre}_cutted"; 
	defined $opts{cut_dir} and $opts{cut_dir} ne '' and $out_dir = $opts{cut_dir}; 
	mkdir($out_dir,0755) or die "[Err]Failed to mkdir [$out_dir]: $!\n"; 
	my $file_name = 0; my $num_loop = 0; 
	open (OUT,'>',File::Spec->catfile($out_dir, $file_name)) or die "[Err]Failed to open file [$file_name] in dir [$out_dir]: $!\n"; 
	$opts{details} and print STDERR "generating [",File::Spec->catfile($out_dir, $file_name),"]\n"; 
	$file_name++; 
	for my $fh (@InFp) {
		for (my ($relHR, $get) = &get_fasta_seq($fh); defined $relHR; ($relHR, $get) = &get_fasta_seq($fh) ) {
			$total_seq_num ++; 
			if ( $num_loop > 0 and $num_loop % $num2cut == 0) {
				close OUT; 
				open (OUT,'>',File::Spec->catfile($out_dir, $file_name)) or die "[Err]Failed to open file [$file_name] in dir [$out_dir]: $!\n"; 
				$opts{details} and print STDERR "generating [",File::Spec->catfile($out_dir, $file_name),"]\n"; 
				$file_name++; 
			}
			print OUT ">$relHR->{head}\n$relHR->{seq}\n"; 
			$num_loop++; 
		}
	}# 
	close OUT; 
	# ��Ҫ��cut�ļ�������һ��; �������ϵͳ����"mv"; 
	chdir ($out_dir) or die "[Err]Failed to chdir to [$out_dir]:$!\n"; 
	( my $mark = $total_seq_num ) =~ tr/[0123456789]/0/; $mark++; 
	for (0..($file_name-1)) {
		system "mv $_ ${out_pre}_$mark.fasta" and die "[Err]Failed to change file name [$_]:$!\n"; 
		print STDERR "mv $_ ${out_pre}_$mark.fasta\n"; 
		$mark++; 
	}
}#end cut_fasta 2007-9-11 11:28 


# pick out sequences whose annotations match regular expression given.input file is $ARGV[0] and output is STDOUT;
############################################################
sub res_match_seqs{
	my $res = qr/$opts{res}/ if(exists $opts{res}); 
	my $nres = qr/$opts{nres}/ if(exists $opts{nres}); 
	my $max = 0; 
	(defined $opts{max_num} and $opts{max_num} > 0) and $max = $opts{max_num};			# define max records output,0 presents no max.
	if ($opts{details}) {
		print STDERR "regexps = /$res/\nmax_num = $max\n" if(exists $opts{res});
		print STDERR "n_regexps = /$nres/\nmax_num = $max\n" if(exists $opts{nres});
	}
	my $record_num=0;
	FILESH: 
	for my $fh (@InFp) {
		SEQUENCE: 
		for ( my ($relHR, $get) = &get_fasta_seq($fh); defined $relHR; ($relHR, $get) = &get_fasta_seq($fh) ) {
			exists $opts{res} and ( $relHR->{head} =~ m/$res/ or next SEQUENCE ); 
			exists $opts{nres} and ( $relHR->{head} =~ m/$nres/ and next SEQUENCE ); 
			if ($opts{table}) {
				(my $table_head = $relHR->{head}) =~ s/\|/\t/g; 
				print STDOUT "$table_head\n"; 
			}else{
				print STDOUT ">$relHR->{head}\n$relHR->{seq}\n"; 
			}
			$record_num++; 
			if ($max > 0 and $record_num >= $max) {
				$record_num = 0; 
				last SEQUENCE; # �ӵ�ǰ�ļ�����; ������һ���ļ��Ķ�ȡ; 
			}
		}
	}# end for FILESH; 
}#end res_match_seqs 2007-9-11 14:30 edit 


##get specified sequences from a file according to start-end order.(1 order for the first one).
####################################################
sub get_sample{
	my ($start,$end);
	if ($opts{sample}=~/(\d*)-(\d*)/) {
		$start = ( $1 ) ? $1 : 1;
		$end = ( $2 ) ? $2 : 'end';
		($1>$2 && $2!=0) and die "[Err]Are you sure?$1 > $2?!\n";
	}else{
		die "[Err]please insert in \"startNumber-endNumber\" format.\n";
	}

	my $max = 0;
	defined $opts{max_num} and $opts{max_num} > 0 and $max = $opts{max_num};			# define max records output,0 presents no max.

	my $record_num = 0;
	my $loop = 0;
	for my $fh (@InFp) {
		SEQUENCE: 
		for ( my ($relHR, $get) = &get_fasta_seq($fh); defined $relHR; ($relHR, $get) = &get_fasta_seq($fh) ) 
		{
			$loop ++; $loop < $start and next SEQUENCE; 
			print STDOUT ">$relHR->{head}\n$relHR->{seq}\n"; 
			$record_num ++; 
			if ($loop == $end && $end ne 'end') {
				$loop = 0; 
				last SEQUENCE; # ������ǰ�ļ�, ������һ���ļ���ȡ; 
			}elsif ($max > 0 and $record_num == $max) {
				$record_num = 0; 
				last SEQUENCE; 
			}
		}
	}# end for fh; 
}#end get_sample

## get a fragment from a single sequence
## 2007-1-9 9:21 add a function to get reverse and complemented sequences;
####################################################
sub frag{
	my (@Starts,@Ends);
	for (split(/:/,$opts{frag})) {
		s/^\s+//; s/\s+$//; 
		if (/^(\-?\d+)-(\-?\d+)$/) {
			push(@Starts,( $1 )? $1 : 1);
			push(@Ends,  ( $2 )? $2 : 'end');
			($1>$2 && $2 > 0) and die "[Err]Are you sure? $1 > $2?\n"
		}else{
			warn "[Err]This para not parsed: [$_]\n";
		}
	}
	!@Starts and die "[Err]No fragments input!\n";
	for my $fh (@InFp) {
		for ( my ($relHR, $get) = &get_fasta_seq($fh); defined $relHR; ($relHR, $get) = &get_fasta_seq($fh) ) {
			$relHR->{seq} =~ s/\s+//g; 
			my $l_seq = length($relHR->{seq}); 
			my ($str, $range); 
			for (my $i=0; $i<@Starts; $i++) {
				my ($add_s, $add_e) = ($Starts[$i], $Ends[$i]); 
				$add_s < 0 and $add_s = $l_seq + $add_s + 1; 
				if ($add_e eq 'end') { 
					$str .= substr($relHR->{seq}, $add_s-1); 
					$range = ( defined $range ) ? "${range},$add_s-$l_seq" : "$add_s-$l_seq"; 
				}else{
					$add_e < 0 and $add_e = $l_seq + $add_e + 1; 
					$str .= substr($relHR->{seq}, $add_s-1, $add_e-$add_s+1); 
					$range = ( defined $range ) ? "${range},$add_s-$add_e" : "$add_s-$add_e" ;
				}
			}
			if ( $opts{frag_c} ) { &rcSeq(\$str, 'c'); $range = "C$range"; } 
			if ( $opts{frag_r} ) { &rcSeq(\$str, 'r'); $range = "R$range"; } 
			my $dispR = &Disp_seq(\$str, $opts{frag_width}); 
			substr($relHR->{head}, length($relHR->{key}),0) = ":$range"; 
			$opts{frag_head}?(print STDOUT ">$relHR->{head}\n$$dispR"):(print STDOUT $$dispR);	# 2007-1-9 9:31 
			undef($dispR); 
		}# end for reading; 
	}# end for fh; 
}# 2007-9-11 15:31 edit.

##output upper/lower case bases; 
####################################################
sub upper_lower{
	for my $fh (@InFp) {
		for ( my ($relHR, $get) = &get_fasta_seq($fh); defined $relHR; ($relHR, $get) = &get_fasta_seq($fh) ) {
			$opts{upper} and $relHR->{seq} = uc($relHR->{seq}); 
			$opts{lower} and $relHR->{seq} = lc($relHR->{seq}); 
			print STDOUT ">$relHR->{head}\n$relHR->{seq}\n"; 
		}
	}
}# 2007-9-11 15:35 edit; 

##output the title line of each entry
#	-attribute<item>    head:seq:key:len:GC:mask:model, output atrribution of sequences
####################################################
sub get_attribute{
	my %ok_key = ( 'key'=>1, 'head'=>1, 'seq'=>1, 'len'=>1, 'GC'=>1, 'GCnum'=>1, 'AG'=>1, 'AGnum'=>1, 'mask'=>1, 'masknum'=>1);  # ��ʱȥ��model����, ������ܺܲ�����; , 'model'=>1 ); 
	
	# define out_code(s); 
	my $recVar = sub { my $v = shift; return '$relHR->{'.$v.'}'; }; # record Var. ͳһ��ʽ; 
	my %out_code; 
	%out_code = (
		'key' => $recVar->('key'), 
		'head' => $recVar->('head'), 
		'seq' => $recVar->('seq'), 
	); 
	
	# calc code, and define some out_code on the same time; 
	my %has; # if has calc the var; 
	my %calc_code; 
	
	$calc_code{line} = sub { $has{line} and return ''; $has{line} = 1; return join('', $out_code{seq},' =~ s/\s+//g; ',"\n"); }; 
	
	$calc_code{len} = sub {
		$has{len} and return ''; $has{len}=1; 
		$out_code{len} = '$len'; 
		my $code = $calc_code{line}->(); 
		$code .= join('','my ',$out_code{len},' = length( ',$out_code{seq},' ); ',"\n"); 
		return $code; 
	}; 
	
	$calc_code{excln} = sub {
		$has{excln} and return ''; $has{excln} = 1; 
		$out_code{excln_seq} = '$excln_seq'; 
		$out_code{excln_len} = '$excln_len'; 
		my $code = $calc_code{line}->(); 
		my $excln = 25; 
		defined $opts{GC_excln} and $excln = $opts{GC_excln}; 
		$code .= join('','(my ',$out_code{excln_seq},' = ',$out_code{seq},' ) =~ s/[Nn]{',$excln,',}//gi; ',"\n"); 
		$code .= join('','my ',$out_code{excln_len},' = length( ',$out_code{excln_seq}, ' ); ',"\n"); 
		return $code; 
	}; 
	
	$calc_code{GC} = sub {
		$has{GC} and return ''; $has{GC} = 1; 
		$out_code{GC} = '$gc_cont'; 
		$out_code{GCnum} = '$gc'; 
		my $code = $calc_code{excln}->(); 
		$code .= join('','my ',$out_code{GCnum},' = ',$out_code{excln_seq},' =~ tr/gcGC/gcGC/; ',"\n"); 
		$code .= join('','my ',$out_code{GC},' = (',$out_code{excln_len},'==0) ? "Null" : ',"$out_code{GCnum}/$out_code{excln_len}",' ; ',"\n"); 
		return $code; 
	}; 
	$calc_code{GCnum} = $calc_code{GC}; 
	
	$calc_code{AG} = sub {
		$has{AG} and return ''; $has{AG} = 1; 
		$out_code{AG} = '$ag_cont'; 
		$out_code{AGnum} = '$ag'; 
		my $code = $calc_code{excln}->(); 
		$code .= join('','my ',$out_code{AGnum},' = ',$out_code{excln_seq},' =~ tr/agAG/agAG/; ',"\n"); 
		$code .= join('','my ',$out_code{AG},' = (',$out_code{excln_len},'==0) ? "Null" : ',"$out_code{AGnum}/$out_code{excln_len}",' ; ',"\n"); 
		return $code; 
	}; 
	$calc_code{AGnum} = $calc_code{AG}; 
	
	$calc_code{mask} = sub {
		$has{mask} and return ''; $has{mask} = 1; 
		$out_code{mask} = '$mask_cont'; 
		$out_code{masknum} = '$mask'; 
		my $code = $calc_code{len}->(); 
		$code .= join('','my ',$out_code{masknum},' = ',$out_code{seq},' =~ tr/nNxX/nNxX/; ',"\n"); 
		$code .= join('','my ',$out_code{mask}," = (",$out_code{len},'==0) ? "Null" : ',"$out_code{masknum}/$out_code{len} ; ","\n"); 
		return $code; 
	}; 
	$calc_code{masknum} = $calc_code{mask}; 
	
	# filtering right request(s);
	my @request; 
	for my $req (split(/:/,$opts{attribute})) {
		if (defined $ok_key{$req}) {
			push(@request, $req); 
		}else{
			warn "[Err]This ele [$req] not identified, so it will be omitted.\n"; 
		}
	}
	
	# test whether @request has content. 
	!@request and do { print STDOUT "No correct ele input.\n"; &usage }; 
	
	
	# begin to make codes for executing; 
	 # title: for and while, uncompleted. 
	my $ori = $"; local $" = "','"; 
	my $exe_code = <<"TITLE"; 
print STDOUT join("\\t",\'@request\')."\\n"; # for head line 
TITLE

	local $" = $ori; # local $" = $ori; 
	$exe_code .= <<'TITLE'; 
for my $fh (@InFp) { # getting file handle, InFp is a glob var. 
	for ( my ($relHR, $get) = &get_fasta_seq($fh); defined $relHR; ($relHR, $get) = &get_fasta_seq($fh) ) { 
TITLE
	 # begin circle in sequence reading. 
	for my $req (@request) { # calculating ; 
		defined $calc_code{$req} and $exe_code .= $calc_code{$req}->(); 
	}
	local $" = ","; 
	$exe_code .= <<"OUTPUT"; # outputting 
print STDOUT join("\\t",@out_code{@request})."\\n";
OUTPUT
	local $" = $ori; 
	 # end circles; 
	$exe_code .= <<'ENDCODE';
	}# end for reading; 
}# end for fh; 
ENDCODE
	
	# test and execution; 
	#die "$exe_code\n"; 
	eval "$exe_code"; 
}# 2007-9-11 15:36 edit; 



####################################################
sub qual{
	my (@Starts,@Ends);
	for (split(/:/,$opts{qual})) {
		if (/^(\d+)-(\d+)$/) {
			push(@Starts, ( $1 ) ? $1 : 1 );
			push(@Ends,   ( $2 ) ? $2 : 'end');
			($1>$2 && $2!=0) and die "[Err]Are you sure? $1 > $2?!\n";
		}else{
			warn "[Err]This position not parsed:[$_]\n";
			warn "[Err]Should be in \"startNumber-endNumber\" format.\n";
		}
	}
	for my $fh (@InFp) {
		for ( my ($relHR, $get) = &get_fasta_seq($fh); defined $relHR; ($relHR, $get) = &get_fasta_seq($fh) ) {
			my @Qual = split(/\s+/, $relHR->{seq}); 
			my (@Str, $range); 
			for (my $i=0; $i<@Starts; $i++) {
				if ($Ends[$i] eq 'end') {
					push(@Str,@Qual[($Starts[$i]-1)..$#Qual]);
					my $tmp_end = $#Qual + 1; 
					$range = (defined $range) ? "$range,$Starts[$i]-$tmp_end" : "$Starts[$i]-$tmp_end" ;
				}else{
					push(@Str,@Qual[($Starts[$i]-1)..($Ends[$i]-1)]);
					$range = (defined $range) ? "$range,$Starts[$i]-$Ends[$i]" : "$Starts[$i]-$Ends[$i]" ;
				}
			}
			if ($opts{qual_c}) { $range = "C$range"; } # 20071129
			if ($opts{qual_r}) { @Str = reverse(@Str); $range = "R$range"; } 
			my $qual_width = 20; 
			defined $opts{qual_width} and $qual_width = $opts{qual_width}; 
			(my $disp=join(' ',@Str)) =~ s/((?>\S+\s?){$qual_width})/(my $tmp=$1) =~ s|\s+$||g; "$tmp\n"; /eg; 
			1 while (chomp($disp)); 
			$disp .= "\n"; 
			substr($relHR->{head}, length($relHR->{key}), 0) = ":$range"; 
			$opts{qual_head}?(print STDOUT ">$relHR->{head}\n$disp"):(print STDOUT $disp);	# 2007-9-11 15:54 
		}
	}# end for fh; 
}# 2007-1-9 14:05

############################## Subroutines ###########################

#--------------------------------------------------------------------#
#+++++++++++++++++++subroutines for functions++++++++++++++++++++++++#
#--------------------------------------------------------------------#

# input: һ��site����($)������, һ����׼����($)������,Max/Min[���,��������?Ĭ�����list]
# output: ����һ���б�, ����site�����ڻ�׼�����ϵĶ�λ, blast��λ��ʽ, index start from 1;ÿ��Ԫ�ظ�ʽΪ(start..end), ע��, 1.��������ʱ��Сд���; 2.�������ж������κδ���, ���Ӧ��������ǰȥ���հ��ַ�, �س����κβ�ϣ�����ֵĸ���; 3.m//gs������ʽ; 4. ��׼���е�ƥ��λ�ûᱻ����ʹ��; 5. ������Ҫ��site��ʹ��ģʽƥ��Ԫ�ַ���, �����ܿ��ܵ��´�����, ��Ϊ���list�൱�ڸ���refSeq�����п���ƥ��site�����п���; 
sub siteList ($$$) {
	my $siteR = shift or die "[Err]no Site input!\n";
	if ($$siteR eq "") {
		warn "[Err]Site sequence cannot be empty!\n";
		return;
	}
	my $qrSite = qr/$$siteR/s;
	my $refR = shift or die "[Err]no refSeq input!\n";
	my $modeChk = shift;
	my $Is_min = 1;
	if (defined $modeChk) {
		$modeChk = lc($modeChk);
		if ($modeChk eq 'max') {
			$Is_min = 0; 
		} elsif ($modeChk eq 'min') {
			$Is_min = 1; 
		} else {
			warn "[Err]Third para of \&siteList should be 'Max' or 'Min' . Not [$modeChk].\n";
		}
	}
	my @posList = ();
	pos($$refR) = 0;
	while ($$refR =~ m/\G(?:.*?)($qrSite)/gs) {
		push ( @posList, [ $-[1]+1 , $+[1], $1 ] );
		$Is_min?(pos($$refR) = $+[1]):(pos($$refR) = $-[1]+1);
	}
	return @posList;
}# end siteList subroutine. 2013-10-30

#sub openFH {
#	my $f = shift;
#	my $type = shift; (defined $type and $type =~ /^[<>|]+$/) or $type = '<';
#	local *FH;
#	open FH,$type,"$f" or die "Failed to open file [$f]:$!\n";
#	return *FH;
#}# end sub openFH

sub openFH ($$) {
	my $f = shift; 
	my $type = shift; 
	my %goodFileType = qw(
		<       read
		>       write
		read    read
		write   write
	); 
	defined $type or $type = 'read'; 
	defined $goodFileType{$type} or die "[Err]Unknown open method tag [$type].\n"; 
	$type = $goodFileType{$type}; 
	local *FH; 
	# my $tfh; 
	if ($type eq 'read') {
		if ($f =~ m/\.gz$/) {
			open (FH, '-|', "gzip -cd $f") or die "[Err]$! [$f]\n"; 
			# open ($tfh, '-|', "gzip -cd $f") or die "[Err]$! [$f]\n"; 
		} elsif ( $f =~ m/\.bz2$/ ) {
			open (FH, '-|', "bzip2 -cd $f") or die "[Err]$! [$f]\n"; 
		} else {
			open (FH, '<', "$f") or die "[Err]$! [$f]\n"; 
		}
	} elsif ($type eq 'write') {
		if ($f =~ m/\.gz$/) {
			open (FH, '|-', "gzip - > $f") or die "[Err]$! [$f]\n"; 
		} elsif ( $f =~ m/\.bz2$/ ) {
			open (FH, '|-', "bzip2 - > $f") or die "[Err]$! [$f]\n"; 
		} else {
			open (FH, '>', "$f") or die "[Err]$! [$f]\n"; 
		}
	} else {
		# Something is wrong. 
		die "[Err]Something is wrong here.\n"; 
	}
	return *FH; 
}#End sub openFH


# input a fasta file's handle and a signal show whether it should has a head line; 
# return (undef(),undef()) if input is not enough data. 
# return (\% , has_get_next) 
# 2007-12-14 13:02:52 about \%, {seq, key, head}
# 2013-11-01 13:02:52 about \%, {seq, key, head, definition}
sub get_fasta_seq {
	my $fh = shift;
	my $has_head = shift; 
	my $has_get = 0; # ����Ƿ�ռ������һ�����е�">"��; 
	my %backH; 
	( defined $has_head and $has_head =~ /^0+$/ ) or $has_head = 1; 
	ref($fh) eq 'GLOB' or ref($fh) eq '' or die "Wrong input!\n"; 
	my %back; 
	if ( $has_head == 1 ) 
	{
		defined ( $backH{head} = readline($fh) ) or return (undef(),undef()); 
		$backH{head} =~ s/^>//g; chomp $backH{head}; 
		$backH{key} = (split(/\s+/,$backH{head}))[0]; 
		( $backH{definition} = $backH{head} ) =~ s/^(\S+)//; 
	}
	my $r = $/; local $/ = "$r>"; 
	defined ( $backH{seq} = readline($fh) ) or do { warn "[Err]The last sequence [$backH{head}] is empty, and it is not calculated!\n"; return (undef(),undef()); } ; 
	chomp $backH{seq} > length($r) and $has_get = 1; 
	local $/ = $r; chomp $backH{seq}; 
	# check if this sequence is a NULL one. 2008-1-4 13:01:22 
	# print "head=+$backH{head}+\nseq=+$backH{seq}+\n"; 
	while ($backH{seq} =~ s/^>//gs) { 
		warn "[Err]Sequence [$backH{head}] is empty, and it is not calculated!\n"; 
		if ($backH{seq} =~ s/^([^$r]+)(?:$r|$)//s) {
			$backH{head} = $1; $backH{key} = (split(/\s+/, $backH{head}))[0]; 
			( $backH{definition} = $backH{head} ) =~ s/^(\S+)//; 
		}
	}
	# check if this sequence is a NULL one. 2008-1-4 13:01:25 
	return (\%backH, $has_get); 
}# end sub get_fasta_seq

# input ($seq_ref, $deal_tag); deal_tag : 'r' => reverse, 'c' => complemented, 'rc' => reverse and complemented; Default 'rc'; 
# no output, edit the input sequence reference. 
sub rcSeq {
	my $seq_r = shift; 
	my $tag = shift; defined $tag or $tag = 'rc'; # $tag = lc($tag); 
	my ($Is_r, $Is_c) = (0)x2; 
	$tag =~ /r/i and $Is_r = 1; 
	$tag =~ /c/i and $Is_c = 1; 
	#$tag eq 'rc' and ( ($Is_r,$Is_c) = (1)x2 ); 
	#$tag eq 'r' and $Is_r = 1; 
	#$tag eq 'c' and $Is_c = 1; 
	!$Is_r and !$Is_c and die "Wrong Input for function rcSeq! $!\n"; 
	$Is_r and $$seq_r = reverse ($$seq_r); 
	# $Is_c and $$seq_r =~ tr/acgturyksbdhvnACGTURYKSBDHVN/tgcaayrmwvhdbnTGCAAYRMWVHDBN/;  # 2007-07-18 refer to NCBI;
	# $Is_c and $$seq_r =~ tr/acgturykmbvdhACGTURYKMBVDH/tgcaayrmkvbhdTGCAAYRMKVBHD/; # edit on 2010-11-14; 
	$Is_c and $$seq_r =~ tr/acgturykmbvdhACGTURYKMBVDHwWsSnN/tgcaayrmkvbhdTGCAAYRMKVBHDwWsSnN/; # edit on 2013-09-11 No difference in result. 
	return 0; 
}# 2007-9-11 9:46 ������Ӧ���򻥲�����; 
#        a       a; adenine
#        c       c; cytosine
#        g       g; guanine
#        t       t; thymine in DNA; uracil in RNA
#        m       a or c
#        k       g or t
#        r       a or g
#        y       c or t
#        w       a or t
#        s       c or g
#        v       a or c or g; not t
#        b       c or g or t; not a
#        h       a or c or t; not g
#        d       a or g or t; not c
#        n       a or c or g or t


#usage: disp_seq(\$string,$num_line);output a seq. sting
# edit on 20070718, return a ref for SCALAR string;
#############################################
sub Disp_seq{
	my $seq_ref=shift;
	my $num_line=( defined $_[0] and int($_[0]) > 0 ) ? int($_[0]) : 80;

	pos($$seq_ref) = 0;
	(my $disp = $$seq_ref) =~ s/(\S{$num_line})/$1\n/g;
	1 while (chomp $disp);
	$disp .= "\n";
	return \$disp;
}

#check whether a sequence accord with gene model
#############################################
sub check_CDS{
	my $seq=shift;
	my ($start,$end,$mid,$triple);
	$mid=1;
	my $len=length($seq);
	$triple=1 if($len%3 == 0);
	$start=1 if($seq=~/^ATG/);
	$end=1 if($seq=~/(TAA)|(TAG)|(TGA)$/);
	for (my $i=3; $i<$len-3; $i+=3) {
		my $codon=substr($seq,$i,3);
		$mid=0 if($codon eq 'TGA' || $codon eq 'TAG' || $codon eq 'TAA');
	}
	if ($start && $mid && $end && $triple ) {
		return 1;
	}else{
		return 0;
	}
}# never use again. 

sub parseCol {
	my @cols = split(/,/, $_[0]);
	my @ncols;
	for my $tc (@cols) {
		$tc =~ s/^\s+//;
		$tc =~ s/\s+$//; 
		if ($tc =~ m/^\d+$/) {
			push(@ncols, $tc);
		} elsif ($tc =~ m/^(\d+)\-(\d+)$/) {
			my ($s, $e) = ($1, $2);
			if ($s <= $e) {
				push(@ncols, ($s .. $e));
			}else{
				push(@ncols, reverse($e .. $s));
			}
		} elsif ( $tc =~ m/^$/ ) { 
			warn "[Err]Null column number set here.\n"; 
			push(@ncols, ''); 
		} else {
			die "[Err]Unparsable column tag for [$tc]\n";
		}
	}
	return (@ncols);
}
