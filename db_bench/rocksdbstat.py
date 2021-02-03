#!/usr/bin/env python3
import re
import argparse
import os
from itertools import accumulate
import numpy as np
import matplotlib as mpl
import matplotlib.pyplot as plt


class Statistics:
    def __init__(self):
        self.uptime = 'Uptime\(secs\).*?(\d*\.\d*)\stotal'
        self.interval = {
            'name': 'Interval step',
            'regex': 'Uptime\(secs\).*?(\d*\.\d*)\sinterval',
            'suffix': '_intervals'
        }
        self.interval_stall = {
            'name': 'Interval Stall',
            'regex': 'Interval\sstall.*?(\d*\.\d*)\spercent',
            'suffix': '_interval_stall'
        }
        self.cumulative_stall = {
            'name': 'Cumulative Stall',
            'regex': 'Cumulative\sstall.*?(\d*\.\d*)\spercent',
            'suffix': '_cumulative_stall'
        }
        self.interval_writes = {
            'name': 'Interval Writes',
            'regex': 'Interval\swrites.*?(\d*\.\d*)\sMB\/s',
            'suffix': '_interval_writes'
        }
        self.cumulative_writes = {
            'name': 'Cumulative Writes',
            'regex': 'Cumulative\swrites.*?(\d*\.\d*)\sMB\/s',
            'suffix': '_cumulative_writes'
        }
        self.cumulative_compaction = {
            'name': 'Cumulative Compaction',
            'regex': 'Cumulative\scompaction.*?(\d*\.\d*)\sMB\/s',
            'suffix': '_cumulative_compaction'
        }
        self.interval_compaction = {
            'name': 'Interval Compaction',
            'regex': 'Interval\scompaction.*?(\d*\.\d*)\sMB\/s',
            'suffix': '_interval_compaction'
        }

        self.test_name = ''
        self.steps = []
        self.matchs = {}

    def get_matches(self, regex, log):
        regex = re.compile(regex)
        path = os.path.join(os.getcwd(), log)
        with open(path, 'r') as f:
            matches = regex.findall(f.read())
        matches = [ float(x) for x in matches ]
        return matches

    def get_steps(self, regex, log):
        interval_steps = self.get_matches(regex, log)[::2]
        accumulated_steps = list(accumulate(
            [float(step) for step in interval_steps]))
        rounded_steps = [round(step, 2) for step in accumulated_steps]
        return rounded_steps

    def get_all_match(self, log):
        self.base_filename = log.split('.')[0]
        interval_steps = self.get_steps(self.interval['regex'], log)
        uptime_steps = [float(step)
                        for step in self.get_matches(self.uptime, log)[::2]]
        min_interval_step = uptime_steps[0] - interval_steps[0]
        self.steps = [round(step - min_interval_step, 2)
                      for step in uptime_steps]
        self.matchs['interval_stall'] = self.get_matches(
            self.interval_stall['regex'], log)
        self.matchs['cumulative_stall'] = self.get_matches(
            self.cumulative_stall['regex'], log)
        self.matchs['interval_writes'] = self.get_matches(
            self.interval_writes['regex'], log)
        self.matchs['cumulative_writes'] = self.get_matches(
            self.cumulative_writes['regex'], log)
        self.matchs['interval_compaction'] = self.get_matches(
            self.interval_compaction['regex'], log)
        self.matchs['cumulative_compaction'] = self.get_matches(
            self.cumulative_compaction['regex'], log)
        print(self.test_name)
        print(self.steps)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("new_a0", type=str, help="logfile")
    parser.add_argument("new_a1", type=str, help="logfile")
    parser.add_argument("old_a0", type=str, help="logfile")
    parser.add_argument("old_a1", type=str, help="logfile")
    args = parser.parse_args()
    types = ['new_a0', 'new_a1', 'old_a0', 'old_a1']
    tests = ['interval_stall', 'cumulative_stall', 'interval_writes',
             'cumulative_writes', 'interval_compaction', 'cumulative_compaction']
    logs = {'new_a0': args.new_a0, 'new_a1': args.new_a1,
            'old_a0': args.old_a0, 'old_a1': args.old_a1}
    ss = {}
    for t in types:
        if logs[t] != '1':
            s = Statistics()
            s.test_name = t
            s.get_all_match(logs[t])
            ss[t] = s
    print(ss.keys())

    for test in tests:
        # fig, ax = plt.subplots()#创建一个figure 
        plt.title(test)
        for t in ss.keys():
            plt.plot(ss[t].steps, ss[t].matchs[test], label=t)
        plt.legend()
        plt.xlabel('time(s)')
        plt.ylabel('rate(MB/s)')
        plt.grid(True)
        plt.show()
