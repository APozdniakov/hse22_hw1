#!/usr/bin/env bash

# создаем символические ссылки в папке symlinks
mkdir -p symlinks
find /usr/share/data-minor-bioinf/assembly/* -print0 | xargs -0 -I '{}' ln -s --force --target_directory symlinks '{}'

function run_seqtk() {
  # 1. аргумент -- откуда брать данные
  # 2. аргумент -- кол-во чтений
  # 3. аргумент -- куда класть результат
  seqtk sample -s 726 "$1" "$2" > "$3"
}

# запускаем seqtk sample и сохраняем результат в папку input
mkdir -p input
run_seqtk symlinks/oil_R1.fastq 5000000 input/paired_end_1.fastq
run_seqtk symlinks/oil_R2.fastq 5000000 input/paired_end_2.fastq
run_seqtk symlinks/oilMP_S4_L001_R1_001.fastq 1500000 input/mate_pairs_1.fastq
run_seqtk symlinks/oilMP_S4_L001_R2_001.fastq 1500000 input/mate_pairs_2.fastq

function create_report() {
  mkdir -p "$2" "$2"_fastqc
  find "$1"/* -print0 | xargs -0 -I '{}' fastqc {} --quiet -o "$2"_fastqc
  multiqc "$2"_fastqc -o "$2"
  rm -rf "$2"_fastqc
}

# создание отчета для исходных чтений
create_report input report_for_initial

# обрезание чтений
platanus_trim input/paired_end_*.fastq 2> /dev/null
platanus_internal_trim input/mate_pairs_*.fastq 2> /dev/null

# создание отчета для обрезанных чтений
create_report input report_for_trimmed

function run_platanus() {
  # сбор контиг
  time platanus assemble  -f "$1" "$2" 2> /dev/null
  # сбор скаффолдов
  time platanus scaffold  -c out_contig.fa   -IP1 "$1" "$2" -OP2 "$3" "$4" 2> /dev/null
  # уменьшение числа промежутков
  time platanus gap_close -c out_scaffold.fa -IP1 "$1" "$2" -OP2 "$3" "$4" 2> /dev/null
}

# запускаем сбор контиг и скаффлодов
run_platanus \
  input/paired_end_1.fastq.trimmed \
  input/paired_end_2.fastq.trimmed \
  input/mate_pairs_1.fastq.int_trimmed \
  input/mate_pairs_2.fastq.int_trimmed

# удаление исходных и подрезанных чтений
rm -rf input
