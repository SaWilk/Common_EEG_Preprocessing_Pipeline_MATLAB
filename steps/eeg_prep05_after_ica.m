function step_out = eeg_prep05_after_ica(subj_id, cfg, paths, helpers)
% EEG_PREP05_AFTER_ICA
%
% PURPOSE
%   Load ICA-applied datasets, classify components with ICLabel, remove
%   selected artifact ICs, export optional QA PNGs, and save datasets for
%   the epoching step.
%
% INPUT
%   paths.prep_04_out_dir
%       *_ica_applied.set
%
% OUTPUT
%   paths.prep_05_out_dir
%       *_until_epoching.set
%
% OPTIONAL QA OUTPUT
%   Method-specific QC subfolders below:
%       paths.qc_dir/<ica_method>/
%       paths.checks_ica_components_subj_dir/<ica_method>/

step_out = struct('ok', false, 'message', '', 'outputs', {{}});

subj_label = sprintf('sub-%s', subj_id);

INPUT_FILE_GLOB   = '*_ica_applied.set';
INPUT_FILE_SUFFIX = '_ica_applied.set';
OUTPUT_SET_SUFFIX = '_until_epoching.set';
OUTPUT_SET_LABEL  = '_until_epoching';

REJECTED_TAG = 'rej';
EDGE_TAG     = 'edge';

MIN_IC_COUNT = 2;

%% ========================================================================
%  STEP CFG DEFAULTS
% ========================================================================
step_cfg = struct();

step_cfg.clear_subject_ica_comps_dir = true;

step_cfg.iclabel_eye_remove_thr       = 0.80;
step_cfg.iclabel_muscle_remove_thr    = 0.80;
step_cfg.iclabel_heart_remove_thr     = 0.80;
step_cfg.iclabel_linenoise_remove_thr = 0.80;
step_cfg.iclabel_channoise_remove_thr = 0.80;
step_cfg.iclabel_other_remove_thr     = 0.95;
step_cfg.iclabel_brain_min_keep_thr   = 0.05;

step_cfg.save_ic_topos_png   = true;
step_cfg.iclabel_edge_margin = 0.10;

step_cfg.ic_topo_dpi        = 300;
step_cfg.ic_topo_fig_cm     = [0 0 18 18];
step_cfg.ic_topo_electrodes = 'off';

step_cfg.write_component_table       = true;
step_cfg.write_run_summary_table     = true;
step_cfg.write_subject_summary_table = true;
step_cfg.qc_table_delimiter          = ';';

step_cfg.overwrite_mode = "";

%% ========================================================================
%  MERGE OVERRIDES FROM CFG
% ========================================================================
if isfield(cfg, 'prep_05') && isstruct(cfg.prep_05)
    step_cfg = helpers.merge_structs_recursive(step_cfg, cfg.prep_05);
end

if isfield(cfg, 'steps') && isfield(cfg.steps, 'prep_05_after_ica') && isstruct(cfg.steps.prep_05_after_ica)
    if isfield(cfg.steps.prep_05_after_ica, 'overwrite_mode') && ...
            strlength(string(cfg.steps.prep_05_after_ica.overwrite_mode)) > 0
        step_cfg.overwrite_mode = string(cfg.steps.prep_05_after_ica.overwrite_mode);
    end
end

overwrite_mode = helpers.resolve_overwrite_mode(cfg, step_cfg.overwrite_mode);

%% ========================================================================
%  ICA METHOD / PATHS
% ========================================================================
ica_method = "unknown";
if isfield(cfg, 'prep_04') && isfield(cfg.prep_04, 'ica_method') && ...
        strlength(string(cfg.prep_04.ica_method)) > 0
    ica_method = string(cfg.prep_04.ica_method);
end
ica_method_tag = lower(regexprep(char(ica_method), '[^\w\-]', '_'));

if ~isfield(paths, 'prep_04_out_dir') || strlength(string(paths.prep_04_out_dir)) == 0
    error('prep05_after_ica: paths.prep_04_out_dir is missing or empty.');
end

if ~isfield(paths, 'prep_05_out_dir') || strlength(string(paths.prep_05_out_dir)) == 0
    error('prep05_after_ica: paths.prep_05_out_dir is missing or empty.');
end

if ~isfield(paths, 'qc_dir') || strlength(string(paths.qc_dir)) == 0
    error('prep05_after_ica: paths.qc_dir is missing or empty.');
end

if ~isfield(paths, 'checks_ica_components_subj_dir') || ...
        strlength(string(paths.checks_ica_components_subj_dir)) == 0
    error('prep05_after_ica: paths.checks_ica_components_subj_dir is missing or empty.');
end

in_dir  = paths.prep_04_out_dir;
out_dir = paths.prep_05_out_dir;

qc_method_dir     = fullfile(paths.qc_dir, ica_method_tag);
checks_method_dir = fullfile(paths.checks_ica_components_subj_dir, ica_method_tag);
checks_rej_dir    = fullfile(checks_method_dir, REJECTED_TAG);
checks_edge_dir   = fullfile(checks_method_dir, EDGE_TAG);

helpers.ensure_dir(out_dir);

%% ========================================================================
%  FIND INPUTS
% ========================================================================
in_sets = dir(fullfile(in_dir, INPUT_FILE_GLOB));

if isempty(in_sets)
    step_out.ok = true;
    step_out.message = sprintf('prep05_after_ica: no %s found for %s (skip).', INPUT_FILE_GLOB, subj_label);
    helpers.log_msg_default('%s', step_out.message);
    return;
end

%% ========================================================================
%  MAIN LOOP
% ========================================================================
outputs_written  = {};
qa_dirs_prepared = false;
summary_rows     = table();

try
    for fi = 1:numel(in_sets)

        in_name   = in_sets(fi).name;
        run_base  = erase(string(in_name), INPUT_FILE_SUFFIX);
        run_base_c = char(run_base);

        out_name = [run_base_c OUTPUT_SET_SUFFIX];
        out_path = fullfile(out_dir, out_name);

        [do_run, reason] = helpers.step_should_run_outputs({out_path}, overwrite_mode, cfg);
        helpers.log_msg_default('prep05_after_ica: %s | %s | %s', subj_label, run_base_c, char(string(reason)));

        if ~do_run
            outputs_written{end+1} = out_path; %#ok<AGROW>
            continue;
        end

        if ~qa_dirs_prepared
            helpers.ensure_dir(qc_method_dir);

            if step_cfg.clear_subject_ica_comps_dir
                helpers.safe_rmdir(checks_method_dir);
            end

            helpers.ensure_dir(checks_method_dir);
            helpers.ensure_dir(checks_rej_dir);
            helpers.ensure_dir(checks_edge_dir);

            qa_dirs_prepared = true;
        end

        if overwrite_mode == "delete" && exist(out_path, 'file') == 2
            helpers.safe_delete_set(out_path);
        end

        EEG = helpers.safe_load_set(in_dir, in_name, helpers);

        EEG = helpers.append_eeg_comment(EEG, 'prep05_after_ica: start');
        EEG = helpers.append_eeg_comment(EEG, sprintf('prep05_after_ica: input=%s', in_name));
        EEG = helpers.append_eeg_comment(EEG, sprintf('prep05_after_ica: ica_method=%s', char(ica_method)));
        EEG = helpers.append_eeg_comment(EEG, sprintf( ...
            ['prep05_after_ica: thresholds eye>%.2f muscle>%.2f heart>%.2f ' ...
             'line>%.2f chnoise>%.2f other>%.2f brain_min>=%.2f edge_margin=%.2f'], ...
            step_cfg.iclabel_eye_remove_thr, ...
            step_cfg.iclabel_muscle_remove_thr, ...
            step_cfg.iclabel_heart_remove_thr, ...
            step_cfg.iclabel_linenoise_remove_thr, ...
            step_cfg.iclabel_channoise_remove_thr, ...
            step_cfg.iclabel_other_remove_thr, ...
            step_cfg.iclabel_brain_min_keep_thr, ...
            step_cfg.iclabel_edge_margin));

        n_ic = 0;
        if isfield(EEG, 'icawinv') && ~isempty(EEG.icawinv)
            n_ic = size(EEG.icawinv, 2);
        elseif isfield(EEG, 'icaweights') && ~isempty(EEG.icaweights)
            n_ic = size(EEG.icaweights, 1);
        end

        if n_ic < MIN_IC_COUNT
            helpers.log_msg_default( ...
                'prep05_after_ica: %s | %s | skip insufficient ICA components (nIC=%d).', ...
                subj_label, run_base_c, n_ic);
            EEG = helpers.append_eeg_comment(EEG, ...
                sprintf('prep05_after_ica: skip insufficient ICA components (nIC=%d)', n_ic));
            continue;
        end

        if exist('iclabel', 'file') ~= 2
            error('ICLabel not available on path (iclabel.m not found).');
        end

        EEG = iclabel(EEG);

        if ~isfield(EEG, 'etc') || ...
           ~isfield(EEG.etc, 'ic_classification') || ...
           ~isfield(EEG.etc.ic_classification, 'ICLabel') || ...
           ~isfield(EEG.etc.ic_classification.ICLabel, 'classifications')
            error('ICLabel classifications missing after iclabel(EEG).');
        end

        classif = EEG.etc.ic_classification.ICLabel.classifications;

        if size(classif, 2) < 7
            error('Unexpected ICLabel classification size: %s', mat2str(size(classif)));
        end

        if size(classif, 1) ~= n_ic
            error('ICLabel returned %d rows, but dataset has %d ICs.', size(classif, 1), n_ic);
        end

        p_brain  = classif(:, 1);
        p_muscle = classif(:, 2);
        p_eye    = classif(:, 3);
        p_heart  = classif(:, 4);
        p_line   = classif(:, 5);
        p_ch     = classif(:, 6);
        p_other  = classif(:, 7);

        ic_eye       = find(p_eye    > step_cfg.iclabel_eye_remove_thr);
        ic_muscle    = find(p_muscle > step_cfg.iclabel_muscle_remove_thr);
        ic_heart     = find(p_heart  > step_cfg.iclabel_heart_remove_thr);
        ic_line      = find(p_line   > step_cfg.iclabel_linenoise_remove_thr);
        ic_ch_noise  = find(p_ch     > step_cfg.iclabel_channoise_remove_thr);
        ic_other     = find(p_other  > step_cfg.iclabel_other_remove_thr);
        ic_low_brain = find(p_brain  < step_cfg.iclabel_brain_min_keep_thr);

        ic_to_remove = unique([ ...
            ic_eye; ...
            ic_muscle; ...
            ic_heart; ...
            ic_line; ...
            ic_ch_noise; ...
            ic_other; ...
            ic_low_brain]);

        edge_margin = step_cfg.iclabel_edge_margin;

        edge_eye = find( ...
            p_eye <= step_cfg.iclabel_eye_remove_thr & ...
            p_eye >  (step_cfg.iclabel_eye_remove_thr - edge_margin));

        edge_muscle = find( ...
            p_muscle <= step_cfg.iclabel_muscle_remove_thr & ...
            p_muscle >  (step_cfg.iclabel_muscle_remove_thr - edge_margin));

        edge_heart = find( ...
            p_heart <= step_cfg.iclabel_heart_remove_thr & ...
            p_heart >  (step_cfg.iclabel_heart_remove_thr - edge_margin));

        edge_line = find( ...
            p_line <= step_cfg.iclabel_linenoise_remove_thr & ...
            p_line >  (step_cfg.iclabel_linenoise_remove_thr - edge_margin));

        edge_ch_noise = find( ...
            p_ch <= step_cfg.iclabel_channoise_remove_thr & ...
            p_ch >  (step_cfg.iclabel_channoise_remove_thr - edge_margin));

        brain_edge_lo = step_cfg.iclabel_brain_min_keep_thr;
        brain_edge_hi = step_cfg.iclabel_brain_min_keep_thr + edge_margin;
        edge_brain = find(p_brain >= brain_edge_lo & p_brain < brain_edge_hi);

        ic_edge_raw = unique([ ...
            edge_eye; ...
            edge_muscle; ...
            edge_heart; ...
            edge_line; ...
            edge_ch_noise; ...
            edge_brain]);

        ic_edge = setdiff(ic_edge_raw, ic_to_remove);

        if ~isfield(EEG, 'etc') || isempty(EEG.etc)
            EEG.etc = struct();
        end

        EEG.etc.ic_rejection = struct();
        EEG.etc.ic_rejection.mode         = "iclabel_thresholds_extended";
        EEG.etc.ic_rejection.ica_method   = char(ica_method);
        EEG.etc.ic_rejection.ic_to_remove = ic_to_remove(:)';
        EEG.etc.ic_rejection.ic_edge      = ic_edge(:)';
        EEG.etc.ic_rejection.timestamp    = datestr(now, 'yyyy-mm-dd HH:MM:SS');

        EEG = helpers.append_eeg_comment(EEG, sprintf( ...
            'prep05_after_ica: n_ic=%d | remove=%d | edge_not_removed=%d', ...
            n_ic, numel(ic_to_remove), numel(ic_edge)));

        helpers.log_msg_default( ...
            'prep05_after_ica: %s | %s | method=%s | nIC=%d | remove=%d | edge=%d', ...
            subj_label, run_base_c, char(ica_method), n_ic, numel(ic_to_remove), numel(ic_edge));

        component_table_path = "";

        if step_cfg.write_component_table
            ic_index = (1:n_ic)';

            component_table = table( ...
                repmat(string(subj_label), n_ic, 1), ...
                repmat(string(run_base), n_ic, 1), ...
                repmat(string(ica_method), n_ic, 1), ...
                ic_index, ...
                p_brain, p_muscle, p_eye, p_heart, p_line, p_ch, p_other, ...
                ismember(ic_index, ic_eye), ...
                ismember(ic_index, ic_muscle), ...
                ismember(ic_index, ic_heart), ...
                ismember(ic_index, ic_line), ...
                ismember(ic_index, ic_ch_noise), ...
                ismember(ic_index, ic_other), ...
                ismember(ic_index, ic_low_brain), ...
                ismember(ic_index, ic_to_remove), ...
                ismember(ic_index, edge_eye), ...
                ismember(ic_index, edge_muscle), ...
                ismember(ic_index, edge_heart), ...
                ismember(ic_index, edge_line), ...
                ismember(ic_index, edge_ch_noise), ...
                ismember(ic_index, edge_brain), ...
                ismember(ic_index, ic_edge), ...
                'VariableNames', { ...
                    'subject_id', 'run_base', 'ica_method', 'ic_index', ...
                    'p_brain', 'p_muscle', 'p_eye', 'p_heart', 'p_line', 'p_channel_noise', 'p_other', ...
                    'flag_eye', 'flag_muscle', 'flag_heart', 'flag_line_noise', 'flag_channel_noise', 'flag_other', 'flag_low_brain', ...
                    'is_removed', ...
                    'edge_eye', 'edge_muscle', 'edge_heart', 'edge_line_noise', 'edge_channel_noise', 'edge_brain', ...
                    'is_edge_not_removed'});

            component_table_path = fullfile( ...
                qc_method_dir, ...
                sprintf('%s_%s_iclabel_components.csv', subj_label, run_base_c));

            writetable(component_table, component_table_path, ...
                'Delimiter', char(string(step_cfg.qc_table_delimiter)));
        end

        if step_cfg.save_ic_topos_png && (~isempty(ic_to_remove) || ~isempty(ic_edge))
            if exist('topoplot', 'file') ~= 2
                helpers.log_msg_default( ...
                    'prep05_after_ica: %s | %s | topoplot missing -> skip QA PNG export.', ...
                    subj_label, run_base_c);
            else
                file_prefix = sprintf('%s_%s_%s', subj_label, run_base_c, ica_method_tag);

                helpers.write_ic_topography_pngs( ...
                    EEG, ic_to_remove(:)', checks_rej_dir, file_prefix, REJECTED_TAG, step_cfg, classif);

                helpers.write_ic_topography_pngs( ...
                    EEG, ic_edge(:)', checks_edge_dir, file_prefix, EDGE_TAG, step_cfg, classif);
            end
        end

        if ~isempty(ic_to_remove)

            if isfield(EEG, 'icaact')
                EEG.icaact = [];
            end

            EEG = eeg_checkset(EEG, 'ica');

            helpers.log_msg_default( ...
                ['prep05_after_ica: %s | %s | ICA dims before subcomp: ' ...
                 'nbchan=%d, icachansind=%d, icaweights=%s, icawinv=%s'], ...
                subj_label, run_base_c, EEG.nbchan, numel(EEG.icachansind), ...
                mat2str(size(EEG.icaweights)), mat2str(size(EEG.icawinv)));

            x = double(EEG.data);
            bad_nonfinite = find(any(~isfinite(x), 2));
            bad_flat      = find(std(x, 0, 2) < 1e-6);
            bad_range     = find((max(x, [], 2) - min(x, [], 2)) < 1e-5);
            bad_diag      = unique([bad_nonfinite; bad_flat; bad_range]);

            if ~isempty(bad_diag)
                try
                    bad_labels = {EEG.chanlocs(bad_diag).labels};
                    helpers.log_msg_default( ...
                        'prep05_after_ica: %s | %s | suspicious channels before subcomp: %s', ...
                        subj_label, run_base_c, strjoin(string(bad_labels), ', '));
                catch
                end
            end

            if exist('pop_subcomp', 'file') == 2
                EEG = pop_subcomp(EEG, ic_to_remove, 0);
            else
                EEG.reject.gcompreject = false(1, n_ic);
                EEG.reject.gcompreject(ic_to_remove) = true;
                EEG = pop_rejcomp(EEG, ic_to_remove, 0);
            end

            EEG = eeg_checkset(EEG);
            EEG = helpers.append_eeg_comment(EEG, ...
                sprintf('prep05_after_ica: removed ICs: %s', mat2str(ic_to_remove(:)')));
        else
            EEG = helpers.append_eeg_comment(EEG, 'prep05_after_ica: no ICs removed');
        end

        EEG.setname = char(run_base + OUTPUT_SET_LABEL);

        n_ic_removed_unique = numel(ic_to_remove);
        n_ic_remaining      = n_ic - n_ic_removed_unique;
        prop_ic_removed     = n_ic_removed_unique / n_ic;

        summary_row = table( ...
            string(subj_label), ...
            string(run_base), ...
            string(ica_method), ...
            n_ic, ...
            n_ic_removed_unique, ...
            n_ic_remaining, ...
            prop_ic_removed, ...
            numel(ic_edge), ...
            numel(ic_eye), ...
            numel(ic_muscle), ...
            numel(ic_heart), ...
            numel(ic_line), ...
            numel(ic_ch_noise), ...
            numel(ic_other), ...
            numel(ic_low_brain), ...
            step_cfg.iclabel_eye_remove_thr, ...
            step_cfg.iclabel_muscle_remove_thr, ...
            step_cfg.iclabel_heart_remove_thr, ...
            step_cfg.iclabel_linenoise_remove_thr, ...
            step_cfg.iclabel_channoise_remove_thr, ...
            step_cfg.iclabel_other_remove_thr, ...
            step_cfg.iclabel_brain_min_keep_thr, ...
            step_cfg.iclabel_edge_margin, ...
            string(component_table_path), ...
            string(out_path), ...
            'VariableNames', { ...
                'subject_id', 'run_base', 'ica_method', ...
                'n_ic_total', 'n_ic_removed_unique', 'n_ic_remaining', 'prop_ic_removed', 'n_ic_edge_not_removed', ...
                'n_ic_flag_eye', 'n_ic_flag_muscle', 'n_ic_flag_heart', 'n_ic_flag_line_noise', ...
                'n_ic_flag_channel_noise', 'n_ic_flag_other', 'n_ic_flag_low_brain', ...
                'thr_eye', 'thr_muscle', 'thr_heart', 'thr_line_noise', 'thr_channel_noise', 'thr_other', 'thr_brain_min_keep', ...
                'edge_margin', 'component_table_path', 'output_set_path'});

        if isempty(summary_rows)
            summary_rows = summary_row;
        else
            summary_rows = [summary_rows; summary_row]; %#ok<AGROW>
        end

        if step_cfg.write_run_summary_table
            run_summary_path = fullfile( ...
                qc_method_dir, ...
                sprintf('%s_%s_prep05_run_summary.csv', subj_label, run_base_c));

            writetable(summary_row, run_summary_path, ...
                'Delimiter', char(string(step_cfg.qc_table_delimiter)));
        end

        EEG = helpers.safe_save_set(EEG, out_dir, out_name, helpers, cfg);
        helpers.log_msg_default('prep05_after_ica: saved: %s', out_path);

        outputs_written{end+1} = out_path; %#ok<AGROW>
    end

    if step_cfg.write_subject_summary_table && ~isempty(summary_rows)
        subject_summary_path = fullfile( ...
            qc_method_dir, ...
            sprintf('%s_prep05_summary.csv', subj_label));

        writetable(summary_rows, subject_summary_path, ...
            'Delimiter', char(string(step_cfg.qc_table_delimiter)));
    end

    if isempty(outputs_written)
        step_out.ok = false;
        step_out.message = sprintf('prep05_after_ica: no outputs for %s.', subj_label);
        return;
    end

    step_out.ok = true;
    step_out.message = sprintf('prep05_after_ica: OK (%d output file(s)).', numel(outputs_written));
    step_out.outputs = outputs_written;

catch me
    step_out.ok = false;
    step_out.message = sprintf('prep05_after_ica: %s', me.message);
end
end