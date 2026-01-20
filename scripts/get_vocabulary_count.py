import os
import json

# 读取english-vocabulary/json_original/json-full
# 将小学、初中、高中、四级、六级、考研、托福、SAT的单词数量分别统计出来

v_map = {
    "PEPXiaoXue3_1": "primary",
    "PEPXiaoXue3_2": "primary",    
    "PEPXiaoXue4_1": "primary",
    "PEPXiaoXue4_2": "primary",
    "PEPXiaoXue5_1": "primary",
    "PEPXiaoXue5_2": "primary",
    "PEPXiaoXue6_1": "primary",
    "PEPXiaoXue6_2": "primary",
    "PEPChuZhong7_1": "middle",
    "PEPChuZhong7_2": "middle",
    "PEPChuZhong8_1": "middle",
    "PEPChuZhong8_2": "middle",
    "PEPChuZhong9_1": "middle",
    "PEPGaoZhong_1": "high",
    "PEPGaoZhong_2": "high",
    "PEPGaoZhong_3": "high",
    "PEPGaoZhong_4": "high",
    "PEPGaoZhong_5": "high",
    "PEPGaoZhong_6": "high",
    "PEPGaoZhong_7": "high",
    "PEPGaoZhong_8": "high",
    "PEPGaoZhong_9": "high",
    "PEPGaoZhong_10": "high",
    "PEPGaoZhong_11": "high",
    "CET4_1": "cet4",
    "CET4_2": "cet4",
    "CET4_3": "cet4",
    "CET6_1": "cet6",
    "CET6_2": "cet6",
    "CET6_3": "cet6",
    "KaoYan_1": "kaoyan",
    "KaoYan_2": "kaoyan",
    "KaoYan_3": "kaoyan",
    "TOEFL_2": "toefl",
    "TOEFL_3": "toefl",
    "SAT_2": "sat",
    "SAT_3": "sat",
}

data_map = {}
for key, value in v_map.items():
    with open(f'english-vocabulary/json_original/json-sentence/{key}.json', 'r') as f:
        data = json.load(f)
        if value not in data_map:
            data_map[value] = []
        # phrases与sentences之保留三个就够了
        for i in data:
            i["phrases"] = i["phrases"][:3]
            i["sentences"] = i["sentences"][:3]
        data_map[value].extend(data)


for key, value in data_map.items():
    with open(f'english-vocabulary/json/{key}.json', 'w') as f:
        print(f"{key} {f.name}, count: {len(value)}")
        json.dump(value, f, ensure_ascii=False)

"""
primary english-vocabulary/json/primary.json, count: 849
middle english-vocabulary/json/middle.json, count: 2320
high english-vocabulary/json/high.json, count: 3877
cet4 english-vocabulary/json/cet4.json, count: 7508
cet6 english-vocabulary/json/cet6.json, count: 5651
kaoyan english-vocabulary/json/kaoyan.json, count: 9602
toefl english-vocabulary/json/toefl.json, count: 13477
sat english-vocabulary/json/sat.json, count: 8887
"""