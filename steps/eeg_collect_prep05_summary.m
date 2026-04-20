function [t_all, t_by_method, t_pair] = eeg_collect_prep05_summary(cfg_or_qc_root)
% EEG_COLLECT_PREP05_SUMMARY
%
% PURPOSE
%   Collect all Step-05 ICLabel summary tables across subjects and methods,
%   write combined summary tables, and create a paired AMICA-vs-runica
%   comparison table where both methods exist for the same subject/run.
%
% INPUT
%   cfg_or_qc_root
%       - [] or omitted: uses eeg_pipeline_config()
%       - cfg struct:     uses fullfile(cfg.paths.out_root, 'qc')
%       - char/string:    interpreted as qc root folder
%
% OUTPUT
%   t_all
%       All collected Step-05 summary rows
%   t_by_method
%       Method-level descriptive summary
%   t_pair
%       Paired runica-vs-amica comparison rows
%
% Saskia WEilken Apr 2026

if nargin < 1 || isempty(cfg_or_qc_root)
    cfg = eeg_pipeline_config();
    qc_root = fullfile(cfg.paths.out_root, 'qc');
elseif isstruct(cfg_or_qc_root)
    qc_root = fullfile(cfg_or_qc_root.paths.out_root, 'qc');
else
    qc_root = char(string(cfg_or_qc_root));
end

if exist(qc_root, 'dir') ~= 7
    error('QC root not found: %s', qc_root);
end

summary_files = dir(fullfile(qc_root, '**', '*_prep05_summary.csv'));

if isempty(summary_files)
    error('No Step-05 summary files found below: %s', qc_root);
end

t_all = table();

for k = 1:numel(summary_files)
    this_path = fullfile(summary_files(k).folder, summary_files(k).name);
    t = readtable(this_path, 'Delimiter', ';');

    if ~ismember('subject_id', t.Properties.VariableNames) || ...
       ~ismember('run_base', t.Properties.VariableNames) || ...
       ~ismember('ica_method', t.Properties.VariableNames)
        continue;
    end

    t.subject_id = string(t.subject_id);
    t.run_base   = string(t.run_base);
    t.ica_method = lower(string(t.ica_method));

    if isempty(t_all)
        t_all = t;
    else
        t_all = [t_all; t]; %#ok<AGROW>
    end
end

if isempty(t_all)
    error('Step-05 summary files were found, but no valid rows could be read.');
end

t_all = sortrows(t_all, {'ica_method', 'subject_id', 'run_base'});

all_out = fullfile(qc_root, 'prep05_iclabel_summary_all_subjects.csv');
writetable(t_all, all_out, 'Delimiter', ';');

numeric_vars = { ...
    'n_ic_total', 'n_ic_removed_unique', 'n_ic_remaining', 'prop_ic_removed', ...
    'n_ic_edge_not_removed', ...
    'n_ic_flag_eye', 'n_ic_flag_muscle', 'n_ic_flag_heart', 'n_ic_flag_line_noise', ...
    'n_ic_flag_channel_noise', 'n_ic_flag_other', 'n_ic_flag_low_brain'};

numeric_vars = numeric_vars(ismember(numeric_vars, t_all.Properties.VariableNames));

t_by_method = groupsummary(t_all, 'ica_method', {'mean', 'std', 'median'}, numeric_vars);

by_method_out = fullfile(qc_root, 'prep05_iclabel_summary_by_method.csv');
writetable(t_by_method, by_method_out, 'Delimiter', ';');

method_a = "runica";
method_b = "amica";

pair_key = strcat(t_all.subject_id, "__", t_all.run_base);
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
        row_a.n_ic_total(1), ...
        row_b.n_ic_total(1), ...
        row_a.n_ic_removed_unique(1), ...
        row_b.n_ic_removed_unique(1), ...
        row_a.prop_ic_removed(1), ...
        row_b.prop_ic_removed(1), ...
        row_a.n_ic_edge_not_removed(1), ...
        row_b.n_ic_edge_not_removed(1), ...
        row_a.n_ic_flag_eye(1), ...
        row_b.n_ic_flag_eye(1), ...
        row_a.n_ic_flag_muscle(1), ...
        row_b.n_ic_flag_muscle(1), ...
        row_a.n_ic_flag_heart(1), ...
        row_b.n_ic_flag_heart(1), ...
        row_a.n_ic_flag_line_noise(1), ...
        row_b.n_ic_flag_line_noise(1), ...
        row_a.n_ic_flag_channel_noise(1), ...
        row_b.n_ic_flag_channel_noise(1), ...
        row_a.n_ic_flag_other(1), ...
        row_b.n_ic_flag_other(1), ...
        row_a.n_ic_flag_low_brain(1), ...
        row_b.n_ic_flag_low_brain(1), ...
        'VariableNames', { ...
            'subject_id', 'run_base', ...
            'n_ic_total_runica', 'n_ic_total_amica', ...
            'n_ic_removed_runica', 'n_ic_removed_amica', ...
            'prop_ic_removed_runica', 'prop_ic_removed_amica', ...
            'n_ic_edge_runica', 'n_ic_edge_amica', ...
            'n_ic_flag_eye_runica', 'n_ic_flag_eye_amica', ...
            'n_ic_flag_muscle_runica', 'n_ic_flag_muscle_amica', ...
            'n_ic_flag_heart_runica', 'n_ic_flag_heart_amica', ...
            'n_ic_flag_line_noise_runica', 'n_ic_flag_line_noise_amica', ...
            'n_ic_flag_channel_noise_runica', 'n_ic_flag_channel_noise_amica', ...
            'n_ic_flag_other_runica', 'n_ic_flag_other_amica', ...
            'n_ic_flag_low_brain_runica', 'n_ic_flag_low_brain_amica'});

    if isempty(t_pair)
        t_pair = pair_row;
    else
        t_pair = [t_pair; pair_row]; %#ok<AGROW>
    end
end

if ~isempty(t_pair)
    pair_out = fullfile(qc_root, 'prep05_iclabel_comparison_runica_vs_amica.csv');
    writetable(t_pair, pair_out, 'Delimiter', ';');
end

fprintf('\nWrote:\n');
fprintf('  %s\n', all_out);
fprintf('  %s\n', by_method_out);
if ~isempty(t_pair)
    fprintf('  %s\n', pair_out);
end
end