"""Import the approved design tables; run only when updating the design source."""
import json
import pathlib
import re
import sys
import xml.etree.ElementTree as ET
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
NS = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}


def text(element):
    return "".join(node.text or "" for node in element.findall(".//w:t", NS))


def vector(value):
    return [int(number) for number in re.findall(r"-?\d+", value)]


def main(source):
    with zipfile.ZipFile(source) as archive:
        root = ET.fromstring(archive.read("word/document.xml"))
    tables = [
        [[text(cell) for cell in row.findall("w:tc", NS)] for row in table.findall("w:tr", NS)]
        for table in root.findall(".//w:tbl", NS)
    ]
    potions = {}
    templates = []
    fish = []
    for rows in tables:
        if rows[0] == ["等级", "药品", "智慧", "情感", "意志", "分类"]:
            for index, row in enumerate(rows[1:]):
                potions[row[1]] = {
                    "id": f"medicine_{index + 1:02}", "name": row[1],
                    "tier": {"一级": 1, "二级": 2, "三级": 3}[row[0]],
                    "effect": [int(number) for number in row[2:5]], "category": row[5],
                }
        if rows[0] == ["灵魂", "固定缺陷", "示例初值", "推荐用药", "用药后"]:
            for row in rows[1:]:
                start = vector(row[2])
                defect = [-1 if v < lo else 1 if v > hi else 0 for v, lo, hi in zip(start, [6, 7, 4], [8, 9, 7])]
                templates.append({"name": row[0], "defect": defect, "sample": start, "route": row[3].split("→")})
        if rows[0] == ["来源鱼", "原液", "等级", "属性倾向", "本级成品及概率", "升阶成品及概率"]:
            for row in rows[1:]:
                outcomes = []
                for cell in row[4:6]:
                    match = re.search(r"(\d+)%\s*(\S+药)", cell)
                    if match:
                        outcomes.append({"name": match[2], "weight": int(match[1])})
                fish.append({"name": row[0], "essence": row[1], "tier": {"一级": 1, "二级": 2, "三级": 3}[row[2]], "outcomes": outcomes})
    assert len(potions) == 11 and len(templates) == 30 and len(fish) == 11
    data = {"potions": list(potions.values()), "sources": fish, "guests": templates}
    target = ROOT / "data" / "alchemy" / "design.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    lines = ["extends RefCounted", "## Approved fixed medicines, brewing distributions and guest templates.", ""]
    lines.append("const POTIONS := {")
    for drug in potions.values():
        lines.append('\t%s: {"id": %s, "name": %s, "tier": %d, "effect": Vector3i(%s), "category": %s, "reaction": ""},' % (
            json.dumps(drug["id"]), json.dumps(drug["id"]), json.dumps(drug["name"], ensure_ascii=False), drug["tier"],
            ", ".join(map(str, drug["effect"])), json.dumps(drug["category"], ensure_ascii=False)))
    lines.extend(["}", "", "const SOURCES := {"])
    for source in fish:
        outcomes = [[potions[o["name"]]["id"], o["weight"]] for o in source["outcomes"]]
        lines.append('\t%s: {"essence": %s, "tier": %d, "outcomes": %s},' % (
            json.dumps(source["name"], ensure_ascii=False), json.dumps(source["essence"], ensure_ascii=False), source["tier"], json.dumps(outcomes)))
    lines.extend(["}", "", "const GUESTS := ["])
    for guest in templates:
        lines.append('\t{"name": %s, "defect": Vector3i(%s), "sample": Vector3i(%s), "route": %s},' % (
            json.dumps(guest["name"], ensure_ascii=False), ", ".join(map(str, guest["defect"])),
            ", ".join(map(str, guest["sample"])), json.dumps([potions[n]["id"] for n in guest["route"]])))
    lines.extend(["]", ""])
    (ROOT / "scripts" / "systems" / "alchemy_rules.gd").write_text("\n".join(lines), encoding="utf-8")
    print(f"Imported {len(potions)} medicines, {len(fish)} sources, {len(templates)} guests")


if __name__ == "__main__":
    main(sys.argv[1])
