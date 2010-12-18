#!/usr/bin/env perl
use strict;
use warnings;
use GD;
use GD::Simple;
use Lingua::JA::Heisig 'heisig_number';
use Encode;
use utf8;

my $query = "select fields.value from fields join fieldModels on (fieldModels.id = fields.fieldModelId) join models on (fieldModels.modelId = models.id) join facts on (facts.id = fields.factId) where models.tags like '%kanji%' and (fieldModels.name='漢字' or fieldModels.name='英語' or fieldModels.name='読み') order by facts.created, fieldModels.ordinal ASC;";

system("cp ~/Documents/Anki/Japanese.anki ~/tmp/japanese-$$.anki");
open my $results, qq{echo "$query" | sqlite3 ~/tmp/japanese-$$.anki |};

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
    print $kanji;

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
        if (my $heisig = heisig_number(decode_utf8 $kanji)) {
            $gd->stringFT($black, $font, $size, 0, 40, 30, "#$heisig");
        }

        if ($yomi) {
            my $font = '/Library/Fonts/Hiragino Sans GB W3.otf';
            $yomi = encode_utf8 join "\n", split '', decode_utf8 $yomi;

            my (undef, $y0, undef, undef, undef, $y1) = $gd->stringFT($white, $font, $size, 0, 0, 0, $yomi);
            my $y = (($HEIGHT - ($y1 - $y0)) / 2);

            #$gd->stringFT($black, $font, $size, 0, 400, $y, $yomi);
        }
    };

    my $dir = 'kanji/' . int(rand(160));
    mkdir $dir;
    my $file = "$dir/".int(rand(100000)).".jpg";
    open my $handle, '>', $file;
    binmode $handle;
    print $handle $gd->jpeg(100);
    close $handle;
}
