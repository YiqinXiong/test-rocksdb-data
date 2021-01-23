#!/usr/bin/env bash
# Copyright (c) Facebook, Inc. and its affiliates. All Rights Reserved.
# REQUIRE: db_bench binary exists in the current directory

if [ $# -ne 6 ]; then
    echo -n "./benchmark.sh [bulkload/fillseq/updaterandom] [new/old] [num_threads] [db_dir] [output_dir] [auto-tuned?]"
    exit 0
fi

# size constants
K=1024
M=$((1024 * K))
G=$((1024 * M))
W=10000

db_bench_path=./db_bench_$2

db_dir=$4
if [ ! -d "$db_dir" ]; then
    mkdir -p "$db_dir"
fi

echo db_dir="$db_dir"

wal_dir=$db_dir

output_dir=$5
if [ ! -d "$output_dir" ]; then
    mkdir -p "$output_dir"
fi

# all multithreaded tests run with sync=1 unless
# $DB_BENCH_NO_SYNC is defined
DB_BENCH_NO_SYNC=1
syncval="1"
if [ -n "$DB_BENCH_NO_SYNC" ]; then
    echo "Turning sync off for all multithreaded tests"
    syncval="0"
fi

num_threads=$3
# Only for tests that do range scans
cache_size=$((4 * G))
duration=0

num_keys=$((4000 * W))
key_size=20
value_size=400
block_size=$((8 * K))

const_params="\
  --db=$db_dir \
  --wal_dir=$wal_dir \
  \
  --num_levels=6 \
  --key_size=$key_size \
  --value_size=$value_size \
  --block_size=$block_size \
  --cache_size=$cache_size \
  --cache_numshardbits=6 \
  --compression_max_dict_bytes=0 \
  --compression_ratio=0.5 \
  --compression_type=zstd \
  --level_compaction_dynamic_level_bytes=0 \
  --bytes_per_sync=8388608 \
  --cache_index_and_filter_blocks=0 \
  --pin_l0_filter_and_index_blocks_in_cache=1 \
  \
  --write_buffer_size=$((128 * M)) \
  --target_file_size_base=$((128 * M)) \
  --max_bytes_for_level_base=$((512 * M)) \
  --max_bytes_for_level_multiplier=8 \
  \
  --statistics=0 \
  --stats_per_interval=1 \
  --stats_interval_seconds=10 \
  --histogram=1 \
  \
  --open_files=-1 \
  \
  --max_background_jobs=16 \
  --subcompactions=5 \
  --rate_limiter_bytes_per_sec=$((400 * M)) \
  --rate_limiter_auto_tuned=$6 \
  --max_compaction_bytes=$((10 * G))"

l0_config="--level0_file_num_compaction_trigger=4 \
           --level0_stop_writes_trigger=20"

if [ "$duration" -gt 0 ]; then
    const_params="$const_params --duration=$duration"
fi

params_w="$const_params \
          $l0_config \
          --max_write_buffer_number=2 \
          --use_multi_thread_write=1"

params_bulkload="$const_params \
                 --max_write_buffer_number=8 \
                 --allow_concurrent_memtable_write=false \
                 --level0_file_num_compaction_trigger=$((10 * M)) \
                 --level0_slowdown_writes_trigger=$((10 * M)) \
                 --level0_stop_writes_trigger=$((10 * M))"

#
# Tune values for level and universal compaction.
# For universal compaction, these level0_* options mean total sorted of runs in
# LSM. In level-based compaction, it means number of L0 files.
#
params_level_compact="$const_params \
                --max_background_flushes=4 \
                --max_write_buffer_number=4 \
                --level0_file_num_compaction_trigger=4 \
                --level0_slowdown_writes_trigger=16 \
                --level0_stop_writes_trigger=20"

params_univ_compact="$const_params \
                --max_background_flushes=4 \
                --max_write_buffer_number=4 \
                --level0_file_num_compaction_trigger=8 \
                --level0_slowdown_writes_trigger=16 \
                --level0_stop_writes_trigger=20"

function run_bulkload() {
    # This runs with a vector memtable and the WAL disabled to load faster. It is still crash safe and the
    # client can discover where to restart a load after a crash. I think this is a good way to load.
    echo "Bulk loading $num_keys random keys"
    cmd="$db_bench_path --benchmarks=fillrandom \
       --use_existing_db=0 \
       --disable_auto_compactions=1 \
       --sync=0 \
       --num=$num_keys \
       $params_bulkload \
       --threads=1 \
       --memtablerep=vector \
       --disable_wal=1 \
       --seed=$(date +%s) \
       2>&1 | tee -a $output_dir/benchmark_bulkload_fillrandom.log"
    echo "$cmd" | tee "$output_dir"/benchmark_bulkload_fillrandom.log
    eval "$cmd"

    echo "Compacting..."
    cmd="$db_bench_path --benchmarks=compact \
       --use_existing_db=1 \
       --disable_auto_compactions=1 \
       --sync=0 \
       --num=$num_keys \
       $params_w \
       --threads=10 \
       2>&1 | tee -a $output_dir/benchmark_bulkload_compact.log"
    echo "$cmd" | tee "$output_dir"/benchmark_bulkload_compact.log
    eval "$cmd"
}

function run_fillseq() {
    # This runs with a vector memtable. WAL can be either disabled or enabled
    # depending on the input parameter (1 for disabled, 0 for enabled). The main
    # benefit behind disabling WAL is to make loading faster. It is still crash
    # safe and the client can discover where to restart a load after a crash. I
    # think this is a good way to load.

    # Make sure that we'll have unique names for all the files so that data won't
    # be overwritten.
    if [ "$1" == 1 ]; then
        log_file_name=$output_dir/benchmark_fillseq.wal_disabled.v${value_size}.log
    else
        log_file_name=$output_dir/benchmark_fillseq.wal_enabled.v${value_size}.log
    fi

    echo "Loading $num_keys keys sequentially"
    cmd="$db_bench_path --benchmarks=fillseq \
       --use_existing_db=0 \
       --sync=$syncval \
       --num=$num_keys \
       $params_w \
       --min_level_to_compress=0 \
       --threads=$num_threads \
       --disable_wal=$1 \
       2>&1 | grep -v \"... thread\" | tee -a $log_file_name"
    echo "$cmd" | tee "$log_file_name"
    eval "$cmd" >/dev/null 2>&1

}

function run_change() {
    num_keys=$((num_keys/4))
    operation=$1
    echo "Do $num_keys random $operation"
    out_name="benchmark_${operation}.t${num_threads}.s${syncval}.log"
    cmd="$db_bench_path --benchmarks=$operation \
       --use_existing_db=1 \
       --sync=$syncval \
       --num=$num_keys \
       $params_w \
       --threads=$num_threads \
       2>&1 | grep -v \"... thread\" | tee -a $output_dir/${out_name}"
    num_keys=$((num_keys*4))
    echo "$cmd" | tee "$output_dir/${out_name}"
    eval "$cmd" >/dev/null 2>&1
}

function now() {
    date +"%s"
}

schedule="$output_dir/schedule.txt"

echo "===== Benchmark ====="

# Run!!!
IFS=',' read -r -a jobs <<<$1
# shellcheck disable=SC2068
for job in "${jobs[@]}"; do

    if [ "$job" != debug ]; then
        echo "Start $job at $(date) by using $num_threads threads" | tee -a "$schedule"
    fi

    start=$(now)
    if [ "$job" = bulkload ]; then
        run_bulkload
    elif [ "$job" = fillseq_disable_wal ]; then
        run_fillseq 1
    elif [ "$job" = fillseq_enable_wal ]; then
        run_fillseq 0
    elif [ "$job" = updaterandom ]; then
        run_change updaterandom
    else
        echo "unknown job $job"
        exit
    fi
    end=$(now)

    if [ "$job" != debug ]; then
        echo "Complete $job in $((end - start)) seconds" | tee -a "$schedule"
    fi

done
