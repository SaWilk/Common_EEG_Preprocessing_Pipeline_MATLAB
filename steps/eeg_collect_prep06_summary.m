function [t_all, t_by_method, t_pair] = eeg_collect_prep06_summary(cfg_or_qc_root)
% EEG_COLLECT_PREP06_SUMMARY
%
% PURPOSE
%   Collect all Step-06 epoching summary tables across subjects and methods,
%   write combined summary tables, and create a paired AMICA-vs-runica
%   comparison table where both methods exist for the same subject/run/
%   epoching condition.
%
% INPUT
%   cfg_or_qc_root
%       - [] or omitted: uses eeg_pipeline_config()
%       - cfg struct:     uses fullfile(cfg.paths.derivatives_root, 'qc')
%       - char/string:    interpreted as qc root folder
%
% OUTPUT
%   t_all
%       All collected Step-06 summary rows
%   t_by_method
%       Method-level descriptive summary by epoching mode and condition
%   t_pair
%       Paired runica-vs-amica comparison rows
%
% EXPECTED INPUT FILES
%   Below qc root:
%       **/*_prep06_summary.csv
%
% WRITTEN OUTPUT FILES
%   <qc_root>/prep06_epoching_summary_all_subjects.csv
%   <qc_root>/prep06_epoching_summary_by_method_condition.csv
%   <qc_root>/prep06_epoching_comparison_runica_vs_amica.csv   (if pairs exist)
%
% Saskia Wilken Apr 2026

%% ------------------------------------------------------------------------
%  Resolve QC root
% -------------------------------------------------------------------------
if nargin < 1 || isempty(cfg_or_qc_root)
    cfg = eeg_pipeline_config();
    qc_root = fullfile(cfg.paths.derivatives_root, 'qc');
elseif isstruct(cfg_or_qc_root)
    qc_root = fullfile(cfg_or_qc_root.paths.derivatives_root, 'qc');
else
    qc_root = char(string(cfg_or_qc_root));
end

if exist(qc_root, 'dir') ~= 7
    error('QC root not found: %s', qc_root);
end

%% ------------------------------------------------------------------------
%  Find subject-level Step-06 summary files
% -------------------------------------------------------------------------
summary_files = dir(fullfile(qc_root, '**', '*_prep06_summary.csv'));

if isempty(summary_files)
    error('No Step-06 summary files found below: %s', qc_root);
end

t_all = table();

for k = 1:numel(summary_files)
    this_path = fullfile(summary_files(k).folder, summary_files(k).name);

    t = readtable(this_path, 'Delimiter', ';');
    t = normalize_prep06_summary_table_impl(t);

    if isempty(t)
        continue;
    end

    if isempty(t_all)
        t_all = t;
    else
        t_all = [t_all; t]; %#ok<AGROW>
    end
end

if isempty(t_all)
    error('Step-06 summary files were found, but no valid rows could be read.');
end

%% ------------------------------------------------------------------------
%  Sort + write full table
% -------------------------------------------------------------------------
sort_vars = intersect( ...
    {'ica_method', 'subject_id', 'run_base', 'epoching_mode', 'condition'}, ...
    t_all.Properties.VariableNames, ...
    'stable');

if ~isempty(sort_vars)
    t_all = sortrows(t_all, sort_vars);
end

all_out = fullfile(qc_root, 'prep06_epoching_summary_all_subjects.csv');
writetable(t_all, all_out, 'Delimiter', ';');

%% ------------------------------------------------------------------------
%  Add helper numeric columns for descriptive summaries
% -------------------------------------------------------------------------
t_all.saved_numeric    = double(t_all.status == "saved");
t_all.excluded_numeric = double(t_all.excluded_by_max_reject_prop);
t_all.empty_numeric    = double(t_all.status == "empty_after_rejection");

numeric_vars = { ...
    'n_eeg_channels', ...
    'n_eog_channels', ...
    'n_non_eeg_channels', ...
    'n_epochs_total', ...
    'n_rejected_hard', ...
    'n_rejected_sophisticated', ...
    'n_rejected_total', ...
    'n_epochs_kept', ...
    'prop_rejected_total', ...
    'saved_numeric', ...
    'excluded_numeric', ...
    'empty_numeric'};

numeric_vars = numeric_vars(ismember(numeric_vars, t_all.Properties.VariableNames));

group_vars = {'ica_method', 'epoching_mode', 'condition'};
group_vars = group_vars(ismember(group_vars, t_all.Properties.VariableNames));

t_by_method = groupsummary(t_all, group_vars, {'mean', 'std', 'median'}, numeric_vars);

by_method_out = fullfile(qc_root, 'prep06_epoching_summary_by_method_condition.csv');
writetable(t_by_method, by_method_out, 'Delimiter', ';');

%% ------------------------------------------------------------------------
%  Paired runica-vs-amica comparison
% -------------------------------------------------------------------------
method_a = "runica";
method_b = "amica";

pair_key = strcat( ...
    t_all.subject_id, "__", ...
    t_all.run_base, "__", ...
    t_all.epoching_mode, "__", ...
    t_all.condition);

unique_keys = unique(pair_key);
t_pair = table();

for k = 1:numel(unique_keys)
    this_key = unique_keys(k);

    row_a = t_all(pair_key == this_key & t_all.ica_method == method_a, :);
    row_b = t_all(pair_key == this_key & t_all.ica_method == method_b, :);

    if height(row_a) ~= 1 || height(row_b) ~= 1
        continue;
    end

    pair_row = table( ...
        row_a.subject_id(1), ...
        row_a.run_base(1), ...
        row_a.epoching_mode(1), ...
        row_a.condition(1), ...
        row_a.status(1), ...
        row_b.status(1), ...
        row_a.n_epochs_total(1), ...
        row_b.n_epochs_total(1), ...
        row_a.n_rejected_hard(1), ...
        row_b.n_rejected_hard(1), ...
        row_a.n_rejected_sophisticated(1), ...
        row_b.n_rejected_sophisticated(1), ...
        row_a.n_rejected_total(1), ...
        row_b.n_rejected_total(1), ...
        row_a.n_epochs_kept(1), ...
        row_b.n_epochs_kept(1), ...
        row_a.prop_rejected_total(1), ...
        row_b.prop_rejected_total(1), ...
        row_a.excluded_by_max_reject_prop(1), ...
        row_b.excluded_by_max_reject_prop(1), ...
        row_b.n_rejected_total(1) - row_a.n_rejected_total(1), ...
        row_b.n_epochs_kept(1)    - row_a.n_epochs_kept(1), ...
        row_b.prop_rejected_total(1) - row_a.prop_rejected_total(1), ...
        'VariableNames', { ...
            'subject_id', 'run_base', 'epoching_mode', 'condition', ...
            'status_runica', 'status_amica', ...
            'n_epochs_total_runica', 'n_epochs_total_amica', ...
            'n_rejected_hard_runica', 'n_rejected_hard_amica', ...
            'n_rejected_sophisticated_runica', 'n_rejected_sophisticated_amica', ...
            'n_rejected_total_runica', 'n_rejected_total_amica', ...
            'n_epochs_kept_runica', 'n_epochs_kept_amica', ...
            'prop_rejected_total_runica', 'prop_rejected_total_amica', ...
            'excluded_runica', 'excluded_amica', ...
            'delta_n_rejected_total_amica_minus_runica', ...
            'delta_n_epochs_kept_amica_minus_runica', ...
            'delta_prop_rejected_amica_minus_runica'});

    if isempty(t_pair)
        t_pair = pair_row;
    else
        t_pair = [t_pair; pair_row]; %#ok<AGROW>
    end
end

if ~isempty(t_pair)
    pair_out = fullfile(qc_root, 'prep06_epoching_comparison_runica_vs_amica.csv');
    writetable(t_pair, pair_out, 'Delimiter', ';');
end

%% ------------------------------------------------------------------------
%  Console output
% -------------------------------------------------------------------------
fprintf('\nWrote:\n');
fprintf('  %s\n', all_out);
fprintf('  %s\n', by_method_out);
if ~isempty(t_pair)
    fprintf('  %s\n', pair_out);
end

end


function t = normalize_prep06_summary_table_impl(t)
% Bring older/newer Step-06 summary tables to one common schema.

if ~istable(t) || isempty(t)
    t = table();
    return;
end

n = height(t);

string_vars = { ...
    'subject_id', ...
    'run_base', ...
    'ica_method', ...
    'epoching_mode', ...
    'condition', ...
    'status', ...
    'input_set_name', ...
    'output_set_paths'};

double_vars = { ...
    'n_eeg_channels', ...
    'n_eog_channels', ...
    'n_non_eeg_channels', ...
    'n_epochs_total', ...
    'n_rejected_hard', ...
    'n_rejected_sophisticated', ...
    'n_rejected_total', ...
    'n_epochs_kept', ...
    'prop_rejected_total', ...
    'hard_threshold_uv', ...
    'baseline_start_ms', ...
    'baseline_end_ms', ...
    'max_reject_prop', ...
    'shared_faster_z', ...
    'shared_ptp_uV_thresh'};

logical_vars = { ...
    'excluded_by_max_reject_prop', ...
    'artifact_rejection_enabled', ...
    'hard_threshold_enabled', ...
    'baseline_correction_applied', ...
    'shared_rejection_enabled', ...
    'shared_use_robust_z'};

for i = 1:numel(string_vars)
    vn = string_vars{i};
    if ~ismember(vn, t.Properties.VariableNames)
        t.(vn) = strings(n, 1);
    else
        t.(vn) = to_string_column_impl(t.(vn));
    end
end

for i = 1:numel(double_vars)
    vn = double_vars{i};
    if ~ismember(vn, t.Properties.VariableNames)
        t.(vn) = nan(n, 1);
    else
        t.(vn) = to_double_column_impl(t.(vn));
    end
end

for i = 1:numel(logical_vars)
    vn = logical_vars{i};
    if ~ismember(vn, t.Properties.VariableNames)
        t.(vn) = false(n, 1);
    else
        t.(vn) = to_logical_column_impl(t.(vn));
    end
end

t.subject_id   = string(t.subject_id);
t.run_base     = string(t.run_base);
t.ica_method   = lower(string(t.ica_method));
t.epoching_mode = string(t.epoching_mode);
t.condition     = string(t.condition);
t.status        = string(t.status);

end


function out = to_string_column_impl(x)
if isstring(x)
    out = x;
elseif ischar(x)
    out = string(cellstr(x));
elseif iscellstr(x)
    out = string(x);
elseif iscell(x)
    try
        out = string(x);
    catch
        out = repmat("", numel(x), 1);
    end
else
    out = string(x);
end

out = out(:);
end


function out = to_double_column_impl(x)
if isnumeric(x)
    out = double(x);
elseif islogical(x)
    out = double(x);
elseif iscell(x)
    out = nan(numel(x), 1);
    for i = 1:numel(x)
        try
            if ischar(x{i}) || isstring(x{i})
                out(i) = str2double(strrep(char(string(x{i})), ',', '.'));
            else
                out(i) = double(x{i});
            end
        catch
            out(i) = NaN;
        end
    end
else
    s = string(x);
    s = replace(s, ",", ".");
    out = str2double(s);
end

out = out(:);
end


function out = to_logical_column_impl(x)
if islogical(x)
    out = x(:);
    return;
end

if isnumeric(x)
    out = x(:) ~= 0;
    return;
end

s = to_string_column_impl(x);
s = lower(strtrim(s));

out = ismember(s, ["1","true","yes","y","ja"]);
out = out(:);
end