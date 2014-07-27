#!/usr/bin/perl

# asa-natpoller
# Written by Dan Sullivan
# This prints xlate table utilization (%) for the ASA 8.x platform
# It was written as a custom data input for Cacti

init();
use strict;
use warnings;
use Expect;

use POSIX;

sub init() {
        use FindBin qw($Bin);
        use lib "$Bin/../modules";
        use strict;
        use warnings;
        my %environment;
        $environment{'username'} = 'reporter';
        $environment{'password'} = 'whatever';
        $environment{'sshpath'} = '/links/bin/ssh';
        $environment{'enablepassword'} = 'whatever';
        $environment{'cmd'} = 'show xlate count';
        $environment{'device'} = '10.10.10.1';
        $environment{'enablecmd'} = 'enable';
        $environment{'sessions'} = '650000';
        printMyNATValue(\%environment);
}

sub printMyNATValue() {
        my $environment = $_[0] or die "Called without environment.\n";
        my $session = new Expect();
        $session->raw_pty(0);
        my $command = $environment->{'sshpath'} . " " . $environment->{'username'} .
             "@" . $environment->{'device'};
        $session->spawn($command) or die "Unable to execute command: $command";
        $session->log_stdout(0);

        my $match = $session->expect(10,
                ['Are you sure you want to continue connecting (yes/no)?' =>  sub {
                $session->send("yes\n"),
                Expect::exp_continue; }],
                ['password:' => sub {
                $session->send($environment->{'password'} . "\n");
                Expect::exp_continue; }],
                ['> ' => sub {
                $session->send($environment->{'enablecmd'} . "\n");
                Expect::exp_continue; }],
                ['Password' => sub {
                $session->send($environment->{'enablepassword'} . "\n");
                }]              

        );    

        my $output;
        if($match==4) {
                $session->send($environment->{'cmd'} . "\n");
                $match = $session->expect(10,
                        ['# ' => sub { $session->send("logout\n");
                                $output = $session->exp_before();
                                Expect::exp_continue;
                        }],
                        ['closed.' => sub {
                                #print "Found closed.\n";
                        }]
                );
        } else {
                die "incorrect match for service account.\n";
        }
        my @items = split("\n", $output);
        my $lineOfInterest = $items[1];
        $lineOfInterest=~s/^(\d+) //;
        my $percent = ($1/($environment->{'sessions'}))*100;
        $percent = ceil($percent);
        print "percent:$percent\n";
}
