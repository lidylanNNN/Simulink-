function result = countEffectiveIOLines(subsystemName, maxDepth)
% countEffectiveIOLines  统计子系统的"有效输入/输出线数"
% 中间经过 Bus、OR、AND、DataTypeConversion、Gain、UnitDelay 等时，
% 线束按上游 Inport/From/Constant（输入）和下游 Outport/Goto（输出）来计数。
% 同时保存每个块的类型（BlockType）和父块路径（Parent）
%
% 用法：
%   result = countEffectiveIOLines(gcb);       % 默认深度 5
%   result = countEffectiveIOLines('model/Sub', 5);
%
% 返回值：
%   result.nIn          - 有效输入线数
%   result.nOut         - 有效输出线数
%   result.inputBlocks  - 结构体数组，每个元素包含：
%       .BlockType      - 块类型（'Inport'/'From'/'Constant'）
%       .Parent         - 父块路径
%   result.outputBlocks - 结构体数组，每个元素包含：
%       .BlockType      - 块类型（'Outport'/'Goto'）
%       .Parent         - 父块路径

    if nargin < 1 || isempty(subsystemName)
        subsystemName = gcb;
    end
    if nargin < 2
        maxDepth = 5;
    end
    if isempty(subsystemName)
        error('请先选中一个子系统，或传入子系统路径。');
    end

    h = get_param(subsystemName, 'PortHandles');
    inPorts  = h.Inport;
    outPorts = h.Outport;

    % ===== 输入侧：向上游统计源头 =====
    inputBlocks = {};  % 使用 cell 数组收集块信息
    for k = 1:numel(inPorts)
        visited = containers.Map('KeyType','double','ValueType','logical');
        blocks = collectSourcesFromPort(inPorts(k), 0, maxDepth, visited);
        inputBlocks = [inputBlocks, blocks]; %#ok<AGROW>
    end
    
    % 去重（同一个块可能被多个输入端口追溯到）
    inputBlocks = uniqueBlocks(inputBlocks);
    nIn = length(inputBlocks);
    
    % 转换为结构体数组（修复：直接创建结构体数组）
    if isempty(inputBlocks)
        result.inputBlocks = struct('BlockType', {}, 'Parent', {});
    else
        % 将 {{'Type1', 'Path1'}, {'Type2', 'Path2'}} 转换为结构体数组
        result.inputBlocks = struct('BlockType', {}, 'Parent', {});
        for i = 1:nIn
            result.inputBlocks(i).BlockType = inputBlocks{i}{1};
            result.inputBlocks(i).Parent = inputBlocks{i}{2};
        end
    end

    % ===== 输出侧：向下游统计汇点 =====
    outputBlocks = {};  % 使用 cell 数组收集块信息
    for k = 1:numel(outPorts)
        visited = containers.Map('KeyType','double','ValueType','logical');
        blocks = collectSinksFromPort(outPorts(k), 0, maxDepth, visited);
        outputBlocks = [outputBlocks, blocks]; %#ok<AGROW>
    end
    
    % 去重（同一个块可能被多个输出端口追溯到）
    outputBlocks = uniqueBlocks(outputBlocks);
    nOut = length(outputBlocks);
    
    % 转换为结构体数组（修复：直接创建结构体数组）
    if isempty(outputBlocks)
        result.outputBlocks = struct('BlockType', {}, 'Parent', {});
    else
        % 将 {{'Type1', 'Path1'}, {'Type2', 'Path2'}} 转换为结构体数组
        result.outputBlocks = struct('BlockType', {}, 'Parent', {});
        for i = 1:nOut
            result.outputBlocks(i).BlockType = outputBlocks{i}{1};
            result.outputBlocks(i).Parent = outputBlocks{i}{2};
        end
    end
    
    result.nIn = nIn;
    result.nOut = nOut;

    fprintf('子系统 "%s" 有效输入线数 = %d, 有效输出线数 = %d\n', ...
        subsystemName, nIn, nOut);
    
    % 打印详细信息
    fprintf('\n输入块详情：\n');
    for i = 1:nIn
        fprintf('  [%d] BlockType: %s, Parent: %s\n', ...
            i, result.inputBlocks(i).BlockType, result.inputBlocks(i).Parent);
    end
    
    fprintf('\n输出块详情：\n');
    for i = 1:nOut
        fprintf('  [%d] BlockType: %s, Parent: %s\n', ...
            i, result.outputBlocks(i).BlockType, result.outputBlocks(i).Parent);
    end
end

%% ---------- 辅助：从端口向上游收集源头块信息（输入侧） ----------
function blocks = collectSourcesFromPort(portHandle, depth, maxDepth, visited)
    blocks = {};
    
    if depth >= maxDepth
        return;
    end
    if isKey(visited, portHandle)
        return;
    end
    visited(portHandle) = true;

    line = get_param(portHandle, 'Line');
    if line <= 0
        return;
    end

    srcPort = get_param(line, 'SrcPortHandle');
    if srcPort <= 0
        return;
    end

    blk     = get_param(srcPort, 'Parent');
    blkType = get_param(blk, 'BlockType');   % char

    % 真正的源头：Inport / From / Constant
    sourceTypes = {'Inport','From','Constant'};
    if ismember(blkType, sourceTypes)
        % 获取父块路径
        try
            parent = get_param(blk, 'Parent');
        catch
            parent = 'Unknown';
        end
        blocks{end+1} = {blkType, parent};
        return;    % 到源头就不再往上递归
    end

    % 透明/组合块：Bus、DTC、Gain、UnitDelay、Selector、Logic(AND/OR等)
    transparentTypes = { ...
        'BusCreator','BusSelector','BusAssignment', ...
        'DataTypeConversion','Gain','UnitDelay','Selector','Logic'};

    if ismember(blkType, transparentTypes)
        try
            ph = get_param(blk, 'PortHandles');
            % 检查 ph 是否是结构体，以及是否有 Inport 字段
            if isstruct(ph) && isfield(ph, 'Inport') && ~isempty(ph.Inport)
                inPorts = ph.Inport;
                for q = inPorts   % 多输入各算一根线
                    subBlocks = collectSourcesFromPort(q, depth+1, maxDepth, visited);
                    blocks = [blocks, subBlocks]; %#ok<AGROW>
                end
            end
        catch ME
            % 如果获取 PortHandles 失败，跳过这个块
            warning('无法获取块 %s 的 PortHandles: %s', blk, ME.message);
        end
    end
end

%% ---------- 辅助：从端口向下游收集汇点块信息（输出侧） ----------
function blocks = collectSinksFromPort(portHandle, depth, maxDepth, visited)
    blocks = {};
    
    if depth >= maxDepth
        return;
    end
    if isKey(visited, portHandle)
        return;
    end
    visited(portHandle) = true;

    line = get_param(portHandle, 'Line');
    if line <= 0
        return;
    end

    dstPorts = get_param(line, 'DstPortHandle');
    if iscell(dstPorts)
        nextPorts = [dstPorts{:}];
    else
        nextPorts = dstPorts;
    end

    sinkTypes        = {'Outport','Goto'};
    transparentTypes = { ...
        'BusCreator','BusSelector','BusAssignment', ...
        'DataTypeConversion','Gain','UnitDelay','Selector','Logic'};

    for p = nextPorts
        if p <= 0
            continue;
        end

        blk     = get_param(p, 'Parent');
        blkType = get_param(blk, 'BlockType');   % char

        % 汇点：Outport / Goto
        if ismember(blkType, sinkTypes)
            % 获取父块路径
            try
                parent = get_param(blk, 'Parent');
            catch
                parent = 'Unknown';
            end
            blocks{end+1} = {blkType, parent};
            % 不再从汇点往后递归
            continue;
        end

        % 透明/组合块：继续往下游走
        if ismember(blkType, transparentTypes)
            try
                ph = get_param(blk, 'PortHandles');
                % 检查 ph 是否是结构体，以及是否有 Outport 字段
                if isstruct(ph) && isfield(ph, 'Outport') && ~isempty(ph.Outport)
                    outPorts = ph.Outport;
                    for q = outPorts
                        subBlocks = collectSinksFromPort(q, depth+1, maxDepth, visited);
                        blocks = [blocks, subBlocks]; %#ok<AGROW>
                    end
                end
            catch ME
                % 如果获取 PortHandles 失败，跳过这个块
                warning('无法获取块 %s 的 PortHandles: %s', blk, ME.message);
            end
        end
    end
end

%% ---------- 辅助：去重块信息（基于 Parent 路径） ----------
function uniqueBlocks = uniqueBlocks(blocks)
    if isempty(blocks)
        uniqueBlocks = {};
        return;
    end
    
    % 提取所有 Parent 路径
    parentPaths = cell(size(blocks));
    for i = 1:length(blocks)
        parentPaths{i} = blocks{i}{2};  % Parent 是第二个元素
    end
    
    % 找到唯一的 Parent 路径索引
    [~, uniqueIdx, ~] = unique(parentPaths, 'stable');
    
    % 返回唯一的块
    uniqueBlocks = blocks(uniqueIdx);
end