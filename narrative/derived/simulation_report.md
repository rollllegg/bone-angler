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

- 终端路径：120
- 演出覆盖：5 / 11 个 step，17 条 cue
- 叫破身份：20 / 120
- 迷茫为正：80 / 120

### 结局分布

| 结局 | 路径数 |
| --- | ---: |
| accepted.clear | 10 |
| accepted.confused | 40 |
| accepted.reunion | 10 |
| refused | 60 |

### 选项覆盖

| 选择 | 出现次数 |
| --- | ---: |
| admit | 60 |
| eurydice | 72 |
| lyre | 72 |
| refuse | 60 |

## wukong

- 终端路径：260
- 演出覆盖：7 / 7 个 step，19 条 cue
- 叫破身份：64 / 260
- 大闹冥府：256 / 260

### 结局分布

| 结局 | 路径数 |
| --- | ---: |
| admitted | 128 |
| calm | 4 |
| refused | 128 |

### 选项覆盖

| 选择 | 出现次数 |
| --- | ---: |
| admit | 128 |
| photo | 176 |
| refuse | 128 |
| staff | 176 |
| tail | 176 |
