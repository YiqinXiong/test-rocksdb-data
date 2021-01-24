#! /bin/zsh
echo ***将对应版本db_bench复制到该目录进行测试***
# 参数1：选择新旧版本
if [ $# -ne 3 ]; then
    echo "./easyrun.sh [fillseq_enable_wal,fillseq_disable_wal,bulkload,updaterandom] [new/old] [auto-tuned?]"
    exit 0
fi

tasklist=""
db_bench_dir=../../rocksdb-
thread_array=(8)
db_dir_base=../data/$(date +%m_%d)/$2/$(date +%H_%M)
output_dir_base=../logs/$(date +%m_%d)/$2/$(date +%H_%M)
auto_tuned=$3

if [ "$1" = 1 ]; then
    tasklist=fillseq_enable_wal
elif [ "$1" = 2 ]; then
    tasklist=fillseq_disable_wal
elif [ "$1" = 3 ]; then
    tasklist=bulkload
elif [ "$1" = 4 ]; then
    tasklist=updaterandom
elif [ "$1" = 14 ]; then
    tasklist=fillseq_enable_wal,updaterandom
elif [ "$1" = 24 ]; then
    tasklist=fillseq_disable_wal,updaterandom
elif [ "$1" = 34 ]; then
    tasklist=bulkload,updaterandom
else
    echo "unknown param $1"
    exit
fi

if [ "$2" = new ]; then
    db_bench_dir="$db_bench_dir"cf6a77
elif
    [ "$2" = old ]
then
    db_bench_dir="$db_bench_dir"953f8b
else
    echo "unknown param $2"
    exit
fi

if [ ! -f "./db_bench_$2" ]; then
    cp $db_bench_dir/db_bench ./db_bench_"$2"
fi

sleep 2s
for num_threads in "${thread_array[@]}"; do
    db_dir="$db_dir_base"_t"$num_threads"_a"$auto_tuned"
    output_dir="$output_dir_base"_t"$num_threads"_a"$auto_tuned"
    cmd="./easy.sh $tasklist $2 $num_threads $db_dir $output_dir $auto_tuned"
    eval "$cmd"
done
