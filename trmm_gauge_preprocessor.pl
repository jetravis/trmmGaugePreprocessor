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
my @years=qw/2002/;
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


#### End of user configurable values ####

#### Regular Expressions ####

my $gaugeNameExpression=qr/([a-zA-Z]{3})_(\d{4})/; 
		# regular expression for function getGaugeList 
		# first set of parenthesis needs to be around the 3 letter location code
		# second set of parenthesis needs to be the 4 digit gauge code
		 



#### End of Regular Expressions ####

#### Parameters DO NOT CHANGE ####

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
	# 
	my ($file,$month) = @_; #extract the file and month from the comments
	my @output=();
	my $currentTime=0; # indicates initial time of zero
	my $firstObs=1; # flag to indicate the whether the first observation has been
					# processed
	if (!(-e $file)){
		print LOG "$file does not exist";
		return 0;
	}
	open(GAUGEFILE,"<",$file);
	my $head =<GAUGEFILE>;
	while (<GAUGEFILE>){
		my $line=$_;
#		print $line;
		$line=~m/(\d*)\s*(\d*)\s*(\d*)\s*(\d*)\s*(\d*)\s*(\d*)\s*\d*\s*(-*\d*\.\d*)/; # 
		my $gaugeYear=$1;
		my $gaugeMonth=$2;
		my $gaugeDay=$3;
		my $julianDay=$4;
		my $gaugeHour=$5;
		my $gaugeMinute=$6;
		my $rainRate=$7;
		my $minutesFromStart=($gaugeDay-1)*1440+$gaugeHour*60+$gaugeMinute;
		print $minutesFromStart,"\n";
		next if ($gaugeMonth!=$month);
		while ($currentTime<$minutesFromStart){
			print $currentTime,"\n";
			if ($firstObs==1){
				push(@output,$naValue);
			} else {
				push(@output,0);
			}
			$currentTime++;
		}
		push(@output,$rainRate);
		print "observation added\n";
		$firstObs=0;
	}
	if (scalar(@output)==0){
		print LOG "No data from month $month in $file";
		return 0;
	}
	while (scalar(@output)<1440*$monthlength{$month}){
		push(@output,$naValue);
	}
	close(GAUGEFILE);
	return @output;
}


&checkConfigValid();
my @gaugeList=&getGaugeList("D:\\KWAJ data\\KWAJ Gauge Data\\kwaj_gauge_data_2001");
print join("\n",@gaugeList),"\n";

my @janData=&processMonth("D:\\KWAJ data\\KWAJ Gauge Data\\kwaj_gauge_data_2001\\2A56_KWAJ_KWA_0201_200101_3.asc",1);

