#!/bin/sh -l
#BSUB -o out
#BSUB -e err
#BSUB -q s_long
#BSUB -P R000
#BSUB  -M 20G

wget="/usr/bin/wget --inet4-only"
ys=1997
ye=2021

y=$ys
while [ $y -le $ye ]; do
  mkdir $y
  for m in {1..12}; do
    mm=`printf "%02d" $m`
    ftd="ftp://osisaf.met.no/reprocessed/ice/conc/v3p0/$y/$mm"
    $wget $ftd/*_ease2-250* || exit 1
    for f in ice*.nc; do
      hh=`echo $f | cut -d_ -f3`
      dd=`echo $f | cut -d_ -f6 | cut -c 1-8`
      #gzip $f
      mv -f $f $y/ice_${hh}_${dd}.nc || exit 1 
    done
  done
  y=$(( $y + 1 ))
done
~

