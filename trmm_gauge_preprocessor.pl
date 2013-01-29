#################################################################################
#                                                                               #
# TRMM radar preprocessor                                                       #
#                                                                               #
#                                                                               #
#                                                                               #
#################################################################################

use strict;
use List::MoreUtils qw/ uniq /;

open(LOG,">","trmm_preprocess.log");
#### User Config settings ####

# Input directory is the location where the raw asc files should be stored.
# 
my $inputDirectory="E:/KWAJ data/test/kwaj_gauge_data_2001";
my $outputDirectory="E:/KWAJ data/test/kwaj_gauge_stats";

# Provide a list of years to be processed to time series
my @years=qw/2001/;
# Provide a list of seasons within each year to be processed
# to time series.
# Note that DJF uses December from the previous year ie DJF 2001
# uses December 2000 and January, February 2001.

my @seasons=qw/MAM JJA SON/;

# The program will insert a value of NA for any times before the first 
# observation and after the last. 
my $naValue="NA";
# Specify the extension name of the gauge files. 
my $gaugeFileExtentsion="asc";
# indicates whether a gauge is stored in a single file for each month
# or a file for each year. A value of 1 indicates one file for each month
# 0 indicates one file for each year.
my $gaugeFilePerMonth=1;
my $gaugeDirectoryPerYear=1;


#### End of user configurable values ####

#### Regular Expressions ####

my $gaugeNameExpression=qr/([a-zA-Z]{3})_(\d{4})/; 
		# regular expression for function getGaugeList 
		# first set of parenthesis needs to be around the 3 letter location code
		# second set of parenthesis needs to be the 4 digit gauge code
		 



#### End of Regular Expressions ####

#### Parameters DO NOT CHANGE ####
# 
my @months=qw/01 02 03 04 05 06 07 08 09 10 11 12/;
my %monthlength=("1",31,"2",28,"3",31,"4",30,"5",31,
	"6",30,"7",31,"8",31,"9",30,"10",31,"11",30,"12",31);
my %seasons= ( "DJF"=>[12,1,2],"MAM"=>[3,4,5]
	,"JJA"=>[6,7,8],"SON"=>[9,10,11]);



### End of Parameters ###

sub checkConfigValid{
	# Checks the config options to make sure valid
	if (-d $inputDirectory){
		print "$inputDirectory Exists.\n";
	} else {
		print "$inputDirectory doesn't exist.\n";
	}
	if (-d $outputDirectory){
		print "$outputDirectory Exists.\n";
	} else {
		print "$outputDirectory doesn't exist.\n";
	}
	foreach my $season (@seasons){
		if ( grep( /^$season$/, keys %seasons ) ) {
			print "$season found\n";
		} else {
			print "$season not found\n";
		}
	}
}

sub getGaugeList{
	# Returns a list of gauges obtained by applying the regular 
	# expression $gaugeNameExpression to the list of all files 
	# with the $gaugeFileExtentsion extension. 
	my $directory=$_[0]; # get directory from arguments passed to function
	opendir(DIR,$directory); # opens specified directory for reading
	my @files=grep(/$gaugeFileExtentsion$/,readdir(DIR)); # gets list of files with 
										 # asc extention in directory
	closedir(DIR); # closes directory
	my @gauges=(); # initialize empty array for list for the list of gauges
	foreach my $line (@files){ # iterate over the list of asc files
		$line=~ m/$gaugeNameExpression/; # apply regular expression
#		$line=~ m/([a-zA-Z]{3})_(\d{4})/; # apply regular expression
		push(@gauges,$1.$2); # concatenates the gauge location and code
	}
	@gauges=uniq @gauges; # gets rid of any duplicates
	return @gauges; 
}

sub getGaugeFileList{
	# Get a list of all files for a particular gauge
	my ($directory,$gaugeCode,$gaugeId)=@_;
	opendir(DIR,$directory);
	my @files=grep(/$gaugeCode[_]$gaugeId/,readdir(DIR));
	return @files;
}

sub checkGaugeMonth{
	# checks to see if there is a file for a particular 
	# gauge and month
	# needs to be passed the gauge name, year and season
	if (scalar(@_) == 3){
		(my($gaugeName,$gaugeYear,$GaugeMonth))=@_;
		
	} else {
		return "Arguments are wrong"
	}
}

sub processMonth{
	# Takes two arguments the 1st is the gauge file that needs to be processed.
	# The 2nd argument is the month. 
	
	my ($file,$month) = @_; # extract the file and month from the comments
	my @output=(); # initialize the output array
	my $currentTime=0; # indicates initial time of zero
	my $firstObs=1; # flag to indicate the whether the first observation has been
					# processed
	if (!(-e $file)){ # check that the given file exists. 
		print LOG "$file passed to processMonth does not exist"; 
			# Output to the log if the file doesn't exist
		return 0; 
	}
	if (!($month=~/^\d+$/) || $month<1 || $month>12){ 
		# check to see if the value passed to $month is an integer between 1 and 12
		print LOG "$month supplied to processMonth is not a valid option";
		return 0;
	}
	open(GAUGEFILE,"<",$file); # open the specified function
	my $head =<GAUGEFILE>; # get the header from the file. Not currently used for anything.
	while (<GAUGEFILE>){
		# iterate over the remaining lines in the file
		my $line=$_; # saves the line read from the gaugefile to the variable $line.
		if (!($line=~m/(\d*)\s*(\d*)\s*(\d*)\s*(\d*)\s*(\d*)\s*(\d*)\s*\d*\s*(-*\d*\.\d*)/)){
			next # skip to the next line in the file if current line doesn't match
				 # the specified pattern.
		}; 
		my $gaugeYear=$1; # get the year from the regular expression
		my $gaugeMonth=$2; # get the month from the line read
		my $gaugeDay=$3; # gets the day from the line read
		my $daysFromYearStart=$4; # not currently used
		my $gaugeHour=$5; # gets the hour from the line read
		my $gaugeMinute=$6; # gets the minute form the read
		my $rainRate=$7; # gets the rain rate from the line read
		
		# calculate the number of minutes from the start of the month. 
		# minute 0= 00:00 on the 1st of the month, minute 1=00:01 on the 1st etc
		my $minutesFromStart=($gaugeDay-1)*1440+$gaugeHour*60+$gaugeMinute;
		
		# if the month on the specified line is not equal to the month specified
		# in the file then skip to the next line
		next if ($gaugeMonth!=$month);
		
		# pads the output with either the value specified in $naValue if the current
		# observation is the first in the month or 0 otherwise.
		while ($currentTime<$minutesFromStart){
			if ($firstObs==1){
				push(@output,$naValue);
			} else {
				push(@output,0);
			}
			$currentTime++;
		}
		push(@output,$rainRate); # adds the value of rain rate to the output
		$currentTime++;
		$firstObs=0; # sets the flag to say that the first observation has
					 # been processed. All subsequent gaps will take a value
					 # of zero.
	}
	# if no observations from the month passed to the function are found then
	# the length of output will be zero. If a value of zero is found a 
	if (scalar(@output)==0){
		print LOG "No data from month $month in $file";
		return 0;
	}
	# checks to see if the total length is less than the length of the month.
	# If it is then pads the end of the output with $naValue.
	while (scalar(@output)<1440*$monthlength{$month}){
		push(@output,$naValue);
	}
	# close the gauge file.
	close(GAUGEFILE);
	# return a scalar containing the minute by minute rain rate from the 
	# specified month in the specified file.
	return @output;
}

################## MAIN CODE HERE ########################
&checkConfigValid();
my @gaugeList=&getGaugeList("D:\\KWAJ data\\KWAJ Gauge Data\\2001");
print join("\n",@gaugeList),"\n";

# my @janData=&processMonth("D:\\KWAJ data\\KWAJ Gauge Data\\kwaj_gauge_data_2001\\2A56_KWAJ_KWA_0201_200101_3.asc",1);
print join("\n",@gaugeList),"\n";
foreach my $year (@years){
	foreach my $season (@seasons){
		print $season,"\n";
		my @seasonMonths=@{$seasons{$season}};
		foreach my $gauge (@gaugeList){
			$gauge=~/(\w{3})(\d{4})/;
			print "$gauge\n";
			my $gaugeCode=$1;
			my $gaugeId=$2;
			my @fileList=&getGaugeFileList("D:\\KWAJ data\\KWAJ Gauge Data\\2001\\",$gaugeCode,$gaugeId);
			my @output=qw//;
			my $missingMonth=0;
			foreach my $month (@seasonMonths){
				my $monthfile="";
				if ($month=~/\d{2}/){
					$monthfile=(grep(/$year$month/,@fileList))[0];
				} else {
					$monthfile=(grep(/$year(0)$month/,@fileList))[0];
				}
				if (!($monthfile =~/^$/)){
					my @monthData=&processMonth("D:\\KWAJ data\\KWAJ Gauge Data\\2001\\$monthfile",$month);
					print "Num of obs in $month is:- ",scalar(@monthData),"\n";
					push(@output,@monthData);
				} else {
					print "$gauge is missing $month.\n";
					$missingMonth=1;
				}
			}
			if ($missingMonth==0){
				print scalar(@output),"\n";
				open(GAUGEOUT,">","D:\\kwajtest\\${gauge}_${year}_${season}.dat");
				print GAUGEOUT join("\n",@output);
				close(GAUGEOUT);
			} else {
				print LOG "$gauge is missing a month in $season.\n";
			}
		}
	}
}
