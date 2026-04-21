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
%   1) initial hard absolute-threshold rejection
%   2) sophisticated epoch rejection
%   3) optional baseline correction
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
%   - max_reject_prop <= 0 disables subject-level exclusion
%   - output split keeps current "_NON_EEG" naming

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
step_cfg = struct();

% -------------------------------------------------------------------------
% GENERAL
% -------------------------------------------------------------------------
step_cfg.epoching_mode  = MODE_EVENT_LOCKED;
step_cfg.overwrite_mode = "";

step_cfg.save_final_only         = true;
step_cfg.save_intermediate_steps = false;
step_cfg.savemode                = 'twofiles';

% -------------------------------------------------------------------------
% REFERENCING
% -------------------------------------------------------------------------
step_cfg.reference_mode         = "keep";   % "keep" | "avg" | "mastoid"
step_cfg.mastoid_channel_labels = {'T9','T10'};

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
step_cfg.do_artifact_rejection = true;

step_cfg.do_initial_hard_threshold_rejection = true;
step_cfg.initial_hard_threshold_uv           = 100;

step_cfg.use_faster                    = true;
step_cfg.faster_z_thresh               = 3;
step_cfg.faster_use_robust_z           = false;
step_cfg.faster_warn_if_reject_prop_gt = 0.25;

step_cfg.use_ptp       = true;
step_cfg.ptp_uV_thresh = 600;

step_cfg.max_reject_prop = 0;  % <= 0 means: do not exclude subject/dataset

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
step_cfg.shared_epoch_rejection.enable          = false;
step_cfg.shared_epoch_rejection.use_faster      = true;
step_cfg.shared_epoch_rejection.faster_z        = 3;
step_cfg.shared_epoch_rejection.use_robust_z    = false;
step_cfg.shared_epoch_rejection.use_ptp         = true;
step_cfg.shared_epoch_rejection.ptp_uV_thresh   = 600;
step_cfg.shared_epoch_rejection.max_reject_prop = 0;

% -------------------------------------------------------------------------
% SUMMARY TABLES
% -------------------------------------------------------------------------
step_cfg.write_run_summary_table     = true;
step_cfg.write_subject_summary_table = true;
step_cfg.qc_table_delimiter          = ';';

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

OVERWRITE_MODE = helpers.resolve_overwrite_mode(cfg, step_cfg.overwrite_mode);

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

        output_paths_expected = build_output_paths_for_run_local( ...
            run_base, OUT_DIR, step_cfg, idx_eeg, idx_eog, idx_non_eeg, ...
            MODE_EVENT_LOCKED, MODE_BASELINE, ...
            OUTPUT_LABEL_FINAL, OUTPUT_LABEL_OPEN, OUTPUT_LABEL_CLOSED);

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

        switch string(step_cfg.epoching_mode)

            case MODE_EVENT_LOCKED

                target_events = normalize_event_list_local(step_cfg.events_phase, helpers);

                if isempty(target_events)
                    error('cfg.prep_06.events_phase is missing or empty for epoching_mode="event_locked".');
                end

                present_events = get_present_events_local(EEG_ref, target_events, helpers);

                if isempty(present_events)
                    found_preview = preview_event_types_local(EEG_ref, 25, helpers);
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

                [EEG_final, rej_info] = finalize_epoched_dataset_local( ...
                    EEG_ep, base_stem, OUT_DIR, step_cfg, cfg, helpers, SUBJ_LABEL, run_base);

                saved_paths  = {};
                status_label = "empty_after_rejection";

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

                row_event_locked = build_step06_summary_row_local( ...
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

                    [EEG_open_final, rej_info_open] = finalize_epoched_dataset_local( ...
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

                    row_open = build_step06_summary_row_local( ...
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

                    [EEG_closed_final, rej_info_closed] = finalize_epoched_dataset_local( ...
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

                    row_closed = build_step06_summary_row_local( ...
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
                error('Unsupported cfg.prep_06.epoching_mode: %s', char(string(step_cfg.epoching_mode)));
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
    step_out.ok = false;
    step_out.message = sprintf('prep_06_epoching: %s', me.message);
end
end

%% =========================================================================
%  LOCAL HELPERS
% =========================================================================
function out_paths = build_output_paths_for_run_local( ...
    run_base, out_dir, step_cfg, idx_eeg, idx_eog, idx_non_eeg, ...
    MODE_EVENT_LOCKED, MODE_BASELINE, ...
    OUTPUT_LABEL_FINAL, OUTPUT_LABEL_OPEN, OUTPUT_LABEL_CLOSED)

out_paths = {};

switch string(step_cfg.epoching_mode)

    case MODE_EVENT_LOCKED
        base_stem = string(run_base) + OUTPUT_LABEL_FINAL;
        out_paths = build_output_paths_for_base_stem_local(base_stem, out_dir, step_cfg, idx_eeg, idx_eog, idx_non_eeg);

    case MODE_BASELINE
        base_stem_open   = string(run_base) + OUTPUT_LABEL_OPEN;
        base_stem_closed = string(run_base) + OUTPUT_LABEL_CLOSED;

        out_open   = build_output_paths_for_base_stem_local(base_stem_open,   out_dir, step_cfg, idx_eeg, idx_eog, idx_non_eeg);
        out_closed = build_output_paths_for_base_stem_local(base_stem_closed, out_dir, step_cfg, idx_eeg, idx_eog, idx_non_eeg);

        out_paths = [out_open(:); out_closed(:)];

    otherwise
        error('Unsupported cfg.prep_06.epoching_mode: %s', char(string(step_cfg.epoching_mode)));
end
end

function out_paths = build_output_paths_for_base_stem_local(base_stem, out_dir, step_cfg, idx_eeg, idx_eog, idx_non_eeg)
out_paths = {};

if step_cfg.split_non_eeg_channels
    out_paths{end+1,1} = fullfile(out_dir, char(string(base_stem) + "_EEG.set")); %#ok<AGROW>

    if step_cfg.eeg_only_keep_eog
        secondary_idx = idx_non_eeg(:);
    else
        secondary_idx = unique([idx_eog(:); idx_non_eeg(:)]);
    end

    if ~isempty(secondary_idx)
        out_paths{end+1,1} = fullfile(out_dir, char(string(base_stem) + "_NON_EEG.set")); %#ok<AGROW>
    end
else
    out_paths{end+1,1} = fullfile(out_dir, char(string(base_stem) + ".set")); %#ok<AGROW>
end
end

function target_events = normalize_event_list_local(event_list, helpers)
target_events = strings(0,1);

if isempty(event_list)
    return;
end

if ischar(event_list) || isstring(event_list)
    event_list = cellstr(string(event_list));
end

for i = 1:numel(event_list)
    tok = string(helpers.normalize_trigger_type(event_list{i}));
    if strlength(tok) > 0
        target_events(end+1,1) = tok; %#ok<AGROW>
    end
end

target_events = unique(target_events, 'stable');
end

function present_events = get_present_events_local(EEG, target_events, helpers)
present_events = strings(0,1);

if ~isfield(EEG, 'event') || isempty(EEG.event)
    return;
end

all_types = strings(0,1);
for k = 1:numel(EEG.event)
    tok = string(helpers.normalize_trigger_type(EEG.event(k).type));
    if tok == "boundary" || strlength(tok) == 0
        continue;
    end
    all_types(end+1,1) = tok; %#ok<AGROW>
end

all_types = unique(all_types, 'stable');
present_events = intersect(target_events, all_types, 'stable');
end

function preview = preview_event_types_local(EEG, n_max, helpers)
preview = strings(0,1);

if nargin < 2 || isempty(n_max)
    n_max = 25;
end

if ~isfield(EEG, 'event') || isempty(EEG.event)
    return;
end

all_types = strings(0,1);
for k = 1:numel(EEG.event)
    tok = string(helpers.normalize_trigger_type(EEG.event(k).type));
    if tok == "boundary" || strlength(tok) == 0
        continue;
    end
    all_types(end+1,1) = tok; %#ok<AGROW>
end

all_types = unique(all_types, 'stable');
preview = all_types(1:min(n_max, numel(all_types)));
end

function [EEG_final, rej_info] = finalize_epoched_dataset_local( ...
    EEG_ep, base_stem, out_dir, step_cfg, cfg, helpers, subj_label, run_label)

EEG_final = EEG_ep;

rej_info = struct();
rej_info.excluded = false;
rej_info.n_total  = EEG_ep.trials;
rej_info.n_rejected_hard = 0;
rej_info.n_rejected_sophisticated = 0;
rej_info.n_rejected_total = 0;
rej_info.n_kept = EEG_ep.trials;

if step_cfg.save_intermediate_steps && ~step_cfg.save_final_only
    helpers.save_intermediate_set( ...
        EEG_ep, out_dir, string(base_stem) + "_stage-epoched", ...
        "delete", cfg, step_cfg.savemode, helpers);
end

[idx_eeg, ~, ~] = helpers.get_channel_indices_by_type(EEG_ep);
EEG_work = EEG_ep;

if step_cfg.do_artifact_rejection

    if isempty(idx_eeg) || EEG_work.trials < 1
        EEG_work = helpers.append_eeg_comment(EEG_work, ...
            'prep_06_epoching: artifact rejection skipped (no EEG channels or no epochs)');

    else
        if step_cfg.do_initial_hard_threshold_rejection
            [EEG_work, hard_info] = helpers.apply_hard_epoch_threshold_rejection( ...
                EEG_work, idx_eeg, step_cfg.initial_hard_threshold_uv);

            rej_info.n_rejected_hard = hard_info.n_rejected;
            rej_info.n_kept = EEG_work.trials;

            EEG_work = helpers.append_eeg_comment(EEG_work, sprintf( ...
                'prep_06_epoching: hard threshold rejection | abs(amplitude) > %.1f uV | rejected=%d/%d | kept=%d', ...
                step_cfg.initial_hard_threshold_uv, ...
                hard_info.n_rejected, ...
                hard_info.n_total, ...
                hard_info.n_kept));

            helpers.log_msg_default( ...
                'prep_06_epoching: %s | %s | hard rejection=%d/%d | kept=%d | threshold=%.1f uV', ...
                char(string(subj_label)), char(string(run_label)), ...
                hard_info.n_rejected, hard_info.n_total, hard_info.n_kept, ...
                step_cfg.initial_hard_threshold_uv);

            if step_cfg.save_intermediate_steps && ~step_cfg.save_final_only
                helpers.save_intermediate_set( ...
                    EEG_work, out_dir, string(base_stem) + "_stage-hardrejected", ...
                    "delete", cfg, step_cfg.savemode, helpers);
            end
        else
            EEG_work = helpers.append_eeg_comment(EEG_work, ...
                'prep_06_epoching: hard threshold rejection skipped by config');
        end

        if EEG_work.trials >= 1
            use_shared = ...
                isfield(step_cfg, 'shared_epoch_rejection') && ...
                isstruct(step_cfg.shared_epoch_rejection) && ...
                isfield(step_cfg.shared_epoch_rejection, 'enable') && ...
                step_cfg.shared_epoch_rejection.enable;

            if use_shared
                [EEG_work, shared_info] = helpers.apply_shared_epoch_rejection( ...
                    EEG_work, step_cfg.shared_epoch_rejection);

                rej_info.n_rejected_sophisticated = shared_info.n_rejected;
                rej_info.n_kept = EEG_work.trials;

                EEG_work = helpers.append_eeg_comment(EEG_work, sprintf( ...
                    'prep_06_epoching: shared rejection after hard threshold | rejected=%d/%d | kept=%d', ...
                    shared_info.n_rejected, shared_info.n_before, EEG_work.trials));

                helpers.log_msg_default( ...
                    'prep_06_epoching: %s | %s | shared rejection=%d/%d | kept=%d', ...
                    char(string(subj_label)), char(string(run_label)), ...
                    shared_info.n_rejected, shared_info.n_before, EEG_work.trials);

            else
                [EEG_work, soft_info] = helpers.apply_fallback_epoch_rejection( ...
                    EEG_work, idx_eeg, step_cfg);

                rej_info.n_rejected_sophisticated = soft_info.n_rejected;
                rej_info.n_kept = EEG_work.trials;

                EEG_work = helpers.append_eeg_comment(EEG_work, sprintf( ...
                    'prep_06_epoching: fallback rejection after hard threshold | rejected=%d/%d | kept=%d | robust=%d', ...
                    soft_info.n_rejected, soft_info.n_total, soft_info.n_kept, soft_info.robust_z));

                helpers.log_msg_default( ...
                    'prep_06_epoching: %s | %s | fallback rejection=%d/%d | kept=%d', ...
                    char(string(subj_label)), char(string(run_label)), ...
                    soft_info.n_rejected, soft_info.n_total, soft_info.n_kept);
            end

            if step_cfg.save_intermediate_steps && ~step_cfg.save_final_only
                helpers.save_intermediate_set( ...
                    EEG_work, out_dir, string(base_stem) + "_stage-artifactrejected", ...
                    "delete", cfg, step_cfg.savemode, helpers);
            end
        else
            helpers.log_msg_default( ...
                'prep_06_epoching: %s | %s | no epochs left after hard threshold rejection', ...
                char(string(subj_label)), char(string(run_label)));
        end
    end
else
    EEG_work = helpers.append_eeg_comment(EEG_work, ...
        'prep_06_epoching: artifact rejection disabled by config');
end

rej_info.n_rejected_total = max(0, rej_info.n_total - EEG_work.trials);
rej_info.n_kept = EEG_work.trials;

if rej_info.n_total > 0
    prop_rejected = rej_info.n_rejected_total / rej_info.n_total;
else
    prop_rejected = 0;
end

apply_max_reject_exclusion = ...
    isfield(step_cfg, 'max_reject_prop') && ...
    ~isempty(step_cfg.max_reject_prop) && ...
    isscalar(step_cfg.max_reject_prop) && ...
    isfinite(step_cfg.max_reject_prop) && ...
    (step_cfg.max_reject_prop > 0);

if apply_max_reject_exclusion && (prop_rejected > step_cfg.max_reject_prop)
    rej_info.excluded = true;

    EEG_work = helpers.append_eeg_comment(EEG_work, sprintf( ...
        ['prep_06_epoching: dataset excluded | rejected %.1f%% of epochs ' ...
         '(threshold %.1f%%) | hard=%d | sophisticated=%d'], ...
        100 * prop_rejected, ...
        100 * step_cfg.max_reject_prop, ...
        rej_info.n_rejected_hard, ...
        rej_info.n_rejected_sophisticated));

    helpers.log_msg_default( ...
        'prep_06_epoching: %s | %s | dataset excluded | rejected %.1f%% of epochs', ...
        char(string(subj_label)), char(string(run_label)), 100 * prop_rejected);

    EEG_final = EEG_work;
    return;
end

EEG_final = EEG_work;

if step_cfg.do_baseline_correction && EEG_final.trials >= 1
    EEG_final = pop_rmbase(EEG_final, [step_cfg.base_start_ms step_cfg.base_end_ms]);
    EEG_final = eeg_checkset(EEG_final);
    EEG_final = helpers.append_eeg_comment(EEG_final, sprintf( ...
        'prep_06_epoching: baseline correction applied [%d %d] ms', ...
        step_cfg.base_start_ms, step_cfg.base_end_ms));

    if step_cfg.save_intermediate_steps && ~step_cfg.save_final_only
        helpers.save_intermediate_set( ...
            EEG_final, out_dir, string(base_stem) + "_stage-baselinecorrected", ...
            "delete", cfg, step_cfg.savemode, helpers);
    end
else
    EEG_final = helpers.append_eeg_comment(EEG_final, ...
        'prep_06_epoching: baseline correction skipped');
end
end

function row = build_step06_summary_row_local( ...
    subj_label, run_base, ica_method, step_cfg, ...
    epoching_mode, condition_label, ...
    input_name, rej_info, saved_paths, status_label, ...
    n_eeg, n_eog, n_non_eeg)

if nargin < 9 || isempty(saved_paths)
    saved_paths = {};
end

output_paths_joined = "";
if ~isempty(saved_paths)
    output_paths_joined = strjoin(string(saved_paths), ' | ');
end

prop_rejected_total = NaN;
if isfield(rej_info, 'n_total') && rej_info.n_total > 0
    prop_rejected_total = rej_info.n_rejected_total / rej_info.n_total;
end

shared_enable = false;
shared_faster_z = NaN;
shared_ptp = NaN;
shared_robust = false;

if isfield(step_cfg, 'shared_epoch_rejection') && isstruct(step_cfg.shared_epoch_rejection)
    if isfield(step_cfg.shared_epoch_rejection, 'enable')
        shared_enable = logical(step_cfg.shared_epoch_rejection.enable);
    end
    if isfield(step_cfg.shared_epoch_rejection, 'faster_z')
        shared_faster_z = step_cfg.shared_epoch_rejection.faster_z;
    end
    if isfield(step_cfg.shared_epoch_rejection, 'ptp_uV_thresh')
        shared_ptp = step_cfg.shared_epoch_rejection.ptp_uV_thresh;
    end
    if isfield(step_cfg.shared_epoch_rejection, 'use_robust_z')
        shared_robust = logical(step_cfg.shared_epoch_rejection.use_robust_z);
    end
end

row = table( ...
    string(subj_label), ...
    string(run_base), ...
    string(ica_method), ...
    string(epoching_mode), ...
    string(condition_label), ...
    string(status_label), ...
    string(input_name), ...
    n_eeg, ...
    n_eog, ...
    n_non_eeg, ...
    rej_info.n_total, ...
    rej_info.n_rejected_hard, ...
    rej_info.n_rejected_sophisticated, ...
    rej_info.n_rejected_total, ...
    rej_info.n_kept, ...
    prop_rejected_total, ...
    logical(rej_info.excluded), ...
    logical(step_cfg.do_artifact_rejection), ...
    logical(step_cfg.do_initial_hard_threshold_rejection), ...
    step_cfg.initial_hard_threshold_uv, ...
    logical(step_cfg.do_baseline_correction), ...
    step_cfg.base_start_ms, ...
    step_cfg.base_end_ms, ...
    step_cfg.max_reject_prop, ...
    shared_enable, ...
    shared_faster_z, ...
    shared_ptp, ...
    shared_robust, ...
    string(output_paths_joined), ...
    'VariableNames', { ...
        'subject_id', 'run_base', 'ica_method', 'epoching_mode', 'condition', 'status', ...
        'input_set_name', ...
        'n_eeg_channels', 'n_eog_channels', 'n_non_eeg_channels', ...
        'n_epochs_total', 'n_rejected_hard', 'n_rejected_sophisticated', 'n_rejected_total', 'n_epochs_kept', ...
        'prop_rejected_total', 'excluded_by_max_reject_prop', ...
        'artifact_rejection_enabled', 'hard_threshold_enabled', 'hard_threshold_uv', ...
        'baseline_correction_applied', 'baseline_start_ms', 'baseline_end_ms', ...
        'max_reject_prop', ...
        'shared_rejection_enabled', 'shared_faster_z', 'shared_ptp_uV_thresh', 'shared_use_robust_z', ...
        'output_set_paths'});
end