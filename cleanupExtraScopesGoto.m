function cleanupExtraScopesGoto(subsystemName, result)
% cleanupExtraScopesGoto
% 按流程图：
% 1. 遍历 result 中 From / Inport 源模块
% 2. 沿信号方向向前追溯相邻模块
% 3. 追溯结果为单一 → 更新“追溯模块”为该模块，继续
% 4. 追溯结果为多分支：
%    - 先只保留路径仍在选中子系统 subsystemName 这一“条线”上的模块
%    - 若其中包含 Goto / Scope / Outport → 调整这些模块坐标
%    - 再将“追溯模块”更新为另一模块，继续循环
% 5. 遍历完所有 From / Inport 源模块后结束

    fprintf('\n[收尾] 调整与子系统连线上的 scope / goto / output 模块...\n');

    if nargin < 1 || isempty(subsystemName)
        subsystemName = gcb;
    end
    if nargin < 2 || isempty(result) || ~isfield(result, 'inputBlocks')
        fprintf('  未提供有效的 result.inputBlocks，跳过收尾。\n');
        return;
    end
    if isempty(subsystemName)
        error('请先选中一个子系统，或传入子系统路径。');
    end

    inputBlocks = result.inputBlocks;
    if isempty(inputBlocks)
        fprintf('  result.inputBlocks 为空，跳过收尾。\n');
        return;
    end

    % 只处理 BlockType 为 Inport / From 的源块
    for i = 1:numel(inputBlocks)
        blkType = inputBlocks(i).BlockType;
        blkPath = inputBlocks(i).BlockPath;
        if ~ismember(blkType, {'Inport','From'})
            continue;
        end

        fprintf('  [源块%d] %s (类型=%s)\n', i, blkPath, blkType);

        currentBlock = blkPath;     % 当前追溯模块
        maxSteps     = 30;          % 防止死循环
        step         = 0;

        while step < maxSteps
            step = step + 1;

            % 1) 向前追溯相邻模块（顺着信号方向）
            allNextBlocks = findNextBlocksAlongSignal(currentBlock);

            if isempty(allNextBlocks)
                fprintf('    步 %d: 无后续模块，终止该源块追溯。\n', step);
                break;
            end

            % —— 只保留仍然在选中子系统 subsystemName 这一“条线”上的模块 ——
            % 这里用 startsWith 判断：块路径以 "subsystemName/" 开头视为在该子系统层级下
            insideMask = cellfun(@(b) startsWith(b, [subsystemName '/']), allNextBlocks);
            nextBlocks = allNextBlocks(insideMask);

            if isempty(nextBlocks)
                fprintf('    步 %d: 后续模块不在选中子系统内，结束该源块。\n', step);
                break;
            end

            % 2) 判断追溯结果是否“单一”
            if numel(nextBlocks) == 1
                currentBlock = nextBlocks{1};
                fprintf('    步 %d: 单一后续模块 %s，继续追溯。\n', step, currentBlock);
                continue;
            end

            % 3) 追溯结果非单一 → 检查是否包含 Goto / Scope / Outport
            targetIdx = false(size(nextBlocks));
            targetTypes = {'Goto','Scope','Outport'};
            for j = 1:numel(nextBlocks)
                blk = nextBlocks{j};
                try
                    bt = get_param(blk,'BlockType');
                catch
                    bt = 'Unknown';
                end
                if ismember(bt, targetTypes)
                    targetIdx(j) = true;
                end
            end

            if ~any(targetIdx)
                fprintf('    步 %d: 后续模块非单一，但不含 goto/scope/outport，结束该源块。\n', step);
                break;
            end

            % 4) 对这些 Goto / Scope / Outport 调整坐标
            try
                basePos = get_param(currentBlock,'Position');
            catch
                warning('    无法获取当前追溯块 %s 的位置，跳过该源块。', currentBlock);
                break;
            end
            baseRight   = basePos(3);
            baseCenterY = (basePos(2) + basePos(4)) / 2;

            for j = find(targetIdx)
                blk = nextBlocks{j};
                try
                    bt  = get_param(blk,'BlockType');
                    pos = get_param(blk,'Position');
                    h   = pos(4) - pos(2);
                    w   = pos(3) - pos(1);

                    newLeft   = baseRight + 10;
                    newBottom = baseCenterY + 20;
                    newTop    = newBottom - h;

                    newPos = [newLeft, newTop, newLeft + w, newBottom];
                    set_param(blk,'Position',newPos);

                    fprintf('    步 %d: 调整 %s: %s → [%d %d %d %d]\n', ...
                        step, bt, blk, newPos(1), newPos(2), newPos(3), newPos(4));
                catch ME
                    warning('    调整块 %s 位置失败: %s', blk, ME.message);
                end
            end

            % 5) “追溯模块更新为另一模块”：优先选非 Goto/Scope/Outport 的模块
            nextNonTarget = '';
            for j = 1:numel(nextBlocks)
                if targetIdx(j), continue; end
                blk = nextBlocks{j};
                nextNonTarget = blk;
                break;
            end

            if isempty(nextNonTarget)
                fprintf('    步 %d: 没有找到新的非 goto/scope/outport 模块，结束该源块。\n', step);
                break;
            else
                currentBlock = nextNonTarget;
                fprintf('    步 %d: 更新追溯模块为: %s，继续下一轮。\n', step, currentBlock);
            end
        end % while
    end % for

    fprintf('  ✓ 收尾：scope/goto/output 调整完成\n');
end


function nextBlocks = findNextBlocksAlongSignal(blockPath)
% 返回 blockPath 所有输出线连接到的“下一个模块”（可能多个）

    nextBlocks = {};

    try
        ph = get_param(blockPath,'PortHandles');
    catch
        return;
    end
    if ~isstruct(ph) || ~isfield(ph,'Outport') || isempty(ph.Outport)
        return;
    end

    outPorts = ph.Outport;

    for k = 1:numel(outPorts)
        portHandle = outPorts(k);
        try
            lineH = get_param(portHandle,'Line');
        catch
            lineH = -1;
        end
        if lineH <= 0
            continue;
        end

        dstPorts = get_param(lineH,'DstPortHandle');
        if iscell(dstPorts)
            dstPorts = [dstPorts{:}];
        end

        for p = dstPorts
            if p <= 0, continue; end
            blk = get_param(p,'Parent');
            nextBlocks{end+1} = blk; %#ok<AGROW>
        end
    end

    % 展平嵌套 cell，并去重
    if ~isempty(nextBlocks)
        while any(cellfun(@iscell,nextBlocks))
            nextBlocks = vertcat(nextBlocks{:});
        end
        mask = cellfun(@(v) ischar(v) && ~isempty(v), nextBlocks);
        nextBlocks = nextBlocks(mask);
        if ~isempty(nextBlocks)
            nextBlocks = unique(nextBlocks);
        end
    end
end