use strict;
use warnings;
use threads;
use threads::shared;
use IO::Socket::INET;

$| = 1;
#my $crrIP = '10.0.254.254';
# create a connecting socket
my $tempCon = new IO::Socket::INET (
    PeerHost => '10.0.200.73',
    PeerPort => '7777',
    Proto => 'tcp',
);
die "cannot connect to the server $!\n" unless $tempCon;
my $signal;
$tempCon->recv($signal, 1024);
print "connected to the server\n";
print "$signal\n";
shutdown($tempCon, 1);
#receiving basic data
my $sender = new IO::Socket::INET (
    PeerHost => '10.0.200.73',
    PeerPort => '7778',
    Proto => 'tcp',
);
#receiving basic data==============
my $dataScalar0;
$sender->recv($dataScalar0, 1024);
print "Received data: $dataScalar0\n";
#processing basic data=============
$dataScalar0 =~ /(\d+)\D+(\d+)\D+(\d+)/;
my $sizeY :shared = $1;
my $sizeX :shared = $2;
my $playerNum :shared = $3;
print "SizeY: $sizeY \nSizeX: $sizeX \nPlayerNum: $playerNum \n";
#sending data where to start=======
my $input;
my $validInput = 0;
my $posX;
while ($validInput == 0)#make sure the input is valid, or bad things can happen
{
	print "Starting colum: ";
	$input = <STDIN>;
	if ($input =~ /\D*(\d+)\D*/)#get the first number of the input
	{
		$input =~ /\D*(\d+)\D*/;
		if ($1 < $sizeX)
		{
			$posX = $1;
			$validInput = 1;
		}
		else{ print "That is outside of the arena!\n"; };
	}
	else{ print "Invalid input!\n"; }
}

$validInput = 0;
my $posY;
while ($validInput == 0)#make sure the input is valid, or bad things can happen
{
	print "Staring row: ";
	$input = <STDIN>;
	if ($input =~ /\D*(\d+)\D*/)#get the first number of the input
	{
		$input =~ /\D*(\d+)\D*/;
		if ($1 < $sizeY)
		{
			$posY = $1;
			$validInput = 1;
		}
		else{ print "That is outside of the arena!\n"; };
	}
	else{ print "Invalid input!\n"; }
}
$sender->send("$posX $posY");
my @playerPosY :shared;
my @playerPosX :shared;
my $dataScalar1;
#receiving data about other players
$sender->recv($dataScalar1, 1024);
print "Received data: $dataScalar1\n";
my @stuff = split /\D+/ , $dataScalar1;
for my $i (0 .. $playerNum - 1)
{
	$playerPosY[$i]  = $stuff[$i];
}
print "Positions Y: @playerPosY\n";
my $dataScalar2;
$sender->recv($dataScalar2, 1024);
print "Received data: $dataScalar2\n";
@stuff = split /\D+/ , $dataScalar2;
for my $i (0 .. $playerNum - 1)
{
	$playerPosX[$i]  = $stuff[$i];
}
print "Positions X: @playerPosX\n";
my @cell;
for my $y (0 .. $sizeY - 1)
{
	for my $x (0 .. $sizeX - 1)
	{
		$cell[$y][$x] = 0;
	}
}
#receiving data from server
my $receiverThread = threads->create(
	sub
	{
		print "Connecting receiver...\n";
		my $receiver = new IO::Socket::INET (
		PeerHost => '10.0.200.73',
		PeerPort => '7779',
		Proto => 'tcp',
		);
		die "cannot connect to the server $!\n" unless $receiver;
		print "Receiver connected!\n";
		while (1)
		{
			for my $i (0 .. $playerNum - 1)
			{#setting the cells to 0 is done before receiving the needed data
				$cell[$playerPosY[$i]][$playerPosX[$i]] ++;
			}
			print "\n";
			for my $y (0 .. $sizeY - 1)
			{
				for my $x (0 .. $sizeX - 1)
				{
					print "$cell[$y][$x] ";
				}
				print "\n";
			}
			print "\n";
			#============================================
			for my $i (0 .. $playerNum - 1)
			{#instead of setting everything to zero, lets just set what was changed the last time
				$cell[$playerPosY[$i]][$playerPosX[$i]] = 0;
			}
			#============================================
			print "Receiving basic data...\n";
			my $dataScalar;
			$receiver->recv($dataScalar, 1024);
			print "$dataScalar\n";
			@stuff = split /\D+/ , $dataScalar;
			for my $i (0 .. $playerNum - 1)
			{
				$playerPosY[$i] = $stuff[$i];
			}
			print "Decoded as @playerPosY\n";
			$receiver->recv($dataScalar, 1024);
			print "$dataScalar\n";
			@stuff = split /\D+/ , $dataScalar;
			$playerNum = @stuff;
			print "Data receiving done!\n";
			for my $i (0 .. $playerNum - 1)
			{
				$playerPosX[$i] = $stuff[$i];
			}
			print "Decoded as @playerPosX\n";
		}
	$receiver->close();
	}
);
#interface
my @request;
while (1)
{
	my $input;
	my $validInput = 0;
	while ($validInput == 0)
	{
		print "Player: ";
		$input = <STDIN>;
		if ($input =~ /\D*(\d+)\D*/)#get the first number of the input
		{
			$input =~ /\D*(\d+)\D*/;
			if ($1 < $playerNum)
			{
				$request[0] = $1;
				$validInput = 1;
			}
			else{ print "There are less players than that!\n"; };
		}
		else{ print "Invalid input!\n"; }
	}
	$validInput = 0;
	while ($validInput == 0)
	{
		print "\nMove (up - 0 ; down - 1 ; left - 2 ; right - 3): ";
		$input = <STDIN>;
		if ($input =~ /\D*(\d+)\D*/)#get the first number of the input
		{
			$input =~ /\D*(\d+)\D*/;
			$request[1] = $1;
			$validInput = 1;
		}
		else{ print "Invalid input!\n"; }
	}
	print "sending: @request\n";
	$sender->send("@request");
}
$sender->close();