# Fireworks Tech Graph - Scripts

辅助脚本集合，用于提高 SVG 图表生成的稳定性和效率。

## 脚本列表

### 1. validate-svg.sh

SVG 验证脚本，检查 SVG 语法并报告详细错误。

**用法：**
```bash
./validate-svg.sh <svg-file>
```

**检查项目：**
- 标签平衡（开标签 vs 闭标签）
- 属性引号完整性
- 特殊字符转义
- Marker 引用完整性
- 闭合标签 `</svg>`
- 渲染验证（若可用则先 cairosvg，否则 rsvg-convert）

**示例：**
```bash
./validate-svg.sh /path/to/diagram.svg
```

### 2. generate-diagram.sh

SVG 图表生成脚本，提供自动验证和 PNG 导出。

**用法：**
```bash
./generate-diagram.sh [OPTIONS]
```

**选项：**
- `-t, --type TYPE` - 图表类型（见脚本帮助）
- `-s, --style STYLE` - 风格编号（1-7，默认：1）
- `-o, --output PATH` - 输出目标（SVG 文件路径，或目录：已存在目录/以 `/` 结尾；默认：当前目录）
- `-w, --width WIDTH` - PNG 宽度（像素，默认：1920）
- `--no-validate` - 跳过验证
- `-h, --help` - 显示帮助

**示例：**
```bash
# 生成架构图（Style 1）
./generate-diagram.sh -t architecture -s 1 -o ./output/arch.svg

# 输出到目录（自动命名为 architecture-style1.svg）
./generate-diagram.sh -t architecture -s 1 -o ./output/

# 生成流程图（Style 2，2400px 宽）
./generate-diagram.sh -t flowchart -s 2 -w 2400
```

**注意：** SVG 内容需要先准备好；这个脚本只负责验证与导出。

### 3. generate-from-template.py

基于风格配置和 JSON 数据生成 SVG。当前版本不再只是简单塞入 `nodes/arrows`，
而是会执行 style guide 中的部分可计算规则，例如：

- `style` - 风格编号（1-7）
- `containers` - 泳道 / 分组容器
- `containers[].header_prefix` / `containers[].header_text` - 工程编号式分区标题
- `containers[].side_label` - 左侧 layer label
- `nodes[].kind` - 语义组件类型，例如 `double_rect`、`cylinder`、`document`、`terminal`、`circle_cluster`
- `arrows[].flow` - 语义箭头类型，例如 `control`、`write`、`read`、`data`
- `source_port` / `target_port` - 指定端口锚点
- `route_points` / `corridor_x` / `corridor_y` - 控制复杂图的走线质量
- `style_overrides` - 对现有 style 做局部覆盖
- `window_controls` / `meta_*` - 顶部终端 chrome
- `blueprint_title_block` - 工程蓝图右下角 title block

**用法：**
```bash
python3 ./generate-from-template.py architecture ./output/arch.svg '{"style":1,"title":"My Diagram","containers":[],"nodes":[],"arrows":[]}'
```

**示例：**
```bash
python3 ./generate-from-template.py memory ./output/mem0.svg '{
  "style": 1,
  "title": "Mem0 Memory Architecture",
  "containers": [
    {"x":30,"y":90,"width":900,"height":90,"label":"Input Layer","header_prefix":"01"}
  ],
  "nodes": [
    {"id":"manager","kind":"double_rect","x":360,"y":220,"width":300,"height":72,"label":"Memory Manager"},
    {"id":"vector","kind":"cylinder","x":90,"y":360,"width":140,"height":110,"label":"Vector Store"}
  ],
  "arrows": [
    {"source":"manager","target":"vector","flow":"write","dashed":true}
  ]
}'
```

### 4. test-all-styles.sh

批量测试脚本，测试 7 种风格的回归样例图。

**用法：**
```bash
./test-all-styles.sh
```

**功能：**
- 检查所有风格的参考文件
- 渲染 `fixtures/*.json` 回归样例
- 验证生成出的 SVG 文件
- 导出 PNG 文件到 `test-output/` 目录
- 生成测试报告

**输出：**
- 测试摘要（通过/失败统计）
- PNG 文件（带时间戳）
- 详细的验证错误信息

**示例：**
```bash
./test-all-styles.sh
```

## 依赖

所有脚本需要至少一个 PNG 渲染器。推荐优先级：

- **rsvg-convert（默认首选）** - 独立二进制，稳定，不依赖 Python 运行时
  ```bash
  brew install librsvg                # macOS
  sudo apt install librsvg2-bin       # Ubuntu/Debian
  ```

- **cairosvg（备选）** - CSS 支持好，但依赖系统 cairo 运行时 + Python 环境
  ```bash
  brew install cairo pango gdk-pixbuf libffi   # macOS
  python -m pip install cairosvg
  ```

- **puppeteer（最高保真）** - 真实 Chromium 渲染，适合复杂 SVG
  ```bash
  npm install puppeteer
  ```

`generate-diagram.sh` 与 `test-all-styles.sh` 已统一为：`rsvg-convert` 优先，`cairosvg` 备选，`puppeteer` 作为更重 fallback。完整对比见 [SKILL.md → SVG → PNG Conversion](../SKILL.md)。

## PNG 导出与渲染器优先级（通用规则）

1. **首选 `rsvg-convert`**
   - 安装：`brew install librsvg`
   - 命令：`rsvg-convert -w 2400 -o output.png input.svg`
   - 适用：本地与 CI 的默认稳定路径
2. **备选 `cairosvg`**
   - 安装：`brew install cairo pango gdk-pixbuf libffi && python -m pip install cairosvg`
   - 命令：`cairosvg input.svg -o output.png --output-width 2400`
   - 说明：仅 `pip install cairosvg` 可能不够，仍需系统 cairo 库
3. **高保真 fallback：`puppeteer` / Chrome**
   - 适合复杂 SVG、中文字体、浏览器一致性要求高的场景
   - 依赖更重，优先用于兜底路径
4. **临时 fallback：`sips` / `qlmanage`**
   - 仅临时使用，不建议作为 CI 或正式导出主路径
   - 可能出现比例、画布、字体或渲染差异

### macOS 注意事项

- Apple Silicon 建议使用 Homebrew 路径（`/opt/homebrew`）。
- 避免混用系统 Python、CommandLineTools Python、项目 `.venv`、用户 site-packages。
- 若 cairosvg 报 `libcairo` 缺失，优先补齐 brew 侧 cairo/librsvg。
- 若系统 Python 仍无法解析 cairo 依赖，不建议全局改 `DYLD_*`；优先改用 `rsvg-convert` 或 Homebrew Python 独立 venv。

- **grep, sed, awk** - 文本处理（macOS 自带）

## 目录结构

```
fireworks-tech-graph/
├── SKILL.md                    # Skill 主文档
├── references/                 # 风格参考文件
│   ├── style-1-flat-icon.md
│   ├── style-2-dark-terminal.md
│   └── ...
├── fixtures/                   # 回归测试样例（JSON）
│   ├── mem0-style1.json
│   ├── tool-call-style2.json
│   └── ...
├── scripts/                    # 辅助脚本（本目录）
│   ├── README.md              # 本文档
│   ├── validate-svg.sh        # SVG 验证
│   ├── generate-diagram.sh    # SVG 验证与 PNG 导出
│   ├── generate-from-template.py # 模板化生成 SVG
│   └── test-all-styles.sh     # 批量测试
└── test-output/               # 测试输出目录（自动创建）
```

## 使用场景

### 场景 1：验证现有 SVG

```bash
cd ~/.claude/skills/fireworks-tech-graph/scripts
./validate-svg.sh /path/to/your-diagram.svg
```

### 场景 2：生成并验证图表

1. 使用 Claude Code 生成 SVG 内容
2. 运行验证和导出：
   ```bash
   ./generate-diagram.sh -t architecture -s 1 -o ./output/arch.svg
   ```

### 场景 3：批量测试所有风格

```bash
cd ~/.claude/skills/fireworks-tech-graph/scripts
./test-all-styles.sh
```

测试脚本会自动：
1. 读取 `../fixtures/*.json`
2. 按 `template_type + style` 调用 `generate-from-template.py`
3. 运行 `validate-svg.sh`
4. 导出 PNG 到 `../test-output/`

查看测试输出：
```bash
ls -lh ../test-output/
```

## 故障排除

### 问题：找不到 PNG 渲染器

**解决方案（按优先级）：**
```bash
brew install librsvg                   # 推荐首选（macOS）
sudo apt install librsvg2-bin          # Ubuntu/Debian
brew install cairo pango gdk-pixbuf libffi && python -m pip install cairosvg  # 备选
```

### 问题：rsvg-convert 渲染缺框/缺文字

**原因：** rsvg-convert 对 `<foreignObject>`、CSS `filter`、复杂 `<style>` 块支持有限。

**解决方案：** 切换到 cairosvg 或 puppeteer：
```bash
brew install cairo pango gdk-pixbuf libffi
python -m pip install cairosvg
```
脚本默认优先用 rsvg-convert；遇到复杂 SVG 可改用 cairosvg。若仍需要像素级还原（例如浏览器生成 SVG），改用 puppeteer（见 SKILL.md）。

### 问题：权限被拒绝

**解决方案：**
```bash
chmod +x *.sh
```

### 问题：SVG 验证失败

**解决方案：**
1. 查看详细错误信息
2. 使用 Edit 工具修复语法错误
3. 重新运行验证

## 开发说明

### 添加新的验证规则

编辑 `validate-svg.sh`，在现有检查项后添加新的检查逻辑：

```bash
# Check N: Your new check
echo -n "Checking something... "
# Your validation logic here
if [ condition ]; then
    echo -e "${GREEN}✓ Pass${NC}"
else
    echo -e "${RED}✗ Fail${NC}"
fi
```

### 扩展支持的图表类型

编辑 `generate-diagram.sh`，在 `--type` 参数处理中添加新类型。

## 版本历史

- **v1.0.0** (2026-04-11) - 初始版本
  - SVG 验证脚本
  - 图表生成脚本
  - 批量测试脚本

## 许可证

MIT License - 与 fireworks-tech-graph skill 相同
