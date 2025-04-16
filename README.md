
<!-- README.md is generated from README.Rmd. Please edit that file -->

# variantstring

This R package that defines *variant string format*, a convenient format
for encoding multi-locus genotypes. Functionalities include converting
into and out of variant string format, subsetting based on genomic
position, and comparing two variant strings to see if one is a subset of
the other.

## Installation

You can install directly from Github:

``` r
devtools::install_github(repo = "mrc-ide/variantstring@1.8.2")
```

Note the use of the @ symbol to reference a specific tagged version.
This is highly recommended as the package is still in development and
backwards compatibility is not guaranteed. See the end of this page for
the most recent version number.

## Variant string format

A variant string is a character string that follows these rules:

#### 1. Gene name, locus, and amino acid are separated by :

For example, the string `pfcrt:72:C` specifies that in the *pfcrt* gene
at the 72nd codon position we observed the amino acid C (Cysteine).

Gene names may contain English letters (uppercase or lowercase), digits
(0-9), hyphens, underscores and periods, but the first character must be
a letter. Positions are integers starting from 1. Amino acids must
follow the [IUPAC single-letter
format](https://megasoftware.net/web_help_11/IUPAC_Single_Letter_Codes.htm).

An optional fourth element is the read count, for example
`pfcrt:72:C:50` specifies that 50 reads were observed of this variant.
If present, read counts are used in variant matching functions to
estimate within-sample genotype frequencies in polyclonal samples. Read
counts cannot be zero - if an allele was not observed it should simply
be left out.

#### 2. Loci are separated by \_

For example, `pfcrt:72_73:C_V` specifies that at codon 72 a C (Cysteine)
was observed, and at codon 73 a V (Valine) was observed. Codon positions
must be in increasing numerical order. There is no limit to the number
of loci that are allowed.

Underscores can be omitted between amino acids to give a more concise
notation, for example `pfcrt:72_73:CV` is equivalent to
`pfcrt:72_73:C_V`. However, underscores cannot be omitted between codon
positions.

If read counts are present then these must correspond to each of the
codon positions, for example `pfcrt:72_73:CV:50_55`.

#### 3. Unphased mixed calls are indicated by /

For example, `pfcrt:72:C/S` specifies that both C (Cysteine) and S
(Serine) were observed at codon 72.

Any number of alleles can be present in a heterozygous locus, for
example `pfcrt:72:C/S/A` specifies a tri-allelic site where A (Alanine)
was observed alongside C and S.

Heterozygous calls can be found over multiple loci, for example
`pfcrt:72_73:C/S/A_V/A`. The number of alleles does not need to be
consistent over loci, for example here there are three alleles at
position 72 and two alleles at position 73.

When read counts are present, the counts for each allele must mirror the
format of the amino acids. For example,
`pfcrt:72_73:C/S/A_V/A:60/30/10_45/55` is a valid string that specifies
read counts of {C=60, S=30, A=10} at codon 72 and {V=45, A=55} at codon
73.

#### 4. Phased mixed calls are indicated by \|

For example, `pfcrt:72_73:C|S_V|A` is a valid string. Here, the order in
which amino acids are listed applies over loci, meaning C goes with V
and S goes with A. This differs from the unphased variant
`pfcrt:72_73:C/S_V/A` in which we cannot be certain which amino acids go
together.

All phased heterozygous loci must contain the same number of alleles.
For example, `pfcrt:72_73:C|S|A_V|A` is **not** a valid variant string
because we cannot link three phased alleles at locus 72 with two phased
alleles at locus 73. If needed, the same amino acid can be repeated, for
example `pfcrt:72_73:C|S|A_V|A|A` is a valid variant string specifying
the phased genotypes C-\>V, S-\>A, and A-\>A within a single sample.

Phased and unphased loci can be combined. For example,
`pfcrt:72_73_74:C|S_V|A_M/I` indicates that C-\>V and S-\>A are phased
across codons 72 and 73, but at codon 74 we only know that amino acids M
(Methionine) and I (Isoleucine) were observed and not how these relate
to the phased haplotypes.

Although the number of alleles must be consistent over all phased loci,
it does not have to be consistent between phased and unphased loci. For
example `pfcrt:72_73_74:C|S_V|A_M/I/A` is a valid string despite having
two phased and three unphased alleles.

Phased and unphased alleles cannot be combined within a single locus.
For example, `pfcrt:72:C|S/A` is **not** a valid string. This type of
partial phasing can arise in real data, but unfortunately cannot be
encoded in variant string format.

Finally, if read counts are present they must mirror the format of the
amino acids. For example
`pfcrt:72_73_74:C|S_V|A_M/I/A:40|60_40|60_20/30/50` is a valid string.

#### 5. Genes are separated by ;

For example, `pfcrt:72:C;pfmdr-1:86:Y` specifies that in the *pfcrt*
gene at codon 72 a C was observed, and in the *pfmdr-1* gene at codon 86
a Y was observed. In this way, multi-locus genotypes can be encoded
spanning different parts of the genome, including over different
chromosomes.

There is no limit to the number of genes that can be encoded. The order
of gene names does not matter as genes are first sorted alphabetically
before applying any manipulation functions. However, the same gene name
cannot be repeated multiple times.

All of the rules above apply between genes just the same as within
genes. For example, `pfcrt:72_73:C|S_V|A:40|60_40|60;mdr-1:86:N|Y:30|70`
is a valid variant string specifying two phased genotypes over two
genes, with read counts at each locus.

## Basic functionality

Here, we demonstrate some of the ways that variant strings can be
manipulated to produce useful quantities.

### Extracting component genotypes

Imagine we start with the following data set:

``` r
data_string <- c("dhps:437:G",
                 "dhps:437_540:G_K",
                 "dhps:437_540:G_K/E",
                 "dhps:437_540:A/G_K/E")
```

All of these samples were successfully sequenced at *dhps* locus 437,
and some were also sequenced at locus 540. Some contain heterozygous
calls while others contain only homozygous calls.

Our first question might be; **what unique genotypes are present within
this dataset?**

- The first two samples have no heterozygous sites, meaning we can be
  certain that both `dhps:437:G` and `dhps:437_540:G_K` are present in
  the data.
- The third sample is interesting because there is a heterozygous site
  (540 K/E), but we can still work out the two genotypes that make up
  this sample. These are `dhps:437_540:G_K` and `dhps:437_540:G_E`.
- The fourth sample contains two heterozygous sites, meaning **it is no
  longer possible to establish which genotypes make up this sample**. It
  could be composed of `A_K` coming together with `G_E`, or by `A_E`
  coming together with `G_K`, or by some combination of these.

In code, we can use the `get_component_variants()` function:

``` r
get_component_variants(data_string)
#> [[1]]
#> [1] "dhps:437:G"
#> 
#> [[2]]
#> [1] "dhps:437_540:G_K"
#> 
#> [[3]]
#> [1] "dhps:437_540:G_K" "dhps:437_540:G_E"
#> 
#> [[4]]
#> [1] NA
```

This returns the component genotypes of each sample. The fourth sample
returns `NA` because we cannot unambiguously work out the component
genotypes.

### Matching variants

Now that we know what genotypes can be unambiguously defined from the
data, we may want to match these back against the data. Starting with
the first genotype `dhps:437:G`:

``` r
compare_variant_string(target_string = "dhps:437:G",
                       comparison_strings = data_string)
#>   match ambiguous prop
#> 1  TRUE     FALSE    1
#> 2  TRUE     FALSE    1
#> 3  TRUE     FALSE    1
#> 4  TRUE     FALSE   NA
```

The `match` column tells us the 437G mutation is present in all four
samples. The `ambiguous` column tells us that none of these matches are
ambiguous, i.e. we can be completely confident the target is present in
the sample.

Looking at the `proportions` column, the target genotype makes up 100%
of the within-sample genotype frequency (WSGF) of the first three
samples. For the fourth sample we cannot know the WSGF because the data
are heterozygous `A/G` at this locus and no read count information was
given to inform the relative balance of these alleles.

Moving on to the second target genotype:

``` r
compare_variant_string(target_string = "dhps:437_540:G_K",
                       comparison_strings = data_string)
#>   match ambiguous prop
#> 1 FALSE     FALSE    0
#> 2  TRUE     FALSE    1
#> 3  TRUE     FALSE   NA
#> 4  TRUE      TRUE   NA
```

There is no match against the first sample because this only contains
information at the 437 locus, and the target genotype requires a match
at both 437 and 540. The second sample is an exact match at both loci.
The third sample is a match, but we cannot know the WSGF because once
again there is a heterozygous locus.

The fourth sample is an **ambiguous match**. It is possible that target
genotype `dhps:437_540:G_K` is present in this sample
(`dhps:437_540:A/G_K/E`), however it is also possible that this genotype
is not present. There is no way around this without using other forms of
data to phase the genotypes.

Finally, moving on to the third target genotype:

``` r
compare_variant_string(target_string = "dhps:437_540:G_E",
                       comparison_strings = data_string)
#>   match ambiguous prop
#> 1 FALSE     FALSE    0
#> 2 FALSE     FALSE    0
#> 3  TRUE     FALSE   NA
#> 4  TRUE      TRUE   NA
```

This genotype is a definite match against the third sample. It is also
an ambiguous match against the fourth sample.

### Matching positions and calculating prevalence

The examples above allow us to calculate the numerator in a prevalence
calculation. However, we also need to know the correct denominator. For
this, we need to know which samples were successfully sequenced at the
same positions, irrespective of the amino acids observed.

We can do this using **position strings**, which are simply variant
strings with the amino acids and read counts stripped away. We can get
these directly from the data:

``` r
position_from_variant_string(data_string) |>
  unique()
#> [1] "dhps:437"     "dhps:437_540"
```

Now we can use the `compare_position_string()` function to look for
matches in terms of positions only. Starting with the first string:

``` r
compare_position_string(target_string = "dhps:437",
                        comparison_strings = data_string)
#> [1] TRUE TRUE TRUE TRUE
```

All four samples contain information about the 437 locus, meaning all
four should be in the denominator of the prevalence calculation.
Combining this with the information above, we can say that the
prevalence of the `dhps:437:G` variant is 4/4 = 100%.

Moving on to the second position string:

``` r
compare_position_string(target_string = "dhps:437_540",
                        comparison_strings = data_string)
#> [1] FALSE  TRUE  TRUE  TRUE
```

This is only present in three samples, meaning the first sample should
be excluded from any prevalence calculation. Combining this with the
results above, we can say that:

- The `dhps:437_540:G_K` variant is present at between 2/3 and 3/3
  samples. The prevalence is in the range 67%-100%.
- The `dhps:437_540:G_E` variant is present at between 1/3 and 2/3
  samples. The prevalence is in the range 50%-67%.

We can see that prevalence calculation is not always straightforward due
to ambiguous matches, and requires a judgement call on how best to use
the data. For example, we could report a range of prevalence as above,
or alternatively we could exclude all samples with heterozygous calls
(aka focussing on monoclonals) to produce an unbiased prevalence
estimate but from a smaller sample. What is **not** valid is to exclude
ambiguous matches, as this risks biasing prevalence estimates downwards.

### Converting to long form

Variant strings are intended to be a convenient format when working with
short genotypes, and to facilitate data entry from e.g. academic papers.
However, there are situations when a long character string becomes
cumbersome and stops being a useful shorthand.

For example, take the string
`pfcrt:72_73_74_75_76:CVIE_K/T:54_34_64_29_54/64;pfmdr-1:86_184:N|Y_Y|F:43|56_64|43`.
This is a valid variant string specifying mutations at the *pfcrt* and
*pfmrd-1* genes, along with read counts. Writing the genotype in this
way is compact, but hard to follow. We can use the `variant_to_long()`
function to unpack this into a long-form data frame:

``` r
variant_to_long("pfcrt:72_73_74_75_76:CVIE_K/T:54_34_64_29_54/64;pfmdr-1:86_184:N|Y_Y|F:43|56_64|43")
#> [[1]]
#>       gene pos n_aa   het phased aa read_count
#> 1    pfcrt  72    1 FALSE  FALSE  C         54
#> 2    pfcrt  73    1 FALSE  FALSE  V         34
#> 3    pfcrt  74    1 FALSE  FALSE  I         64
#> 4    pfcrt  75    1 FALSE  FALSE  E         29
#> 5    pfcrt  76    2  TRUE  FALSE  K         54
#> 6    pfcrt  76    2  TRUE  FALSE  T         64
#> 7  pfmdr-1  86    2  TRUE   TRUE  N         43
#> 8  pfmdr-1  86    2  TRUE   TRUE  Y         56
#> 9  pfmdr-1 184    2  TRUE   TRUE  Y         64
#> 10 pfmdr-1 184    2  TRUE   TRUE  F         43
```

This contains the same information, but may be easier to work with for
some operations. We can always convert back using `long_to_variant()`.

## Release history

The current version is 1.8.2, released 16 April 2025.
