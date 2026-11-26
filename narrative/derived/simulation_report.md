# 剧情模拟报告

- 案例：anubis, orpheus, wukong
- 世界预设：`world.hades_rampage` 为 false 和 true 各跑一遍。
- 抽样说明：药按正/负/零各抽样一次，叫破按成功/失败各抽样一次；用于验证可达性，不是完整组合数。

## anubis

- 终端路径：18
- 演出覆盖：6 / 52 个 step，9 条 cue
- 叫破身份：6 / 18

### 结局分布

| 结局 | 路径数 |
| --- | ---: |
| judged.all | 6 |
| judged.other | 6 |
| judged.zero | 6 |

### 选项覆盖

| 选择 | 出现次数 |
| --- | ---: |
| admit | 18 |
| 称心:0 | 6 |
| 称心:100 | 6 |
| 称心:50 | 6 |

## orpheus

- 终端路径：48
- 演出覆盖：4 / 4 个 step，12 条 cue
- 叫破身份：8 / 48
- 迷茫为正：32 / 48

### 结局分布

| 结局 | 路径数 |
| --- | ---: |
| accepted.clear | 4 |
| accepted.confused | 16 |
| accepted.reunion | 4 |
| refused | 24 |

### 选项覆盖

| 选择 | 出现次数 |
| --- | ---: |
| admit | 24 |
| lyre | 24 |
| refuse | 24 |

## wukong

- 终端路径：84
- 演出覆盖：6 / 6 个 step，17 条 cue
- 叫破身份：20 / 84
- 大闹冥府：80 / 84

### 结局分布

| 结局 | 路径数 |
| --- | ---: |
| admitted | 40 |
| calm | 4 |
| refused | 40 |

### 选项覆盖

| 选择 | 出现次数 |
| --- | ---: |
| admit | 40 |
| photo | 48 |
| refuse | 40 |
| staff | 48 |
