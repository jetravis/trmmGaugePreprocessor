#################################################################################
#                                                                               #
# TRMM gauge preprocessor                                                       #
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
my $inputDirectory="D:\\KWAJ data\\KWAJ Gauge Data";
my $outputDirectory="D:\\kwajtest";

# Provide a list of years to be processed to time series
my @years=qw/2001 2002/;
# Provide a list of seasons within each year to be processed
# to time series.
# Note that DJF uses December from the previous year ie DJF 2001
# uses December 2000 and January, February 2001.

my @seasons=qw/DJF MAM JJA SON/;

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
		print LOG "$inputDirectory Exists.\n";
	} else {
		print LOG "$inputDirectory doesn't exist.\n";
	}
	if (-d $outputDirectory){
		print LOG "$outputDirectory Exists.\n";
	} else {
		print LOG "$outputDirectory doesn't exist.\n";
	}
	foreach my $season (@seasons){
		if ( grep( /^$season$/, keys %seasons ) ) {
			print LOG "$season valid\n";
		} else {
			print LOG "$season not valid\n";
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
	# Takes three arguments the 1st is the gauge file that needs to be processed.
	# The 2nd argument is the month and the third is the year. If the file exists
	# and contains data from the specified month and year then the function will
	# output a time series for the specified month. Otherwise it will return a
	# scalar with value 0.
	
	my ($file,$month,$year) = @_; # extract the file and month from the comments
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
		
		# if the month and the year on the specified line are not equal to those specified
		# in the function arguments then skip to the next line.
		next if ($gaugeMonth!=$month || $gaugeYear!=$year);
		
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
		print LOG "No data from month $month in $file\n";
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

# Call a function to check that the configuration is valid.
&checkConfigValid();

# first iterate over each of the specified years.
foreach my $year (@years){
	# First get a list of the gauges contained in the directory. If the variable 
	# $gaugeDirectoryPerYear is equal to 1 then the program assumes that each year
	# is contained in a directory named after the year under the directory 
	# specified in the variable $inputDirectory. Otherwise it assumes all gauge
	# files are contained with $inputDirectory.
	my @gaugeList=qw//;
	if ($gaugeDirectoryPerYear==1){
		@gaugeList=&getGaugeList("$inputDirectory\\$year");
	} else {
		@gaugeList=&getGaugeList("$inputDirectory");
	}
	# skip to next year and prints to the log if no valid files are found.
	if (scalar(@gaugeList)==0){ # checks to see if any 
		print LOG "No gauges files found for year $year.\n";
		next;
	}
	if (!(-d "$outputDirectory\\$year")){
		mkdir "$outputDirectory\\$year"
	}
	foreach my $season (@seasons){
		# iterates over each of the specified seasons.
		my @seasonMonths=@{$seasons{$season}};
		# gets a list of the months in each season from the hash %seasons.
		foreach my $gauge (@gaugeList){
			# iterate over a list of all the gauges found in a particular year.
			# First seperate the gauge code into the 3 letter code and 4 digit id.
			$gauge=~/(\w{3})(\d{4})/;
			my $gaugeCode=$1;
			my $gaugeId=$2;
			# Initialize the output to be an empty list
			my @output=qw//;
			# Set the flag $missingMonth=0. If $missingMonth=1 it means that one
			# of the months in the season does not have a file in the directory.
			my $missingMonth=0;
			foreach my $month (@seasonMonths){
				# Iterates over each month in the current season. 
				
				# Initialize variables to hold the year that is being worked on
				# and the current directory. 
				my $currentYear;
				my $currentDirectory;
				# By convention the season DJF2001 would contain Dec 2000, Jan
				# 2001 and Feb 2001.
				if ($month==12){
					$currentYear=$year-1;
				} else {
					$currentYear=$year;
				}
				# checks to see if the files are stored in a directory for each
				# year.
				if ($gaugeDirectoryPerYear==1){
					$currentDirectory="$inputDirectory\\$currentYear";
				} else {
					$currentDirectory="$inputDirectory";
				}
				# get a list of the files for the specified year.
				my @fileList=&getGaugeFileList($currentDirectory,$gaugeCode,$gaugeId);
				# initialize a variable to hold the name of the file that contains
				# the data for the specified gauge and month.
				my $monthfile="";
				# First checks to see if there is one file per year or one per month.
				# In the first case it will search for files containing the name
				# just the year in the file name. Otherwise it searchs for the year
				# and the month separated by an underscore.
				if ($gaugeFilePerMonth==0){
					$monthfile=(grep(/$currentYear/,@fileList))[0];
				} elsif ($month=~/\d{2}/){
					$monthfile=(grep(/$currentYear$month/,@fileList))[0];
				} else {
					$monthfile=(grep(/$currentYear(0)$month/,@fileList))[0];
				}
				# Check to see if a file was found. If a file was found process the
				# file and append the resulting time series to the other time series
				# for that season. If no file was found set the $missingMonth flag to 1.
				if (!($monthfile =~/^$/)){
					my @monthData=&processMonth("$currentDirectory\\$monthfile",$month,$currentYear);
					# @monthData will return a scalar with a value of zero if there are any
					# issues with the file. To check for this we check to see if the list
					# @monthData contains a single element. 
					if (scalar(@monthData)==1){
						$missingMonth=1;
					}
					# Append the process time series for the particular month to the output.
					push(@output,@monthData);
				} else {
					# print a message to the log if a no file exists for a particular
					# gauge and month. 
					print LOG "$gauge is missing $month.\n";
					$missingMonth=1;
				}
			}
			# checks to see if there are no months missing for a particular
			# gauge and season. 
			if ($missingMonth==0){
				# If there aren't it writes the time series for a particular season to
				# the file specified in the $year directory under the directory 
				# specified in $outputDirectory. 
				open(GAUGEOUT,">","$outputDirectory\\$year\\${gauge}_${year}_${season}.dat");
				print GAUGEOUT join("\n",@output);
				close(GAUGEOUT);
			} else {
				# If there are any months missing print a message to the log
				# starting which gauge and season is missing a month.
				print LOG "$gauge is missing a month in $season.\n";
			}
		}
	}
}
