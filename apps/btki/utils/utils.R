library(ggplot2)
library(ggpubr)
library(viridis)

plot_adt_qc <- function(md, cellmd, sample_name = "Sample",
                        base_font_size = 14,
                        title_size = 16,
                        axis_text_size = 12,
                        axis_title_size = 14,
                        legend_text_size = 10,
                        legend_title_size = 12,
                        facet_text_size = 12,
                        bottom_text_size = 12,   # 为兼容，也加上（可不使用）
                        show_legend = TRUE,
                        legend_position = "bottom",
                        class_colors = NULL) {  # 为兼容 RNA 函数结构，也加入（可不使用）


  cellmd <- cellmd %>%
    mutate(across(c(n.gene, rna.size, rna.size.log10, prot.size.log10), as.numeric))
  md <- md %>%
    mutate(across(c(n.gene, rna.size, rna.size.log10, prot.size.log10), as.numeric))

  # 计算 x 和 y 的坐标范围用于统一缩放
  xlim_gene <- range(log10(md$n.gene), na.rm = TRUE)
  ylim_prot <- range(md$prot.size.log10, na.rm = TRUE)

  # 图1：Gene Count vs Protein Size
  p1 <- ggplot(md, aes(x = log10(n.gene), y = prot.size.log10)) +
    geom_bin2d(bins = 80, alpha = 0.8) +
    scale_fill_viridis_c(option = "C") +
    facet_wrap(~drop.class) +
    labs(x = "log10(Number of genes)", y = "Protein size", fill = "Cell count", title = "Gene Count vs Protein Size") +
    theme_bw(base_size = base_font_size) +
    theme(
      legend.position = if (show_legend) legend_position else "none",
      legend.text = element_text(size = legend_text_size),
      legend.title = element_text(size = legend_title_size),
      strip.background = element_rect(fill = "grey90"),
      strip.text = element_text(face = "bold", size = facet_text_size),
      plot.title = element_text(hjust = 0.5, face = "bold", size = title_size),
      axis.text = element_text(size = axis_text_size),
      axis.title = element_text(size = axis_title_size)
    )

  p1_singled <- ggplot(cellmd, aes(x = log10(n.gene), y = prot.size.log10)) +
    geom_bin2d(bins = 80, alpha = 0.8) +
    scale_fill_viridis_c(option = "C") +
    facet_wrap(~cell) +
    labs(x = "log10(Number of genes)", y = "Protein size", fill = "Singlet count", title = "Gene Count vs Protein Size") +
    theme_bw(base_size = base_font_size) +
    theme(
      legend.position = if (show_legend) legend_position else "none",
      legend.text = element_text(size = legend_text_size),
      legend.title = element_text(size = legend_title_size),
      strip.background = element_rect(fill = "grey90"),
      strip.text = element_text(face = "bold", size = facet_text_size),
      plot.title = element_text(hjust = 0.5, face = "bold", size = title_size),
      axis.text = element_text(size = axis_text_size),
      axis.title = element_text(size = axis_title_size)
    ) +
    coord_cartesian(xlim = xlim_gene, ylim = ylim_prot)

  p1_combined <- ggarrange(p1, p1_singled, ncol = 2, widths = c(3, 2))

  # 图2：RNA Size vs Protein Size
  xlim_rna <- range(md$rna.size.log10, na.rm = TRUE)

  p2 <- ggplot(md, aes(x = rna.size.log10, y = prot.size.log10)) +
    geom_bin2d(bins = 80, alpha = 0.8) +
    scale_fill_viridis_c(option = "C") +
    facet_wrap(~drop.class) +
    labs(x = "log10(RNA size)", y = "Protein size", fill = "Cell count", title = "RNA Size vs Protein Size") +
    theme_bw(base_size = base_font_size) +
    theme(
      legend.position = if (show_legend) legend_position else "none",
      legend.text = element_text(size = legend_text_size),
      legend.title = element_text(size = legend_title_size),
      strip.background = element_rect(fill = "grey90"),
      strip.text = element_text(face = "bold", size = facet_text_size),
      plot.title = element_text(hjust = 0.5, face = "bold", size = title_size),
      axis.text = element_text(size = axis_text_size),
      axis.title = element_text(size = axis_title_size)
    )

  p2_singled <- ggplot(cellmd, aes(x = rna.size.log10, y = prot.size.log10)) +
    geom_bin2d(bins = 80, alpha = 0.8) +
    scale_fill_viridis_c(option = "C") +
    facet_wrap(~cell) +
    labs(x = "log10(RNA size)", y = "Protein size", fill = "Singlet count", title = "RNA Size vs Protein Size") +
    theme_bw(base_size = base_font_size) +
    theme(
      legend.position = if (show_legend) legend_position else "none",
      legend.text = element_text(size = legend_text_size),
      legend.title = element_text(size = legend_title_size),
      strip.background = element_rect(fill = "grey90"),
      strip.text = element_text(face = "bold", size = facet_text_size),
      plot.title = element_text(hjust = 0.5, face = "bold", size = title_size),
      axis.text = element_text(size = axis_text_size),
      axis.title = element_text(size = axis_title_size)
    ) +
    coord_cartesian(xlim = xlim_rna, ylim = ylim_prot)

  p2_combined <- ggarrange(p2, p2_singled, ncol = 2, widths = c(3, 2))

  # 总图合并
  p_adt_qc <- ggarrange(p1_combined, p2_combined, ncol = 1, nrow = 2,
                        labels = c("A", "B"),
                        common.legend = TRUE,
                        legend = legend_position)

  # 添加标题
  p_adt_qc <- annotate_figure(p_adt_qc,
                              top = text_grob(sample_name, face = "bold", size = title_size))

  return(p_adt_qc)
}




library(ggplot2)
library(ggpubr)
library(dplyr)
library(tidyr)
library(ggpmisc)  # 用于 stat_cor

plot_rna_qc <- function(cellmd, sample_name = "Sample",
                        base_font_size = 14,
                        title_size = 16,
                        axis_text_size = 12,
                        axis_title_size = 14,
                        legend_text_size = 10,
                        legend_title_size = 12,
                        facet_text_size = 12,     # 为兼容 ADT 函数结构，也加入（可不使用）
                        bottom_text_size = 12,
                        show_legend = TRUE,
                        legend_position = "bottom",
                        class_colors = c("singlet" = "#e23c4b", "doublet" = "#9cd0f4")) {

  # Violin plots + Scatter plots before and after QC

  ## ------------------ Before QC ------------------
  cellmd <- cellmd %>%
    mutate(across(c(n.gene, rna.size, mt.prop, ery.prop, ribo.prop), as.numeric))

  df_before <- cellmd
  cellmd_long_before <- df_before %>%
    pivot_longer(
      cols = c(n.gene, rna.size, mt.prop, ery.prop, ribo.prop),
      names_to = "feature",
      values_to = "value"
    ) %>%
    mutate(feature = factor(feature, levels = c("n.gene", "rna.size", "mt.prop", "ery.prop", "ribo.prop")))

  # Violin plot
  p_violin_before <- ggplot(cellmd_long_before, aes(x = scDblFinder.class, y = value, fill = scDblFinder.class)) +
    geom_violin(trim = FALSE) +
    facet_wrap(~feature, scales = "free_y", nrow = 1) +
    scale_fill_manual(values = class_colors) +
    labs(title = paste0(sample_name, ": Before QC"), x = "", y = "") +
    theme_bw(base_size = base_font_size) +
    theme(
      legend.position = if (show_legend) legend_position else "none",
      strip.text = element_text(face = "bold", size = axis_text_size),
      plot.title = element_text(hjust = 0.5, face = "bold", size = title_size),
      axis.text = element_text(size = axis_text_size),
      axis.title = element_text(size = axis_title_size)
    )

  # Scatter plot
  p_scatter_before <- ggplot(df_before, aes(x = rna.size, y = n.gene, color = scDblFinder.class)) +
    geom_point(alpha = 0.6, size = 1) +
    scale_color_manual(values = class_colors) +
    labs(title = "nCount_RNA vs nFeature_RNA", x = "nCount_RNA (rna.size)", y = "nFeature_RNA (n.gene)", color = "Class") +
    theme_bw(base_size = base_font_size) +
    theme(
      legend.position = if (show_legend) legend_position else "none",
      legend.text = element_text(size = legend_text_size),
      legend.title = element_text(size = legend_title_size),
      plot.title = element_text(hjust = 0.5, face = "bold", size = title_size),
      axis.text = element_text(size = axis_text_size),
      axis.title = element_text(size = axis_title_size)
    ) +
    stat_cor(method = "pearson", label.x.npc = "left", label.y.npc = "top")

  # 合并前QC图
  plot_beforeQC <- ggarrange(p_violin_before, p_scatter_before, widths = c(2, 1))

  # 计算 cell 数量
  cell_counts <- table(df_before$scDblFinder.class)
  singlet_count <- cell_counts["singlet"]
  doublet_count <- cell_counts["doublet"]
  bottom_text_before <- paste0("Total cells: ", nrow(df_before),
                               " | Singlets: ", singlet_count,
                               " | Doublets: ", doublet_count)

  plot_beforeQC <- annotate_figure(plot_beforeQC,
                                    bottom = text_grob(bottom_text_before,
                                                       hjust = 0.5,
                                                       x = 0.5,
                                                       y = 1,
                                                       size = bottom_text_size))


  ## ------------------ After QC ------------------
  df_after <- cellmd %>%
    filter(cell %in% c("qualitifed singlet", "qualified singlet"))

  cellmd_long_after <- df_after %>%
    pivot_longer(
      cols = c(n.gene, rna.size, mt.prop, ery.prop, ribo.prop),
      names_to = "feature",
      values_to = "value"
    ) %>%
    mutate(feature = factor(feature, levels = c("n.gene", "rna.size", "mt.prop", "ery.prop", "ribo.prop")))

  # Violin plot
  p_violin_after <- ggplot(cellmd_long_after, aes(x = scDblFinder.class, y = value, fill = scDblFinder.class)) +
    geom_violin(trim = FALSE) +
    facet_wrap(~feature, scales = "free_y", nrow = 1) +
    scale_fill_manual(values = class_colors) +
    labs(title = paste0(sample_name, ": After QC"), x = "", y = "") +
    theme_bw(base_size = base_font_size) +
    theme(
      legend.position = if (show_legend) legend_position else "none",
      strip.text = element_text(face = "bold", size = axis_text_size),
      plot.title = element_text(hjust = 0.5, face = "bold", size = title_size),
      axis.text = element_text(size = axis_text_size),
      axis.title = element_text(size = axis_title_size)
    )

  # Scatter plot
  p_scatter_after <- ggplot(df_after, aes(x = rna.size, y = n.gene, color = scDblFinder.class)) +
    geom_point(alpha = 0.6, size = 1) +
    scale_color_manual(values = class_colors) +
    labs(title = "nCount_RNA vs nFeature_RNA", x = "nCount_RNA (rna.size)", y = "nFeature_RNA (n.gene)", color = "Class") +
    theme_bw(base_size = base_font_size) +
    theme(
      legend.position = if (show_legend) legend_position else "none",
      legend.text = element_text(size = legend_text_size),
      legend.title = element_text(size = legend_title_size),
      plot.title = element_text(hjust = 0.5, face = "bold", size = title_size),
      axis.text = element_text(size = axis_text_size),
      axis.title = element_text(size = axis_title_size)
    ) +
    stat_cor(method = "pearson", label.x.npc = "left", label.y.npc = "top")

  # 合并后QC图
  plot_afterQC <- ggarrange(p_violin_after, p_scatter_after, widths = c(2, 1))

  bottom_text_after <- paste0("Qualified cells: ", nrow(df_after), " (100% singlets)")
  plot_afterQC <- annotate_figure(plot_afterQC,
                                   bottom = text_grob(bottom_text_after,
                                                      hjust = 0.5,
                                                      x = 0.5,
                                                      y = 1,
                                                      size = bottom_text_size))

  ## ------------------ Combine All ------------------
  plot_qc <- ggarrange(plot_beforeQC, plot_afterQC, nrow = 2)

  return(plot_qc)
}
