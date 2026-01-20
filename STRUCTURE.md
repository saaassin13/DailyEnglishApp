# 项目目录结构

## 根目录

```
daily-english-app/
├── android/              # Android平台配置
├── build/                # 构建输出目录
├── english-vocabulary/   # 词库数据
├── lib/                  # 源代码目录
├── scripts/              # 工具脚本
├── UI/                   # UI设计资源
├── pubspec.yaml          # 项目依赖配置
└── README.md             # 项目说明
```

## lib/ 源代码目录

```
lib/
├── main.dart                    # 应用入口
├── models/                      # 数据模型
│   ├── word.dart               # 单词模型
│   ├── wordbook.dart           # 词库模型
│   └── study_record.dart       # 学习记录模型
├── screens/                     # 页面
│   ├── main_screen.dart        # 主页面（底部导航）
│   ├── wordbook_selection_screen.dart  # 词库选择页面
│   ├── study_detail_screen.dart        # 学习详情页面
│   ├── check_in_screen.dart            # 签到页面
│   └── profile_screen.dart             # 个人中心页面
├── services/                     # 业务服务
│   ├── word_service.dart        # 单词服务
│   ├── study_record_service.dart # 学习记录服务
│   ├── settings_service.dart    # 设置服务
│   ├── pronunciation_service.dart # 发音服务
│   └── review_algorithm.dart    # 复习算法
└── utils/                       # 工具类
    └── json_parser.dart         # JSON解析工具
```

## english-vocabulary/ 词库数据

```
english-vocabulary/
├── json/                        # 合并后的词库JSON文件
│   ├── primary.json            # 小学词库
│   ├── middle.json             # 中学词库
│   ├── high.json               # 高中词库
│   ├── cet4.json               # 四级词库
│   ├── cet6.json               # 六级词库
│   ├── kaoyan.json             # 考研词库
│   ├── toefl.json              # 托福词库
│   └── sat.json                # SAT词库
└── json_original/               # 原始词库数据（备份）
```

## scripts/ 工具脚本

```
scripts/
├── clear_android_data.sh       # 清除Android数据
├── clear_data.dart             # 清除学习数据
├── get_vocabulary_count.py     # 统计词库数量
└── quick_clear.sh              # 快速清除脚本
```

## 主要目录说明

### models/
定义应用的核心数据模型，包括单词、词库、学习记录等。

### screens/
包含所有UI页面，使用Flutter Widget构建。

### services/
业务逻辑层，处理数据存储、状态管理、算法计算等。

### utils/
通用工具类，提供JSON解析等辅助功能。

### english-vocabulary/
词库数据存储目录，包含8个预定义词库的JSON文件。

