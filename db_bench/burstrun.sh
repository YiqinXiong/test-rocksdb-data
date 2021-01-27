#! /bin/bash
echo "***将对应版本db_bench复制到该目录进行测试***"
# 参数1：选择新旧版本
if [ $# -ne 2 ]; then
    echo "./burstrun.sh [new/old] [auto-tuned?]"
    exit 0
fi

# size constants
K=1024
M=$((1024 * K))
G=$((1024 * M))
W=10000

cache_size=$((4 * G))

num_keys=$((8000 * W))
key_size=20
value_size=400
block_size=$((8 * K))

db_bench_dir=../../rocksdb-
db_bench_path=./db_bench_

db_dir_base=../data/burstrun/$1
output_dir_base=../logs/burstrun/$1
auto_tuned=$2

if [ "$1" = new ]; then
    db_bench_dir="$db_bench_dir"cf6a77
    db_bench_path="$db_bench_path"new
elif [ "$1" = old ]; then
    db_bench_dir="$db_bench_dir"953f8b
    db_bench_path="$db_bench_path"old
else
    echo "unknown param $1"
    exit
fi

if [ ! -f $db_bench_path ]; then
    cp $db_bench_dir/db_bench $db_bench_path
fi

db_dir="$db_dir_base"_a"$auto_tuned"
if [ ! -d "$db_dir" ]; then
    mkdir -p "$db_dir"
fi

output_dir="$output_dir_base"_a"$auto_tuned"
if [ ! -d "$output_dir" ]; then
    mkdir -p "$output_dir"
fi

log_file_name=$output_dir/benchmark_fillseq.wal_enabled.v${value_size}.log
burst_log_file_name=$output_dir/burst_benchmark_updaterandom.v${value_size}.log
schedule="$output_dir/schedule.txt"

function now() {
    date +"%s"
}

cmd="\
    $db_bench_path \
    --benchmarks=fillseq \
    --use_existing_db=0 \
    --num=$num_keys \
    --db=$db_dir \
    --wal_dir=$db_dir \
    \
    --num_levels=6 \
    --key_size=$key_size \
    --value_size=$value_size \
    --block_size=$block_size \
    --cache_size=$cache_size \
    --level_compaction_dynamic_level_bytes=1 \
    \
    --write_buffer_size=$((128 * M)) \
    --target_file_size_base=$((128 * M)) \
    --max_bytes_for_level_base=$((512 * M)) \
    --max_bytes_for_level_multiplier=8 \
    \
    --statistics=0 \
    --stats_per_interval=1 \
    --stats_interval_seconds=3 \
    --histogram=1 \
    \
    --max_background_jobs=16 \
    --subcompactions=5 \
    --rate_limiter_bytes_per_sec=$((400 * M)) \
    --rate_limiter_auto_tuned=$auto_tuned \
    --max_compaction_bytes=$((10 * G)) \
    \
    --level0_file_num_compaction_trigger=4 \
    \
    --max_write_buffer_number=2 \
    \
    --threads=8 \
    2>&1 | grep -v \"... thread\" | tee -a $log_file_name"

burst_cmd="\
    $db_bench_path \
    --benchmarks=updaterandom \
    --use_existing_db=1 \
    --use_existing_keys=1 \
    --use_secondary_db=1 \
    --db=$db_dir \
    --wal_dir=$db_dir \
    \
    --num_levels=6 \
    --key_size=$key_size \
    --value_size=$value_size \
    --block_size=$block_size \
    --cache_size=$cache_size \
    --level_compaction_dynamic_level_bytes=1 \
    \
    --write_buffer_size=$((128 * M)) \
    --target_file_size_base=$((128 * M)) \
    --max_bytes_for_level_base=$((512 * M)) \
    --max_bytes_for_level_multiplier=8 \
    \
    --statistics=0 \
    --stats_per_interval=1 \
    --stats_interval_seconds=3 \
    --histogram=1 \
    \
    --max_background_jobs=16 \
    --subcompactions=5 \
    --rate_limiter_bytes_per_sec=$((400 * M)) \
    --rate_limiter_auto_tuned=$auto_tuned \
    --max_compaction_bytes=$((10 * G)) \
    \
    --level0_file_num_compaction_trigger=4 \
    \
    --max_write_buffer_number=2 \
    \
    --threads=8 \
    \
    --duration=30 \
    2>&1 | grep -v \"... thread\" | tee -a $burst_log_file_name"

sleep 2s

begin=$(now)
{
    start=$(now)
    echo "$cmd" | tee "$log_file_name"
    eval "$cmd" >/dev/null 2>&1
    end=$(now)
    echo "Complete fillseq in $((end - start)) seconds" | tee -a "$schedule"
} &

for i in 1 2 3 4 5; do
    sleep 60s
    echo ..........running burst_$i..........
    start=$(now)
    echo "Begin burst updaterandom #$i at $((start - begin)) s" | tee -a "$schedule"
    echo "$burst_cmd" | tee "$burst_log_file_name"
    eval "$burst_cmd" >/dev/null 2>&1
    end=$(now)
    echo "End burst updaterandom #$i at $((end - begin)) s" | tee -a "$schedule"
    echo "Complete burst updaterandom #$i in $((end - start)) seconds" | tee -a "$schedule"
done
