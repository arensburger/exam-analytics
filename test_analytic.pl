#!/usr/bin/perl

# Feb 2016, runs analytics on exam questions, assumes there are 2 versions, A and B, the first answer to each line gives the version number 
# and correct answers

use strict;
use Text::CSV;
my $csv = Text::CSV->new({ sep_char => ',' });
my $file = $ARGV[0] or die "Need to get CSV file on the command line\n";
open(my $data, '<', $file) or die "Could not open '$file' $!\n";
my %qd; # hash of array, student number as key (unique id) and array with answers to questions as value
my $linenumber = 0;
my @equivalenceAB; # holds the equivalent questions in B compared to version A
my @keyA; # holds the key to version A
my @keyB; # holds the key to version B

#### load the data from the csv file ####
while (my $line = <$data>) {
 	chomp $line;
 	if ($csv->parse($line)) {
		my @fields = $csv->fields();
		my @answers; #holds the answers on the current line;
		if ($linenumber == 0) { #treat the first line differently because it has the equivalence data
			 @equivalenceAB = split(" ", $fields[0]);
		}
		elsif ($linenumber == 1) { #treat the line different it has the key data
			@keyA = split("", $fields[0]);
		}
		elsif ($linenumber == 2) { #treat the line different it has the key data
			@keyB = split("", sort_answers($fields[0]));
		}
		else { #go here if it's not one of the first three lines
			@answers = split("", $fields[0]);
			if ($answers[0] eq "a") {
			}
			elsif ($answers[0] eq "b") { 
#				my $sorted_answers = sort_answers($fields[0]);
				@answers = split("", sort_answers($fields[0]));
			}
			else {
				my $printline = $linenumber+1;
				warn "Question on line $printline does not start with an a or b, skipping\n";
			}
			
		}

		#update %qd
		for (my $j=0; $j<scalar @answers; $j++) {
			$qd{$linenumber}[$j] = $answers[$j];
		}
		$linenumber++;
  	} 
	else {
      		warn "Line could not be parsed: $line\n";
  	}
}

# Perform quality control test on equivalence and key data
my $lengthequivalence = scalar @equivalenceAB;
my $lengthkeyA = scalar @keyA;
my $lengthkeyB = scalar @keyB;
unless (($lengthequivalence == $lengthkeyA) and ($lengthequivalence == $lengthkeyB)) {
	die "Error, not all the key and equivalence lengths are the same\nequivalence length: $lengthequivalence\nkey A length: $lengthkeyA\nkey B length: $lengthkeyB\n";
}

#### determine the difficulty of each question
my @diff_correct; #holds the number times each question answered correctly
my @diff_wrong; #holds the number times each question answered incorrectly
my @diff_blank; #holds the number times each question is left blank
my %total_score; #holds the student number as key and total number of correct answers as value, used in discrimination index
foreach my $sn (keys %qd) { # sn = student number
	for (my $i=0; $i<scalar @keyA; $i++) {
		
		#decide if use key A or B
		if ($qd{$sn}[0] eq "a") {
			if($keyA[$i] eq $qd{$sn}[$i]) {
				$diff_correct[$i]++;
				$total_score{$sn}++;
			}
			elsif ($qd{$sn}[$i] =~ /\S+/) { #check if there is an answer
				$diff_wrong[$i]++;
			}
			else {
				$diff_blank[$i]++;
			}	
		}
		elsif ($qd{$sn}[0] eq "b") {
			if($keyB[$i] eq $qd{$sn}[$i]) {
				$diff_correct[$i]++;
				$total_score{$sn}++;
			}
			elsif ($qd{$sn}[$i] =~ /\S+/) { #check if there is an answer
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

# record answers
my @difficulty_score; # percent difficulty, order is the same as the questions
for (my $i=0; $i<scalar @keyA; $i++) {
	my $total = $diff_correct[$i] + $diff_wrong[$i] + $diff_blank[$i];
	push @difficulty_score, int(($diff_correct[$i]/$total)*100);
#	my $difficulty = int(($diff_correct[$i]/$total)*100);
#	my $question_number = $i+1;
#	print "$question_number\t$difficulty%\t$diff_correct[$i]\t$diff_wrong[$i]\t$diff_blank[$i]\n";
}


#### calculate discrimination
my $num_scores = keys %total_score; # number of people in the test
my @scores; # holds the scores
# copy scores to array
foreach my $key (keys %total_score) { # copy scores to array
	push @scores, $total_score{$key};
}
my @sorted_scores = sort { $a <=> $b } @scores; #sort the scores
my $top_cutoff = round($num_scores * 0.73, 0); # position in the array of the top
my $bottom_cutoff = round($num_scores * 0.27, 0); # position in the array of the bottom

# store data for top and bottom students
my %top_answers; # holds the answers of the top students
my %bottom_answers; # holds the answers of the bottom students;
foreach my $sn (keys %qd) { # sn = student number
	if ($total_score{$sn} >= $sorted_scores[$top_cutoff]) {
		push @{$top_answers{$sn}}, @{$qd{$sn}};
	}
	if ($total_score{$sn} <= $sorted_scores[$bottom_cutoff]) {
		push @{$bottom_answers{$sn}}, @{$qd{$sn}};
	}
	
}
# go through the exam and calculate discrimination for each question
my @top_correct; # for top students, number of correct answers, order of array same as questions
my @bottom_correct; # for bottom students, number of correct answers, order of array same as questions

# calculate correct numbers for top sudents
foreach my $sn (keys %top_answers) { # loop through top students
	for (my $i=0; $i<scalar @keyA; $i++) { # loop through questions	
		#decide if use key A or B
		if ($top_answers{$sn}[0] eq "a") {
			if($keyA[$i] eq $top_answers{$sn}[$i]) {
				$top_correct[$i]++;
			}
		}
		elsif ($top_answers{$sn}[0] eq "b") {
			if($keyB[$i] eq $top_answers{$sn}[$i]) {
				$top_correct[$i]++;
			}
		}
		else {
			die "cannot dertmine the key top students @{$top_answers{$sn}}";
		}
	}
}

# calculate correct numbers for bottom sudents
foreach my $sn (keys %bottom_answers) { # loop through top students
	for (my $i=0; $i<scalar @keyA; $i++) { # loop through questions	
		#decide if use key A or B
		if ($bottom_answers{$sn}[0] eq "a") {
			if($keyA[$i] eq $bottom_answers{$sn}[$i]) {
				$bottom_correct[$i]++;
			}
		}
		elsif ($bottom_answers{$sn}[0] eq "b") {
			if($keyB[$i] eq $bottom_answers{$sn}[$i]) {
				$bottom_correct[$i]++;
			}
		}
		else {
			die "cannot dertmine the key bottom students @{$top_answers{$sn}}";
		}
	}
}

# calculate discrimnation per question
my @discrimination_score;
my $denominator = ((keys %bottom_answers) + (keys %top_answers))/2;
for (my $i=0; $i <  scalar @keyA; $i++) {
	push @discrimination_score, (($top_correct[$i] - $bottom_correct[$i])/$denominator);
}

### Output the all the answers
print "Question number (vA)\tdifficulty\tdiscrimnation\n";
for (my $i=0; $i<scalar @keyA; $i++) {
	my $question_number = $i+1;
	print "$question_number\t$difficulty_score[$i]\t$discrimination_score[$i]\n";
}

sub sort_answers {
	my ($inputline) = @_;
	my @answers = split("", $inputline);
	my @sorted_answers; #holds the answers in correct order
	for (my $i=0; $i<scalar(@answers); $i++) {
		$sorted_answers[$equivalenceAB[$i]] = $answers[$i];
	}
	return(join("",@sorted_answers));
}

sub round {
    my ($nr,$decimals) = @_;
    return (-1)*(int(abs($nr)*(10**$decimals) +.5 ) / (10**$decimals)) if $nr<0;
    return int( $nr*(10**$decimals) +.5 ) / (10**$decimals);
}
