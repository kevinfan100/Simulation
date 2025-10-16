# Reference / 參考檔案

本資料夾包含參考實作、工具和技術文檔。

## 📖 技術文件

### PDF 文檔
- **Flux_Control_B_oldmodel_merged.pdf** - 舊模型技術文件
- **Flux_Control_R_newmodel.pdf** - 新模型技術文件（R-based）

## 🔧 參考實作

### Model_6_6_Continuous_Weighted.m
早期連續時間系統參考實作
- 6×6 MIMO 系統
- 包含完整測試流程
- 可作為對照參考

### r_controller_page1_exact_final.m
控制器參數計算參考
- 基於 PDF 第 1 頁數學推導
- 參數計算和極點配置

## 🛠️ 開發工具

### generate_simulink_framework.m
Simulink 框架生成工具
- 用於重建或修改系統框架
- 包含 Plant 模型定義
- 信號連接自動化

---

## 使用注意

此資料夾中的檔案為**參考用途**，不建議直接修改。
如需使用，請複製到專案根目錄或適當位置。

---

*最後更新：2025-10-15*
