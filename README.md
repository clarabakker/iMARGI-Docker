# iMARGI-Docker

iMARGI-Docker distributes the iMARGI sequencing data processing pipeline

- [iMARGI-Docker](#imargi-docker)
  - [Description](#description)
  - [Repo Contents](#repo-contents)
  - [Installation Guide](#installation-guide)
    - [Hardware Requirements](#hardware-requirements)
    - [Software Requirements](#software-requirements)
    - [Installation](#installation)
      - [Pull from Docker Hub](#pull-from-docker-hub)
      - [Build with Dockerfile](#build-with-dockerfile)
  - [Software Testing Demo](#software-testing-demo)
    - [Testing Data](#testing-data)
    - [Testing Command](#testing-command)
    - [Testing Results](#testing-results)
      - [Running Time Profile](#running-time-profile)
      - [Expected Result files](#expected-result-files)
  - [License](#license)

## Description

*in situ* MARGI (**iMARGI**) is a sequencing technique to genome-wide determine the potential genomic interaction loci
of Chromatin associated RNAs (caRNAs). To minimize variations in data processing, we developed a complete data
processing pipeline to improve analysis reproducibility by standardizing data processing steps. **iMARGI-Docker**, a
Docker image, was built to perform the data processing pipeline in a more convenient way.

This repo hosts the iMARGI-Docker source code with brief introductions. For more detail of performing the iMARGI data
analysis using iMARGI-Docker, please read our online comprehensive
[**documentation**](https://sysbio.ucsd.edu/imargi_pipeline).

## Repo Contents

- src: source code, such as the Dockerfile of iMARGI-Docker
- data: small chunk of data for testing
- docs: source file of [documentation](https://sysbio.ucsd.edu/imargi_pipeline)

## Installation Guide

### Hardware Requirements

There isn't specific high performance hardware requirements of running iMARGI-Docker. However, as iMARGI generates hugh
amount of sequencing data, usually more than 300 million read pairs, so a high performance computer will save you a lot
of time. Generally, a faster multi-core CPU, larger memory and hard drive storage will benefits you a lot. We suggest
the following specs:

- CPU: at least 4 core CPU
- RAM: at least 16 GB
- Hard drive storage: Depends on your data, typically at least 160 GB is required. Besides, fast IO storage is better,
  such as SSD.

### Software Requirements

iMARGI-Docker only requires Docker. You can use Docker [Community Edition (CE)](https://docs.docker.com/install/) or
[Enterprise Edition (EE)](https://docs.docker.com/ee/). Docker supports all the mainstream OS, such as Linux, Windows
and Mac. For how to install and configure Docker, please read the
[official documentation of Docker](https://docs.docker.com/).

### Installation

#### Pull from Docker Hub

When Docker was installed, it's easy to install iMARGI-Docker by pulling from
[Docker Hub](https://hub.docker.com/r/zhonglab/imargi). It takes about 10 seconds to install, which depends on your
network speed.

``` bash
docker pull zhonglab/imargi
```

#### Build with Dockerfile

We provided all the source code for building iMARGI-Docker in the [`src`](./src/) folder, including Dockerfile and all
the script tools. So you can modify and rebuild your own Docker image. It will take about several minutes to build,
which depends on your computer performance and network speed.

## Software Testing Demo

To test whether you have successfully installed iMARGI-Docker, you can follow instructions below to do a demo test run.

### Testing Data

As real iMARGI sequencing data are always very big, so we randomly extracted a small chunk of real data for software
testing. The data can be found in [`data`](./data/) folder. Please download them to your computer.

Besides, you need to download a human genome reference FASTA file. 
We use the reference genome used by
[4D Nucleome](https://www.4dnucleome.org/) and
[ENCODE project](https://www.encodeproject.org/data-standards/reference-sequences/). The FASTA file of the reference
genome is too large for us to host it in GitHub repo. You can be download it use the link:
[GRCh38_no_alt_analysis_set_GCA_000001405.15](https://www.encodeproject.org/files/GRCh38_no_alt_analysis_set_GCA_000001405.15/@@download/GRCh38_no_alt_analysis_set_GCA_000001405.15.fasta.gz).
It needs to be decompressed using `gunzip -d` command.

We assume that you put the data and reference files in the following directory structure.

``` bash
~/imargi_example
    ├── data
    │   ├── sample_R1.fastq.gz
    │   └── sample_R2.fastq.gz
    ├── output
    └── ref
        └── GRCh38_no_alt_analysis_set_GCA_000001405.15.fasta
```

### Testing Command

We can use one command line to perform the whole pipeline to the testing data.

``` bash
docker run -u 1043 -v ~/imargi_example:/imargi imargi imargi_wrapper.sh \
    -r hg38 \
    -N test_sample \
    -t 4 \
    -g ./ref/GRCh38_no_alt_analysis_set_GCA_000001405.15.fasta \
    -1 ./data/sample_R1.fastq.gz \
    -2 ./data/sample_R2.fastq.gz \
    -o ./output
```

*Tips:*

- `-u 1043`: Run docker with your own UID of your Linux system (use `id` command to check your UID) to avoid file/dir
  permission problem.

- Building bwa index costs the most running time. If you have human genome bwa index built before, you can supply it
  with `-i` argument. See more details in the
  [documentation of command line API section](https://sysbio.ucsd.edu/imargi_pipeline/commandline_api.html#imargi-wrapper-sh)

### Testing Results

#### Running Time Profile

It took about 85 minutes to perform the pipeline. The most of time (75 min) was consumed by building bwa index files.
So once you built the bwa index, supply it to the command with `-i` next time.

Step | Time | Speed up suggestion
---------|----------|----------
Generating chromosome size file | 10 sec | It's fast, but you can supply with `-c` once you've generated it.
Generating bwa index | 75 min | Supply with `-i` once you've built it.
Generating restriction fragment file | 4 min | Supply with `-R` once you've created it.
cleaning | 10 sec | It's fast and not parallelization.
bwa mapping | 2 min | More CPU cores with `-t`.
interaction pair parsing | 1 min | More CPU cores with `-t`.

#### Expected Result files

The output result files are in the folder assign with `-o` argument. The final output `.pairs` format file for further
analysis is `final_test_sample.pairs.gz`. Besides, multiple intermediate output files of each step are in the
`clean_fastq`, `bwa_output`, and `parse_temp` sub-directories of the `output` directory. In addition, the generated
chromosome size file, bwa index folder and restriction fragment BED file are all in the `ref` directory, in which the
reference genome FASTA file is. Here is the final directory structure after completing the pipeline.

``` bash
~/imargi_example/
    ├── data
    │   ├── sample_R1.fastq.gz
    │   └── sample_R2.fastq.gz
    ├── ref
    │   ├── GRCh38_no_alt_analysis_set_GCA_000001405.15.fasta
    │   ├── GRCh38_no_alt_analysis_set_GCA_000001405.15.fasta.fai
    │   ├── chrom.sizes.hg38.txt
    │   ├── AluI_frags.bed.gz
    │   └── bwa_index
    │       ├── bwa_index_hg38.amb
    │       ├── bwa_index_hg38.ann
    │       ├── bwa_index_hg38.bwt
    │       ├── bwa_index_hg38.pac
    │       └── bwa_index_hg38.sa
    └── output
        ├── bwa_output
        │   └── test_sample.bam
        ├── clean_fastq
        │   ├── clean_sample_R1.fastq.gz
        │   └── clean_sample_R2.fastq.gz
        ├── parse_temp
        │   ├── dedup_test_sample.pairs.gz
        │   ├── drop_test_sample.pairs.gz
        │   ├── duplication_test_sample.pairs.gz
        │   ├── sorted_all_test_sample.pairs.gz
        │   ├── stats_dedup_test_sample.txt
        │   └── unmapped_test_sample.pairs.gz
        ├── final_test_sample.pairs.gz
        └── stats_final_test_sample.txt
```

## License

iMARGI-Docker source code is licensed under the [BSD 2 license](./src/LICENSE).