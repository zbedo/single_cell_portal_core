#!/usr/bin/env bash
#
# Generate data to simulate large study, e.g. to test download features.

letters=('A' 'B' 'C' 'D')

numItems=16584

header="GENE\t"
for ((i=1;i<=numItems;i++)); do

  # Generate a 16-character string of random combinations of letters A, B, C, and D
  ri1=$((RANDOM % 4)) # random index 1
  randomString=${letters[ri1]}
  for j in {0..16}; do
    ri1=$((RANDOM % 4))
    randomString+=${letters[ri1]}
  done

  ri2=$((RANDOM % 8))
  ri3=$((RANDOM % 8))

  header+="FoobarXY${ri2}_BazMoo_${ri3}_${randomString}-1\t"
done

content=''
for i in {1..80}; do
  echo "On item $i"
  randomFloatString=''
  for ((j=1;j<numItems;j++)); do
    r1=$RANDOM
    r2=$RANDOM
    r3=$RANDOM
    randomFloatString+="-0.0${r1}${r2}${r3}\t"
  done
  content+="${randomFloatString}\n"
done

data="${header}\n${content}"

printf $data > 'IJ_test_data_signature_50000.txt'