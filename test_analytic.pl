#!/usr/bin/perl

# Feb 2016, runs analytics on exam questions, assumes there are 2 versions, A and B, the first answer to each line gives the version number

use strict;
use Text::CSV;
my $csv = Text::CSV->new({ sep_char => ',' });
my $file = $ARGV[0] or die "Need to get CSV file on the command line\n";
open(my $data, '<', $file) or die "Could not open '$file' $!\n";
my %qd; # hash of array, student number as key (unique id) and array with answers to questions as value
my $studentnumber = 0;

#### load the data from the csv file ####
while (my $line = <$data>) {
 	chomp $line;
 	if ($csv->parse($line)) {
	my @fields = $csv->fields();
	my @answers = split("", $fields[0]);
	for (my $j=0; $j<scalar @answers; $j++) {
		$qd{$studentnumber}[$j] = $answers[$j];
	}
	$studentnumber++;
  } else {
      warn "Line could not be parsed: $line\n";
  }
}

my @keyA = @{$qd{0}}; # answer key Version A;
my @keyB = @{$qd{1}}; # answer key Version B;
delete $qd{0}; # remove the keys 
delete $qd{1}; # remove the keys 

#### determine the difficulty of each question
my @diff_correct; #holds the number times each question answered correctly
my @diff_wrong; #holds the number times each question answered incorrectly
my @diff_blank; #holds the number times each question is left blank
foreach my $sn (keys %qd) { # sn = student number
	for (my $i=0; $i<scalar @keyA; $i++) {		
		#decide if use key A or B
		if ($qd{$sn}[0] eq "a") {
			if($keyA[$i] eq $qd{$sn}[$i]) {
				$diff_correct[$i]++;
			}
			elsif ($qd{$sn}[$i] =~ /\S+/) { #check if there is answer
				$diff_wrong[$i]++;
			}
			else {
				$diff_blank[$i]++;
			}	
		}
		elsif ($qd{$sn}[0] eq "b") {
			if($keyB[$i] eq $qd{$sn}[$i]) {
				$diff_correct[$i]++;
			}
			elsif ($qd{$sn}[$i] =~ /\S+/) { #check if there is answer
				$diff_wrong[$i]++;
			}
			else {
				$diff_blank[$i]++;
			}	
		}
		else {
			die "cannot dertmine the key for @{$qd{$sn}}";
		}
	}
}

#need to introduce the question equivalence between versions
# print difficulty 
print "Questions difficulty:\n\n";
for (my $i=0; $i<scalar @keyA; $i++) {
	my $total = $diff_correct[$i] + $diff_wrong[$i] + $diff_blank[$i];
	
	print "$i\t$diff_correct[$i]\t$diff_wrong[$i]\t$diff_blank[$i]\n";
}
