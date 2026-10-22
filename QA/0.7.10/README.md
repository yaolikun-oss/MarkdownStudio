# Markdown Studio Visual 0.7.10 分隔条修复验证

## 修复

- 拖动区域从 14pt 收窄为 8pt；双箭头光标限定在中间 6pt。
- hitTest 使用 split view 局部坐标，避免容器不在窗口原点时点击/光标区域偏移。
- 分隔条悬停时显示 3pt 浅灰线，离开恢复 1pt 细线。
- 避免无变化时反复重建 hover tracking area，并移除宽区域的 cursorUpdate 光标设置。

## 测试

- `swift test --filter NotebookSplitViewTests`：5 项通过，1 项原生拖动测试按设计在默认并行测试中跳过。
- `MARKDOWN_STUDIO_NATIVE_DRAG_TEST=1 swift test --filter nativeDragStartsBesideTheThinLineAndSavesOnlyAfterRelease`：单独进程原生拖动测试通过；拖动 90pt，尺寸只保存一次。
- 加入非原点父容器测试：确认分隔条两侧 3.5pt 命中，编辑区内 6pt 不误命中。


## 安装包界面复核

在最终 0.7.10 包中依次打开可视化单栏、源码单栏和源码+可视化并排模式：三种内容均正常显示。源码+可视化模式下实际拖动中间分隔条，辅助功能读数由 272 变为 283，左右内容随宽度更新；从分隔条移到源码编辑区后，截图中不再保留双向调整光标。源码区和可视化区分别点击均可聚焦，切换模式后目录及正文正常。复核文档为 /tmp 下自建临时文件。

DMG 的 hdiutil 校验和应用签名验证均通过。SHA-256 见安装包校验结果。
SHA-256: 3048b8d174b0bd8dd8d22250398e17d74213340f52a12cffab306e270707e6c5
