#! /bin/bash
echo ***将对应版本db_bench复制到该目录进行测试***
# 参数1：选择新旧版本
if [ $# -ne 2 ]; then
    echo "./easyrun.sh [fillseq_enable_wal,updaterandom,bulkload] [new/old]"
    exit 0
fi

thread_array=(1 2 4 8 16)

if [ "$2" = new ]; then
    rm ./db_bench
    cp ../../rocksdb-cf6a77/db_bench ./db_bench
    sleep 5s
    for num_threads in "${thread_array[@]}"; do
        ./easy.sh "$1" "$2" "$num_threads"
    done
elif
    [ "$2" = old ]
then
    rm ./db_bench
    cp ../../rocksdb-953f8b/db_bench ./db_bench
    sleep 5s
    for num_threads in "${thread_array[@]}"; do
        ./easy.sh "$1" "$2" "$num_threads"
    done
else
    echo "unknown param $2"
    exit
fi
