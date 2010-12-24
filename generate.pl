#!/usr/bin/env perl
use strict;
use warnings;
use GD;
use GD::Simple;
use Lingua::JA::Heisig 'heisig_number';
use utf8;

my $query = "select fields.value from fields join fieldModels on (fieldModels.id = fields.fieldModelId) join models on (fieldModels.modelId = models.id) join facts on (facts.id = fields.factId) where models.tags like '%kanji%' and (fieldModels.name='漢字' or fieldModels.name='英語' or fieldModels.name='読み') order by facts.created, fieldModels.ordinal ASC;";

my $db = "$ENV{HOME}/tmp/japanese-$$.anki";
system("cp ~/Documents/Anki/Japanese.anki $db");
END { unlink $db }

open my $results, qq{echo "$query" | sqlite3 $db |};

binmode(\*STDOUT, ':utf8');
binmode($results, ':utf8');

system 'rm -rf kanji/';
mkdir 'kanji';

my $WIDTH = 460;
my $HEIGHT = 220;

$| = 1;
my $i = 0;
while (1) {
    ++$i;
    defined(my $meaning = <$results>) or last;
    defined(my $kanji   = <$results>) or last;
    defined(my $yomi    = <$results>) or last;
    chomp for $meaning, $kanji, $yomi;

    # the dimensions of my frame, but there are some borders so it's not
    # $HEIGHT and $WIDTH
    my $gd = GD::Image->new(480, 234);
    my $white = $gd->colorAllocate(255, 255, 255);
    $gd->rectangle(0, 0, 480, 234, $white);

    my $black = $gd->colorAllocate(0, 0, 0);
    do {
        my $size = 100;
        my $font = '/Library/Fonts/Hiragino Sans GB W3.otf';
        my ($x0, undef, $x1) = $gd->stringFT($white, $font, $size, 0, 0, 0, $kanji);
        my $x = (($WIDTH - ($x1 - $x0)) / 2);

        $gd->stringFT($black, $font, $size, 0, $x, 140, $kanji);
    };
    do {
        my $size = 20;
        my $font = '/home/sartak/Library/Fonts/GenBasR.ttf';
        my ($x0, undef, $x1) = $gd->stringFT($white, $font, $size, 0, 0, 0, $meaning);
        my $x = (($WIDTH - ($x1 - $x0)) / 2) + 10;

        # meaning
        $gd->stringFT($black, $font, $size, 0, $x, 180, $meaning);

        # number
        if (my $heisig = heisig_number($kanji)) {
            $gd->stringFT($black, $font, $size, 0, 40, 30, "#$heisig");
        }

        if ($yomi) {
            my $font = '/Library/Fonts/Hiragino Sans GB W3.otf';

            my $line = $yomi;
            $line =~ s/ の .*//; # I only know a compound word

            my ($compound, $component) = $yomi =~ /(.*) の (.*)/;

            # now that we're done munging text, make everything vertical

            $_ = join "\n", split '', $_ || ''
                for $line, $yomi, $compound, $component;

            my (undef, $y0, undef, undef, undef, $y1) = $gd->stringFT($white, $font, $size, 0, 0, 0, $line);
            my $y = (($HEIGHT - ($y0 - $y1)) / 2) + 30;

            if ($compound && $component) {
                $gd->stringFT($black, $font, $size, 0, 350, $y,      $compound);
                $gd->stringFT($black, $font,    10, 0, 330, $y - 5, "の");
                $gd->stringFT($black, $font, $size, 0, 320, $y + 28, $component);
            }
            else {
                $gd->stringFT($black, $font, $size, 0, 350, $y, $yomi);
            }
        }
    };

    # SD cards (because of fat-16 or something?) seem to be able to fit only
    # about 170 files in a single directory, so spread them out my digital
    # photo frame shows the pictures sorted by filename, so randomize that too
    my $dir = 'kanji/' . int(rand(160));
    mkdir $dir;
    my $file = "$dir/".int(rand(100000)).".jpg";
    open my $handle, '>', $file;
    binmode $handle;
    print $handle $gd->jpeg(100); # 100% quality. device doesn't support png!
    close $handle;

    if ($yomi) {
        print "\e[1;32m"; # green
    }
    print $kanji;
    print "\e[m"; # reset
}

print "\n";
