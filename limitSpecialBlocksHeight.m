function limitSpecialBlocksHeight(root, maxHeight)
% limitSpecialBlocksHeight
% 将模型/子系统内所有指定类型块的高度限制为不超过 maxHeight，且保持质心不变
%
% 用法示例：
%   limitSpecialBlocksHeight('myModel', 30);
%   limitSpecialBlocksHeight(gcs, 30);  % 当前模型
%
% 参数：
%   root      : 模型名或子系统路径，例如 'myModel' 或 'myModel/Subsystem'
%   maxHeight : 允许的最大高度（像素），例如 30

    if nargin < 1 || isempty(root)
        root = gcs;  % 当前模型
    end
    if nargin < 2
        maxHeight = 30;
    end

    % 需要处理的 BlockType 列表
    targetTypes = { ...
        'DataTypeConversion', ...
        'Gain', ...
        'UnitDelay', ...
        'Inport', ...
        'Outport', ...
        'Goto', ...
        'From' ...
    };

    % 统一设置 find_system 选项
    fsOpts = { ...
        'LookUnderMasks', 'all', ...
        'FollowLinks',   'on' ...
    };

    fprintf('在 "%s" 中限制以下类型块高度 ≤ %.0f 像素：\n', root, maxHeight);
    disp(strjoin(targetTypes, ', '));

    for t = 1:numel(targetTypes)
        btype = targetTypes{t};
        % 查找所有该类型块
        blocks = find_system(root, fsOpts{:}, 'BlockType', btype);

        fprintf('  处理 BlockType = %s，找到 %d 个块\n', btype, numel(blocks));

        for i = 1:numel(blocks)
            blk = blocks{i};
            try
                pos = get_param(blk, 'Position');  % [x1 y1 x2 y2]
            catch
                continue;
            end

            x1 = pos(1); y1 = pos(2); x2 = pos(3); y2 = pos(4);
            h  = y2 - y1;

            if h <= maxHeight
                % 已经不超过 maxHeight，无需调整
                continue;
            end

            % 质心（竖直方向中心）
            cy = (y1 + y2) / 2;

            % 新高度为 maxHeight，保持中心不变
            newY1 = cy - maxHeight/2;
            newY2 = cy + maxHeight/2;

            newPos = [x1, newY1, x2, newY2];

            try
                set_param(blk, 'Position', newPos);
                fprintf('    调整: %s  高度 %.0f -> %.0f\n', blk, h, maxHeight);
            catch ME
                warning('    无法调整块 %s: %s', blk, ME.message);
            end
        end
    end

    fprintf('处理完成。\n');
end