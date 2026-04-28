function step_out = eeg_prep06_epoching(subj_id, cfg, paths, helpers)
% EEG_PREP06_EPOCHING
%
% PURPOSE
%   Create final epoched datasets from post-ICA continuous data.
%
% SUPPORTED MODES
%   1) "event_locked"
%      - epoch around configured event markers
%
%   2) "baseline"
%      - segment continuous baseline into open/closed chunks
%      - create regular regepochs within each chunk
%
% ARTIFACT HANDLING ORDER
%   1) optional initial hard absolute-threshold rejection
%   2) sophisticated epoch rejection (preferred: EEG-only shared helper)
%   3) optional baseline correction
%   4) optional subject exclusion by per-condition minimum trial counts
%
% INPUT
%   paths.prep_05_out_dir
%       *_until_epoching.set
%
% OUTPUT
%   paths.prep_06_out_dir
%       event_locked:
%           *_epoched_final.set
%           or split outputs
%
%       baseline:
%           *_cond-open_epoched_final.set
%           *_cond-closed_epoched_final.set
%           or split outputs
%
% NOTES
%   - reference_mode defaults to "keep"
%   - output split keeps current "_NON_EEG" naming
%
% Saskia Wilken Dez 2025
% Updated Apr 2026

step_out = struct( ...
    'ok', false, ...
    'message', '', ...
    'outputs', {{}}, ...
    'summary_files', {{}});

SUBJ_LABEL        = sprintf('sub-%s', subj_id);
INPUT_FILE_GLOB   = '*_until_epoching.set';
INPUT_FILE_SUFFIX = "_until_epoching.set";

MODE_EVENT_LOCKED = "event_locked";
MODE_BASELINE     = "baseline";

OUTPUT_LABEL_FINAL  = "_epoched_final";
OUTPUT_LABEL_OPEN   = "_cond-open_epoched_final";
OUTPUT_LABEL_CLOSED = "_cond-closed_epoched_final";

%% ========================================================================
%  STEP CFG DEFAULTS
% ========================================================================
step_cfg = local_default_prep06_cfg_impl();

%% ========================================================================
%  MERGE USER CONFIG
% ========================================================================
if isfield(cfg, 'prep_06') && isstruct(cfg.prep_06)
    step_cfg = helpers.merge_structs_recursive(step_cfg, cfg.prep_06);
end

if isfield(cfg, 'steps') && isfield(cfg.steps, 'prep_06_epoching') && isstruct(cfg.steps.prep_06_epoching)
    if isfield(cfg.steps.prep_06_epoching, 'overwrite_mode') && ...
            strlength(string(cfg.steps.prep_06_epoching.overwrite_mode)) > 0
        step_cfg.overwrite_mode = string(cfg.steps.prep_06_epoching.overwrite_mode);
    end
end

step_cfg.epoching_mode = string(step_cfg.epoching_mode);
step_cfg.epoching_mode = step_cfg.epoching_mode(1);
step_cfg.epoching_mode = string(helpers.normalize_epoching_mode_value(step_cfg.epoching_mode));

OVERWRITE_MODE = helpers.resolve_overwrite_mode(cfg, step_cfg.overwrite_mode);

if step_cfg.epoching_mode == MODE_EVENT_LOCKED && ...
        isfield(step_cfg, 'min_trials_per_condition_enable') && ...
        step_cfg.min_trials_per_condition_enable && ...
        isempty(step_cfg.min_trials_per_condition_codes)
    error(['cfg.prep_06.min_trials_per_condition_codes is empty, but ' ...
           'cfg.prep_06.min_trials_per_condition_enable=true.']);
end

%% ========================================================================
%  PATHS
% ========================================================================
if ~isfield(paths, 'prep_05_out_dir') || strlength(string(paths.prep_05_out_dir)) == 0
    error('prep_06_epoching: paths.prep_05_out_dir is missing or empty.');
end

if ~isfield(paths, 'prep_06_out_dir') || strlength(string(paths.prep_06_out_dir)) == 0
    error('prep_06_epoching: paths.prep_06_out_dir is missing or empty.');
end

if ~isfield(paths, 'qc_dir') || strlength(string(paths.qc_dir)) == 0
    error('prep_06_epoching: paths.qc_dir is missing or empty.');
end

ica_method = "unknown";
if isfield(cfg, 'prep_04') && isfield(cfg.prep_04, 'ica_method') && ...
        strlength(string(cfg.prep_04.ica_method)) > 0
    ica_method = string(cfg.prep_04.ica_method);
end
ica_method_tag = lower(regexprep(char(ica_method), '[^\w\-]', '_'));

IN_DIR        = paths.prep_05_out_dir;
OUT_DIR       = paths.prep_06_out_dir;
QC_METHOD_DIR = fullfile(paths.qc_dir, ica_method_tag);

helpers.ensure_dir(OUT_DIR);
helpers.ensure_dir(QC_METHOD_DIR);

%% ========================================================================
%  FIND INPUTS
% ========================================================================
IN_SETS = dir(fullfile(IN_DIR, INPUT_FILE_GLOB));

if isempty(IN_SETS)
    step_out.ok = true;
    step_out.message = sprintf('prep_06_epoching: no %s found for %s (skip).', INPUT_FILE_GLOB, SUBJ_LABEL);
    helpers.log_msg_default('%s', step_out.message);
    return;
end

outputs_written = {};
summary_files   = {};
summary_rows    = table();

%% ========================================================================
%  MAIN LOOP
% ========================================================================
try
    for fi = 1:numel(IN_SETS)

        in_name_c  = IN_SETS(fi).name;
        in_name    = string(in_name_c);
        run_base   = erase(in_name, INPUT_FILE_SUFFIX);
        run_base_c = char(run_base);

        EEG_in = helpers.safe_load_set(IN_DIR, in_name_c, helpers);
        EEG_in = helpers.normalize_event_types(EEG_in);

        [idx_eeg, idx_eog, idx_non_eeg] = helpers.get_channel_indices_by_type(EEG_in);

        output_spec = helpers.build_epoching_output_paths( ...
            run_base, OUT_DIR, step_cfg, idx_eeg, idx_eog, idx_non_eeg);

        output_paths_expected = output_spec.all_paths;

        [do_run, reason] = helpers.step_should_run_outputs(output_paths_expected, OVERWRITE_MODE, cfg);
        helpers.log_msg_default('prep_06_epoching: %s | %s | %s', ...
            SUBJ_LABEL, run_base_c, char(string(reason)));

        if ~do_run
            for k = 1:numel(output_paths_expected)
                outputs_written{end+1} = output_paths_expected{k}; %#ok<AGROW>
            end
            continue;
        end

        if OVERWRITE_MODE == "delete"
            for k = 1:numel(output_paths_expected)
                if exist(output_paths_expected{k}, 'file') == 2
                    helpers.safe_delete_set(output_paths_expected{k});
                end
            end
        end

        EEG_in = helpers.append_eeg_comment(EEG_in, 'prep_06_epoching: start');
        EEG_in = helpers.append_eeg_comment(EEG_in, sprintf('prep_06_epoching: input=%s', in_name_c));
        EEG_in = helpers.append_eeg_comment(EEG_in, sprintf( ...
            'prep_06_epoching: channel counts EEG=%d | EOG=%d | NON_EEG=%d', ...
            numel(idx_eeg), numel(idx_eog), numel(idx_non_eeg)));

        EEG_ref = helpers.apply_reference_mode(EEG_in, step_cfg, helpers);

        run_summary_rows = table();

        switch step_cfg.epoching_mode

            case MODE_EVENT_LOCKED

                target_events = helpers.normalize_event_list(step_cfg.events_phase);

                if isempty(target_events)
                    error('cfg.prep_06.events_phase is missing or empty for epoching_mode="event_locked".');
                end

                present_events = helpers.get_present_events(EEG_ref, target_events);

                if isempty(present_events)
                    found_preview = helpers.preview_event_types(EEG_ref, 25);
                    error(['prep_06_epoching: none of cfg.prep_06.events_phase are present in input set. ' ...
                           'This usually means Step 02 triggerfix was skipped or cfg.prep_06.events_phase does not match the dataset. ' ...
                           'Requested=%s | Found examples=%s'], ...
                        strjoin(cellstr(target_events), ', '), ...
                        strjoin(cellstr(found_preview), ', '));
                end

                if numel(present_events) < numel(target_events)
                    missing_events = setdiff(target_events, present_events, 'stable');
                    helpers.log_msg_default( ...
                        'prep_06_epoching: %s | %s | WARNING only %d/%d requested events are present. Missing: %s', ...
                        SUBJ_LABEL, run_base_c, numel(present_events), numel(target_events), ...
                        strjoin(cellstr(missing_events), ', '));
                end

                EEG_ep = pop_epoch( ...
                    EEG_ref, ...
                    cellstr(present_events), ...
                    [step_cfg.epoch_start_s step_cfg.epoch_end_s], ...
                    'newname', sprintf('%s_epoched', run_base_c), ...
                    'epochinfo', 'yes');

                EEG_ep = eeg_checkset(EEG_ep);

                try
                    EEG_ep.times = round(linspace( ...
                        step_cfg.epoch_start_s * 1000, ...
                        step_cfg.epoch_end_s   * 1000, ...
                        size(EEG_ep.data, 2)));
                catch
                end

                EEG_ep = helpers.append_eeg_comment(EEG_ep, sprintf( ...
                    'prep_06_epoching: event_locked epoching | n_requested=%d | n_present=%d | window=[%.3f %.3f] s', ...
                    numel(target_events), numel(present_events), step_cfg.epoch_start_s, step_cfg.epoch_end_s));

                base_stem = run_base + OUTPUT_LABEL_FINAL;

                [EEG_final, rej_info] = helpers.finalize_epoched_dataset( ...
                    EEG_ep, base_stem, OUT_DIR, step_cfg, cfg, helpers, SUBJ_LABEL, run_base);

                saved_paths  = {};
                status_label = "empty_after_rejection";

                if ~rej_info.excluded && EEG_final.trials > 0 && step_cfg.min_trials_per_condition_enable
                    [min_ok, min_info] = helpers.evaluate_min_trials_per_condition( ...
                        EEG_final, ...
                        step_cfg.min_trials_per_condition_codes, ...
                        step_cfg.min_trials_per_condition_min_n, ...
                        step_cfg.min_trials_per_condition_zero_tol_ms);

                    rej_info.min_trials_required               = min_info.min_required;
                    rej_info.min_trials_condition_counts       = min_info.counts_joined;
                    rej_info.min_trials_insufficient_conditions = min_info.insufficient_joined;

                    if min_ok
                        helpers.log_msg_default( ...
                            'prep_06_epoching: %s | %s | min-trials PASS | required=%d | counts=%s', ...
                            SUBJ_LABEL, run_base_c, min_info.min_required, char(min_info.counts_joined));

                        EEG_final = helpers.append_eeg_comment(EEG_final, sprintf( ...
                            'prep_06_epoching: min-trials rule passed | min_n=%d | counts=%s', ...
                            min_info.min_required, char(min_info.counts_joined)));
                    else
                        rej_info.excluded                   = true;
                        rej_info.excluded_by_min_trials_rule = true;
                        rej_info.exclusion_reason           = "min_trials_per_condition";
                        status_label                        = "excluded";

                        helpers.log_msg_default( ...
                            ['prep_06_epoching: %s | %s | dataset excluded by min-trials rule | ' ...
                             'required=%d | counts=%s | insufficient=%s'], ...
                            SUBJ_LABEL, run_base_c, min_info.min_required, ...
                            char(min_info.counts_joined), char(min_info.insufficient_joined));

                        EEG_final = helpers.append_eeg_comment(EEG_final, sprintf( ...
                            ['prep_06_epoching: dataset excluded by min-trials rule | ' ...
                             'min_n=%d | counts=%s | insufficient=%s'], ...
                            min_info.min_required, ...
                            char(min_info.counts_joined), ...
                            char(min_info.insufficient_joined)));
                    end
                end

                if ~rej_info.excluded && EEG_final.trials > 0
                    saved_paths = helpers.save_final_epoched_outputs( ...
                        EEG_final, base_stem, OUT_DIR, step_cfg, cfg, helpers);

                    for k = 1:numel(saved_paths)
                        outputs_written{end+1} = saved_paths{k}; %#ok<AGROW>
                    end
                    status_label = "saved";

                elseif rej_info.excluded
                    status_label = "excluded";
                    helpers.log_msg_default( ...
                        'prep_06_epoching: %s | %s | event_locked dataset excluded.', ...
                        SUBJ_LABEL, run_base_c);

                else
                    helpers.log_msg_default( ...
                        'prep_06_epoching: %s | %s | no final event_locked dataset written.', ...
                        SUBJ_LABEL, run_base_c);
                end

                row_event_locked = helpers.build_step06_summary_row( ...
                    SUBJ_LABEL, run_base, ica_method, step_cfg, ...
                    MODE_EVENT_LOCKED, "event_locked", ...
                    in_name, rej_info, saved_paths, status_label, ...
                    numel(idx_eeg), numel(idx_eog), numel(idx_non_eeg));

                run_summary_rows = row_event_locked;

            case MODE_BASELINE

                [EEG_open, EEG_closed] = helpers.create_baseline_condition_datasets( ...
                    EEG_ref, step_cfg, helpers, run_base);

                if ~isempty(EEG_open) && EEG_open.trials > 0
                    base_stem_open = run_base + OUTPUT_LABEL_OPEN;

                    [EEG_open_final, rej_info_open] = helpers.finalize_epoched_dataset( ...
                        EEG_open, base_stem_open, OUT_DIR, step_cfg, cfg, helpers, SUBJ_LABEL, run_base + "_open");

                    saved_paths_open = {};
                    status_open      = "empty_after_rejection";

                    if ~rej_info_open.excluded && EEG_open_final.trials > 0
                        saved_paths_open = helpers.save_final_epoched_outputs( ...
                            EEG_open_final, base_stem_open, OUT_DIR, step_cfg, cfg, helpers);

                        for k = 1:numel(saved_paths_open)
                            outputs_written{end+1} = saved_paths_open{k}; %#ok<AGROW>
                        end
                        status_open = "saved";

                    elseif rej_info_open.excluded
                        status_open = "excluded";
                        helpers.log_msg_default( ...
                            'prep_06_epoching: %s | %s | baseline OPEN dataset excluded.', ...
                            SUBJ_LABEL, run_base_c);

                    else
                        helpers.log_msg_default( ...
                            'prep_06_epoching: %s | %s | baseline OPEN dataset empty after rejection.', ...
                            SUBJ_LABEL, run_base_c);
                    end

                    row_open = helpers.build_step06_summary_row( ...
                        SUBJ_LABEL, run_base, ica_method, step_cfg, ...
                        MODE_BASELINE, "open", ...
                        in_name, rej_info_open, saved_paths_open, status_open, ...
                        numel(idx_eeg), numel(idx_eog), numel(idx_non_eeg));

                    if isempty(run_summary_rows)
                        run_summary_rows = row_open;
                    else
                        run_summary_rows = [run_summary_rows; row_open]; %#ok<AGROW>
                    end
                else
                    helpers.log_msg_default( ...
                        'prep_06_epoching: %s | %s | no OPEN dataset created.', ...
                        SUBJ_LABEL, run_base_c);
                end

                if ~isempty(EEG_closed) && EEG_closed.trials > 0
                    base_stem_closed = run_base + OUTPUT_LABEL_CLOSED;

                    [EEG_closed_final, rej_info_closed] = helpers.finalize_epoched_dataset( ...
                        EEG_closed, base_stem_closed, OUT_DIR, step_cfg, cfg, helpers, SUBJ_LABEL, run_base + "_closed");

                    saved_paths_closed = {};
                    status_closed      = "empty_after_rejection";

                    if ~rej_info_closed.excluded && EEG_closed_final.trials > 0
                        saved_paths_closed = helpers.save_final_epoched_outputs( ...
                            EEG_closed_final, base_stem_closed, OUT_DIR, step_cfg, cfg, helpers);

                        for k = 1:numel(saved_paths_closed)
                            outputs_written{end+1} = saved_paths_closed{k}; %#ok<AGROW>
                        end
                        status_closed = "saved";

                    elseif rej_info_closed.excluded
                        status_closed = "excluded";
                        helpers.log_msg_default( ...
                            'prep_06_epoching: %s | %s | baseline CLOSED dataset excluded.', ...
                            SUBJ_LABEL, run_base_c);

                    else
                        helpers.log_msg_default( ...
                            'prep_06_epoching: %s | %s | baseline CLOSED dataset empty after rejection.', ...
                            SUBJ_LABEL, run_base_c);
                    end

                    row_closed = helpers.build_step06_summary_row( ...
                        SUBJ_LABEL, run_base, ica_method, step_cfg, ...
                        MODE_BASELINE, "closed", ...
                        in_name, rej_info_closed, saved_paths_closed, status_closed, ...
                        numel(idx_eeg), numel(idx_eog), numel(idx_non_eeg));

                    if isempty(run_summary_rows)
                        run_summary_rows = row_closed;
                    else
                        run_summary_rows = [run_summary_rows; row_closed]; %#ok<AGROW>
                    end
                else
                    helpers.log_msg_default( ...
                        'prep_06_epoching: %s | %s | no CLOSED dataset created.', ...
                        SUBJ_LABEL, run_base_c);
                end

                if isempty(run_summary_rows)
                    helpers.log_msg_default( ...
                        'prep_06_epoching: %s | %s | WARNING: no baseline output written.', ...
                        SUBJ_LABEL, run_base_c);
                end

            otherwise
                error('Unsupported cfg.prep_06.epoching_mode: %s', char(step_cfg.epoching_mode));
        end

        if ~isempty(run_summary_rows)
            if isempty(summary_rows)
                summary_rows = run_summary_rows;
            else
                summary_rows = [summary_rows; run_summary_rows]; %#ok<AGROW>
            end

            if step_cfg.write_run_summary_table
                run_summary_path = fullfile( ...
                    QC_METHOD_DIR, ...
                    sprintf('%s_%s_prep06_run_summary.csv', SUBJ_LABEL, run_base_c));

                writetable(run_summary_rows, run_summary_path, ...
                    'Delimiter', char(string(step_cfg.qc_table_delimiter)));

                summary_files{end+1} = run_summary_path; %#ok<AGROW>
            end
        end
    end

    if step_cfg.write_subject_summary_table && ~isempty(summary_rows)
        subject_summary_path = fullfile( ...
            QC_METHOD_DIR, ...
            sprintf('%s_prep06_summary.csv', SUBJ_LABEL));

        writetable(summary_rows, subject_summary_path, ...
            'Delimiter', char(string(step_cfg.qc_table_delimiter)));

        summary_files{end+1} = subject_summary_path; %#ok<AGROW>
    end

    if isempty(outputs_written)
        step_out.ok = false;
        step_out.message = sprintf('prep_06_epoching: no outputs written for %s.', SUBJ_LABEL);
        return;
    end

    step_out.ok = true;
    step_out.outputs = outputs_written;
    step_out.summary_files = summary_files;
    step_out.message = sprintf('prep_06_epoching: OK (%d output file(s)).', numel(outputs_written));

catch me
    helpers.log_msg_default('prep_06_epoching DEBUG CATCH | identifier=%s', me.identifier);
    helpers.log_msg_default('prep_06_epoching DEBUG CATCH | message=%s', me.message);

    try
        for si = 1:numel(me.stack)
            helpers.log_msg_default( ...
                'prep_06_epoching DEBUG STACK | #%d | file=%s | name=%s | line=%d', ...
                si, me.stack(si).file, me.stack(si).name, me.stack(si).line);
        end
    catch
    end

    step_out.ok = false;
    step_out.message = sprintf('prep_06_epoching: %s', me.message);
end
end

function step_cfg = local_default_prep06_cfg_impl()
step_cfg = struct();

% -------------------------------------------------------------------------
% GENERAL
% -------------------------------------------------------------------------
step_cfg.epoching_mode  = "event_locked";
step_cfg.overwrite_mode = "";

step_cfg.save_final_only         = true;
step_cfg.save_intermediate_steps = false;
step_cfg.savemode                = 'twofiles';

% -------------------------------------------------------------------------
% REFERENCING
% -------------------------------------------------------------------------
step_cfg.reference_mode            = "keep";
step_cfg.mastoid_channel_labels    = {'T9','T10'};
step_cfg.reference_exclude_non_eeg = true;

% -------------------------------------------------------------------------
% EVENT-LOCKED EPOCHING
% -------------------------------------------------------------------------
step_cfg.events_phase  = {};
step_cfg.epoch_start_s = -0.4;
step_cfg.epoch_end_s   =  2.6;

% -------------------------------------------------------------------------
% BASELINE EPOCHING
% -------------------------------------------------------------------------
step_cfg.regepoch_length_sec = 10;
step_cfg.regepoch_step_sec   = 10;

step_cfg.baseline_start_condition        = "open";
step_cfg.baseline_open_marker_prefixes   = {'S 1'};
step_cfg.baseline_closed_marker_prefixes = {'S 2'};
step_cfg.baseline_end_markers            = {'S 99'};

% -------------------------------------------------------------------------
% ARTIFACT REJECTION
% -------------------------------------------------------------------------
step_cfg.do_artifact_rejection               = true;
step_cfg.do_initial_hard_threshold_rejection = false;
step_cfg.initial_hard_threshold_uv           = 100;

step_cfg.use_faster                    = true;
step_cfg.faster_z_thresh               = 3;
step_cfg.faster_use_robust_z           = true;
step_cfg.faster_warn_if_reject_prop_gt = 0.25;

step_cfg.use_ptp       = true;
step_cfg.ptp_uV_thresh = 300;

step_cfg.max_reject_prop = 1;

% -------------------------------------------------------------------------
% BASELINE CORRECTION
% -------------------------------------------------------------------------
step_cfg.do_baseline_correction = false;
step_cfg.base_start_ms          = -200;
step_cfg.base_end_ms            = 0;

% -------------------------------------------------------------------------
% OUTPUT SPLITTING
% -------------------------------------------------------------------------
step_cfg.split_non_eeg_channels = false;
step_cfg.eeg_only_keep_eog      = false;

% -------------------------------------------------------------------------
% SHARED EPOCH REJECTION
% -------------------------------------------------------------------------
step_cfg.shared_epoch_rejection = struct();
step_cfg.shared_epoch_rejection.enable          = true;
step_cfg.shared_epoch_rejection.use_faster      = true;
step_cfg.shared_epoch_rejection.faster_z        = 3;
step_cfg.shared_epoch_rejection.use_robust_z    = true;
step_cfg.shared_epoch_rejection.use_ptp         = true;
step_cfg.shared_epoch_rejection.ptp_uV_thresh   = 300;
step_cfg.shared_epoch_rejection.max_reject_prop = 1;

% -------------------------------------------------------------------------
% MINIMUM TRIALS PER CONDITION (event_locked only)
% -------------------------------------------------------------------------
step_cfg.min_trials_per_condition_enable      = false;
step_cfg.min_trials_per_condition_min_n       = 3;
step_cfg.min_trials_per_condition_zero_tol_ms = 2;
step_cfg.min_trials_per_condition_codes       = {};

% -------------------------------------------------------------------------
% SUMMARY TABLES
% -------------------------------------------------------------------------
step_cfg.write_run_summary_table     = true;
step_cfg.write_subject_summary_table = true;
step_cfg.qc_table_delimiter          = ';';
end