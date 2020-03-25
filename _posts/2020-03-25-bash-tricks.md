---
layout: post
title: Bash tricks to make your life easier.
categories: [Bash, Bioinformatics]
---

A while ago I gave a presentation on some of the lesser known features of bash to a group of people, and I thought I should share it again.

I'm from a generation of research computing/programmers that learnt to do things by googling and StackExchange forums.
Researching this topic was really my first foray into actually using `man` documentation.


For a good reference of the topics discussed here checkout:

```bash
# Syntax, parameter expansions, arrays etc
man bash

# For read, declare etc.
man builtins
```

And for a more tutorial-esque thing, tldp is amazing 
[https://www.tldp.org/LDP/abs/html/](https://www.tldp.org/LDP/abs/html/).

My focus here is on bash and some of the features are bash specific.
But usually some variant of it will work with `zsh` or regular posix `sh`.


## Make your bash script stop as soon as an error occurs.

I wish this was more general knowledge, but bash will just try to keep running things in scripts even if previous lines have failed.
As an example, say `gunzip`-ing a file failed halfway through for some-reason, your downstream programs might continue with the truncated file and you'd never know that your analysis was faulty.

It is my strong opinion that bash scripts should have at least the following line at the top of the script (after the shebang).


```bash
set -eu

# This is sometimes used too.
# set -euo pipefail
```

`-e` tells your shell to exit the script as soon as you get a non-zero exit code, and `-u` tells it to raise an error if you try to use a variable that doesn't exist.


## Bash Arrays

A few people will be aware that you can define arrays in bash.
These are roughly analagous to lists or vectors in other languages.


```bash
# Define the array. Elements should be separated by what's in your IFS environment variable (usually a space).
ARR=( one two three four )

# Grabbing all elements of an array
echo "${ARR[@]}"

# Grabbing indices (NB bash is 0-based, zsh is 1-based)
echo "${ARR[0]}"

# Leaving out the square braces does weird things
echo "${ARR}"

# Find the length of an array
echo "${#ARR[@]}"

# But don't forget the @
echo "${#ARR}"

# Get the keys (indices) of an array (useful for loops)
echo "${!ARR[@]}"
```

```
## one two three four
## one
## one
## 4
## 3
## 0 1 2 3
```

Sadly you can't have nested arrays, but you could nest space delimited strings and fudge it if you _really_ wanted to.


## Associative arrays

You may not know that bash has what they call "associative arrays" which are basically dictionaries or hashmaps (NB. this requires bash version > 4).


```bash
# Defining requires explicit declaraton
declare -A AARR
AARR=([one]=1 [two]=2 [three]=3 [four]=4 [five]="5 6")

# Add single records
AARR[six]=6

# Get elements by key!
echo "Get key two" ${AARR[two]}
echo "Get key six ${AARR[six]}"

# Other operators work like in regular arrays
echo "Print all values ${AARR[@]}" # All values
echo ${!AARR[@]} # All keys
echo ${#AARR[@]} # Number of elements
```

```
## Get key two 2
## Get key six 6
## Print all values 5 6 2 3 4 6 1
## five two three four six one
## 6
```


## Returning arrays from functions

Bash returns are... different.
To return something other than an exit-code, you need to print something to a file (e.g. stdout or stderr).
There are a few weird and wonderful ways to do this (that work with things other than arrays).

#### Option 1. echo the string (Regular arrays only)


```bash
myfun () {
    MYARR=(1 2 3)
    echo "${MYARR[@]}"
}

MYARR=( $(myfun) )
echo "${MYARR[@]}"
```

```
## 1 2 3
```


#### Option 2. Declare as a global variable.

This option is most definitely **not** recommended.


```bash
myfun2 () {
    declare -g -A MYARR2=([one]=1 [two]=2)
}

echo "Before call: ${MYARR2[one]:-unset}"

myfun2

echo "After call: ${MYARR2[one]:-unset}"
```

```
## Before call: unset
## After call: 1
```


#### Option 3. Return a declare string

This is most flexible but esoteric option.
This will work with associative arrays and function too, so you could do some wacky metaprogramming things.


```bash
myfun3 () {
    declare -A MYARR3=([one]=1 [two]=2)
    declare -p MYARR3
}

echo "Return of myfun: $(myfun3)"
echo "Before eval: ${MYARR3[one]:-unset}"

eval $(myfun3)
echo "After eval: ${MYARR3[one]:-unset}"
```

```
## Return of myfun: declare -A MYARR3=([two]="2" [one]="1" )
## Before eval: unset
## After eval: 1
```


## Parameter expansion

Bash has some basic string manipulation facilities what work on variables, which for some reason is known as "parameter expansion" in their documentation.
This is super useful for dealing with filenames in scripts.


```bash
FILENAME="hello.txt"

# Delete characters up to and including first '.'
echo "#*." ${FILENAME#*.}

# Same but from the end
echo "%.*" ${FILENAME%.*}
```

```
## #*. txt
## %.* hello
```

Note that `#` matches characters from the beginning of the string, and `%` matches characters from the end.
Both of these versions will only match to the first instance of the pattern, so if we have multiple extensions, we might need to use the greedy versions `##` and `%%`.


```bash
FILENAME2="my.fastq.gz"

echo "Original       : ${FILENAME2}"

# Not greedy
echo "%.*            :" ${FILENAME2%.*}

# Greedy
echo "%%.*           :" ${FILENAME2%%.*}

# String substitution
echo "/fastq/tar     :" ${FILENAME2/fastq/tar}

# Not greedy
echo "/./DOT         :" ${FILENAME2/./DOT}

# Greedy
echo "//./DOT        :" ${FILENAME2//./DOT}

# Find replace from end of string
echo "/%fastq.gz/tgz :" ${FILENAME2/%fastq.gz/tgz}

# Find replace from start of string
echo "/#my/your      :" ${FILENAME2/#my/your}

# Empty replacements just add text to start/end
# Replacements can include '/'
echo "/#/mydir/      :" ${FILENAME2/#/mydir/}
```

```
## Original       : my.fastq.gz
## %.*            : my.fastq
## %%.*           : my
## /fastq/tar     : my.tar.gz
## /./DOT         : myDOTfastq.gz
## //./DOT        : myDOTfastqDOTgz
## /%fastq.gz/tgz : my.tgz
## /#my/your      : your.fastq.gz
## /#/mydir/      : mydir/my.fastq.gz
```


## Parameter expansion in arrays

Parameter expansion really comes into its own when we apply it to arrays.
We can actually do something like vectorised string manipulation, which I find really useful for HPC batch scripting.

Basically, you do the same operations as above, but you take an array and add the `[@]` element selector.



```bash
# Define an array with some filenames.
ARR=( my1.fastq.gz my2.fastq.gz )

# Replace from end for all elements of array
echo "/%.*/.bam/      :" ${ARR[@]/%.*/.bam}
echo "/%fastq.gz/bam  :" ${ARR[@]/%fastq.gz/bam}

# Add to string to start or array elements
# This would add a directory to the beginning of the string.
echo "/#/mydir/       :" ${ARR[@]/#/mydir/}

# Each operation returns the IFS separated string
# To chain operations you need to convert the output to new a array.

BAMS=( ${ARR[@]/%.*/.bam} )  # replace .fastq.gz with .bam extension
BAMS=( ${BAMS[@]/#/mydir/} )  # Add a directory
BAIS=( ${BAMS[@]/%/.bai})  # Get names for bais.

echo
echo "BAMS:" ${BAMS[@]}
echo "BAIS:" ${BAIS[@]}
```

```
## /%.*/.bam/      : my1.bam my2.bam
## /%fastq.gz/bam  : my1.bam my2.bam
## /#/mydir/       : mydir/my1.fastq.gz mydir/my2.fastq.gz
## 
## BAMS: mydir/my1.bam mydir/my2.bam
## BAIS: mydir/my1.bam.bai mydir/my2.bam.bai
```


## Brace expansion

A final useful thing is a special kind of globbing pattern called brace expansion.
This is really handy for making combinations of strings.


```bash
echo "Repeat string for multiple values."
echo file_{0,two,"spa ces",}.txt
echo "sample_R"{1,2}".fastq.gz"

# Spaces are your enemy here
echo file.{txt, csv } # Won't work
echo file.{txt,csv} # Will work

# Can be nested for big combinations
echo -e cat{erpillar,_{dog,duck}}
```

```
## Repeat string for multiple values.
## file_0.txt file_two.txt file_spa ces.txt file_.txt
## sample_R1.fastq.gz sample_R2.fastq.gz
## file.{txt, csv }
## file.txt file.csv
## caterpillar cat_dog cat_duck
```


You can also use this to write out a range of number similar to the `seq` command using the `{start..end..step}` syntax (step is optional).


```bash
# Useful for writing out parameter grid searches...
echo -e "-k "{50..90..10}{" --optional-arg",}"\n" | sed 's/^\s*//g'
```

```
## -k 50 --optional-arg
## -k 50
## -k 60 --optional-arg
## -k 60
## -k 70 --optional-arg
## -k 70
## -k 80 --optional-arg
## -k 80
## -k 90 --optional-arg
## -k 90
```


## Combining it all as an example for use on clusters

So apart from regular bash scripts and day-to-day linux-y things, these features are really useful for running more complex pipelines on HPC clusters, if you can't use Nextflow or snakemake for whatever reason.

As a small bit of setup, we have a tsv files containing details of some fastq files.


```bash
cat ./2020-03-25-bash-tricks.tsv
```

```
## platform	flowcell	lane	adapter_index	sample	sample_index	read1_file	read2_file
## illumina	CAU9HANXX	L001	GAGATTCC-AGGCGAAG	WAC13529	52	52_CAU9HANXX_GAGATTCC-AGGCGAAG_L001_R1.fastq.gz	52_CAU9HANXX_GAGATTCC-AGGCGAAG_L001_R2.fastq.gz
## illumina	CAU9HANXX	L002	GAGATTCC-AGGCGAAG	WAC13529	52	52_CAU9HANXX_GAGATTCC-AGGCGAAG_L002_R1.fastq.gz	52_CAU9HANXX_GAGATTCC-AGGCGAAG_L002_R2.fastq.gz
## illumina	CBBV2ANXX	L001	GAGATTCC-AGGCGAAG	WAC13529	52	52_CBBV2ANXX_GAGATTCC-AGGCGAAG_L001_R1.fastq.gz	52_CBBV2ANXX_GAGATTCC-AGGCGAAG_L001_R2.fastq.gz
## illumina	CAU9HANXX	L001	CTGAAGCT-AGGCGAAG	WAC13532	55	55_CAU9HANXX_CTGAAGCT-AGGCGAAG_L001_R1.fastq.gz	55_CAU9HANXX_CTGAAGCT-AGGCGAAG_L001_R2.fastq.gz
## illumina	CAU9HANXX	L002	CTGAAGCT-AGGCGAAG	WAC13532	55	55_CAU9HANXX_CTGAAGCT-AGGCGAAG_L002_R1.fastq.gz	55_CAU9HANXX_CTGAAGCT-AGGCGAAG_L002_R2.fastq.gz
## illumina	CBBV2ANXX	L001	CTGAAGCT-AGGCGAAG	WAC13532	55	55_CBBV2ANXX_CTGAAGCT-AGGCGAAG_L001_R1.fastq.gz	55_CBBV2ANXX_CTGAAGCT-AGGCGAAG_L001_R2.fastq.gz
```

Now we can use some of these tools to process files in parallel, selecting a parameter- and data-set to use based on an integer.
The integer could be an MPI rank, or something specific to your cluster (e.g. on slurm `SLURM_PROCID` and `SLURM_ARRAY_TASK_ID`).



```bash
# Set up a parameter grid to search
# see also the readarray command in `man bash`, reads file lines as array.
PSETS=( $(echo -e "-k "{50..90..10}{" --optional-arg",}"\n" | sed 's/^\s*//g' | head -n-1) )

TABLE="2020-03-25-bash-tricks.tsv"

# Read samples into an array
SAMPLES=( $(awk 'NR > 1 {print $5}' "${TABLE}" | uniq) )
echo "These are the samples:" ${SAMPLES[@]}

# Find the number of tasks you need to run based on your data.
NTASKS=$(( ${#PSETS[@]} * ${#SAMPLES[@]} ))
NTASKS_PER_NODE=3
echo "NTASKS: ${NTASKS}"

echo

# Could combine job arrays with MPI-style packing
# We would run multiple tasks like this but the "RANK" variable will tell us which sample and parameterset we should use.
RANK=0 #$(( ${SLURM_ARRAY_TASK_ID} + ${SLURM_PROCID} ))

# Get hybrid ranks for sample and parameter sets
SAMPLE_IDX=$(( ${RANK} / ${#PSETS[@]} ))
PSET_IDX=$(( ${RANK} % ${#PSETS[@]} ))

SAMPLE="${SAMPLES[${SAMPLE_IDX}]}"
echo "Sample is: ${SAMPLE}"

PSET="${PSETS[${PSET_IDX}]}"
echo "Paramset is: ${PSET}"

echo

# Select the rows of the table relevant to this sample
SUBTABLE=$(awk -v sample=${SAMPLE} '$5==sample' "${TABLE}")
# Don't forget your quotes, otherwise all formatting is lost!

# Read the column names in as an array
COLUMNS=( $(head -n 1 "${TABLE}") )

# Parse the columns from subtab into an associative array by column
# We loop over the column _indices_ and use them to access the column names
# and the column values.

declare -A PARAMS
for col_idx in ${!COLUMNS[@]}; do
    col="${COLUMNS[${col_idx}]}"
    # NB cut uses 1-based indices, hence +1.
    PARAMS[${col}]=$(echo "${SUBTABLE}" | cut -f $(( ${col_idx} + 1 )) )
done

# Now we can access the information using the associative array! (dict)

echo "PARAMS[read1_file]:" ${PARAMS[read1_file]}
echo "PARAMS[flowcell]:"   ${PARAMS[flowcell]}


echo

# Convert the string elements of some columns into arrays
R1_ARR=( ${PARAMS[read1_file]} )
R2_ARR=( ${PARAMS[read2_file]} )

# Print out or run a command
echo somekindofaligner ${R1_ARR[@]/#/--in1 indir/} ${R1_ARR[@]/#/--in2 indir/} ${PSET} --out "outdir/${SAMPLE}.bam"
```

```
## These are the samples: WAC13529 WAC13532
## NTASKS: 50
## 
## Sample is: WAC13529
## Paramset is: -k
## 
## PARAMS[read1_file]: 52_CAU9HANXX_GAGATTCC-AGGCGAAG_L001_R1.fastq.gz 52_CAU9HANXX_GAGATTCC-AGGCGAAG_L002_R1.fastq.gz 52_CBBV2ANXX_GAGATTCC-AGGCGAAG_L001_R1.fastq.gz
## PARAMS[flowcell]: CAU9HANXX CAU9HANXX CBBV2ANXX
## 
## somekindofaligner --in1 indir/52_CAU9HANXX_GAGATTCC-AGGCGAAG_L001_R1.fastq.gz --in1 indir/52_CAU9HANXX_GAGATTCC-AGGCGAAG_L002_R1.fastq.gz --in1 indir/52_CBBV2ANXX_GAGATTCC-AGGCGAAG_L001_R1.fastq.gz --in2 indir/52_CAU9HANXX_GAGATTCC-AGGCGAAG_L001_R1.fastq.gz --in2 indir/52_CAU9HANXX_GAGATTCC-AGGCGAAG_L002_R1.fastq.gz --in2 indir/52_CBBV2ANXX_GAGATTCC-AGGCGAAG_L001_R1.fastq.gz -k --out outdir/WAC13529.bam
```


The final line is the thing that we would actually run.
Note that by changing the value of `RANK`, we can change the command automatically.


Anyway.
This example is a bit more complicated than it needs to be, but I have actually run jobs on supercomputers like this and it works rather well once you've set it up.


I hope this is useful to someone.
Cheers, Darcy
