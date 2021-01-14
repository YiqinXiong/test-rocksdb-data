#!/bin/bash

log_file_name="logFileName"

cmd="./db_bench --benchmarks=fillseq \
       --use_existing_db=0 \
       --sync=0 \
       --min_level_to_compress=0 \
       --threads=10 \
       --memtablerep=vector \
       --allow_concurrent_memtable_write=false \
       --seed=$( date +%s ) \
       2>&1 | grep Compression | tee -a $log_file_name"
echo "$cmd" | tee "$log_file_name"
eval "$cmd" > /dev/null 2>&1