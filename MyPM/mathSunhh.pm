package mathSunhh; 
#BEGIN {
#	push(@INC,'/usr/local/share/perl5/'); 
#}
# This is a package storing sub functions. 
# So there isn't objects created. 
use strict; 
use warnings; 
use Statistics::Descriptive; 
use Scalar::Util qw(looks_like_number blessed);
use Exporter qw(import);
our @EXPORT = qw(ins_calc);
our @EXPORT_OK = qw();

use LogInforSunhh; 


############################################################
#  Methods
############################################################

sub new {
	my $class = shift; 
	my $self = {}; 
	bless $self, $class; 
	
	$self->_initialize(@_); 
	
	return $self; 
}

sub _initialize {
	my $self = shift; 
	my %parm = $self->_setHashFromArr(@_); 
	return; 
}


=head2 repArr (\@units, 'each'=>1, 'times'=>1, 'length'=>\@units) 

Required : \@units

Function : A repeat function similar to rep() in R. 
           First apply 'each', then apply 'times', and at least apply 'length'; 

Return   : \@repeated_eles 

=cut
sub repArr {
	my $self = shift; 
	my $ref_arr = shift; 
	my %parm = $self->_setHashFromArr(@_); 
	$parm{'each'} = $parm{'each'} // 1; 
	$parm{'times'} = $parm{'times'} // 1; 
	$parm{'length'} = $parm{'length'} // ( ($#$ref_arr+1) * $parm{'each'} * $parm{'times'} ); 
	$parm{'length'} > 0 or return []; 
	my @each_arr; 
	for my $te (@$ref_arr) {
		push( @each_arr, ( $te ) x $parm{'each'} ); 
	}
	my @time_arr; 
	for ( my $i=0; $i<$parm{'times'}; $i++ ) {
		push(@time_arr, @each_arr); 
	}
	my @back_arr; 
	for ( my ($i, $time_idx) = (0,0) ; $i<$parm{'length'}; $i++ ) {
		$time_idx > $#time_arr and $time_idx -= ( $#time_arr + 1 ); 
		push(@back_arr, $time_arr[$time_idx]); 
		$time_idx ++; 
	}
	return \@back_arr; 
}# End repArr() 


=head2 newNumber ( 'other_safeNumber'=>[$mathSunhhObj->{'safeNumber'}, ...], 'onlyMerge'=>0, 'debug'=>0 )

Required : Null 

Function : Construct 'safeNumber' hash to store not used numbers in the same object. 
            It seems that this number is not only unique in the same object, but also unique in all objects in the same module calling this mathSunhh.pm module. 

Input    : Null 

Return   : A new number not used before. 

=cut
sub newNumber {
	my $self = shift; 
	my %parm = $self->_setHashFromArr(@_); 
	$parm{'debug'} = $parm{'debug'} // 0; 
	$parm{'onlyMerge'} = $parm{'onlyMerge'} // 0; 
	if ( defined $parm{'other_safeNumber'} ) {
		for my $h1 ( @{$parm{'other_safeNumber'}} ) {
			my ($min1, $max1) ; 
			for my $tN ( keys %{ $h1->{'has'} } ) {
				defined $min1 or $min1 = $tN; 
				defined $max1 or $max1 = $tN; 
				$min1 > $tN and $min1 = $tN; 
				$max1 < $tN and $max1 = $tN; 
				$parm{'debug'} and defined $self->{'safeNumber'} and defined $self->{'safeNumber'}{'has'}{$tN} and &tsmsg("[Wrn] existed number $tN in other_safeNumber\n"); 
				$self->{'safeNumber'}{'has'}{$tN} = 1; 
			}
			defined $self->{'safeNumber'}{'min'} or $self->{'safeNumber'}{'min'} = $min1; 
			defined $self->{'safeNumber'}{'max'} or $self->{'safeNumber'}{'max'} = $max1; 
			defined $self->{'safeNumber'}{'has'} or $self->{'safeNumber'}{'has'} = {}; 
			defined $min1 and $min1 < $self->{'safeNumber'}{'min'} and $self->{'safeNumber'}{'min'} = $min1; 
			defined $max1 and $max1 > $self->{'safeNumber'}{'max'} and $self->{'safeNumber'}{'max'} = $max1; 
		}
	}
	$parm{'onlyMerge'} and return ; 
	if ( defined $self->{'safeNumber'} ) {
		my $newN = ( defined $self->{'safeNumber'}{'max'} ) ? $self->{'safeNumber'}{'max'} + 1 : 1; 
		while ( defined $self->{'safeNumber'}{'has'}{$newN} ) {
			$newN ++; 
		}
		$self->{'safeNumber'}{'max'} = $newN; 
		$self->{'safeNumber'}{'has'}{$newN} = 1; 
		$self->{'safeNumber'}{'lastN'} = $newN; 
		return $newN; 
	} else {
		my $newN = 1; 
		$self->{'safeNumber'}{'min'} = $newN; 
		$self->{'safeNumber'}{'max'} = $newN; 
		$self->{'safeNumber'}{'has'}{$newN} = 1; 
		$self->{'safeNumber'}{'lastN'} = $newN; 
		return $newN; 
	}
}# newNumber() 

=head2 offspringArray( $rootID, $code_reference_of_function, 'unique'=>1 )

Required : 
  $rootID
  $code_reference_of_function : sub { return [@arr_value_as_next_self_loop] }

Function : Trace back all offsprings from root ID according to sub_routine_reference given. 
           Be aware that if the offspring has the same ID of rootID, this function will terminate!!! 
           This is used to avoid infinite cycles caused by relationship: rootID is a child of rootID. 

Input    : ( $rootID, sub { return @offspring; }, 'unique'=>1 )

Output   : [offspring1, offspring2, ...]

=cut
sub offspringArray {
	my $self = shift;
	my $rootID = shift;  # rootID from which to find offsprings. 
	my $coderef = shift; # reference of subroutine which return a array of offspring list. 
	my %parm = $self->_setHashFromArr(@_); 
	$parm{'unique'} = $parm{'unique'} // 1; 

	my @cIDs;            # All Children IDs. 
	my @off1 = ( &$coderef( $rootID ) ); # Offsprings directly from rootID. 
	scalar(@off1) == 0 and return [];
	my %haveID ; 
	$haveID{$rootID} = 1; 

	for my $cID ( @off1 ) {
		defined $haveID{$cID} and next; 
		push(@cIDs, $cID);
		my @ccIDs = grep { !(defined $haveID{$_}) } @{ $self->offspringArray( $cID, $coderef, %parm ) };
		push(@cIDs, @ccIDs);
	}

	if ( $parm{'unique'} ) {
		my %usedID; 
		my @bIDs; 
		for my $cID (@cIDs) {
			defined $usedID{$cID} or push(@bIDs, $cID); 
			$usedID{$cID} = 1; 
		}
		@cIDs = @bIDs; 
	}

	return [@cIDs];
}# _allChild()

=head2 setup_windows( 'ttl_start'=>1, 'ttl_end'=>99999999, 'wind_size'=>1000, 'wind_step'=> // 'wind_size', 
  'minRatio'=> 0
)

Required: 
 

Function: return a list of windows in hash reference according to given [window_size, window_step, total_start, total_end]

Return  : \%back_wind; 
 'keys'  => values
 'info' => {'ttl_start/ttl_end/wind_size/wind_step/minRatio/windSloci' => values} 
 'loci'  => {
              'wind_start_position' => [start_pos, end_pos, interval_len]
            }
 
=cut
sub setup_windows {
	my $self = shift; 
	my %parm = $self->_setHashFromArr(@_); 
	$parm{'ttl_start'} = $parm{'ttl_start'} // 1; 
	$parm{'ttl_end'}   = $parm{'ttl_end'}   // 99999999; 
	$parm{'wind_size'} = $parm{'wind_size'} // 1000; 
	$parm{'wind_step'} = $parm{'wind_step'} // $parm{'wind_size'}; 
	$parm{'minRatio'}  = $parm{'minRatio'}  // 0; 
	my %back_wind; 
	for (qw/ttl_start ttl_end wind_size wind_step minRatio/) {
		$back_wind{'info'}{$_} = $parm{$_}; 
	}
	my $min_windSize = int($parm{'minRatio'}*$parm{'wind_size'}); 
	$min_windSize < $parm{'minRatio'}*$parm{'wind_size'} and $min_windSize ++; 
	$min_windSize == 0 and $min_windSize = 1;  
	
	for (my $si=$parm{'ttl_start'}; $si+$min_windSize-1 <= $parm{'ttl_end'}; $si += $parm{'wind_step'}) {
		my $ei = $si + $parm{'wind_size'}-1; 
		$ei > $parm{'ttl_end'} and $ei = $parm{'ttl_end'}; 
		my $cur_len = $ei-$si+1; 
		$back_wind{'loci'}{$si} = [$si, $ei, $cur_len]; 
		push(@{$back_wind{'info'}{'windSloci'}}, $si); 
	}
	return \%back_wind; 
}# sub setup_windows

=head2 map_windows ( 'posi/position'=>Integer, 'wind_hash'=>setup_windows->(), 
  'ttl_start'=>1, 'ttl_end'=>99999999, 'wind_size'=>1000, 'wind_step'=>'wind_size', 'minRatio'=>0
)

Required: 
 'posi/position'

Function: 
 Given a position, return an array reference recording all start_positions of windows that this position locates in. 
 'wind_hash' will mask 'ttl_*' and 'wind_size/wind_step'. 

Return  : 
 \@back_si = [si_1, si_2, si_3, ...]
 Here "si" should be a key of %{$parm{'wind_hash'}{loci}}; 

=cut
sub map_windows {
	my $self = shift; 
	my %parm = $self->_setHashFromArr(@_); 
	my $posi = $parm{'posi'} // $parm{'position'} // &stopErr("[Err] No position assigned.\n"); 
	Scalar::Util::looks_like_number( $posi ) or &stopErr("[Err] input position [$posi] is not like a number.\n"); 
	$posi = int($posi); 
	if (defined $parm{'wind_hash'}) {
		for ( qw/ttl_start ttl_end wind_size wind_step minRatio/ ) {
			$parm{$_} = $parm{$_} // $parm{'wind_hash'}{'info'}{$_} // undef(); 
		}
	}
	$parm{'ttl_start'} = $parm{'ttl_start'} // 1; 
	$parm{'ttl_end'}   = $parm{'ttl_end'}   // 99999999; 
	$parm{'wind_size'} = $parm{'wind_size'} // 1000; 
	$parm{'wind_step'} = $parm{'wind_step'} // $parm{'wind_size'}; 
	$parm{'minRatio'}  = $parm{'minRatio'}  // 0; 
	
	my @back_si; 
	my $resid = ($posi-$parm{'ttl_start'}) % $parm{'wind_step'}; 
	my $end_si = $posi - $resid; 
	
	my $min_windSize = int($parm{'minRatio'}*$parm{'wind_size'}); 
	$min_windSize < $parm{'minRatio'}*$parm{'wind_size'} and $min_windSize ++; 
	$min_windSize == 0 and $min_windSize = 1;  
	
	for (my $si=$end_si; $si+$parm{'wind_size'}-1>=$posi && $si >= $parm{'ttl_start'}; $si-=$parm{'wind_step'}) {
		$si+$min_windSize-1 <= $parm{'ttl_end'} or next; 
		push(@back_si, $si); 
	}

	@back_si = reverse(@back_si); 
	
	return \@back_si; 
}# sub map_windows 


#=head2 ovl_len( $start1, $end1, $start2, $end2 )
#
#Required: 
# ( $start1, $end1, $start2, $end2 )
#
#Function : 
# return overlapped length of to regions [$start1,$end1] and [$start2,$end2]
#
#=cut
#sub ovl_len {
#	my $self = shift; 
#	my ($s1, $e1, $s2, $e2) = @_; 
#	($s1, $e1) = sort {$a <=> $b} ($s1, $e1); 
#	($s2, $e2) = sort {$a <=> $b} ($s2, $e2); 
#	if ($e1 < $s2 or $s1 > $e2) {
#		return 0; 
#	} else {
#		return &min($e1, $e2) - &max($s1, $s2) + 1; 
#	}
#}
=head2 ovl_region( $start1, $end1, $start2, $end2 )

Required: ($start1, $end1, $start2, $end2)

Function: Check overlapping region

Return  : ( $overlapped_bp_length, [ ovl_start, ovl_end ] )

=cut
sub ovl_region {
	my $self = shift; 
	my ($s1, $e1, $s2, $e2) = @_; 
	$s1 > $e1 and ($s1, $e1) = ($e1, $s1); 
	$s2 > $e2 and ($s2, $e2) = ($e2, $s2); 
	if ( $e1 < $s2 or $s1 > $e2 ) {
		return (0, []); 
	} else {
		my $ee = &min($e1, $e2); 
		my $ss = &max($s1, $s2); 
		return ( $ee - $ss + 1, [$ss, $ee] ); 
	}
}# ovl_region(); 

=head2 compare_number_list( $sePair_list1, $sePair_list2, 
 'compare'=>'same/ovl/nonovl', 
 'sort'=>'0/single/pair'
)

Required : 
 $sePair_list1 : [ [s11,e11], [s12,e12], ... ]
 $sePair_list2 : [ [s21,e21], [s22,e22], ... ]

Return   : 
 Case 'compare'='same'   : 1/0 : 1 for yes_same, 0 for different. 
 Case 'compare'='ovl'    : ( $ovlLen_nonDup, $ovlCnt_mayDup, \@ovlLoc ) 
                         : @ovlLoc=([overlap_S1, overlap_E1], [overlap_S2, overlap_E2], 
 Case 'compare'='nonovl' : ( [@spec1], [@spec2] ) 
                         : @spec1=( [nonOvl_lis1_S1, nonOvl_lis1_E1], [nonOvl_lis1_S1, nonOvl_lis1_E1], ... )
						 : @spec2=( [nonOvl_lis2_S1, nonOvl_lis2_E1], [nonOvl_lis2_S1, nonOvl_lis2_E1], ... )

Function : 
 Case 'sort'='0'         : Use the input order in list1/list2; 
 Case 'sort'='single'    : Sort numbers from small to large one by one; 
 Case 'sort'='pair'      : Sort numbers from small to large as pairs, but no sorting within any pair. 

=cut
sub compare_number_list {
	my $self = shift; 
	my $list1 = shift; 
	my $list2 = shift; 
	my %parm = $self->_setHashFromArr(@_); 
	$parm{'compare'} = $parm{'compare'} // 'same'; # same/ovl/nonovl
	$parm{'compare'} = lc( $parm{'compare'} ); 
	$parm{'sort'} = $parm{'sort'} // 0; # 0/single/pair
	$parm{'sort'} = lc( $parm{'sort'} ); 
	my (@srt_lis1, @srt_lis2); 
	for ( @$list1 ) {
		if ( ref($_) eq "" ) {
			push(@srt_lis1, $_); 
		} elsif ( ref($_) eq 'ARRAY' ) {
			my @ta = @$_; 
			@ta > 2 and @ta = @ta[0,1]; 
			push(@srt_lis1, @ta); 
		} else {
		}
	}
	for ( @$list2 ) {
		if ( ref($_) eq "" ) {
			push(@srt_lis2, $_); 
		} elsif ( ref($_) eq 'ARRAY' ) {
			my @ta = @$_; 
			@ta > 2 and @ta = @ta[0,1]; 
			push(@srt_lis2, @ta); 
		} else {
		}
	}
	
	if ($parm{'sort'} =~ m/^s(ingle)?$/) {
		@srt_lis1 = map { [$_] } sort { $a <=> $b } @srt_lis1; 
		@srt_lis2 = map { [$_] } sort { $a <=> $b } @srt_lis2; 
	} elsif ( $parm{'sort'} =~ m/^p(air(ed)?)?$/) {
		scalar( @srt_lis1 ) % 2 == 0 or &stopErr("[Err] Input list1 is not even.\n"); 
		scalar( @srt_lis2 ) % 2 == 0 or &stopErr("[Err] Input list2 is not even.\n"); 
		my (@tmp_1, @tmp_2); 
		for (my $i=0; $i<@srt_lis1; $i+=2) { push(@tmp_1, [ @srt_lis1[$i, $i+1] ]); } 
		for (my $i=0; $i<@srt_lis2; $i+=2) { push(@tmp_2, [ @srt_lis2[$i, $i+1] ]); }
		@srt_lis1 = sort { $a->[0] <=> $b->[0] || $a->[1] <=> $b->[1] } @tmp_1; 
		@srt_lis2 = sort { $a->[0] <=> $b->[0] || $a->[1] <=> $b->[1] } @tmp_2; 
	} elsif ($parm{'sort'} eq '0') {
		my (@tmp_1, @tmp_2); 
		for (my $i=0; $i<@srt_lis1; $i+=2) { push(@tmp_1, [ @srt_lis1[$i, $i+1] ]); } 
		for (my $i=0; $i<@srt_lis2; $i+=2) { push(@tmp_2, [ @srt_lis2[$i, $i+1] ]); }
		@srt_lis1 = @tmp_1; 
		@srt_lis2 = @tmp_2; 
	} else {
		&stopErr("[Err] Unknown 'sort' value [$parm{'sort'}]\n"); 
	}
	
	if ( $parm{'compare'} eq 'same' ) {
		$#srt_lis1 == $#srt_lis2 or return 0; 
		my $str_lis1 = join("\t", map { @$_ } @srt_lis1); 
		my $str_lis2 = join("\t", map { @$_ } @srt_lis2); 
		return ( ($str_lis1 eq $str_lis2) ? 1 : 0 ); 
	} elsif ( $parm{'compare'} eq 'ovl' or $parm{'compare'} eq 'nonovl' ) { 
		my ( $ovlLen, $ovlCnt ) = 0; 
		my @ovlLoc; 
		@srt_lis1 = map { [ sort { $a<=>$b } @$_ ] } @srt_lis1; 
		@srt_lis2 = map { [ sort { $a<=>$b } @$_ ] } @srt_lis2; 
		for my $a1 (@srt_lis1) {
			my ($s1, $e1) = @$a1; 
			for my $a2 (@srt_lis2) {
				my ($s2, $e2) = @$a2; 
				my ($ovl_len, $ovl_loc) = $self->ovl_region($s1, $e1, $s2, $e2); 
				$ovl_len > 0 and do { $ovlCnt ++; push( @ovlLoc, [@$ovl_loc] );  }; 
			}
		}
		# Merge @ovlLoc blocks
		@ovlLoc = @{ $self->mergeLocBlk(\@ovlLoc) }; 
		
		if ( $parm{'compare'} eq 'ovl' ) {
			for my $a1 (@ovlLoc) {
				$ovlLen += ( $a1->[1] - $a1->[0] + 1 ); 
			}
			return( $ovlLen, $ovlCnt, \@ovlLoc ); 
		} elsif ( $parm{'compare'} eq 'nonovl' ) {
			# Search for non-overlap regions. 
			my @spec1; 
			for my $a1 (@srt_lis1) {
				my ($s1, $e1) = @$a1; 
				for my $a3 (@ovlLoc) {
					my ($s3, $e3) = @$a3; 
					my ( $ovl_o1, $ovl_o2 ) = $self->ovl_region($s1, $e1, $s3, $e3); 
					if ( $ovl_o1 > 0 ) {
						$s1 <= $ovl_o2->[0]-1 and push(@spec1, [$s1, $ovl_o2->[0]-1]); 
						$e1 >= $ovl_o2->[1]+1 and push(@spec1, [$ovl_o2->[1]+1, $e1]); 
					} else {
						push(@spec1, [ $s1, $e1 ]); 
					}
					$ovl_o1 > 0 and next; 
				}
			}#End for my $a1 : @spec1
			my @spec2; 
			for my $a1 (@srt_lis2) {
				my ($s1, $e1) = @$a1; 
				for my $a3 (@ovlLoc) {
					my ($s3, $e3) = @$a3; 
					my ( $ovl_o1, $ovl_o2 ) = $self->ovl_region($s1, $e1, $s3, $e3); 
					if ( $ovl_o1 > 0 ) {
						$s1 <= $ovl_o2->[0]-1 and push(@spec2, [$s1, $ovl_o2->[0]-1]); 
						$e1 >= $ovl_o2->[1]+1 and push(@spec2, [$ovl_o2->[1]+1, $e1]); 
					} else {
						push(@spec2, [ $s1, $e1 ]); 
					}
					$ovl_o1 > 0 and next; 
				}
			}#End for my $a1 : @spec2
			return ( [@spec1], [@spec2] ); 
		} else {
			&stopErr("[Err] Why here! 'compare'=$parm{'compare'}\n"); 
		}
		return ($ovlLen, $ovlCnt, \@ovlLoc); 
	} else {
		&stopErr("[Err] Unknown 'compare'=[$parm{'compare'}]\n"); 
	}
}# compare_number_list()

=head2 mergeLocBlk( [ [s1,e1], [s2,e2], ... ], [[s21,e21], [s22, e22], ... ] )

Required   : At least one array reference like [ [$s1,$e1] ]; 

Function   : Merge [s1,e1],[s2,e2],[s21,e21],[e22,e22] ... together into non-overlapping blocks. 

 Can be used as &mergeLocBlk( [ [$s11,$e11], [$s12,$e12] ], [[$s21, $e21]], 'dist2join'=>1  )
 
 Here 'dist2join' is the number distance between two blocks that can be joined. Default is 0, means [4,6] and [7,10] will be two blocks. 
 If set 'dist2join'=>2, [4,6] and [8,10] will be joined into [4,10] ; 

Return     : [[ss1, ee1], [ss2, ee2], ...]

=cut 
sub mergeLocBlk {
	my $self = shift; 
	my @back_blk; 
	my @srt_blk; 
	my @para_array; 
	for my $blk_arr (@_) {
		ref($blk_arr) eq '' and do { push(@para_array, $blk_arr); next; }; 
		push(@srt_blk, @$blk_arr); 
	}
	my %parm = &_setHashFromArr(@para_array); 
	$parm{'dist2join'} //= 0; 
	@srt_blk = sort { $a->[0] <=> $b->[0] || $a->[1] <=> $b->[1] } map { [ sort { $a <=> $b } @$_ ] } @srt_blk; 
	for my $a1 (@srt_blk) {
		my ($s, $e) = @$a1; 
		if ( scalar(@back_blk) > 0 ) {
			if ( $back_blk[-1][1] >= $s - $parm{'dist2join'} ) {
				$e > $back_blk[-1][1] and $back_blk[-1][1] = $e; 
			} else {
				push(@back_blk, [$s, $e]); 
			}
		} else {
			@back_blk = ([$s, $e]); 
		}
	}
	return \@back_blk; 
}# mergeLocBlk() 

=head1 _setHashFromArr(@keyVal_array)

=head2 _setHashFromArr(@keyVal_array)

Required: @keyVal_array

Function: @keyVal_array contain ( key1, val1, key2, val2, ... ) pairs. 
          It will skip the latter duplicated keyN. 

Return  : %back_hash
  In %back_hash : 
   {keyN} => valN

=cut
sub _setHashFromArr {
	my $self = shift; 
	if ( ref($self) ne 'mathSunhh' ) {
		ref($self) eq '' or &stopErr("[Err] _setHashFromArr() input [$self] illegal.\n"); 
		unshift(@_, $self); 
	}
	my %back_hash; 
	for (my $i=0; $i<@_; $i+=2) {
		my $val; 
		if (exists $_[$i+1]) {
			$val = $_[$i+1]; 
		} else {
			exists $back_hash{$_[$i]} or &tsmsg("[Wrn] Input array is not even! Use undef() for key [", $_[$i],"]\n"); 
			$val = undef(); 
		}
		exists $back_hash{$_[$i]} or $back_hash{$_[$i]} = $val; 
	}
	return(%back_hash); 
}# _setHashFromArr() 

=head2 switch_position('qry2ref'=>\%refPos, 'qryID'=>$queryID, 'qryPos'=>$queryPos, 'qryStr'=>'+/-')

Input       : 
 %refPos   : {qryID} => sortedByQrySE [ [qryS_1, qryE_1, refID_1, refS_1, refE_1, refStr_1(+/-)], [qryS_2, qryE_2, refID_2, refS_2, refE_2, refStr_2], ... ]
 
               qryS <= qryE && refS <= refE 

			   qryS_1 <= qryS_2 ... 

Function    : 

 Get position on ref for qryID_qryPos

Return      : 

 ([refID_1, refPos_1, refStr_1], [refID_2, refPos_2, refStr_2])

=cut
sub switch_position {
	my $self = shift; 
	my %parm = $self->_setHashFromArr(@_); 
	for (qw/qry2ref qryID qryPos/) {
		defined $parm{$_} or &stopErr("[Err] '$_' not defined.\n"); 
	}
	$parm{'qryStr'} //= '+'; 
	my $qry_aref = $parm{'qry2ref'}{ $parm{'qryID'} } // []; 
	my @back; 
	for my $ta (@$qry_aref) {
		$ta->[1] < $parm{'qryPos'} and next; 
		$ta->[0] > $parm{'qryPos'} and last; 
		my $refID = $ta->[2]; 
		my ($refPos, $refStr); 
		$refStr = $parm{'qryStr'}; 
		if ( $ta->[5] eq '+' ) {
			$refPos = $ta->[3] + ($parm{'qryPos'}-$ta->[0]); 
		} elsif ( $ta->[5] eq '-' ) {
			$refPos = $ta->[4] - ($parm{'qryPos'}-$ta->[0]); 
			$refStr =~ tr!+-!-+!; 
		} else {
			&stopErr("[Err] Unknown refStr($ta->[5])\n"); 
		}
		push(@back, [$refID, $refPos, $refStr]); 
	}
	@back == 0 and @back = ([]); 
	return (@back); 
}# sub switch_position () 

############################################################
#  Sub-routines. 
############################################################

=head1 _parseCol( $col_string )

Required    : $col_string
 $col_string : Like 0-100 | 0,3,4,5-7,1-10 | 10-8

Function    : 
 '0-5' returns (0 .. 5)
 '0,3,5-7,6-9' returns (0,3,5,6,7,6,7,8,9)
 ' -3 - -4, 10-8'  returns (-3,-4,10,9,8)

Return      : (@col_numbers)

=cut
sub _parseCol {
	my @ncols; 
	for my $tc (split(/,/, shift)) {
		$tc =~ s!\s!!g; 
		$tc =~ m!^$! and next; 
		if ( $tc =~ m!^\-?\d+$! ) {
			push(@ncols, $tc); 
		} elsif ( $tc =~ m!^(\-?\d+)\-(\-?\d+)$! ) {
			my ($s, $e) = ($1, $2); 
			if ( $s <= $e ) {
				push(@ncols, ($s .. $e)); 
			} else {
				push(@ncols, reverse($e .. $s)); 
			}
		} else {
			&stopErr("[Err] Unparsable column tag [$tc] in _parseCol().\n"); 
		}
	}
	return (@ncols); 
}# _parseCol() 

=head1 _mean(@numbers)
=cut
sub _mean {
	my $stat = Statistics::Descriptive::Full->new(); 
	$stat->add_data(@_); 
	return $stat->mean(); 
}
=head1 _sum(@numbers)
=cut
sub _sum {
	my $stat = Statistics::Descriptive::Full->new(); 
	$stat->add_data(@_); 
	return $stat->sum(); 
}
=head1 _median(@numbers)
=cut
sub _median {
	my $stat = Statistics::Descriptive::Full->new(); 
	$stat->add_data(@_); 
	return $stat->median(); 
}


=head1 min(@numbers)

=head2 min(@numbers)

Function: This is not a method, but a sub-routine()

=cut
sub min {
	my $min = shift; 
	unless ( ref($min) eq '' ) {
		ref($min) eq 'mathSunhh' or &stopErr("[Err] min() input should be an array of number.\n"); 
		$min = shift; 
	}
	for (@_) {
		defined $_ or next; 
		defined $min or $min = $_; 
		$min > $_ and $min = $_; 
	}
	return $min; 
}# min() 

=head1 max(@numbers)

=head2 max(@numbers)

Function: This is not a method, but a sub-routine()

=cut
sub max {
	my $max = shift; 
	unless ( ref($max) eq '' ) {
		ref($max) eq 'mathSunhh' or &stopErr("[Err] max() input should be an array of number.\n"); 
		$max = shift; 
	}
	for (@_) {
		defined $_ or next; 
		defined $max or $max = $_; 
		$max < $_ and $max = $_; 
	}
	return $max; 
}# max() 

=head1 ins_calc( \@numbers, $min_valid_number_count )

Function: This is not a method, but a sub-routine(). 

Description: For calculating insert sizes. 
             Following Heng Li's bwa method (Estimating Insert Size Distribution). 
             But the max/min distance of INS are only using 6 * sigma values. 
             http://linux.die.net/man/1/bwa
             BWA estimates the insert size distribution per 256*1024 read pairs. It first collects pairs of reads with both ends mapped with a single-end quality 20 or higher and then calculates median (Q2), lower and higher quartile (Q1 and Q3). It estimates the mean and the variance of the insert size distribution from pairs whose insert sizes are within interval [Q1-2(Q3-Q1), Q3+2(Q3-Q1)]. The maximum distance x for a pair considered to be properly paired (SAM flag 0x2) is calculated by solving equation Phi((x-mu)/sigma)=x/L*p0, where mu is the mean, sigma is the standard error of the insert size distribution, L is the length of the genome, p0 is prior of anomalous pair and Phi() is the standard cumulative distribution function. For mapping Illumina short-insert reads to the human genome, x is about 6-7 sigma away from the mean. Quartiles, mean, variance and x will be printed to the standard error output.

Input      : (\@ins_value_array)

Output     : (\%hash_of_values) 
             keys = qw(SUM COUNT MEAN MEDIAN Q1 Q3 interval_low interval_high interval_mean interval_median interval_var interval_stdev limit_low limit_high min max)

=cut
sub ins_calc {
	my $r_arr = shift; 
	unless ( ref($r_arr) eq 'ARRAY' ) {
		ref($r_arr) eq 'mathSunhh' or &stopErr("[Err] ins_calc() input-1st should be an array reference.\n"); 
		$r_arr = shift; 
	}
	my $min_val_number = shift // 1; 
	my %back; 
	if ( (! defined $r_arr) or scalar(@$r_arr) < $min_val_number) {
		for my $ta (qw/SUM COUNT MEAN MEDIAN Q1 Q3 interval_low interval_high interval_mean interval_median interval_var interval_stdev limit_low limit_high/) {
			$back{$ta} = ''; 
		}
		return \%back; 
	}
	my $stat = Statistics::Descriptive::Full->new();
	$stat->add_data(@$r_arr); 
	$back{'SUM'} = $stat->sum(); 
	$back{'COUNT'} = $stat->count(); 
	$back{'MEAN'} = $stat->mean(); 
	$back{'MEDIAN'} = $stat->median(); 
	$back{'Q1'} = $stat->quantile(1); 
	$back{'Q3'} = $stat->quantile(3); 
	$back{'interval_low'}  = $back{'Q1'} - 2 * ($back{'Q3'}-$back{'Q1'}); 
	$back{'interval_high'} = $back{'Q3'} + 2 * ($back{'Q3'}-$back{'Q1'}); 
	$back{'min'} = $stat->min(); 
	$back{'max'} = $stat->max(); 
	
	$stat->clear(); 
	my @sub_arr; 
	for my $ta (@$r_arr) {
		$ta >= $back{'interval_low'} and $ta <= $back{'interval_high'} and push(@sub_arr, $ta); 
	}
	$stat->add_data(@sub_arr); 
	$back{'interval_mean'}  = $stat->mean(); 
	$back{'interval_median'} = $stat->median(); 
	$back{'interval_var'}   = $stat->variance(); 
	$back{'interval_stdev'} = $stat->standard_deviation(); 
	$back{'limit_low'}  = $back{'interval_mean'} - 6 * $back{'interval_stdev'}; 
	$back{'limit_high'} = $back{'interval_mean'} + 6 * $back{'interval_stdev'}; 
	$stat->clear(); 
	return \%back; 
}# ins_calc() 

=head1 permutations( \@list_of_element, $number_of_list ) 

This is not a method, but a sub-routine. 

Given (\@list_of_ele, $n_in_class), return all permutations by array. Return ([@perm1_of_ele], [@perm2], ...)

=cut
sub permutations {
	my $list = shift; 
	unless ( ref($list) eq 'ARRAY' ) {
		ref($list) eq 'mathSunhh' or &stopErr("[Err] permutations() input-1st should be an array reference.\n"); 
		$list = shift; 
	}
	my $n = shift; 
	$n = $n // scalar(@$list); 
	$n > @$list and return ($list); 
	$n <= 1 and return(map {[$_]} @$list); 
	my @perm; 
	for my $i (0 .. $#$list) {
		my @rest = @$list; 
		my $val = splice(@rest, $i, 1); 
		for ( &permutations(\@rest, $n-1) ) {
			push(@perm, [$val, @$_]); 
		}
	}
	return @perm; 
}#sub permutations() 

=head1 combinations(\@list_of_ele, $n_in_class)

This is not a method, but a sub-routine. 

Given (\@list_of_ele, $n_in_class), return all combinations by array. Return ([@comb1_of_ele], [@comb2_of_ele], ...) 

=cut
sub combinations {
	my $list = shift; 
	unless ( ref($list) eq 'ARRAY' ) {
		ref($list) eq 'mathSunhh' or &stopErr("[Err] combinations() input-1st should be an array reference.\n"); 
		$list = shift; 
	}
	my $n = shift; 
	$n = $n // scalar(@$list); 
	$n > @$list and return ($list); 
	$n <= 1 and return(map {[$_]} @$list); 
	my @comb; 
	for (my $i=0; $i+$n<=@$list; $i++) {
		my $val = $list->[$i]; 
		my @rest = @$list[$i+1 .. $#$list]; 
		for (&combinations(\@rest, $n-1)) {
			push(@comb, [$val, @$_]); 
		}
	}
	return @comb; 
}#sub combinations

=head1 dvd_array( \@array_to_be_divided, $number_of_subgroups, $If_keep_order[default=0], $prev_grp_colN )

Function : Divide @array_to_be_divided into $number_of_subgroups subgroups. 
If $If_keep_order is TRUE, the elements in subgroups will be sequenctial same to the raw order. 

Return   : ( [ \@subgroup_1, \@subgroup_2, ... ] )

Example  : 
  &dvd_array( [0,1,2,3,4,5,6,7] , 3 )    returns [ [0,3,6], [1,4,7], [2,5] ] ; 
  &dvd_array( [0,1,2,3,4,5,6,7] , 3, 1 ) returns [ [0,1,2], [3,4,5], [6,7] ] ; 

=cut
sub dvd_array {
	my $inA = shift; 
	my $grpN = shift; 
	my $keepOrder = shift; 
	my $prevGrp_ColN = shift; 
	$prevGrp_ColN //= 'N'; 
	$grpN = int($grpN);
	$grpN >= 1 or $grpN = 1; 
	my @sub_grps;
	if ( $keepOrder ) {
		my $num_ttl = scalar(@$inA); 
		my $num_subG = int( $num_ttl/$grpN ); 
		$num_subG * $grpN >= $num_ttl or $num_subG++; 
		$num_subG * $grpN >= $num_ttl or &stopErr("[Err] num_ttl=$num_ttl , grpN=$grpN\n"); 
		if ( $prevGrp_ColN eq 'N' ) {
			for (my $i=0; $i<@$inA; $i+=$num_subG) {
				my $e = $i+$num_subG-1; 
				$e > $#$inA and $e = $#$inA; 
				push( @sub_grps, [ @{$inA}[ $i .. $e ] ] ); 
			}
		} else {
			my $prev_tag; 
			my $curr_num = 0; 
			my $subGrp_idx = 0; 
			my $num_cutoff = $num_subG; 
			for (sort { $a->[$prevGrp_ColN]<=>$b->[$prevGrp_ColN] || $a->[$prevGrp_ColN] cmp $b->[$prevGrp_ColN] } @$inA) {
				$prev_tag //= $_->[$prevGrp_ColN]; 
				if ( $prev_tag ne $_->[$prevGrp_ColN] ) {
					$prev_tag = $_->[$prevGrp_ColN]; 
					if ( $curr_num < $num_cutoff ) {
						push( @{$sub_grps[$subGrp_idx]}, $_ ); 
					} else {
						$subGrp_idx ++; 
						$num_cutoff = $curr_num + $num_subG; 
						push( @{$sub_grps[$subGrp_idx]}, $_ ); 
					}
				} else {
					push( @{$sub_grps[$subGrp_idx]}, $_ ); 
				}
				$curr_num ++; 
			}
		}
	} else {
		$prevGrp_ColN ne 'N' and &stopErr("[Err] mathSunhh::dvd_array(): prev_grp_colN can be only ['N'] when If_keep_order is 0.\n"); 
		for (my $i=0; $i<@$inA; $i+=$grpN) {
			for (my $j=0; $j<$grpN; $j++) {
				my $k = $j+$i;
				$k < @$inA or last;
				push(@{$sub_grps[$j]}, $inA->[$k]);
			}
		}
	}
	return \@sub_grps;
}# dvd_array ()


=head1 complete_pair_for_grouping ( \%relation_pairs )

Input      : Format of %relation_pairs is 
             {$element_1}{$element_2} = 1; 
             {$element_3}{$element_4} = 1; 
             {$element_4}{$element_3} = 1; 
             {$element_5}{$element_6} = 1; 
             {$element_1}{$element_6} = 1; 
             {$element_6}{$element_1} = 1; 
             ...... 

Output     : ( \%complete_relation_pairs )
             {$element_1}{$element_2} = 1; 
             {$element_2}{$element_1} = 1; 
             {$element_3}{$element_4} = 1; 
             {$element_4}{$element_3} = 1; 
             {$element_5}{$element_6} = 1; 
             {$element_5}{$element_5} = 1; 
             {$element_1}{$element_6} = 1; 
             {$element_6}{$element_1} = 1; 
             ...... 

=cut
sub complete_pair_for_grouping {
	my ( $pair_href ) = @_; 
	my %back_hash = %$pair_href; 
	my %to_add; 
	for my $tk1 ( keys %back_hash ) {
		for my $tk2 ( keys %{$back_hash{$tk1}} ) {
			defined $back_hash{$tk2} and defined $back_hash{$tk2}{$tk1} and next; 
			$to_add{$tk2}{$tk1} = 1; 
		}
	}
	for my $tk1 ( keys %to_add ) {
		for my $tk2 ( keys %{$to_add{$tk1}} ) {
			$back_hash{$tk1}{$tk2} = 1; 
		}
	}
	return (\%back_hash); 
} # complete_pair_for_grouping() 

=head1 divide_group_fromHash ( \%relation_pairs ) 

Required   : Do be aware that in %relation_pairs, each pair should have two formed key pairs, {k1}{k2} and {k2}{k1}

Input      : Format of %relation_pairs is 
             {$element_1}{$element_2} = 1; 
             {$element_2}{$element_1} = 1; 
             {$element_3}{$element_4} = 1; 
             {$element_4}{$element_3} = 1; 
             {$element_5}{$element_6} = 1; 
             {$element_5}{$element_5} = 1; 
             {$element_1}{$element_6} = 1; 
             {$element_6}{$element_1} = 1; 
             ...... 

Function   : Divide elements in %relation_pairs into groups. 
             Each group contains related elements, and there is no related pairs between groups. 
             This should be much faster than &divide_group(); 

Output     : (\@back_groups_array)
 @back_groups_array format is ( [group_1_ele_1, group1_ele_2, ...], [group_2_ele_1, group_2_ele_2, ...], ... ); 

=cut
sub divide_group_fromHash {
	my ( $pair_href ) = @_; 
	my @array_input; 
	map { push( @array_input, [ $_, keys %{$pair_href->{$_}} ] ); } keys %$pair_href; 
	my ($back_aref) = &divide_group_fromArray(\@array_input); 
	
	return ($back_aref); 
}# divide_group_fromHash() 

=head1 divide_group_fromArray ( \@elements_in_groups ) 

Required   : 

Input      : Format of @elements_in_groups is 
             ([ ele1, ele2, ... ], 
             [ele3, ele4, ele5, ...], 
             [ele1, ele3], 
             [ele6, ele7, ele8], 
             [ele11, ele10, ele9], 
             ......)

Function   : Divide elements in @elements_in_groups into groups. 
             Each group contains related elements, and there is no related pairs between groups. 

Output     : (\@back_groups_array)
 @back_groups_array format is ( [group_1_ele_1, group1_ele_2, ...], [group_2_ele_1, group_2_ele_2, ...], ... ); 

=cut
sub divide_group_fromArray {
	my ( $pair_aref ) = @_; 
	my (%eleID_to_grpID, %grpID_wi_eleID, $grpID); 
	$grpID = 0; 
	for my $ar1 ( @$pair_aref ) {
		my @ta = @$ar1; 
		my ($minGID, $maxGID) = ('X', 'X'); 
		my %usedGID; 
		# Check if $ele2 in @ta already exists in %eleID_to_grpID, and determine the $minGID and maxGID of parent groups ; 
		for my $ele2 ( @ta ) {
			defined $eleID_to_grpID{$ele2} or next; 
			$usedGID{ $eleID_to_grpID{$ele2} } = 1; 
			$minGID = ( $minGID eq 'X' )
			  ? $eleID_to_grpID{$ele2} 
			  : ( $minGID > $eleID_to_grpID{$ele2} ) 
			    ? $eleID_to_grpID{$ele2} 
			    : $minGID 
			; 
			$maxGID = ( $maxGID eq 'X' ) 
			  ? $eleID_to_grpID{$ele2}
			  : ( $maxGID < $eleID_to_grpID{$ele2}  )
			    ? $eleID_to_grpID{$ele2}
			    : $maxGID
			; 
		}# End for my $ele2 ( @ta ) 
		
		if ( $minGID eq 'X' ) {
			# Setup a new group if there is no existing parent group; 
			map { $eleID_to_grpID{$_} = $grpID; $grpID_wi_eleID{$grpID}{$_}=1; } @ta; 
			$grpID ++; 
		} elsif ( $minGID < $maxGID ) {
			# Move groups with GID larger than $minGID to group with $minGID; 
			# And then remove those larger groups. 
			# Add all of the rest elements (eleID) to group of $minGID; 
			delete $usedGID{ $minGID } ; 
			for my $t_GID ( keys %usedGID ) {
				map { $eleID_to_grpID{$_}=$minGID; $grpID_wi_eleID{$minGID}{$_}=1; } keys %{ $grpID_wi_eleID{$t_GID} }; 
				delete $grpID_wi_eleID{$t_GID}; 
			}
			## Adding rest elements. 
			for my $eleID (@ta) {
				exists $eleID_to_grpID{$eleID} and next; 
				$eleID_to_grpID{$eleID}=$minGID; 
				$grpID_wi_eleID{$minGID}{$eleID}=1; 
			}
		} else {
			# Here minGID == maxGID, which means all of the elements are in the same existing group. 
			# So simply add the ones not included previously to that group. 
			for my $eleID (@ta) {
				exists $eleID_to_grpID{$eleID} and next; 
				$eleID_to_grpID{$eleID}=$minGID; 
				$grpID_wi_eleID{$minGID}{$eleID}=1; 
			}
		}#End if ( $minGID eq 'X' ) 
	}#End for my $ar1 ( @$pair_aref ) 
	
	my @back_array; 
	my (%grpID_to_eleID, %grpLen); 
	while (my ($t_EID, $t_GID) = each %eleID_to_grpID) {
		push(@{$grpID_to_eleID{$t_GID}}, $t_EID); 
		$grpLen{$t_GID} ++; 
	}
	for my $t_GID (sort { $grpLen{$b}<=>$grpLen{$a} || $a <=> $b } keys %grpID_to_eleID) {
		push(@back_array, [ @{$grpID_to_eleID{$t_GID}} ]); 
	}
	
	return (\@back_array); 
}# divide_group_fromArray() 


=head1 divide_group( \%relation_pairs )

Required   : Do be aware that in %relation_pairs, each pair should have two formed key pairs, {k1}{k2} and {k2}{k1}

Input      : Format of %relation_pairs is 
             {$element_1}{$element_2} = 1; 
             {$element_2}{$element_1} = 1; 
             {$element_3}{$element_4} = 1; 
             {$element_4}{$element_3} = 1; 
             {$element_5}{$element_6} = 1; 
             {$element_5}{$element_5} = 1; 
             {$element_1}{$element_6} = 1; 
             {$element_6}{$element_1} = 1; 
             ...... 

Function   : Divide elements in %relation_pairs into groups. 
             Each group contains related elements, and there is no related pairs between groups. 

Output     : (\@back_groups_array)
 @back_groups_array format is ( [group_1_ele_1, group1_ele_2, ...], [group_2_ele_1, group_2_ele_2, ...], ... ); 

=cut
sub divide_group {
	my ( $pair_href ) = @_; 
	my %new_excl ; 
	my @back_array; 
	for my $tk1 (keys %$pair_href) {
		defined $new_excl{$tk1} and next; 
		my ($b_href, $e_href) = &extract_group( $pair_href, \%new_excl, $tk1 ); 
		push(@back_array, [ sort keys %$b_href ]); 
		map { $new_excl{$_} = 1; } @{$back_array[-1]}; 
	}
	return( \@back_array ); 
}# divide_group() 

=head1 extract_group( \%relation_pairs, \%excluded_IDs, $in_seed_element ) 

Input      : Format of %relation_pairs is 
             {$element_1}{$element_2} = 1; 
             {$element_3}{$element_4} = 1; 
             {$element_5}{$element_6} = 1; 
             {$element_1}{$element_6} = 1; 
             ...... 

             Format of %excluded_IDs is [IDs that should not be considered.]
             {$element_x1} = 1; 
             {$element_x2} = 1; 
             ...... 

Function   : Extract a group which contains all and only contains the elements related to $in_seed_element by some chaining. 

Output     : (\%group_IDs, \%new_excluded_IDs)
 %group_IDs is in format {$in_seed_element} = 1, {$relate_ID_1} = 1, {$relate_ID_2} = 1, ...
 %new_excluded_IDs is in the same format of %exluded_IDs, and include all IDs in %excluded_IDs and IDs in %group_IDs; 

=cut
sub extract_group {
	my ( $pair_href, $excl_href, $in_key ) = @_; 
	my %back_hash; 
	my %new_excl = %$excl_href; 
	$back_hash{$in_key} = 1; 
	$new_excl{$in_key} = 1; 
	for my $tk ( keys %{$pair_href->{$in_key}} ) {
		defined $new_excl{$tk} and next; 
		$back_hash{$tk} = 1; 
		$new_excl{$tk} = 1; 
		my ($b_href, $e_href) = &extract_group( $pair_href, \%new_excl, $tk); 
		map { $new_excl{$_} = 1; } keys %$e_href; 
		map { $back_hash{$_} = 1; } keys %$b_href; 
	}
	return (\%back_hash, \%new_excl); 
}# extract_group() 

=head1 extract_group_fromHash( \%relation_pairs, \%excluded_IDs, $in_seed_element ) 

Input      : Format of %relation_pairs is 
             {$element_1}{$element_2} = 1; 
             {$element_3}{$element_4} = 1; 
             {$element_5}{$element_6} = 1; 
             {$element_1}{$element_6} = 1; 
             ...... 

             Format of %excluded_IDs is [IDs that should not be considered.]
             {$element_x1} = 1; 
             {$element_x2} = 1; 
             ...... 

Function   : Extract a group which contains all and only contains the elements related to $in_seed_element by some chaining. 

Output     : (\%group_IDs, \%new_excluded_IDs)
 %group_IDs is in format {$in_seed_element} = 1, {$relate_ID_1} = 1, {$relate_ID_2} = 1, ...
 %new_excluded_IDs is in the same format of %exluded_IDs, and include all IDs in %excluded_IDs and IDs in %group_IDs; 

=cut
sub extract_group_fromHash {
	my ( $pair_href, $excl_href, $in_key ) = @_; 
	$excl_href //= {}; 
	defined $in_key or die "Must give \$in_seed_element for mathSunhh::extract_group_fromHash()\n"; 
	my (%back_hash, %new_excl); 
	%new_excl = %$excl_href; 

	my @array_input; 
	for my $tk1 (keys %$pair_href) {
		defined $new_excl{$tk1} and next; 
		for my $tk2 ( keys %{$pair_href->{$tk1}} ) {
			defined $new_excl{$tk2} and next; 
			push(@array_input, [ $tk1, $tk2 ]); 
		}
	}
	my ($back_href, $new_excl_href) = &extract_group_fromArray( \@array_input, \%new_excl, $in_key ); 
	
	return($back_href, $new_excl_href); 
}# extract_group_fromHash() 

=head1 extract_group_fromArray( \@elements_in_groups, \%excluded_IDs, $in_seed_element ) 

Input      : Format of @elements_in_groups is 
             ([ ele1, ele2, ... ], 
             [ele3, ele4, ele5, ...], 
             [ele1, ele3], 
             [ele6, ele7, ele8], 
             [ele11, ele10, ele9], 
             ......
             )

             Format of %excluded_IDs is [IDs that should not be considered.]
             {$element_x1} = 1; 
             {$element_x2} = 1; 
             ...... 

Function   : Extract a group which contains all and only contains the elements related to $in_seed_element by some chaining. 

Output     : (\%group_IDs, \%new_excluded_IDs)
 %group_IDs is in format {$in_seed_element} = 1, {$relate_ID_1} = 1, {$relate_ID_2} = 1, ...
 %new_excluded_IDs is in the same format of %exluded_IDs, and include all IDs in %excluded_IDs and IDs in %group_IDs; 

=cut
sub extract_group_fromArray {
	my ( $pair_aref, $excl_href, $in_key ) = @_; 
	$excl_href //= {}; 
	defined $in_key or die "Must give \$in_seed_element for mathSunhh::extract_group_fromArray()\n"; 
	my (%back_hash, %new_excl); 
	%new_excl = %$excl_href; 

	my @array_input; 
	for my $ar1 (@$pair_aref) {
		my @ta; 
		for my $eleID (@$ar1) {
			defined $new_excl{$eleID} and next; 
			push(@ta, $eleID); 
		}
		scalar(@ta) > 0 and push(@array_input, [@ta]); 
	}
	my ($back_aref) = &divide_group_fromArray(\@array_input); 
	for my $ar1 (@$back_aref) {
		my $is_has = 0; 
		for my $eleID (@$ar1) {
			$eleID eq $in_key or next; 
			$is_has = 1; 
			last; 
		}
		if ( $is_has == 1 ) {
			for my $eleID (@$ar1) {
				$back_hash{$eleID} = 1; 
				$new_excl{$eleID} = 1; 
			}
			last; 
		}
	}
	
	return(\%back_hash, \%new_excl); 
}# extract_group_fromArray() 

=head1 sep_loc2_by_loc1_multiLoc2( \@loci_1, \@loci_2, [@colN_from_loci_1] )

Required   : 
 \@loci_1 should be sorted by each start position! 
 \@loci_1 and \@loci_2 in the same format: [ [sec_1_S, sec_1_E], [sec_2_S, sec_2_E], ...  ]

Function   : 
 Separate @loci_2 regions by overlapping @loci_1 or not. 
 And return regions contained in @loci_2; 
 \@loci_2 will be merged into non-overlapping segments. 

Return     : (\@not_overlappedSE, \@overlappedSE)
 Format of @not_overlappedSE

=cut
sub sep_loc2_by_loc1_multiLoc2 {
	my ( $aref_1, $aref_2, $aref_colN ) = @_; 
	my ( @specSE, @ovlpSE, $idx_start ); 
	my $loci_2 = &mergeLocBlk('', $aref_2, 'dist2join' => 1); 
	for my $ar2 (@$loci_2) {
		my ( $t_specSE, $t_ovlpSE, $t_idx_start ) = &sep_loc2_by_loc1_singleLoc2( $aref_1, $ar2, $aref_colN ); 
		$idx_start //= $t_idx_start; 
		$idx_start > $t_idx_start and $idx_start = $t_idx_start; 
		push(@specSE, @$t_specSE); 
		push(@ovlpSE, @$t_ovlpSE); 
	}
	
	return( \@specSE, \@ovlpSE, $idx_start ); 
}# sep_loc2_by_loc1_multiLoc2() 

=head1 sep_loc2_by_loc1_singleLoc2( \@loci_1, [$s2, $e2], [@colN_from_loci_1] ) 

Input      : 
 \@loci_1 should be sorted by each start position! 
 \@loci_1 in the format: [ [sec_1_S, sec_1_E], [sec_2_S, sec_2_E], ...  ]
 [@colN_from_loci_1] : Default [], means no columns to add. 
   If given, like [0,3], the 0-th and 3-rd columns from each $loci_1[$x] element will be added to \@overlappedSE; 

Required   : \@loci_1 , [$s2, $e2]

Function   : 
 Separate [$s2, $e2] region by overlapping @loci_1 or not. 
 And return regions contained in [$s2, $e2]

Return     : (\@not_overlappedSE, \@overlappedSE, $idx_start)
 Format of @not_overlappedSE : ( [ $s_1, $e_1 ], [ $s_2, $e_2 ], ... )
 Format of @overlappedSE : ( [ $s_1, $e_1, ... added ], [ $s_2, $e_2, ... added ], ... )
 $idx_start : The elements before this index_element is not larger than any of \@not_overlappedSE|\@overlappedSE . 

=cut
sub sep_loc2_by_loc1_singleLoc2 {
	my ($aref_1, $aref_2, $aref_colN) = @_; 
	my (@specSE, @ovlpSE); 
	$aref_colN //= []; 
	
	my $cur_p = $aref_2->[0]; 
	my $idx_cnt = -1; 
	my $idx_start; #  
	for my $ar1 (@$aref_1) {
		# ar1 -> ( loci_1_start, loci_1_end )
		$idx_cnt ++; 
		$ar1->[1] < $cur_p and next;       # The end of loci_1 (end_1)is smaller than current positoin; Go to next. 
		$ar1->[0] > $aref_2->[1] and last; # The beginning of loci_1 (start_1) is larger than loci_2, so we don't need to compare the followings. 
		if ( $ar1->[0] <= $cur_p) {
			# The start_1 is smaller than current position, but end_1 is no less than current position; 
			# The loci_1 is spanning current position. 
			$idx_start //= $idx_cnt; 
			if ( $ar1->[1] >= $cur_p ) {
				if ( $ar1->[1] <= $aref_2->[1] ) {
					push(@ovlpSE, [ $cur_p, $ar1->[1], @{$ar1}[@$aref_colN] ]); 
				} else {
					push(@ovlpSE, [ $cur_p, $aref_2->[1], @{$ar1}[@$aref_colN] ]); 
				}
			}
			$cur_p = $ar1->[1] + 1; 
		} elsif ( $ar1->[0] > $cur_p ) {
			# The loci_1 is overlapping loci_2, but larger than current position
			$idx_start //= $idx_cnt; 
			push( @specSE, [$cur_p, $ar1->[0]-1 ] ); 
			$cur_p = $ar1->[1] + 1; 
			if ( $ar1->[1] <= $aref_2->[1] ) {
				push( @ovlpSE, [ $ar1->[0], $ar1->[1], @{$ar1}[@$aref_colN] ] ); 
			} else {
				push( @ovlpSE, [ $ar1->[0], $aref_2->[1], @{$ar1}[@$aref_colN] ] ); 
			}
		} else {
			# This is impossible! 
			&stopErr("[Err] Wrongly reach this line in sep_loc2_by_loc1_singleLoc2()\n"); 
		}
	}# for my $ar1 (@$aref_1)
	
	if ( $cur_p <= $aref_2->[1] ) {
		# After checking loci_1 regions, there is also loci_2 region left. 
		push( @specSE, [ $cur_p, $aref_2->[1] ] ); 
		$idx_cnt < 0 and $idx_cnt = 0; # In this case, the loci_1 is empty. 
		$idx_start //= $idx_cnt; 
	}
	
	return (\@specSE, \@ovlpSE, $idx_start); 
}# sep_loc2_by_loc1_singleLoc2() 

=head1 map_loc_byReference( \@reference_1to2, \@LocSE_1, '+/-' )

Input      : 

 \@reference_1to2 : Format as [ $start1, $end1, $start2, $end2 ], in which loc_1 [$start1,$end1] is mapped to loc_2 [$start2, $end2]; 
 
 \@LocSE_1        : Format as [ $targetS_1, $targetE_1 ] 
 
 '+/-'            : The strand (direction) how loc_1 is aligned to loc_2. If '-', $start1 is mapped to $end2, and $end1 is mapped to $start2; 

Function   : According to \@reference_1to2, map loc_1 positions [ $targetS_1, $targetE_1 ] to loc_2 positions, and return them. 

Return     : ( $targetS_2, $targetE_2 )

=cut
sub map_loc_byReference {
	my ( $aref_1, $aref_2, $str ) = @_; 
	$str //= '+'; 
	my ( $targetS_2, $targetE_2 ); 
	
	# $aref_1 is in format [ $start1, $end1, $start2, $end2 ]
	# $aref_2 is in format [ $targetS_1, $targetE_1 ]
	my $ratio = ( $aref_1->[1]-$aref_1->[0] == 0 ) ? 0 : ($aref_1->[3]-$aref_1->[2])/($aref_1->[1]-$aref_1->[0]) ; 
	## Here $targetS_2 should be always no larger than $targetE_2, in case $aref_2->[1] >= $aref_2->[0]; 
	$targetS_2 = ( $str eq '-' ) 
	  ? $aref_1->[3] - int( ($aref_2->[1]-$aref_1->[0]) * $ratio)
	  : $aref_1->[2] + int( ($aref_2->[0]-$aref_1->[0]) * $ratio )
	; 
	$targetE_2 = ( $str eq '-' )
	  ? $aref_1->[3] - int( ($aref_2->[0]-$aref_1->[0]) * $ratio ) 
	  : $aref_1->[2] + int( ($aref_2->[1]-$aref_1->[0]) * $ratio )
	; 
	
	return ($targetS_2, $targetE_2); 
}# map_loc_byReference() 

=head1 insert_SEloc_toSEArray( \@toSEArray, \@SEloc, $idx_start )

Input      : 
 \@toSEArray   : Sorted. [ [$s1,$e1], [$s2, $e2], ... ]
 \@SEloc       : [ $s, $e ]
 $idx_start    : The elements in @toSEArray before index($idx_start) is not smaller than $s. Default 0. 

Required   : \@toSEArray, \@SEloc

Function   : Insert \@SEloc into \@toSEArray by low-to-high order. 

Return     : No return. The array \@toSEArray will be changed. 

=cut
sub insert_SEloc_toSEArray {
	my ($aref_1, $aref_2, $idx_curr) = @_; 
	$idx_curr //= 0; 
	my $is_found = 0; 
	for (; $idx_curr < @$aref_1; $idx_curr++) {
		my $ar1 = $aref_1->[$idx_curr]; 
		# $ar1 -> [ start, end ]
		$ar1->[0] < $aref_2->[0] and next; 
		$ar1->[0] == $aref_2->[0] and $ar1->[1] <= $aref_2->[1] and next; 
		$is_found = 1; 
		last; 
	}
	if ( $is_found == 0 or $idx_curr > $#$aref_1 ) {
		push(@$aref_1, $aref_2); 
	} else {
		splice(@$aref_1, $idx_curr, 0, $aref_2); 
	}
	return; 
}# insert_SEloc_toSEArray() 



1; 
