function arrangeSubsystem(subsystemName)
    % 如果没有提供子系统名称，使用当前选中的块
    if nargin < 1 || isempty(subsystemName)
        subsystemName = gcb;
        if isempty(subsystemName)
            error('请先选中一个子系统，或提供子系统路径');
        end
    end
    
    fprintf('========================================\n');
    fprintf('开始整理子系统: %s\n', subsystemName);
    fprintf('========================================\n');
    
    % 步骤1：检查是否为子系统或状态机
    try
        blockType = get_param(subsystemName, 'BlockType');
        if ~strcmp(blockType, 'SubSystem') && ~strcmp(blockType, 'Chart')
            error('指定的路径不是子系统或状态机！');
        end
    catch ME
        error('无法访问指定的路径: %s\n错误信息: %s', subsystemName, ME.message);
    end
    
    % 步骤1.5：统计有效输入/输出线数
    fprintf('\n[步骤0] 统计有效输入/输出线数...\n');
    result = countEffectiveIOLines(subsystemName, 5);
    
    % 步骤2：调节子系统大小
    fprintf('\n[步骤1] 调节子系统大小...\n');
    limitSpecialBlocksHeight(bdroot, 15);
    resizeSubsystem(subsystemName, result.nIn, result.nOut);
    
    % 步骤3：调整外部输入引线模块坐标
    fprintf('\n[步骤2] 调整外部输入引线模块坐标...\n');
    adjustExternalInputBlocks(subsystemName);
    
    % 步骤4：调整外部输出引线模块坐标
    fprintf('\n[步骤3] 调整外部输出引线模块坐标...\n');
    adjustExternalOutputBlocks(subsystemName);
    % 步骤5：收尾 —— 调整 scope/goto/output
    % cleanupExtraScopesGoto(subsystemName, result);
    fprintf('\n========================================\n');
    fprintf('子系统整理完成！\n');
    fprintf('========================================\n');
end