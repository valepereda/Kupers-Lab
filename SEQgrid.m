%% ===== PARAMETERS =====
folder       = 'faces';   % folder with the full face images
fragmentSec  = 0.5;       % how long the fragment is visible
nRepeats     = 1;         % times each face is used as the target
shuffleFaces = false;     % false = faces in folder order, true = random order
outFile      = 'results.csv';

%% ===== LOAD FACES =====
files = dir(fullfile(folder, '*.*'));
files([files.isdir]) = [];

faces = {};  faceNames = {};
for k = 1:numel(files)
    try
        img = imread(fullfile(folder, files(k).name));
    catch
        continue                      % skip files that aren't readable images
    end
    if size(img,3) == 1, img = repmat(img, 1, 1, 3); end   % grayscale -> RGB
    img = img(:,:,1:3);                                     % drop alpha channel
    faces{end+1}     = img;                 %#ok<SAGROW>
    faceNames{end+1} = files(k).name;       %#ok<SAGROW>
end
nFaces = numel(faces);
assert(nFaces >= 2, 'Need at least 2 readable face images in "%s".', folder);

%% ===== TRIAL ORDER =====
targets = repmat(1:nFaces, 1, nRepeats);
if shuffleFaces, targets = targets(randperm(numel(targets))); end
nTrials = numel(targets);

%% ===== FIGURE SETUP =====
fig = figure('Color','k', 'MenuBar','none', 'ToolBar','none', ...
             'NumberTitle','off', 'Name','Face experiment', ...
             'WindowState','maximized', 'KeyPressFcn',@onKey);

axMain = axes('Parent',fig, 'Position',[0.20 0.05 0.60 0.90], 'Color','k');
axL    = axes('Parent',fig, 'Position',[0.08 0.12 0.38 0.62], 'Color','k');
axR    = axes('Parent',fig, 'Position',[0.54 0.12 0.38 0.62], 'Color','k');
axis([axMain axL axR], 'off');

txt = uicontrol(fig, 'Style','text', 'Units','normalized', ...
                'Position',[0.05 0.82 0.90 0.12], 'FontSize',28, ...
                'BackgroundColor','k', 'ForegroundColor','w');

%% ===== INSTRUCTIONS =====
txt.String = 'You will briefly see part of a face. Then choose which face you saw: LEFT or RIGHT arrow. Press any key to start.';
txt.Position = [0.1 0.35 0.8 0.3];
drawnow;
waitForKey(fig, {});
txt.Position = [0.05 0.82 0.90 0.12];
txt.String = '';

%% ===== RUN TRIALS =====
results = struct('trial',{}, 'target',{}, 'foil',{}, 'quadrant',{}, ...
                 'targetSide',{}, 'response',{}, 'correct',{}, 'rt',{});
quadNames = {'TL','TR','BL','BR'};

for t = 1:nTrials
    target = targets(t);
    others = setdiff(1:nFaces, target);
    foil   = others(randi(numel(others)));
    quad   = randi(4);                         % random fragment
    targetSide = ternary(rand < 0.5, 'left', 'right');

    % --- Build the fragment (black canvas, fragment in its original place)
    img = faces{target};
    [h, w, ~] = size(img);
    h2 = floor(h/2);  w2 = floor(w/2);
    rows = {1:h2, 1:h2, h2+1:2*h2, h2+1:2*h2};
    cols = {1:w2, w2+1:2*w2, 1:w2, w2+1:2*w2};
    canvas = zeros(2*h2, 2*w2, 3, 'like', img);
    canvas(rows{quad}, cols{quad}, :) = img(rows{quad}, cols{quad}, :);

    % --- 1) Show fragment
    txt.Visible = 'off';
    imshow(canvas, 'Parent', axMain);
    drawnow;
    pause(fragmentSec);

    % --- 2) Fragment disappears, question appears immediately
    cla(axMain);
    if strcmp(targetSide, 'left')
        imshow(faces{target}, 'Parent', axL);  imshow(faces{foil},   'Parent', axR);
    else
        imshow(faces{foil},   'Parent', axL);  imshow(faces{target}, 'Parent', axR);
    end
    title(axL, '\leftarrow', 'Color','w', 'FontSize',30);
    title(axR, '\rightarrow', 'Color','w', 'FontSize',30);
    txt.String  = 'What face did you just see?';
    txt.Visible = 'on';
    drawnow;

    % --- 3) Wait for arrow key
    [key, rt] = waitForKey(fig, {'leftarrow','rightarrow','escape'});
    if strcmp(key, 'escape') || ~isvalid(fig), break; end

    response = erase(key, 'arrow');            % 'left' or 'right'
    correct  = strcmp(response, targetSide);

    results(end+1) = struct('trial',t, 'target',faceNames{target}, ...
        'foil',faceNames{foil}, 'quadrant',quadNames{quad}, ...
        'targetSide',targetSide, 'response',response, ...
        'correct',correct, 'rt',rt);          %#ok<SAGROW>

    % --- clear screen before next trial
    cla(axL); cla(axR); title(axL,''); title(axR,'');
    txt.Visible = 'off';
    drawnow;
end

%% ===== SAVE & REPORT =====
if isvalid(fig), close(fig); end
if ~isempty(results)
    T = struct2table(results);
    writetable(T, outFile);
    fprintf('Accuracy: %.1f%% (%d trials). Saved to %s\n', ...
            100*mean(T.correct), height(T), outFile);
end

%% ===== LOCAL FUNCTIONS =====
function onKey(src, evt)
    setappdata(src, 'key', evt.Key);
    uiresume(src);
end

function [key, rt] = waitForKey(fig, allowed)
    setappdata(fig, 'key', '');
    tStart = tic;
    while true
        uiwait(fig);
        if ~isvalid(fig), key = 'escape'; rt = NaN; return; end
        k = getappdata(fig, 'key');
        if isempty(allowed) || ismember(k, allowed)
            key = k;  rt = toc(tStart);  return
        end
    end
end

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end