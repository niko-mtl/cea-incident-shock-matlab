function [] = inp_creator(T,P,u1)

%% =========================
%  CEA .INP CREATION + RUN + PARSE TO EXCEL
%  (InitialGAS and ShockedGAS parsed with TWO SEPARATE FUNCTIONS)
%  =========================

%% ---- User inputs ----
% T  = 300;              % Temperature in K
% P  = 101325;           % Pressure in Pa
% u1 = 8500;             % Speed in m/s

%% ---- File names ----
inpBase = 'data_file';   % base filename (no extension)
inpFile = [inpBase '.inp'];      % full file name with extension

%% ---- Convert pressure (Pa -> bar) ----
P_bar = P / 1e5;                 % 1 bar = 1e5 Pa

%% ------------------------
%  Write new .inp file
%  ------------------------
fid = fopen(inpFile,'w');
if fid<0
    error('Cannot open %s for writing.', inpFile);
end

fprintf(fid,'prob case=data file  shock  incd  equilibrium  ions\n');
fprintf(fid,'p,bar=%.6f\n', P_bar);
fprintf(fid,'t,k=%g\n', T);
fprintf(fid,'u1=%g\n\n', u1);

fprintf(fid,'reac\n');

fprintf(fid,'  name O2   mole=0.2095\n');
fprintf(fid,'  name N2   mole=0.7808\n');
fprintf(fid,'  name Ar   mole=0.0093\n');
fprintf(fid,'  name CO2  mole=0.0004\n\n');


fprintf(fid,'outp siunits debug\n');
fprintf(fid,'trace=1.0e-9\n');
fprintf(fid,'end\n');

fclose(fid);
disp(['Created ' inpFile]);

%% ------------------------
%  Run CEA Fortran (FCEA2.exe) in the same folder
%  ------------------------
exeName = 'FCEA2.exe';
if ~isfile(exeName)
    error('Could not find %s in %s', exeName, pwd);
end
cmd = sprintf('echo %s | "%s"', inpBase, exeName);
[status, cmdout] = system(cmd);
if status ~= 0
    error('CEA run failed.\n%s', cmdout);
else
    disp('CEA run completed.');
    if isfile([inpBase '.out']); disp(['Created ' inpBase '.out']); end
    if isfile([inpBase '.plt']); disp(['Created ' inpBase '.plt']); end
end

%% ------------------------
%  Parse .out into Excel
%  ------------------------
outFile = [inpBase '.out'];
xlsFile  = [inpBase '.xlsx'];


txt   = fileread(outFile);
lines = regexp(txt, '\r\n|\n|\r', 'split');

idxInit  = findHeader(lines, {'^\s*INITIAL\s+GAS\s*\(\s*1\s*\)\s*$'});
idxShock = findHeader(lines, {'^\s*SHOCKED\s+GAS\s*\(\s*2\s*\).*INCIDENT.*EQUILIBRIUM\s*$', ...
                              '^\s*SHOCKED\s+GAS\s*\(\s*2\s*\)'});
idxMole  = findHeader(lines, {'^\s*MOLE\s+FRACTIONS\s*$'});



InitialTbl = parseInitialBlock(lines, idxInit, idxShock);
ShockedTbl = parseShockedBlock(lines, idxShock, idxMole);
MoleTbl    = parseMoleFractions(lines, idxMole);

writetable(InitialTbl, xlsFile, 'Sheet','InitialGAS',    'WriteMode','overwrite');
writetable(ShockedTbl, xlsFile, 'Sheet','ShockedGAS',    'WriteMode','overwritesheet');
writetable(MoleTbl,    xlsFile, 'Sheet','MoleFractions', 'WriteMode','overwritesheet');


%% ===== Reverse Pressure Conversion =====
sheets = {'InitialGAS','ShockedGAS'};

for s = 1:numel(sheets)
    sheetName = sheets{s};
    
    % Read the table
    T = readtable(xlsFile,'Sheet',sheetName);
    
    % Find row with Variable == 'P'
    idx = strcmpi(T.Variable,'P');
    
    if any(idx)
        % Convert from bar to Pa
        T.Value(idx) = T.Value(idx) * 1e5;
        
        % Change units to PA
        T.Unit(idx) = {'PA'};
    end
    
    % Write table back to Excel (overwrite sheet)
    writetable(T, xlsFile, 'Sheet', sheetName, 'WriteMode','overwritesheet');
    
    fprintf('Updated pressure in sheet %s\n', sheetName);
end

disp('All pressures converted to Pascals and units updated.');

disp(['Excel file created: ' xlsFile]);


%% ------------------------
%  Copy Excel 
%  ------------------------
try
    srcFile = fullfile(pwd, xlsFile);


    tgt1 = fullfile(pwd, 'physical_parameters_analysis');
    if exist(tgt1,'dir') == 7
        copyfile(srcFile, tgt1, 'f');  % overwrite if exists
        fprintf('Copied %s -> %s\n', xlsFile, tgt1);
    else
        fprintf('Skip copy: folder not found: %s\n', tgt1);
    end

    % 2) Copy to ./physical_parameters_analysis/PythonFiles
    tgt2 = fullfile(pwd, 'physical_parameters_analysis', 'PythonFiles');
    if exist(tgt2,'dir') == 7
        copyfile(srcFile, tgt2, 'f');  % overwrite if exists
        fprintf('Copied %s -> %s\n', xlsFile, tgt2);
    else
        fprintf('Skip copy: folder not found: %s\n', tgt2);
    end
catch ME
    warning('Excel copy step skipped due to error: %s', char(ME.message));
end

%% ======================= Local functions =======================

function idx = findHeader(lines, patternList)
idx = [];
for p = 1:numel(patternList)
    pat = patternList{p};
    for i = 1:numel(lines)
        if ~isempty( regexp(lines{i}, pat, 'once','ignorecase') )
            idx = i; return;
        end
    end
end
end

function blk = collectRange(lines, startIdx, endIdx)
blk = {};
i = startIdx + 1;
while i < endIdx
    if ~isBlankLine(lines{i})
        blk{end+1} = lines{i}; %#ok<AGROW>
    end
    i = i + 1;
end
end

function T = extractTableFromBlock(blk, targets)
vars  = cell(size(targets,1),1);
units = cell(size(targets,1),1);
vals  = nan(size(targets,1),1);

for k = 1:size(targets,1)
    vars{k}  = targets{k,1};
    units{k} = targets{k,2};
    pat      = targets{k,3};
    valFound = NaN;

    for j = 1:numel(blk)
        L = strtrim(blk{j});
        if ~isempty(regexp(L, pat, 'once','ignorecase'))
            vStr = getBestNumericToken(L);
            if ~isempty(vStr)
                valFound = parseCEAValue(vStr);
            end
            break;
        end
    end
    vals(k) = valFound;
end

T = table(vars, units, vals, 'VariableNames', {'Variable','Unit','Value'});
end

%% -------- Initial GAS parser (with extras)
function T = parseInitialBlock(lines, idxInit, idxShock)
blk = collectRange(lines, idxInit, idxShock);
targetsInit = { ...
    'MACH NUMBER', '',           '^\s*MACH\s+NUMBER' ; ...
    'U',           'M/SEC',      '^\s*U1?\s*,\s*M/SEC' ; ...
    'P',           'BAR',        '^\s*P\s*,\s*BAR' ; ...
    'T',           'K',          '^\s*T\s*,\s*K' ; ...
    'RHO',         'KG/CU M',    '^\s*RHO\s*,\s*KG/CU\s*M' ; ...
    'H',           'KJ/KG',      '^\s*H\s*,\s*KJ/KG' ; ...
    'U',           'KJ/KG',      '^\s*U\s*,\s*KJ/KG' ; ...
    'G',           'KJ/KG',      '^\s*G\s*,\s*KJ/KG' ; ...
    'S',           'KJ/(KG)(K)', '^\s*S\s*,\s*KJ/\(KG\)\(K\)' ; ...
    'M',           '(1/n)',      '^\s*M\s*,\s*\(1/n\)' ; ...
    'Cp',          'KJ/(KG)(K)', '^\s*Cp\s*,\s*KJ/\(KG\)\(K\)' ; ...
    'GAMMAs',      '',           '^\s*GAMMA\S*' ; ...   % <— robust GAMMA*
    'SON VEL',     'M/SEC',      '^\s*SON\s+VEL\s*,\s*M/SEC' ...
    };
T = extractTableFromBlock(blk, targetsInit);
end

%% -------- Shocked GAS parser (with extras)
function T = parseShockedBlock(lines, idxShock, idxMole)
blk = collectRange(lines, idxShock, idxMole);
targetsShock = { ...
    'U',           'M/SEC',      '^\s*U2?\s*,\s*M/SEC' ; ...
    'P',           'BAR',        '^\s*P\s*,\s*BAR' ; ...
    'T',           'K',          '^\s*T\s*,\s*K' ; ...
    'RHO',         'KG/CU M',    '^\s*RHO\s*,\s*KG/CU\s*M' ; ...
    'H',           'KJ/KG',      '^\s*H\s*,\s*KJ/KG' ; ...
    'U',           'KJ/KG',      '^\s*U\s*,\s*KJ/KG' ; ...
    'G',           'KJ/KG',      '^\s*G\s*,\s*KJ/KG' ; ...
    'S',           'KJ/(KG)(K)', '^\s*S\s*,\s*KJ/\(KG\)\(K\)' ; ...
    'M',           '(1/n)',      '^\s*M\s*,\s*\(1/n\)' ; ...
    '(dLV/dLP)t',  '',           '^\s*\(dLV/dLP\)t' ; ...
    '(dLV/dLT)p',  '',           '^\s*\(dLV/dLT\)p' ; ...
    'Cp',          'KJ/(KG)(K)', '^\s*Cp\s*,\s*KJ/\(KG\)\(K\)' ; ...
    'GAMMAs',      '',           '^\s*GAMMA\S*' ; ...  % <— robust GAMMA*
    'SON VEL',     'M/SEC',      '^\s*SON\s+VEL\s*,\s*M/SEC' ; ...
    'P2/P1',       '',           '^\s*P2\/P1' ; ...
    'T2/T1',       '',           '^\s*T2\/T1' ; ...
    'M2/M1',       '',           '^\s*M2\/M1' ; ...
    'RHO2/RHO1',   '',           '^\s*RHO2\/RHO1' ; ...
    'V2',          'M/SEC',      '^\s*V2\s*,\s*M/SEC' ...
    };
T = extractTableFromBlock(blk, targetsShock);
end

%% -------- Mole Fractions (unchanged)
function MF = parseMoleFractions(lines, startIdx)
data = {};
i = startIdx + 1;
while i <= numel(lines) && isBlankLine(lines{i}), i = i + 1; end
while i <= numel(lines) && ~isBlankLine(lines{i})
    L = lines{i};
    tok = regexp(L, '^\s*\*?([A-Za-z0-9\+\-]+)\s+([-+]?\d+(?:\.\d+)?(?:[EeDd][+-]?\d+|[+-]\d+)?)\s*$', 'tokens', 'once');
    if ~isempty(tok)
        species = strtrim(tok{1});
        vStr    = strtrim(tok{2});
        val     = parseCEAValue(vStr);
        data(end+1,:) = {species, val}; %#ok<AGROW>
    end
    i = i + 1;
end
MF = cell2table(data, 'VariableNames', {'Species','MoleFraction'});
end

%% -------- Helpers
function tf = isBlankLine(s), tf = isempty(s) || all(isspace(s)); end

function vStr = getBestNumericToken(L)
numPat = '[-+]?\d+(?:\.\d+)?(?:[EeDd][+-]?\d+|[-+]\d+)?';
tokens = regexp(L, numPat, 'match');
if isempty(tokens), vStr = ''; return; end
[~, idx] = max(cellfun(@length, tokens));
vStr = tokens{idx};
end

function v = parseCEAValue(s)
s = strtrim(s);
if isempty(s), v = NaN; return; end
if ~isempty(regexpi(s,'[Dd]')), s = regexprep(s,'[Dd]','E'); end
if ~isempty(regexpi(s,'E')), v = str2double(s); return; end
tok = regexp(s, '^([+-]?\d*(?:\.\d+)?)([+-])(\d+)$', 'tokens', 'once');
if ~isempty(tok)
    mant = str2double(tok{1}); expo = str2double(tok{3});
    if strcmp(tok{2},'+'), v = mant*10^expo; else, v = mant*10^-expo; end
    return;
end
v = str2double(s);
end
end
