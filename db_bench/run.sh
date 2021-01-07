#! /bin/bash
date
# db和wal的路径："./test${testVersion}/db"
# rocksdb参数：write_buffer_size，level0_file_num_compaction_trigger，max_background_compactions，max_write_buffer_number
# 测试参数：num，duration，key_size，value_size，report_file
declare -i testVersion=1
# ----------------------------------rocksdb参数-----------------------------------------
declare -i default_write_buffer_size=67108864              # Memtable大小64MB
declare -i default_level0_file_num_compaction_trigger=4    # L0触发compaction的SST文件数目
declare -i default_max_background_compactions=1            # 最大compaction线程数
declare -i default_max_write_buffer_number=2               # 最大Memtable个数
declare -i write_buffer_size=${default_write_buffer_size}
declare -i level0_file_num_compaction_trigger=${default_level0_file_num_compaction_trigger}
declare -i max_background_compactions=${default_max_background_compactions}
declare -i max_write_buffer_number=${default_max_write_buffer_number}
# ----------------------------------db_bench参数----------------------------------------
declare -i default_num=100000000   # 100Mil请求
declare -i default_duration=120    # 最多120秒持续IO
declare -i default_key_size=16     # 16B的key大小
declare -i default_value_size=100  # 100B的value大小

echo "now running test ${testVersion} ......"
# test 1
write_buffer_size=${default_write_buffer_size}
level0_file_num_compaction_trigger=${default_level0_file_num_compaction_trigger}
max_background_compactions=${default_max_background_compactions}
max_write_buffer_number=${default_max_write_buffer_number}
# 顺序写、随机读、随机写、顺序读
~/rocksdb-6.6.4/db_bench \
--benchmarks="fillseq,stats,readrandom,stats,fillrandom,stats,readseq,stats" \
--db="./test${testVersion}/db" \
--wal_dir="./test${testVersion}/db" \
 \
--write_buffer_size=${write_buffer_size} \
--level0_file_num_compaction_trigger=${level0_file_num_compaction_trigger} \
--max_background_compactions=${max_background_compactions} \
--max_write_buffer_number=${max_write_buffer_number} \
 \
--num=${default_num} \
--duration=${default_duration} \
--key_size=${default_key_size} \
--value_size=${default_value_size} \
--report_file="./test${testVersion}/report.csv" \
> ./test${testVersion}/stats.log

testVersion=${testVersion}+1