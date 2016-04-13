#!/usr/local/bin/perl
#
# Fred P. Davis, NIH/NIAMS
# fredpdavis@gmail.com
# 
# mdllabook is a markdown-format lab notebook
#

use strict;
use warnings;
use Getopt::Std ;
use Cwd ;
use File::Path qw/mkpath/ ;
use File::Spec ;
use File::Basename qw/basename dirname/ ;
use File::Temp qw/tempdir/ ;
use File::Copy qw/move copy/;

main() ;

sub main {

   my $usage = "USAGE: ".__FILE__." [OPTIONS] -c CONFIGFILE

-c CONFIGFILE   ONLY REQUIRED OPTION: see example_mdlabbook.config

-h              describe usage
-e YEARMODA     open/create a specific entry, eg, 20160322 for March 22, 2016
                - if -e not specified, will open today's entry
-w              convert to webpages (automatically runs after editing an entry)
-p              convert to PDF
-f FILE1 FILE2... moves files to files directory of today's notebook
-n              don't add prefix to filename before moving (default: date)

-s PDF          crops 2-page PDF scans into individual page PNG files
                - requires imagemagick
                - defaults work for 300dpi 8.5x11 2-page scan of 5.5x8 green NIH
                  notebooks (Federal Supply Service, GPO 7530-00-286-6207)
-b PAGENUM      first physical page number in the PDF scan (default: 1)
-l cropspec     left page cropping spec (default: 1600x2350+250+0)
-r cropspec     right page cropping spec (default: 1600x2350+1750+0)
-o out_prefix   Prefix for cropped PNG file names (default \"nb_p\")
-x CROPSPECFILE file listing cropping specs for individual pages, listed by
                physical page number, eg: \"1 1600x2350+250+0\"

" ;

# Figure out run mode
   my $opts = {} ;
   getopts('phfne:d:c:i:', $opts) ;
   $opts->{usage} = $usage ;

   if (exists $opts->{h}) { die $usage;}
   if (!exists $opts->{c}) { die "ERROR: must specify -c CONFIGFILE\n$usage" ;}
   $opts->{c} = File::Spec->rel2abs($opts->{c})  ;
   read_configfile($opts) ;

   if (exists $opts->{w}) { make_webpages($opts); exit;}
   if (exists $opts->{i}) { make_webindex($opts) ; exit;}
   if (exists $opts->{p}) { make_pdf($opts); exit;}
   if (exists $opts->{s}) { crop_notebookscan($opts); exit;}

# Defaults for unspecified options
   if (!exists $opts->{editor}) { $opts->{editor} = 'vim' ; }


# Set source directory for access to css, Makefile, etc
   $opts->{srcdir} = dirname(__FILE__) ;
   if (-l $opts->{srcdir}) {
      $opts->{srcdir} = dirname(readlink($opts->{srcdir})); }
   $opts->{srcdir} = File::Spec->rel2abs($opts->{srcdir})  ;

   if (!exists $opts->{dir}) {
      die "ERROR: must specify -dir in CONFIG file\n$usage\n";}

# Check if notebook directory exists and already has Makefile and css.
   if (!-s $opts->{dir}) { mkpath($opts->{dir}) ; }
   if (!-s $opts->{dir}."/Makefile") {
      open(ORIGMAKEF, $opts->{srcdir}."/Makefile") ;
      open(MAKEF, ">".$opts->{dir}."/Makefile") ;
      while (my $line = <ORIGMAKEF>) {
         $line =~ s/CONFIGFILE/$opts->{c}/g ;
         $line =~ s/SRCDIR/$opts->{srcdir}/g ;
         print MAKEF $line ;
      }
      close(ORIGMAKEF) ;
      close(MAKEF) ;

      mkpath($opts->{dir}."/css") ;
      copy($opts->{srcdir}."/css/buttondown_edit.css", $opts->{dir}."/css") ;
   }

   my @months = qw/January   February  March
                   April     May       June
                   July      August    September
                   October   November  December/ ;

# Figure out entry date
   my ($day, $month, $year, $monthName) ;
   if (!exists $opts->{e}) { #Today's date
      ($day, $month, $year)=(localtime)[3,4,5];
      $year += 1900 ;

      $monthName = $months[$month] ;
      $month++ ;

      if ($day < 10) {$day = "0$day";}
      if ($month < 10) {$month = "0$month";}

   } else { # If entry date specified, parse into year, month, day
      if (length($opts->{e}) < 8) {
         die "ERROR: -e requires YEARMODA format. ".
             "eg, 20160326 for March 26, 2016\n".$usage;
      }
      ($year, $month, $day) = ($opts->{e} =~ /([0-9]{4})([0-9]{2})([0-9]{2})/) ;
      $monthName = $months[($month - 1)] ;
   }

# Figure out last entry prior to today (or specified entry date) for split-vim
   my $prevFn ;
   my ($prevDay, $prevMo, $prevYear) = ($day, $month, $year);

# Deal with edge case of brand new notebook
   my $nbexists_flag = 0 ;
   {
      my @entries = glob($opts->{dir}."/*/*/*md") ;
      if ($#entries >= 1) { $nbexists_flag = 1;}
   }

# If this isn't a new notebook, look for prior date
   while (!defined $prevFn & $nbexists_flag) {
      $prevDay-- ; 
      if ($prevDay < 0) {$prevDay = 31; $prevMo--;  }
      if ($prevMo < 0)  {$prevMo = 12;  $prevYear--;}

      if (length($prevDay) == 1) {$prevDay = '0'.$prevDay;}
      if (length($prevMo) == 1)  {$prevMo = '0'.$prevMo;}

      my $t = $opts->{dir}."/$prevYear/$prevYear$prevMo/".
              "$prevYear$prevMo$prevDay.md" ;
      if (-s $t) {
         $prevFn = $t; }
   }

# Make directory for this month, if doesn't exist yet
   my $todayDir = $opts->{dir}."/$year/$year$month" ;
   if (! -s $todayDir) {mkpath($todayDir);}

# If not in filing mode, then edit today(/specified day)'s entry
   if (!exists $opts->{f}) { #ie entry mode

      my $todayFn = "$todayDir/$year$month$day.md" ;
   
      if (! -s $todayFn) { #only
         open(TODAYF, ">$todayFn") ;
         print TODAYF "---
title: ".$opts->{title}."
author: ".$opts->{author}."
date: $monthName $day, $year
---
" ;
         close(TODAYF) ;
      }

      if ($opts->{editor} eq 'vim' & defined $prevFn) {
         system("vim -c 'set ro|sp $todayFn|set noro' $prevFn") ;
      } elsif ($opts->{editor} eq 'emacs' & defined $prevFn) {
         system("emacs -nw $prevFn $todayFn") ;
      } else {
         system($opts->{editor}." ".$todayFn) ;
      }

      my $cwd = getcwd() ;
      chdir $opts->{dir} ;
      system("make") ;
      chdir $cwd ;

# Otherwise, in filing mode
   } else {

# Figure out timestamp prefix, unless -n specified (noprefix)
      my $prefix = "$year$month$day"."_" ;
      if (exists $opts->{n}) { $prefix = '' ; }

# Figure out destination directory
      my $fileDir = $todayDir."/files" ;
      if (! -s $fileDir) {mkpath($fileDir);}

# Iterate over specified files and move to destination
      foreach my $i (0..$#ARGV) {
         my $fileFn = $ARGV[$i] ;
         my $newFileFn = $prefix.basename($fileFn) ;
         move $fileFn, "$fileDir/$newFileFn" ;
         print "[$newFileFn](files/$newFileFn)\n";
      }
   }

}

sub make_webindex {
   my $opts = shift ;
# Make calendar tables linked to entries
   my $cwd = getcwd() ;
   chdir $opts->{dir} ;

   my $specs = {months_per_line => 3} ;

   my @files= glob("*/*/*md") ;
   my $month2entry = {};
   foreach my $j ( 0 .. $#files) {
      my ($month, $entry) = ($files[$j] =~ /\/([0-9]+)\/(.+).md/) ;
      $month2entry->{$month}->{$entry} = $files[$j] ;
   }

   my $lastentry ;
   my $lastentry_html ;
   {
      my ($lastmonth, undef) = sort {$b <=> $a} keys %{$month2entry};
      ($lastentry, undef) = sort {$b <=> $a} keys %{$month2entry->{$lastmonth}};
      $lastentry_html =$month2entry->{$lastmonth}->{$lastentry};
      $lastentry_html =~ s/md$/html/ ;
   }

   print "---
title: ".$opts->{title}."
author: ".$opts->{author}."
---
" ;

   print "<table><tr>\n"; #HORIZ
   my $linenum = 0 ;
   my $x = 0 ;
   foreach my $month (sort {$b <=> $a} keys %{$month2entry}) {

      my ($y, $m) = ($month =~ /(20[0-9][0-9])([0-9][0-9])/) ;

      my $calout = `cal $m $y` ; chomp $calout ;
      my @callines = split(/\n/, $calout) ;
      my $month_string = shift @callines ;
      $month_string =~ s/^ +// ;
      $month_string =~ s/ +$// ;

#VERT      print "<p><table><caption>$month_string</caption>\n" ;
      print "<td><table><caption>$month_string</caption>\n" ; #HORIZ
      foreach my $j ( 0 .. $#callines) {

         $callines[$j] .= ' ' ;
         my (@curdays) = ( $callines[$j] =~ m/.{3}/g );
#         print STDERR "last curday = ".$curdays[$#curdays]."\n";
         my @outcells = @curdays ;
         my @linkeddays ;
         foreach my $k ( 0 .. $#curdays) {
            my $val = $curdays[$k] ;
            $val =~ s/ //g ;

            if ($val =~ /^[0-9]+$/) {
               if (length($val) == 1) {
                  $val = '0'.$val ;
               }
               if (exists $month2entry->{$month}->{$month.$val}) {
                  my $fn = $month2entry->{$month}->{$month.$val} ;
                  my $html_fn = $fn ;$html_fn =~ s/md$/html/ ;
                  $val = "<a href=\"$html_fn\">$val</a>";
               }
            } else {
               $val = "<b>$val</b>" ;
            }

            $outcells[$k] = "<td>$val</td>" ;
         }
         print "<tr>\n" ;
         print join(" ", @outcells)."\n";
         print "</tr>\n"
      }
      print "</table>" ;
      print "\n\n" ;
      print "</td>"; #HORIZ
      $x++;

      if (($m - 1) % $specs->{months_per_line} == 0) {
         print "</tr>";
         if ($linenum == 0 ) {
            print "<caption><a href=\"$lastentry_html\">latest: $lastentry</a></caption>";}
         print "</table>\n\n"; #END horiz table
         print "<table><tr>\n"; #START new HORIZ
         $linenum++;
      }
   }
   print "</tr></caption></table>\n"; #HORIZ

   chdir $cwd ;
}

sub crop_notebookscan {
   my $opts = shift ;

   my $specs =  {
      out_prefix        => "nb_p",
      left_crop_spec    => "1600x2350+250+0",
      right_crop_spec   => "1600x2350+1750+0",
      startpage         => 1,
   } ;

   my $j = 0 ;
   while ($j <= $#ARGV) {
      my $key = $ARGV[$j] ; $key =~ s/^-// ;
      $specs->{$key} = $ARGV[($j + 1)] ;
      $j += 2;
   }

   if (! -s $specs->{s}) {
      die "ERROR: ".$specs->{s}." not found\n$opts->{usage}\n";}

   my $customspecs = {} ;
   if (exists $opts->{x}) {
      open(CUSTOMSPECS, $opts->{x}) ;
      while (my $line = <CUSTOMSPECS>) {
         chomp $line;
         my ($page, $cropspec) = split(' ', $line) ;
         $customspecs->{$page} = $cropspec ;
      }
      close(CUSTOMSPECS) ;
   }

   my $scratchdir       = tempdir(CLEANUP => 1) ;
   print STDERR "scratchdir: $scratchdir\n";

   print STDERR "Converting to PNG\n" ;
   my $tcom= "convert -density 300 ".$specs->{pdf_fn}." $scratchdir/tmp.$$.png";
   system($tcom) ;

   print STDERR "Cropping page:   " ;
   my @origfiles = glob("$scratchdir/tmp.$$*.png") ;
   foreach my $j ( 0 .. $#origfiles) {
      print STDERR "\b"x(length($j)).($j + 1) ;

      my ($orig_p)      = ($origfiles[$j] =~ /tmp.$$-(.+).png/) ;
      if (!defined $orig_p) {$orig_p = 0;}

      $orig_p           = ($orig_p * 2) + 1;
      my $out_p         = $orig_p + $specs->{startpage} - 1 ;

      foreach my $crop (@{$specs}{qw/left_crop_spec right_crop_spec/}) {
         my $crop_spec = $crop ;
         if (exists $customspecs->{$out_p}) {
            $crop_spec = $customspecs->{$out_p};}

         my $tcom       = "convert ".$origfiles[$j]." -crop $crop_spec ".
                          " ".$specs->{out_prefix}.$out_p.".png" ;
         system($tcom) ;
         $out_p++ ;
      }

      unlink $origfiles[$j] ;
   }
   print STDERR "\nDone\n" ;

}

sub read_configfile {
# Reads configuration file and adds entry to opts hash

   my $opts = shift ;
   open(CONFIGF, $opts->{c}) ;
   while (my $line = <CONFIGF>) {
      chomp $line;
      if ($line =~ /^#/ || $line =~ /^$/) {next;}
      my ($key, $val) = ($line =~ /^\-([^ ]+) (.+)$/) ;
      $opts->{$key} = $val ;
   }
   close(CONFIGF) ;

# tilde expansion from perlfaq5

   $opts->{dir} =~ s{
             ^ ~             # find a leading tilde
             (               # save this in $1
                 [^/]        # a non-slash character
                       *     # repeated 0 or more times (0 means me)
             )
   }{
             $1
                 ? (getpwnam($1))[7]
                 : ( $ENV{HOME} || $ENV{LOGDIR} )
   }ex;

}

sub make_webpages {
   my $opts = shift ;
   my $cwd = getcwd() ;
   chdir $opts->{dir} ;
   system("make") ;
   chdir $cwd ;
}


sub make_pdf {

   my $opts = shift ;
   my $cwd = getcwd() ;
   chdir $opts->{dir} ;

   my $fn = {};
   $fn->{wholemd} = $opts->{dir}."/wholenotebook.md" ;
   $fn->{wholepdf} = $opts->{dir}."/wholenotebook.pdf" ;

   my $fh = {} ;
   open($fh->{wholemd}, ">".$fn->{wholemd}) ;

print {$fh->{wholemd}} '---
title: '.$opts->{title}.'
author: '.$opts->{author}.'
geometry: margin=1in
header-includes:
    - \usepackage[tablename=,figurename=]{caption}
date: \today
fontsize: 11pt
---
' ;

   my $NBDIR = $ARGV[0] || "." ;

   my @mds = glob("*/*/*md");
   foreach my $md (@mds) {
      open(MDF, $md);

      my $fulldate= basename($md) ;
      my ($year, $mo, $date) = ($fulldate =~ /([0-9]{4})([0-9]{2})([0-9]{2})/) ;

      my $inheader = 0 ;
      while (my $line = <MDF>){
         chomp $line;
         if ($line eq '---') {
            if ($inheader) {$inheader = 0;}
            else {$inheader = 1}
            if (!$inheader) {next;}
         }

         if ($inheader) {
            if ($line =~ /date/) {
               $line =~ s/date: //; 
               print {$fh->{wholemd}} "\n# ".$line."\n" ;
            }
            next;
         }

         if ($line =~ /^#/) {$line = '#'.$line;}
         if ($line =~ /\]\(files/) {
            $line =~ s/\]\(files/\]\($NBDIR\/$year\/$year$mo\/files/g ;
         } else {
            $line =~ s/\]\((\.\..*files)/\]\($NBDIR\/$year\/$year$mo\/$1/g ;
         }
         print {$fh->{wholemd}} $line."\n";
      }
      print {$fh->{wholemd}} '\newpage'."\n\n";
      close(MDF);
   }
   close($fh->{wholemd}) ;

   system("pandoc -s --variable mainfont=Georgia --latex-engine=xelatex ".
          $fn->{wholemd}." --toc -o ".$fn->{wholepdf}) ;

   chdir $cwd ;
}
