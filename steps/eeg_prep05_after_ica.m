function step_out = eeg_prep05_after_ica(subj_id, cfg, paths, helpers)
% EEG_PREP05_AFTER_ICA
% Copyright (C) 2025-2026 Saskia Wilken and contributors
%
% Classify independent components with ICLabel, remove only the configured
% artifact classes, verify the resulting signal, and save QC tables before
% handing the data to epoching. Signal-QC failures are hard failures by
% default: the cleaned .set file is not written, while the failure reason
% and a corrective recommendation remain available in the normal QC files.

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
%  STEP CONFIGURATION DEFAULTS
% ========================================================================
step_cfg = struct();

step_cfg.clear_subject_ica_comps_dir = true;

% Each ICLabel removal rule has an independent switch. A higher threshold
% removes fewer components. "Other" and low-Brain rules are opt-in because
% they are broad, non-specific rules rather than named artifact classes.
step_cfg.iclabel_remove_eye           = true;
step_cfg.iclabel_remove_muscle        = true;
step_cfg.iclabel_remove_heart         = true;
step_cfg.iclabel_remove_linenoise     = true;
step_cfg.iclabel_remove_channoise     = true;
step_cfg.iclabel_remove_other         = false;
step_cfg.iclabel_remove_low_brain     = false;

step_cfg.iclabel_eye_remove_thr       = 0.85;
step_cfg.iclabel_muscle_remove_thr    = 0.85;
step_cfg.iclabel_heart_remove_thr     = 0.85;
step_cfg.iclabel_linenoise_remove_thr = 0.85;
step_cfg.iclabel_channoise_remove_thr = 0.85;
step_cfg.iclabel_other_remove_thr     = 0.95;
step_cfg.iclabel_brain_min_keep_thr   = 0.05;

step_cfg.save_ic_topos_png   = true;
step_cfg.iclabel_edge_margin = 0.10;
step_cfg.ic_topo_dpi         = 300;
step_cfg.ic_topo_fig_cm      = [0 0 18 18];
step_cfg.ic_topo_electrodes  = 'off';

% Conservative engineering safety rails. They are not universal EEG
% validity criteria and should be calibrated in the small pilot sample.
% The default scope excludes EOG channels so intended ocular cleanup does
% not by itself dominate the before/after comparison.
step_cfg.signal_qc_enable                         = true;
step_cfg.signal_qc_fail_on_violation              = true;
step_cfg.signal_qc_channel_scope                  = "eeg";
step_cfg.signal_qc_max_prop_ic_removed            = 0.50;
step_cfg.signal_qc_min_remaining_components       = 2;
step_cfg.signal_qc_min_median_channel_correlation = 0.80;
step_cfg.signal_qc_max_relative_change_rms        = 0.75;
step_cfg.signal_qc_min_rms_ratio                  = 0.50;
step_cfg.signal_qc_max_rms_ratio                  = 1.10;
step_cfg.signal_qc_fail_on_nonfinite              = true;
step_cfg.signal_qc_fail_on_flat_channels          = true;
step_cfg.signal_qc_flat_std_epsilon               = 1e-8;

% Enabled automatically by the runica-versus-AMICA pilot. This computes a
% deterministic, algorithm-independent residual pairwise-MI diagnostic on
% the IC activations before IC rejection. Lower values indicate more nearly
% independent components. It is a pilot comparison metric, not a hard gate.
step_cfg.compute_decomposition_qc    = false;
step_cfg.decomposition_qc_max_samples = 20000;
step_cfg.decomposition_qc_mi_bins     = 20;

step_cfg.write_component_table       = true;
step_cfg.write_run_summary_table     = true;
step_cfg.write_subject_summary_table = true;
step_cfg.qc_table_delimiter          = ';';
step_cfg.overwrite_mode              = "";

%% ========================================================================
%  MERGE AND VALIDATE CONFIGURATION
% ========================================================================
if isfield(cfg, 'prep_05') && isstruct(cfg.prep_05)
    step_cfg = helpers.merge_structs_recursive(step_cfg, cfg.prep_05);
end

if isfield(cfg, 'steps') && isfield(cfg.steps, 'prep_05_after_ica') && ...
        isstruct(cfg.steps.prep_05_after_ica) && ...
        isfield(cfg.steps.prep_05_after_ica, 'overwrite_mode') && ...
        strlength(string(cfg.steps.prep_05_after_ica.overwrite_mode)) > 0
    step_cfg.overwrite_mode = string(cfg.steps.prep_05_after_ica.overwrite_mode);
end

helpers.validate_prep05_config(step_cfg);
overwrite_mode = helpers.resolve_overwrite_mode(cfg, step_cfg.overwrite_mode);

%% ========================================================================
%  METHOD-SPECIFIC PATHS
% ========================================================================
ica_method = "unknown";
if isfield(cfg, 'prep_04') && isfield(cfg.prep_04, 'ica_method') && ...
        strlength(string(cfg.prep_04.ica_method)) > 0
    ica_method = lower(string(cfg.prep_04.ica_method));
end
ica_method_tag = lower(regexprep(char(ica_method), '[^\w\-]', '_'));

required_path_fields = { ...
    'prep_04_out_dir', 'prep_05_out_dir', 'qc_dir', ...
    'checks_ica_components_subj_dir'};
for pi = 1:numel(required_path_fields)
    field_name = required_path_fields{pi};
    if ~isfield(paths, field_name) || strlength(string(paths.(field_name))) == 0
        error('prep05_after_ica: paths.%s is missing or empty.', field_name);
    end
end

in_dir  = paths.prep_04_out_dir;
out_dir = paths.prep_05_out_dir;

qc_method_dir     = fullfile(paths.qc_dir, ica_method_tag);
checks_method_dir = fullfile(paths.checks_ica_components_subj_dir, ica_method_tag);
checks_rej_dir    = fullfile(checks_method_dir, REJECTED_TAG);
checks_edge_dir   = fullfile(checks_method_dir, EDGE_TAG);

helpers.ensure_dir(out_dir);
helpers.ensure_dir(qc_method_dir);

%% ========================================================================
%  FIND INPUTS
% ========================================================================
in_sets = dir(fullfile(in_dir, INPUT_FILE_GLOB));
if isempty(in_sets)
    step_out.ok = true;
    step_out.message = sprintf( ...
        'prep05_after_ica: no %s found for %s (skip).', ...
        INPUT_FILE_GLOB, subj_label);
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
        in_name    = in_sets(fi).name;
        run_base   = erase(string(in_name), INPUT_FILE_SUFFIX);
        run_base_c = char(run_base);
        out_name   = [run_base_c OUTPUT_SET_SUFFIX];
        out_path   = fullfile(out_dir, out_name);

        [do_run, reason] = helpers.step_should_run_outputs( ...
            {out_path}, overwrite_mode, cfg);
        helpers.log_msg_default( ...
            'prep05_after_ica: %s | %s | %s', ...
            subj_label, run_base_c, char(string(reason)));

        if ~do_run
            outputs_written{end+1} = out_path; %#ok<AGROW>
            continue;
        end

        if ~qa_dirs_prepared
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
        EEG = helpers.append_eeg_comment(EEG, ...
            sprintf('prep05_after_ica: input=%s', in_name));
        EEG = helpers.append_eeg_comment(EEG, ...
            sprintf('prep05_after_ica: ica_method=%s', char(ica_method)));

        n_ic = helpers.infer_n_ic(EEG);
        if n_ic < MIN_IC_COUNT
            error('prep05_after_ica:InsufficientICs', ...
                '%s | %s has only %d ICA component(s).', ...
                subj_label, run_base_c, n_ic);
        end

        if exist('iclabel', 'file') ~= 2
            error('prep05_after_ica:ICLabelMissing', ...
                'ICLabel not available on path (iclabel.m not found).');
        end

        EEG = iclabel(EEG);
        classif = helpers.get_iclabel_classifications(EEG, n_ic);
        flags = helpers.build_iclabel_flags(classif, step_cfg);
        ic_to_remove = find(flags.remove_any);
        ic_edge = find(flags.edge_any & ~flags.remove_any);

        n_ic_removed_unique = numel(ic_to_remove);
        n_ic_remaining = n_ic - n_ic_removed_unique;
        prop_ic_removed = n_ic_removed_unique / n_ic;

        if ~isfield(EEG, 'etc') || isempty(EEG.etc)
            EEG.etc = struct();
        end
        EEG.etc.ic_rejection = struct();
        EEG.etc.ic_rejection.mode = "iclabel_configurable_classes_with_signal_qc";
        EEG.etc.ic_rejection.ica_method = char(ica_method);
        EEG.etc.ic_rejection.ic_to_remove = ic_to_remove(:)';
        EEG.etc.ic_rejection.ic_edge = ic_edge(:)';
        EEG.etc.ic_rejection.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');

        EEG = helpers.append_eeg_comment(EEG, sprintf( ...
            ['prep05_after_ica: n_ic=%d | remove=%d | remaining=%d | ' ...
             'edge_not_removed=%d'], ...
            n_ic, n_ic_removed_unique, n_ic_remaining, numel(ic_edge)));

        helpers.log_msg_default( ...
            ['prep05_after_ica: %s | %s | method=%s | nIC=%d | ' ...
             'remove=%d | remaining=%d | edge=%d'], ...
            subj_label, run_base_c, char(ica_method), n_ic, ...
            n_ic_removed_unique, n_ic_remaining, numel(ic_edge));

        component_table_path = "";
        if step_cfg.write_component_table
            component_table = helpers.build_iclabel_component_table( ...
                subj_label, run_base, ica_method, classif, flags);
            component_table_path = fullfile(qc_method_dir, sprintf( ...
                '%s_%s_iclabel_components.csv', subj_label, run_base_c));
            writetable(component_table, component_table_path, ...
                'Delimiter', char(string(step_cfg.qc_table_delimiter)));
        end

        if step_cfg.save_ic_topos_png && ...
                (~isempty(ic_to_remove) || ~isempty(ic_edge))
            if exist('topoplot', 'file') ~= 2
                helpers.log_msg_default( ...
                    ['prep05_after_ica: %s | %s | topoplot missing -> ' ...
                     'skip QA PNG export.'], subj_label, run_base_c);
            else
                file_prefix = sprintf('%s_%s_%s', ...
                    subj_label, run_base_c, ica_method_tag);
                helpers.write_ic_topography_pngs( ...
                    EEG, ic_to_remove(:)', checks_rej_dir, file_prefix, ...
                    REJECTED_TAG, step_cfg, classif);
                helpers.write_ic_topography_pngs( ...
                    EEG, ic_edge(:)', checks_edge_dir, file_prefix, ...
                    EDGE_TAG, step_cfg, classif);
            end
        end

        decomposition_qc = helpers.empty_ica_decomposition_qc();
        if logical(step_cfg.compute_decomposition_qc)
            decomposition_qc = helpers.compute_ica_decomposition_qc(EEG, step_cfg);
            helpers.log_msg_default( ...
                ['prep05_after_ica: %s | %s | residual pairwise MI ' ...
                 'mean=%.6f bits | median=%.6f bits | pairs=%d'], ...
                subj_label, run_base_c, decomposition_qc.mean_pairwise_mi_bits, ...
                decomposition_qc.median_pairwise_mi_bits, ...
                decomposition_qc.n_component_pairs);
        end

        data_before = EEG.data;

        if ~isempty(ic_to_remove)
            if isfield(EEG, 'icaact')
                EEG.icaact = [];
            end
            EEG = eeg_checkset(EEG, 'ica');

            if exist('pop_subcomp', 'file') == 2
                EEG = pop_subcomp(EEG, ic_to_remove, 0);
            elseif exist('pop_rejcomp', 'file') == 2
                EEG.reject.gcompreject = false(1, n_ic);
                EEG.reject.gcompreject(ic_to_remove) = true;
                EEG = pop_rejcomp(EEG, ic_to_remove, 0);
            else
                error('prep05_after_ica:ComponentRemovalMissing', ...
                    'Neither pop_subcomp nor pop_rejcomp is available.');
            end

            EEG = eeg_checkset(EEG);
            EEG = helpers.append_eeg_comment(EEG, sprintf( ...
                'prep05_after_ica: removed ICs: %s', ...
                mat2str(ic_to_remove(:)')));
        else
            EEG = helpers.append_eeg_comment(EEG, ...
                'prep05_after_ica: no ICs removed');
        end

        signal_qc = helpers.evaluate_ic_rejection_signal_change( ...
            data_before, EEG.data, EEG, step_cfg, n_ic, ...
            n_ic_removed_unique, n_ic_remaining, flags);
        clear data_before;

        if signal_qc.status == "fail" && ...
                ~logical(step_cfg.signal_qc_fail_on_violation)
            signal_qc.status = "warning";
        end

        EEG.etc.ic_rejection.signal_qc = signal_qc;
        EEG.etc.ic_rejection.decomposition_qc = decomposition_qc;
        EEG = helpers.append_eeg_comment(EEG, sprintf( ...
            ['prep05_after_ica: signal_qc=%s | median_corr=%.4f | ' ...
             'relative_change_rms=%.4f | rms_ratio=%.4f'], ...
            char(signal_qc.status), ...
            signal_qc.median_channel_correlation, ...
            signal_qc.relative_change_rms, signal_qc.rms_ratio));

        prep04_qc = helpers.extract_prep04_qc_from_eeg(EEG);
        summary_row = helpers.build_prep05_summary_row( ...
            cfg, subj_label, run_base, ica_method, step_cfg, flags, ...
            signal_qc, decomposition_qc, prep04_qc, n_ic, ...
            n_ic_removed_unique, n_ic_remaining, prop_ic_removed, ...
            numel(ic_edge), component_table_path, out_path, false);

        if signal_qc.status == "fail"
            summary_rows = helpers.append_prep05_summary_row(summary_rows, summary_row);
            helpers.write_prep05_run_summary( ...
                summary_row, qc_method_dir, subj_label, run_base_c, step_cfg);
            helpers.write_prep05_subject_summary( ...
                summary_rows, qc_method_dir, subj_label, step_cfg);

            helpers.log_msg_default( ...
                ['prep05_after_ica: HARD QC FAIL | %s | %s | %s | ' ...
                 'action=%s'], subj_label, run_base_c, ...
                char(signal_qc.failure_reason), ...
                char(signal_qc.recommended_action));

            if logical(step_cfg.signal_qc_fail_on_violation)
                error('prep05_after_ica:SignalQCFailure', ...
                    '%s | %s | %s Recommended action: %s', ...
                    subj_label, run_base_c, ...
                    char(signal_qc.failure_reason), ...
                    char(signal_qc.recommended_action));
            end
        end

        EEG.setname = char(run_base + OUTPUT_SET_LABEL);
        EEG = helpers.safe_save_set(EEG, out_dir, out_name, helpers, cfg);
        helpers.log_msg_default('prep05_after_ica: saved: %s', out_path);

        summary_row.output_written(:) = true;
        summary_rows = helpers.append_prep05_summary_row(summary_rows, summary_row);
        helpers.write_prep05_run_summary( ...
            summary_row, qc_method_dir, subj_label, run_base_c, step_cfg);
        helpers.write_prep05_subject_summary( ...
            summary_rows, qc_method_dir, subj_label, step_cfg);

        outputs_written{end+1} = out_path; %#ok<AGROW>
    end

    if isempty(outputs_written)
        step_out.ok = false;
        step_out.message = sprintf( ...
            'prep05_after_ica: no outputs for %s.', subj_label);
        return;
    end

    step_out.ok = true;
    step_out.message = sprintf( ...
        'prep05_after_ica: OK (%d output file(s)).', ...
        numel(outputs_written));
    step_out.outputs = outputs_written;

catch me
    step_out.ok = false;
    step_out.message = sprintf('prep05_after_ica: %s', me.message);
end
end
