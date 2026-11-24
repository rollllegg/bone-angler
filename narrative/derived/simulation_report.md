# 剧情模拟报告

- 案例：orpheus, wukong
- 世界预设：`world.hades_rampage` 为 false 和 true 各跑一遍。
- 抽样说明：药按正/负/零各抽样一次，叫破按成功/失败各抽样一次；用于验证可达性，不是完整组合数。

## orpheus

- 终端路径：384
- 演出覆盖：7 / 23 个 step，19 条 cue
- 叫破身份：64 / 384
- 迷茫为正：256 / 384

### 结局分布

| 结局 | 路径数 |
| --- | ---: |
| accepted.clear | 32 |
| accepted.confused | 128 |
| accepted.reunion | 32 |
| refused | 192 |

### 选项覆盖

| 选择 | 出现次数 |
| --- | ---: |
| admit | 192 |
| eurydice | 264 |
| lyre | 264 |
| refuse | 192 |
| registry | 264 |

## wukong

- 终端路径：1044
- 演出覆盖：11 / 18 个 step，25 条 cue
- 叫破身份：260 / 1044
- 大闹冥府：1040 / 1044

### 结局分布

| 结局 | 路径数 |
| --- | ---: |
| admitted | 520 |
| calm | 4 |
| refused | 520 |

### 选项覆盖

| 选择 | 出现次数 |
| --- | ---: |
| admit | 520 |
| coin | 784 |
| photo | 784 |
| refuse | 520 |
| staff | 784 |
| tail | 784 |
