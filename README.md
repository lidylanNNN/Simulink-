# Simulink 子系统规范化工具

本工具用于对 Simulink 子系统内外的连线和接口进行自动规范化整理，提升模型可读性和一致性，便于代码审查、调试与适航文档交付。

## 功能概览

- **子系统尺寸自适应**  
  根据有效输入 / 输出线数自动调整子系统高度和宽度。

- **外部输入模块排布**  
  按子系统输入端口编号排序外部输入模块位置，尽量避免交叉线。

- **外部输出模块排布**  
  按子系统输出端口编号排序外部输出模块位置，减少线缠绕。

- **透明模块高度统一**  
  统一 `DataTypeConversion / Gain / UnitDelay / Inport / Outport / Goto / From` 等模块高度，保持视觉整齐。

- **Scope / Goto 收尾整理**  
  对与子系统连线上的 `Scope / Goto / Outport` 进行位置收尾调整，避免远距离“挂线”。

- **有效 IO 统计**  
  统计穿过 Bus、逻辑组合等“透明模块”后的有效输入 / 输出线数，作为尺寸调整依据。

## 目录结构

line_simplify/
  arrangeSubsystem.m            # 主入口：整理选中子系统
  resizeSubsystem.m             # 步骤1：按有效 IO 调整子系统尺寸
  adjustExternalInputBlocks.m   # 步骤2：整理外部输入线与模块
  adjustExternalOutputBlocks.m  # 步骤3：整理外部输出线与模块
  limitSpecialBlocksHeight.m    # 规范常见小块高度
  countEffectiveIOL.m           # 统计有效输入/输出线数并记录块信息
  cleanupExtraScopesGoto.m      # 收尾：调整 Scope/Goto/Outport 位置
  traceRelatedBlocks.m          # 调试辅助：追踪相关块链路## 环境要求

- MATLAB + Simulink（建议 R2020a 及以上）
- 已加载并打开待整理的 Simulink 模型

## 使用方法

1. 将 `line_simplify` 文件夹加入 MATLAB 路径，例如：

  lab
   addpath('d:\learning_file\python\line_simplify');
   2. 在 Simulink 中打开目标模型，**选中需要整理的子系统块**。

3. 在 MATLAB 命令行运行：

 arrangeSubsystem(gcb)即可

## 使用建议

- 建议先在模型副本上试用工具，确认整理效果符合团队建模规范后，再应用到主干分支。
- 对结构极为复杂的模型，可以适当减小 `maxDepth` 参数，以控制递归深度和运行时间。
- 如有内部建模规范，可根据需要调整：
  - 外部模块与子系统之间的水平、竖直间距；
  - 哪些块类型参与高度限制和“透明块”传递；
  - 是否、以及如何自动移动 `Scope / Goto` 等监视模块。
## 效果展示
<img width="720" height="627" alt="image" src="https://github.com/user-attachments/assets/90ee9638-55a5-417f-bd43-9c7cf99923cb" />
<img width="608" height="469" alt="image" src="https://github.com/user-attachments/assets/94cc8fac-51b7-4ac3-b48b-2bec75e5f354" />

