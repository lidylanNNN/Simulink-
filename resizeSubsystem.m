% ============================================
% 步骤1：调节子系统大小
% 宽度150，高度 = n * max(输入引线数, 输出引线数)，n = 20
% 修复：支持状态机对象（无Inport块的情况）
% ============================================
function resizeSubsystem(subsystemName, nIn, nOut)
    % 如果未提供 nIn 和 nOut，则使用默认值（向后兼容）
    if nargin < 2
        nIn = 0;
    end
    if nargin < 3
        nOut = 0;
    end
    
    % 获取块类型
    try
        blockType = get_param(subsystemName, 'BlockType');
    catch ME
        error('无法获取块类型: %s', ME.message);
    end
    
    subsystemHandles = get_param(subsystemName, 'PortHandles');
    inputPortHandles = subsystemHandles.Inport;  % 子系统外的输入接线口
    
    if isempty(inputPortHandles)
        fprintf('  没有输入端口，输入端口数设为0\n');
    end
    
    numInputs = length(inputPortHandles);
    outputPortHandles = subsystemHandles.Outport;  % 子系统外的输出接线口

    if isempty(outputPortHandles)
        fprintf('  没有输出端口，输出端口数设为0\n');
    end

    numOutputs = length(outputPortHandles);
    
    fprintf('  块类型: %s\n', blockType);
    fprintf('  输入端口数: %d\n', numInputs);
    fprintf('  输出端口数: %d\n', numOutputs);
    fprintf('  有效输入线数: %d\n', nIn);
    fprintf('  有效输出线数: %d\n', nOut);
    
    % 计算所需高度：n * max(输入引线数, 输出引线数)
    n = 35;
    maxPorts = max([numInputs, numOutputs, nIn, nOut]);
    
    % 如果端口数为0，设置最小高度
    if maxPorts == 0
        maxPorts = 1;  % 至少1个端口高度
        fprintf('  警告: 未找到端口，使用最小高度\n');
    end
    if maxPorts == 1
        calculatedHeight = 15;
    else
        calculatedHeight = n * maxPorts;
    end
    fprintf('  计算参数: n = %d, max(输入, 输出) = %d\n', n, maxPorts);
    fprintf('  计算高度: %d 像素\n', calculatedHeight);
    
    % 获取当前子系统位置
    currentPos = get_param(subsystemName, 'Position');
    currentX = currentPos(1);
    currentY = currentPos(2);
    
    % 计算新位置：宽度150，高度为计算值
    newHeight = calculatedHeight;
    newPos = [currentX, currentY, currentPos(3), currentY + newHeight];
    
    fprintf('  新高度: %.0f 像素\n', newHeight);
    
    % 应用新位置
    set_param(subsystemName, 'Position', newPos);
    fprintf('  ✓ 子系统大小已调整\n');
end