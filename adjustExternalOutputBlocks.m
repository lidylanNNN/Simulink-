% ============================================
% 步骤3：调整外部输出引线模块坐标（按端口编号排序）
% 根据流程图实现：支持子系统/chart跳过，重叠检测和调整，递归处理
% ============================================
function adjustExternalOutputBlocks(subsystemName)
    % 步骤1：获取子系统位置
    subsystemPos = get_param(subsystemName, 'Position');
    subsystemRight = subsystemPos(3);  % 子系统左侧（用于计算水平坐标）
    
    % 步骤2：获取子系统输出端口句柄
    subsystemHandles = get_param(subsystemName, 'PortHandles');
    outputPortHandles = subsystemHandles.Outport;  % 子系统外的输出接线口
    
    if isempty(outputPortHandles)
        fprintf('  没有输出端口，跳过外部输出模块调整\n');
        return;
    end
    
    numOutputs = length(outputPortHandles);
    fprintf('  找到 %d 个输出接线口\n', numOutputs);
    
    % 步骤3：获取外部输出模块信息（编号、路径、Y坐标、模块类型）
    % 存储格式：{端口编号, 外部模块路径, 连线Y坐标, 模块类型, 连线句柄}
    externalModuleInfo = cell(0, 5);
    
    % 遍历每个输出接线口
    for i = 1:numOutputs
        try
            outputPortHandle = outputPortHandles(i);
            
            % 获取外部输出端口连线句柄
            lineHandles = get_param(outputPortHandle, 'Line');
            
            % 检查是否有连接
            if lineHandles <= 0
                fprintf('  输出接线口 %d 未连接，跳过\n', i);
                continue;
            end
            
            % 从线获取目标端口（可能有多个）
            dstPortHandles = get_param(lineHandles, 'DstPortHandle');
            
            % 处理单个或多个目标端口
            if iscell(dstPortHandles)
                dstPortList = dstPortHandles;
            elseif isscalar(dstPortHandles)
                dstPortList = {dstPortHandles};
            else
                dstPortList = num2cell(dstPortHandles);
            end
            
            % 获取输出接线口的位置（用于计算Y坐标）
            portPos = get_param(outputPortHandle, 'Position');
            connectionY = portPos(2);  % 连线高度（Y坐标）
            
            % 遍历所有目标端口
            for j = 1:length(dstPortList)
                dstPortHandle = dstPortList{j};
                if dstPortHandle > 0
                    % 从目标端口获取外部模块路径
                    externalBlock = get_param(dstPortHandle, 'Parent');
                    
                    % 检查是否在子系统外部
                    if ~startsWith(externalBlock, [subsystemName, '/'])
                        % 获取模块类型
                        try
                            blockType = get_param(externalBlock, 'BlockType');
                        catch
                            blockType = 'Unknown';
                        end
                        
                        % 存储信息：{端口编号, 外部模块路径, 连线Y坐标, 模块类型, 连线句柄}
                        externalModuleInfo{end+1, 1} = i;  % 端口编号
                        externalModuleInfo{end, 2} = externalBlock;  % 模块路径
                        externalModuleInfo{end, 3} = connectionY;  % 连线Y坐标
                        externalModuleInfo{end, 4} = blockType;  % 模块类型
                        externalModuleInfo{end, 5} = lineHandles;  % 连线句柄
                        
                        fprintf('  [端口%d] 找到外部输出模块: %s (类型: %s)\n', i, externalBlock, blockType);
                    end
                end
            end
        catch ME
            warning('处理输出接线口 %d 时出错: %s', i, ME.message);
        end
    end
    
    if isempty(externalModuleInfo)
        fprintf('  没有找到外部输出模块\n');
        return;
    end
    
    fprintf('  共找到 %d 个外部输出模块\n', size(externalModuleInfo, 1));
    
    % 按端口编号排序
    portNums = cell2mat(externalModuleInfo(:, 1));
    [~, sortIdx] = sort(portNums);
    externalModuleInfo = externalModuleInfo(sortIdx, :);
    
    % 步骤4：循环处理每个模块（按流程图逻辑）
    for i = 1:size(externalModuleInfo, 1)
        try
            externalBlock = externalModuleInfo{i, 2};  % 模块路径
            portNum = externalModuleInfo{i, 1};  % 端口编号
            connectionY = externalModuleInfo{i, 3};  % 连线Y坐标
            blockType = externalModuleInfo{i, 4};  % 模块类型
            
            % 判断第i个模块是否为子系统/chart
            isSubsystemOrChart = strcmp(blockType, 'SubSystem') || strcmp(blockType, 'Chart');
            
            % 获取模块当前位置
            currentPos = get_param(externalBlock, 'Position');
            blockHeight = currentPos(4) - currentPos(2);
            blockWidth = currentPos(3) - currentPos(1);
            if isSubsystemOrChart ~= 0
                % 如果是子系统/chart，跳过位置调整（不处理）
                fprintf('  [端口%d] 跳过子系统/chart模块: %s\n', portNum, externalBlock);
                continue;  % 直接进入下一次循环（相当于i+=1）
            else
                % 如果不是子系统/chart，调整模块位置
                % 1. 竖直坐标均值与连线高度相同
                newY = connectionY - blockHeight/2;
                
                % 2. 宽度不变（使用当前宽度）
                % 3. 水平坐标为子系统左侧+150
                newX = subsystemRight + 150;
                
                newPos = [newX, newY, newX + blockWidth, newY + blockHeight];
            end
            
            % 检查第i个模块与第i-1个模块四坐标是否有重叠
            if i > 1
                % 获取第i-1个模块的位置
                prevModule = externalModuleInfo{i-1, 2};
                prevBlockType = externalModuleInfo{i-1, 4};
                
                % 只有当i-1不是子系统/chart时才检查重叠（或者都检查）
                prevPos = get_param(prevModule, 'Position');
                
                % 检查四坐标是否重叠
                if isOverlapping(newPos, prevPos)
                    % 有重叠，调整第i个模块水平坐标为i-1模块左侧+150
                    prevRight = prevPos(3);
                    newX = prevRight + 250;
                    newPos = [newX, newY, newX + blockWidth, newY + blockHeight];
                    
                    fprintf('  [端口%d] 检测到重叠，调整水平位置为i-1模块左侧+150\n', portNum);
                end
            end
            
            % 应用新位置
            set_param(externalBlock, 'Position', newPos);
            fprintf('  ✓ [端口%d] 调整外部输出模块: %s\n', portNum, externalBlock);
            
            % 判断第i个模块是否为output/goto？
            isOutputOrGoto = strcmp(blockType, 'Outport') || strcmp(blockType, 'Goto');
            
            if isOutputOrGoto
                % 如果是output/goto，跳过递归处理
                fprintf('  [端口%d] 跳过output/goto模块，不进行递归处理\n', portNum);
                % 继续下一次循环（相当于i+=1）
            else
                % 如果不是output/goto，递归调用 adjustExternalOutputBlocks(第i个模块)
                % 检查该模块是否为子系统或状态机（可以递归处理）
                try
                    resizeSubsystem(externalBlock);
                    adjustExternalOutputBlocks(externalBlock);
                catch ME
                    warning('递归处理模块 %s 时出错: %s', externalBlock, ME.message);
                end
            end
            
        catch ME
            warning('处理模块 %d 时出错: %s', i, ME.message);
            fprintf('    块路径: %s\n', externalModuleInfo{i, 2});
        end
    end
    
    fprintf('  ✓ 外部输出模块坐标已调整（按端口编号排序）\n');
end

% ============================================
% 辅助函数：检查两个模块的四坐标是否重叠
% 输入：pos1 = [x1, y1, x2, y2], pos2 = [x1, y1, x2, y2]
% 输出：true表示重叠，false表示不重叠
% ============================================
function overlap = isOverlapping(pos1, pos2)
    % 提取坐标
    x1_min = pos1(1);
    y1_min = pos1(2);
    x1_max = pos1(3);
    y1_max = pos1(4);
    
    x2_min = pos2(1);
    y2_min = pos2(2);
    x2_max = pos2(3);
    y2_max = pos2(4);
    
    % 检查是否重叠：两个矩形在X和Y方向都有重叠
    yOverlap = y1_min < y2_max;
    xOverlap = (x1_max+ 300 > x2_min);
    overlap = yOverlap && xOverlap;
end