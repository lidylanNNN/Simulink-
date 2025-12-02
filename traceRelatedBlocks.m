function traceRelatedBlocks(subsystemName, maxDepth)
% traceRelatedBlocks  从子系统端口出发，在限定高度内打印相关块
%
% 用法：
%   traceRelatedBlocks(gcb, 2);    % 选中子系统后，查看它的相关输入/输出块
%
% 参数：
%   subsystemName : 子系统路径（字符串），例如 'model/Subsystem'
%   maxDepth      : 最大搜索层数（推荐 2）

    if nargin < 1 || isempty(subsystemName)
        subsystemName = gcb;
    end
    if nargin < 2
        maxDepth = 2;
    end

    if isempty(subsystemName)
        error('请先选中一个子系统，或传入子系统路径。');
    end

    fprintf('=== 子系统: %s ===\n', subsystemName);

    h = get_param(subsystemName, 'PortHandles');
    inPorts  = h.Inport;
    outPorts = h.Outport;

    %% 输入侧
    fprintf('\n[输入侧相关块] (高度 ≤ %d)\n', maxDepth);
    inputBlocks = {};

    for k = 1:numel(inPorts)
        visited = containers.Map('KeyType','double','ValueType','logical');
        blocks = walkFromPort_simple(inPorts(k), 'backward', 0, maxDepth, visited);
        inputBlocks = [inputBlocks, blocks]; %#ok<AGROW>
    end

    inputBlocks = unique(inputBlocks);
    for i = 1:numel(inputBlocks)
        fprintf('  - %s (BlockType=%s)\n', ...
            inputBlocks{i}, get_param(inputBlocks{i}, 'BlockType'));
    end

    %% 输出侧
    fprintf('\n[输出侧相关块] (高度 ≤ %d)\n', maxDepth);
    outputBlocks = {};

    for k = 1:numel(outPorts)
        visited = containers.Map('KeyType','double','ValueType','logical');
        blocks = walkFromPort_simple(outPorts(k), 'forward', 0, maxDepth, visited);
        outputBlocks = [outputBlocks, blocks]; %#ok<AGROW>
    end

    outputBlocks = unique(outputBlocks);
    for i = 1:numel(outputBlocks)
        fprintf('  - %s (BlockType=%s)\n', ...
            outputBlocks{i}, get_param(outputBlocks{i}, 'BlockType'));
    end

    fprintf('\n=== 结束 ===\n');
end

function blocks = walkFromPort_simple(portHandle, direction, depth, maxDepth, visited)
% 从某个端口出发，沿着线走，最多 maxDepth 层，返回遇到的块路径列表

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

    if strcmp(direction, 'backward')      % 往“信号源”方向走
        nextPort = get_param(line, 'SrcPortHandle');
        nextPorts = nextPort;
    else                                   % 'forward'，往“信号去向”方向走
        dstPorts = get_param(line, 'DstPortHandle');
        if iscell(dstPorts)
            nextPorts = [dstPorts{:}];
        else
            nextPorts = dstPorts;
        end
    end

    for p = nextPorts
        if p <= 0
            continue;
        end

        blk = get_param(p, 'Parent');
        blkType = get_param(blk, 'BlockType');

        % 记录这个块
        blocks{end+1} = blk; %#ok<AGROW>

        % 透明块：继续往前走一层（可按需增减类型）
        transparentTypes = { ...
            'BusCreator','BusSelector','BusAssignment', ...
            'DataTypeConversion','Gain','UnitDelay','Selector'};

        if any(strcmp(blkType, transparentTypes))
            ph = get_param(blk, 'PortHandles');
            if strcmp(direction, 'backward')
                nextSidePorts = ph.Inport;   % 往前追溯信号源
            else
                nextSidePorts = ph.Outport;  % 往前追踪信号去向
            end
            for q = nextSidePorts
                blocks = [blocks, ...
                    walkFromPort_simple(q, direction, depth+1, maxDepth, visited)]; %#ok<AGROW>
            end
        end
    end
end