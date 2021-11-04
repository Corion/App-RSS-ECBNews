#!/usr/bin/perl
use 5.020;
use feature 'signatures';
no warnings 'experimental::signatures';

use XML::RSS;
use LWP::Simple 'get';
use App::scrape 'scrape';
use DateTime;
use DateTime::Format::Mail;
use File::Basename;
use Getopt::Long;

GetOptions(
    'output|o=s' => \my $output_rss,
);

$output_rss //= 'ecbnews.rss';

my $rss = XML::RSS->new(version => '2.0');

my $base = 'https://corion.net/rss/ecb-paym.rss';

my $now = DateTime->from_epoch( epoch => time() );

$rss->channel(
    title => 'ECB PAYM news',
    link         => "$base",
    description  => "ECB PAYM news",
    lastBuildDate => $now,
    syn => {
        updatePeriod    => 'daily',
        updateFrequency => '1',
        updateBase      => "2021-11-01T00:00+00:00",
    },
);

my $news_url = 'https://www.ecb.europa.eu/paym/intro/news/html/index.en.html';
my $html = get $news_url;

my @posts = scrape(
    $html,
    {
        date => 'dt@isodate',
        title => 'dd .title a',
        url => 'dd .title a@href',
    },
    {
        base => $news_url,
        },
);

for my $item (@posts) {
    my $url = $item->{url};

    $item->{date} =~ m!^(\d{4})-(\d\d)-(\d\d)$!
        or warn "Invalid date '$item->{date}'";

    my $date = DateTime->new( year => $1, month => $2, day => $3 );

    my $title = $item->{title};
    $rss->add_item(
        title => $title,
        uri => $url,
        permalink => $url,
        dc => {
            subject   => $title,
            creator   => basename $0,
            date      => $date,
        },
        pubDate      => $date,
    );
};

open my $fh, '>', $output_rss
    or die "Couldn't write RSS file '$output_rss': $!";

print { $fh } $rss->as_string;
