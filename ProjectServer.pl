use strict;
use warnings;
use IO::Socket::INET;
use threads;
use threads::shared;

#$| = 1;
#data
#my $crrIP :shared = '10.0.254.254';
my $input;
my $validInput = 0;
my $sizeY;
while ($validInput == 0)
{
	print "Rows: ";
	$input = <STDIN>;
	if ($input =~ /\D*(\d+)\D*/)#get the first number of the input
	{
		$input =~ /\D*(\d+)\D*/;
		$sizeY = $1;
		$validInput = 1;
	}
	else{ print "Invalid input!\n"; }
}

my $sizeX;
$validInput = 0;
while ($validInput == 0)
{
	print "Colums: ";
	$input = <STDIN>;
	if ($input =~ /\D*(\d+)\D*/)#get the first number of the input
	{
		$input =~ /\D*(\d+)\D*/;
		$sizeX = $1;
		$validInput = 1;
	}
	else{ print "Invalid input!\n"; }
}

my $playerNum :shared = 0;
my @playerPosY :shared;
my @playerPosX :shared;
my $newClient :shared = 0;
my $newReceiver :shared = 0;
my @ReqSelPlayer :shared;
my @ReqMoveDir :shared;
my $blocker :shared = 0;

my $greeterThread = threads->create(
sub
{
	my $socket0 = new IO::Socket::INET (
		LocalHost => '10.0.200.73',
		LocalPort => '7777',
		Proto => 'tcp',
		Listen => 5,
		Reuse => 1
	);
	die "cannot create socket $!\n" unless $socket0;
	print "Starting greeter thread...\n";
	my $greeter;
	while (1)
	{
		print "Waiting for a new client...\n";
		$greeter = $socket0->accept();
		print "A new client has connected!\n";
		$newClient++;
		my $signal = "Hello there!";
		$greeter->send($signal);
		shutdown($greeter, 1);
		$playerNum++;
	}
});
my $receiverThread = threads->create(
sub
{
	print "Receiver thread enabled!\n";
	my $socket1 = new IO::Socket::INET (
		LocalHost => '10.0.200.73',
		LocalPort => '7778',
		Proto => 'tcp',
		Listen => 5,
		Reuse => 1
	);
	die "cannot create socket $!\n" unless $socket1;
	while (1)
	{
		#if a new player has connected
		my @clientSenderThread;
		if ($newClient != 0)
		{
			$clientSenderThread[$playerNum] = threads->create(
			sub
			{
				print "Accepting client sender...\n";
				my $client = $socket1->accept();
				$client->send("$sizeY $sizeX $playerNum");
				my $data;
				$client->recv($data, 1024);
				$data =~ /(\d+)\D+(\d+)\D*/;
				push @playerPosX, $1;
				push @playerPosY, $2;
				print "New player will start at " . $playerPosY[@playerPosY - 1] . ":" . $playerPosX[@playerPosX - 1] . "\n";
				$client->send("@playerPosX");
				$client->send("@playerPosY");
				while (1)
				{
					print "Waiting for request...\n";
					$client->recv($data, 1024);
					print "Received request: $data\n";
					$data =~ /(\d+)\D+(\d+)\D*/;
					my $player = $1;
					my $direction = $2;
					print "Request decoded: $player : $direction\n";
					$ReqSelPlayer[@ReqSelPlayer] = $player;
					$ReqMoveDir[@ReqMoveDir] = $direction;
					{
						no warnings 'threads';
						cond_signal($blocker);
					}
					print "@ReqSelPlayer ; @ReqMoveDir";
				}
			});
			$newClient--;
			$newReceiver++;
		}
	}
});
my $processorThread = threads->create(
sub
{
	my $socket2 = new IO::Socket::INET (
		LocalHost => '10.0.200.73',
		LocalPort => '7779',
		Proto => 'tcp',
		Listen => 5,
		Reuse => 1
	);
	die "cannot create socket $!\n" unless $socket2;
	my @client;
	while (1)
	{
		if ($newReceiver != 0)
		{
			print "Client receiver connecting...\n";
			$client[scalar (@client)] = $socket2->accept();
			$newReceiver--;
		}
		while (@ReqSelPlayer > 0 && @ReqMoveDir > 0 && @ReqMoveDir == @ReqSelPlayer && $newReceiver == 0)
		{
			my $dir = pop @ReqMoveDir;
			my $selectedPl = pop @ReqSelPlayer;
			if ($dir == 0 && $playerPosY[$selectedPl] > 0) { $playerPosY[$selectedPl]--; } #up
			elsif ($dir == 1 && $playerPosY[$selectedPl] < $sizeY - 1) { $playerPosY[$selectedPl]++; } #down
			elsif ($dir == 2 && $playerPosX[$selectedPl] > 0) { $playerPosX[$selectedPl]--; } #left
			elsif ($dir == 3 && $playerPosX[$selectedPl] < $sizeY - 1) { $playerPosX[$selectedPl]++; } #right
		}
		my $debug = scalar (@client);
		print "Sending positions: @playerPosY ; @playerPosX\n to $debug clients...\n";
		for my $i (0 .. scalar (@client) - 1)
		{
			print "Sending info to client $i...\n";
			$client[$i]->send("@playerPosX");
			$client[$i]->send("@playerPosY");
		}
		print "Sending done!\n";
		lock ($blocker);
		cond_wait ($blocker);
	}
	if ($playerNum > 0)
	{
		
	}
});
while (1)
{
	print "@ReqSelPlayer @ReqMoveDir";
	sleep(2);
}