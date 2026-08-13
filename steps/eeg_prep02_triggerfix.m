function step_out = eeg_prep02_triggerfix(subj_id, cfg, paths, helpers)
% EEG_PREP02_TRIGGERFIX
% Copyright (C) 2025–2026 Saskia Wilken and contributors
%
%
% Step 02 of the EEG pipeline.
%
% Does:
%   - Load BIDS BrainVision EEG (.vhdr) for one subject
%   - Optional RTGMN-specific RAW QC: compare CF behavior-log token order
%     against raw EEG trigger order
%   - Remap raw triggers into phase-specific codes using cfg.prep_02 rules
%   - Optionally disable first acquisition/extinction trials
%   - Save *_triggersfixed.set into derivatives/01_trigger_fix/sub-XXX/
%
% Important note:
%   The behavior-log branch in this step is RTGMN/CF-specific. Most users
%   will not have this custom file format. For other projects, leave
%   cfg.prep_02.run_raw_order_qc = false unless you explicitly adapt that
%   branch for your own experiment-specific logs.
%
% Saskia Wilken Dez 2025

step_out = struct( ...
    'ok', false, ...
    'skipped', false, ...
    'out_set_file', '', ...
    'message', '');

try
    helpers.log_msg_default('Step 02 start for sub-%s', subj_id);

    % =====================================================================
    % DEFAULTS
    % =====================================================================
    step_cfg = local_default_step_cfg();

    % Merge step-specific overwrite settings from cfg.steps
    if isfield(cfg, 'steps') && isfield(cfg.steps, 'prep_02_triggerfix') && isstruct(cfg.steps.prep_02_triggerfix)
        step_cfg = helpers.merge_structs_recursive(step_cfg, cfg.steps.prep_02_triggerfix);
    end

    % Merge BIDS defaults
    if isfield(cfg, 'bids') && isstruct(cfg.bids)
        if isfield(cfg.bids, 'task_label')
            step_cfg.task_label = string(cfg.bids.task_label);
        end
        if isfield(cfg.bids, 'session_label')
            step_cfg.session_label = string(cfg.bids.session_label);
        end
    end

    % Merge user-facing step config
    if isfield(cfg, 'prep_02') && isstruct(cfg.prep_02)
        step_cfg = helpers.merge_structs_recursive(step_cfg, cfg.prep_02);
    end

    overwrite_mode = helpers.resolve_overwrite_mode(cfg, step_cfg.overwrite_mode);

    % For per-file overwrite checks, allow the step-specific cutoff date to
    % override cfg.io.overwrite_if_older_than.
    output_check_cfg = cfg;
    if ~isfield(output_check_cfg, 'io') || ~isstruct(output_check_cfg.io)
        output_check_cfg.io = struct();
    end
    if isfield(step_cfg, 'overwrite_if_older_than') && strlength(string(step_cfg.overwrite_if_older_than)) > 0
        output_check_cfg.io.overwrite_if_older_than = string(step_cfg.overwrite_if_older_than);
    end

    session_label = char(string(step_cfg.session_label));
    task_label    = char(string(step_cfg.task_label));

    % =====================================================================
    % PATHS
    % =====================================================================
    if ~isfield(paths, 'bids_ses_dir') || strlength(string(paths.bids_ses_dir)) == 0
        paths.bids_ses_dir = fullfile(paths.bids_root, sprintf('sub-%s', subj_id), ['ses-' session_label]);
    end

    if ~isfield(paths, 'prep_02_out_dir') || strlength(string(paths.prep_02_out_dir)) == 0
        paths.prep_02_out_dir = fullfile(paths.out_root, '01_trigger_fix', sprintf('sub-%s', subj_id));
    end
    helpers.ensure_dir(paths.prep_02_out_dir);

    qc_out_dir = string(step_cfg.qc_out_dir);
    if strlength(qc_out_dir) == 0
        if isfield(paths, 'qc_dir') && strlength(string(paths.qc_dir)) > 0
            qc_out_dir = string(paths.qc_dir);
        else
            qc_out_dir = string(paths.prep_02_out_dir);
        end
    end
    helpers.ensure_dir(char(qc_out_dir));

    eeg_dir = fullfile(paths.bids_ses_dir, 'eeg');
    if exist(eeg_dir, 'dir') ~= 7
        error('Step 02: BIDS eeg directory not found: %s', eeg_dir);
    end

    % =====================================================================
    % INPUT DISCOVERY
    % =====================================================================
    if strlength(string(step_cfg.input_vhdr_pattern)) > 0
        pattern = char(string(step_cfg.input_vhdr_pattern));
    else
        pattern = sprintf('sub-%s_ses-%s_task-%s*_eeg.vhdr', subj_id, session_label, task_label);
    end

    vhdr_list = dir(fullfile(eeg_dir, pattern));

    if isempty(vhdr_list)
        error('Step 02: no BIDS EEG .vhdr found for sub-%s in %s (pattern=%s)', ...
            subj_id, eeg_dir, pattern);
    end

    % Stable ordering
    [~, sort_ix] = sort({vhdr_list.name});
    vhdr_list = vhdr_list(sort_ix);

    if numel(vhdr_list) > 1 && ~step_cfg.allow_multiple_runs
        switch string(step_cfg.multiple_vhdr_policy)
            case "error"
                error(['Step 02: found %d matching .vhdr files for sub-%s but ' ...
                       'allow_multiple_runs=false and policy="error".'], ...
                       numel(vhdr_list), subj_id);

            case "first"
                vhdr_list = vhdr_list(1);

            otherwise % "most_recent"
                [~, ix] = max([vhdr_list.datenum]);
                vhdr_list = vhdr_list(ix);
        end

        helpers.log_msg_default( ...
            'Step 02: multiple vhdr files found; policy="%s" -> using %s', ...
            string(step_cfg.multiple_vhdr_policy), vhdr_list.name);
    end

    helpers.log_msg_default( ...
        'Step 02: found %d matching vhdr file(s) for sub-%s.', ...
        numel(vhdr_list), subj_id);

    % =====================================================================
    % OPTIONAL RTGMN/CF BEHAVIOR LOG
    % =====================================================================
    beh = [];
    beh_file = "";

    if step_cfg.run_raw_order_qc
        try
            beh_file = helpers.find_behavior_log(paths.bids_root, subj_id, session_label);
            beh = helpers.read_behavior_log(beh_file);
            helpers.log_msg_default('Step 02: behavior log for RAW QC: %s', beh_file);
        catch me_beh
            helpers.log_msg_default([ ...
                'WARNING: Step 02 RAW QC skipped for sub-%s because the ' ...
                'RTGMN/CF behavior log could not be read/interpreted. Reason: %s'], ...
                subj_id, me_beh.message);
            beh = [];
            beh_file = "";
        end
    else
        helpers.log_msg_default('Step 02: RAW QC disabled by config.');
    end

    % =====================================================================
    % PRECOMPUTE PHASE/TRIGGER TOKENS
    % =====================================================================
    hab_marker = helpers.normalize_trigger_type(step_cfg.phase_start_markers.habituation);
    acq_marker = helpers.normalize_trigger_type(step_cfg.phase_start_markers.acquisition);
    gen_marker = helpers.normalize_trigger_type(step_cfg.phase_start_markers.generalization);
    ext_marker = helpers.normalize_trigger_type(step_cfg.phase_start_markers.extinction);
    rof_marker = helpers.normalize_trigger_type(step_cfg.phase_start_markers.return_of_fear);

    raw_acq_csminus = helpers.get_raw_trigger_from_key( ...
        step_cfg.raw_triggers, step_cfg.acquisition.cs_minus_key);
    raw_acq_csplus  = helpers.get_raw_trigger_from_key( ...
        step_cfg.raw_triggers, step_cfg.acquisition.cs_plus_key);

    raw_ext_csminus = helpers.get_raw_trigger_from_key( ...
        step_cfg.raw_triggers, step_cfg.extinction.cs_minus_key);
    raw_ext_csplus  = helpers.get_raw_trigger_from_key( ...
        step_cfg.raw_triggers, step_cfg.extinction.cs_plus_key);

    % =====================================================================
    % MAIN LOOP
    % =====================================================================
    out_files = strings(0,1);
    ran_any   = false;

    for f = 1:numel(vhdr_list)

        bids_vhdr = vhdr_list(f).name;
        [~, bids_base] = fileparts(bids_vhdr);

        out_set_file = fullfile(paths.prep_02_out_dir, sprintf('%s_triggersfixed.set', bids_base));
        out_set_file = char(string(out_set_file));

        [do_run, skip_reason] = helpers.step_should_run_outputs(out_set_file, overwrite_mode, output_check_cfg);

        if ~do_run
            helpers.log_msg_default('Step 02 skip for %s: %s', bids_base, string(skip_reason));
            out_files(end+1,1) = string(out_set_file); %#ok<AGROW>
            continue;
        end

        ran_any = true;

        % Whenever we regenerate, remove any old .set/.fdt pair first.
        if exist(out_set_file, 'file') == 2
            helpers.safe_delete_set(out_set_file);
        end

        helpers.log_msg_default('Step 02: loading %s', bids_vhdr);

        if step_cfg.use_explicit_chanlist
            EEG = pop_loadbv(eeg_dir, bids_vhdr, [], step_cfg.explicit_chanlist);
            EEG = eeg_checkset(EEG);
            helpers.log_msg_default( ...
                'Step 02: loaded %s with explicit chanlist (%d channels requested).', ...
                bids_vhdr, numel(step_cfg.explicit_chanlist));
        else
            EEG = helpers.safe_load_bv(eeg_dir, bids_vhdr, helpers);
        end

        EEG = helpers.normalize_event_types(EEG);

        % -----------------------------------------------------------------
        % OPTIONAL RAW QC BEFORE RENAMING
        % -----------------------------------------------------------------
        if ~isempty(beh)
            try
                qc_cfg = struct();
                qc_cfg.bin_size_s                 = step_cfg.raw_qc_bin_size_s;
                qc_cfg.max_rows                   = step_cfg.raw_qc_max_rows;
                qc_cfg.keep_tokens                = string(step_cfg.raw_qc_keep_tokens);
                qc_cfg.write_csv_on_ok            = step_cfg.raw_qc_write_csv_on_ok;
                qc_cfg.behavior_column_event_type = string(step_cfg.behavior_log_column_event_type);
                qc_cfg.behavior_column_code       = string(step_cfg.behavior_log_column_code);
                qc_cfg.behavior_column_time       = string(step_cfg.behavior_log_column_time);
                qc_cfg.behavior_time_unit         = string(step_cfg.behavior_log_time_unit);
                qc_cfg.behavior_log_map           = step_cfg.behavior_log_map;
                qc_cfg.raw_triggers               = step_cfg.raw_triggers;

                helpers.raw_qc_behavior_vs_eeg_and_write_csv( ...
                    beh, EEG, subj_id, bids_base, char(qc_out_dir), qc_cfg);

            catch me_qc
                helpers.log_msg_default( ...
                    'WARNING: Step 02 RAW QC failed for %s (sub-%s). Reason: %s', ...
                    bids_base, subj_id, me_qc.message);
            end
        else
            helpers.log_msg_default( ...
                'Step 02: RAW QC skipped for %s (no usable RTGMN/CF behavior log).', ...
                bids_base);
        end

        EEG = helpers.append_eeg_comment(EEG, ...
            sprintf('prep02_triggerfix: trigger renaming applied for sub-%s', subj_id));

        % -----------------------------------------------------------------
        % PASS 1: PHASE-GATED REMAP
        % -----------------------------------------------------------------
        current_phase = "";

        acq_count_csminus = 0;
        acq_count_csplus  = 0;

        ext_count_csminus = 0;
        ext_count_csplus  = 0;

        for x = 1:numel(EEG.event)

            current_type = helpers.normalize_trigger_type(EEG.event(x).type);
            EEG.event(x).type = current_type;

            switch current_type
                case hab_marker
                    current_phase = "habituation";
                    continue;
                case acq_marker
                    current_phase = "acquisition";
                    continue;
                case gen_marker
                    current_phase = "generalization";
                    continue;
                case ext_marker
                    current_phase = "extinction";
                    continue;
                case rof_marker
                    current_phase = "return_of_fear";
                    continue;
            end

            switch current_phase

                case "habituation"
                    new_type = helpers.map_trigger_by_table( ...
                        current_type, step_cfg.habituation_map, step_cfg.raw_triggers);
                    if ~isempty(new_type)
                        EEG.event(x).type = new_type;
                    end

                case "generalization"
                    new_type = helpers.map_trigger_by_table( ...
                        current_type, step_cfg.generalization_map, step_cfg.raw_triggers);
                    if ~isempty(new_type)
                        EEG.event(x).type = new_type;
                    end

                case "return_of_fear"
                    new_type = helpers.map_trigger_by_table( ...
                        current_type, step_cfg.return_of_fear_map, step_cfg.raw_triggers);
                    if ~isempty(new_type)
                        EEG.event(x).type = new_type;
                    end

                case "acquisition"
                    if strcmp(current_type, raw_acq_csminus)
                        acq_count_csminus = acq_count_csminus + 1;
                        if acq_count_csminus <= step_cfg.acquisition.n_first_block
                            EEG.event(x).type = char(string(step_cfg.acquisition.code_minus_block1));
                        else
                            EEG.event(x).type = char(string(step_cfg.acquisition.code_minus_block2));
                        end
                    elseif strcmp(current_type, raw_acq_csplus)
                        acq_count_csplus = acq_count_csplus + 1;
                        if acq_count_csplus <= step_cfg.acquisition.n_first_block
                            EEG.event(x).type = char(string(step_cfg.acquisition.code_plus_block1));
                        else
                            EEG.event(x).type = char(string(step_cfg.acquisition.code_plus_block2));
                        end
                    end

                case "extinction"
                    if strcmp(current_type, raw_ext_csminus)
                        ext_count_csminus = ext_count_csminus + 1;
                        if ext_count_csminus <= step_cfg.extinction.n_first_block
                            EEG.event(x).type = char(string(step_cfg.extinction.code_minus_block1));
                        elseif ext_count_csminus <= (step_cfg.extinction.n_first_block + step_cfg.extinction.n_second_block)
                            EEG.event(x).type = char(string(step_cfg.extinction.code_minus_block2));
                        else
                            EEG.event(x).type = char(string(step_cfg.extinction.code_minus_block3));
                        end
                    elseif strcmp(current_type, raw_ext_csplus)
                        ext_count_csplus = ext_count_csplus + 1;
                        if ext_count_csplus <= step_cfg.extinction.n_first_block
                            EEG.event(x).type = char(string(step_cfg.extinction.code_plus_block1));
                        elseif ext_count_csplus <= (step_cfg.extinction.n_first_block + step_cfg.extinction.n_second_block)
                            EEG.event(x).type = char(string(step_cfg.extinction.code_plus_block2));
                        else
                            EEG.event(x).type = char(string(step_cfg.extinction.code_plus_block3));
                        end
                    end
            end
        end

        % -----------------------------------------------------------------
        % PASS 2: OPTIONALLY DISABLE FIRST EXTINCTION TRIALS
        % -----------------------------------------------------------------
        if step_cfg.disable_first_ext_trials
            first_ext_minus_done = false;
            first_ext_plus_done  = false;

            revert_minus_raw = helpers.get_raw_trigger_from_key( ...
                step_cfg.raw_triggers, step_cfg.disable_first_extinction.revert_minus_key);

            revert_plus_raw = helpers.get_raw_trigger_from_key( ...
                step_cfg.raw_triggers, step_cfg.disable_first_extinction.revert_plus_key);

            first_minus_code = helpers.normalize_trigger_type( ...
                step_cfg.disable_first_extinction.first_minus_code);
            first_plus_code  = helpers.normalize_trigger_type( ...
                step_cfg.disable_first_extinction.first_plus_code);

            for x = 1:numel(EEG.event)
                current_type = helpers.normalize_trigger_type(EEG.event(x).type);

                if ~first_ext_minus_done && strcmp(current_type, first_minus_code)
                    EEG.event(x).type = revert_minus_raw;
                    first_ext_minus_done = true;
                end

                if ~first_ext_plus_done && strcmp(current_type, first_plus_code)
                    EEG.event(x).type = revert_plus_raw;
                    first_ext_plus_done = true;
                end

                if first_ext_minus_done && first_ext_plus_done
                    break;
                end
            end

            EEG = helpers.append_eeg_comment(EEG, ...
                'prep02_triggerfix: disabled first extinction CS-/CS+ trial');
        end

        % -----------------------------------------------------------------
        % PASS 3: OPTIONALLY DISABLE FIRST ACQUISITION TRIALS
        % -----------------------------------------------------------------
        if step_cfg.disable_first_acq_trials
            acq_minus_done = false;
            acq_plus_done  = false;

            first_minus_code    = helpers.normalize_trigger_type( ...
                step_cfg.disable_first_acquisition.first_minus_code);
            first_plus_code     = helpers.normalize_trigger_type( ...
                step_cfg.disable_first_acquisition.first_plus_code);
            disabled_minus_code = helpers.normalize_trigger_type( ...
                step_cfg.disable_first_acquisition.disabled_minus_code);
            disabled_plus_code  = helpers.normalize_trigger_type( ...
                step_cfg.disable_first_acquisition.disabled_plus_code);

            for x = 1:numel(EEG.event)
                current_type = helpers.normalize_trigger_type(EEG.event(x).type);

                if ~acq_minus_done && strcmp(current_type, first_minus_code)
                    EEG.event(x).type = disabled_minus_code;
                    acq_minus_done = true;
                end

                if ~acq_plus_done && strcmp(current_type, first_plus_code)
                    EEG.event(x).type = disabled_plus_code;
                    acq_plus_done = true;
                end

                if acq_minus_done && acq_plus_done
                    break;
                end
            end

            EEG = helpers.append_eeg_comment(EEG, ...
                'prep02_triggerfix: disabled first acquisition CS-/CS+ trial');
        end

        EEG = eeg_checkset(EEG);

        helpers.log_msg_default( ...
            ['Step 02 summary for %s: ACQ counts CS-=%d, CS+=%d | ' ...
             'EXT counts CS-=%d, CS+=%d'], ...
            bids_base, ...
            acq_count_csminus, acq_count_csplus, ...
            ext_count_csminus, ext_count_csplus);

        % -----------------------------------------------------------------
        % SAVE OUTPUT
        % -----------------------------------------------------------------
        fname = sprintf('%s_triggersfixed.set', bids_base);
        EEG.setname = sprintf('%s_triggersfixed', bids_base);

            EEG = helpers.safe_save_set(EEG, paths.prep_02_out_dir, fname, helpers, cfg);
            helpers.log_msg_default( ...
                'Saved trigger-fixed set: %s', ...
                fullfile(paths.prep_02_out_dir, fname));
            
        out_files(end+1,1) = string(out_set_file); %#ok<AGROW>
    end

    % =====================================================================
    % FINALIZE
    % =====================================================================
    step_out.ok = true;

    if isempty(out_files)
        step_out.skipped = true;
        step_out.message = 'No outputs written (all skipped or no matching files).';

    elseif ~ran_any
        step_out.skipped = true;
        step_out.out_set_file = char(out_files(1));
        step_out.message = 'All matching outputs already existed and were skipped.';

    else
        step_out.out_set_file = char(out_files(1));
        if numel(out_files) == 1
            step_out.message = sprintf('Processed 1 trigger-fixed set for sub-%s.', subj_id);
        else
            step_out.message = sprintf('Processed %d trigger-fixed sets for sub-%s.', numel(out_files), subj_id);
        end
    end

    helpers.log_msg_default('%s', step_out.message);

catch ME
    step_out.ok = false;
    step_out.skipped = false;
    step_out.message = ME.message;

    helpers.log_msg_default('ERROR in Step 02 for sub-%s: %s', subj_id, ME.message);
    helpers.log_msg_default('%s', getReport(ME, 'extended', 'hyperlinks', 'off'));
end

end

% =========================================================================
% LOCAL HELPERS
% =========================================================================
function step_cfg = local_default_step_cfg()

step_cfg = struct();

% General behavior
step_cfg.run_raw_order_qc      = true;
step_cfg.allow_multiple_runs   = false;
step_cfg.multiple_vhdr_policy  = "most_recent"; % "most_recent" | "first" | "error"
step_cfg.qc_out_dir            = "";
step_cfg.task_label            = "task";
step_cfg.session_label         = "01";
step_cfg.input_vhdr_pattern    = "";
step_cfg.use_explicit_chanlist = false;
step_cfg.explicit_chanlist     = 1:66;
step_cfg.overwrite_mode        = "";
step_cfg.overwrite_if_older_than = "";

% Raw QC settings
step_cfg.raw_qc_keep_tokens      = ["S 20","S 21","S 22","S 23","S 24","S 15","S 5"];
step_cfg.raw_qc_bin_size_s       = 1;
step_cfg.raw_qc_max_rows         = 20000;
step_cfg.raw_qc_write_csv_on_ok  = false;

% RTGMN/CF behavior-log parser settings
step_cfg.behavior_log_column_event_type = 'EventType';
step_cfg.behavior_log_column_code       = 'Code';
step_cfg.behavior_log_column_time       = 'Time';
step_cfg.behavior_log_time_unit         = "ms";
step_cfg.behavior_log_map               = {};

% Phase markers
step_cfg.phase_start_markers = struct();
step_cfg.phase_start_markers.habituation    = "S 91";
step_cfg.phase_start_markers.acquisition    = "S 92";
step_cfg.phase_start_markers.generalization = "S 93";
step_cfg.phase_start_markers.extinction     = "S 94";
step_cfg.phase_start_markers.return_of_fear = "S 95";

% Raw trigger dictionary
step_cfg.raw_triggers = struct();
step_cfg.raw_triggers.cs_minus = "S 20";
step_cfg.raw_triggers.gs_1     = "S 21";
step_cfg.raw_triggers.gs_u     = "S 22";
step_cfg.raw_triggers.gs_2     = "S 23";
step_cfg.raw_triggers.cs_plus  = "S 24";
step_cfg.raw_triggers.startle  = "S 15";
step_cfg.raw_triggers.shock    = "S 5";

% Simple phase maps
step_cfg.habituation_map = { ...
    'cs_minus', "S 201"; ...
    'gs_1',     "S 211"; ...
    'gs_u',     "S 221"; ...
    'gs_2',     "S 231"; ...
    'cs_plus',  "S 241"  ...
    };

step_cfg.generalization_map = { ...
    'cs_minus', "S 203"; ...
    'gs_1',     "S 213"; ...
    'gs_u',     "S 223"; ...
    'gs_2',     "S 233"; ...
    'cs_plus',  "S 243"  ...
    };

step_cfg.return_of_fear_map = { ...
    'cs_minus', "S 205"; ...
    'gs_1',     "S 215"; ...
    'gs_u',     "S 225"; ...
    'gs_2',     "S 235"; ...
    'cs_plus',  "S 245"  ...
    };

% Acquisition rules
step_cfg.acquisition = struct();
step_cfg.acquisition.cs_minus_key      = 'cs_minus';
step_cfg.acquisition.cs_plus_key       = 'cs_plus';
step_cfg.acquisition.n_first_block     = 10;
step_cfg.acquisition.code_minus_block1 = "S 2021";
step_cfg.acquisition.code_plus_block1  = "S 2421";
step_cfg.acquisition.code_minus_block2 = "S 2022";
step_cfg.acquisition.code_plus_block2  = "S 2422";

% Extinction rules
step_cfg.extinction = struct();
step_cfg.extinction.cs_minus_key       = 'cs_minus';
step_cfg.extinction.cs_plus_key        = 'cs_plus';
step_cfg.extinction.n_first_block      = 11;
step_cfg.extinction.n_second_block     = 10;
step_cfg.extinction.code_minus_block1  = "S 2041";
step_cfg.extinction.code_plus_block1   = "S 2441";
step_cfg.extinction.code_minus_block2  = "S 2042";
step_cfg.extinction.code_plus_block2   = "S 2442";
step_cfg.extinction.code_minus_block3  = "S 2043";
step_cfg.extinction.code_plus_block3   = "S 2443";

% Optional disabling of first trials
step_cfg.disable_first_ext_trials = true;
step_cfg.disable_first_acq_trials = true;

step_cfg.disable_first_extinction = struct();
step_cfg.disable_first_extinction.first_minus_code = "S 2041";
step_cfg.disable_first_extinction.first_plus_code  = "S 2441";
step_cfg.disable_first_extinction.revert_minus_key = 'cs_minus';
step_cfg.disable_first_extinction.revert_plus_key  = 'cs_plus';

step_cfg.disable_first_acquisition = struct();
step_cfg.disable_first_acquisition.first_minus_code    = "S 2021";
step_cfg.disable_first_acquisition.first_plus_code     = "S 2421";
step_cfg.disable_first_acquisition.disabled_minus_code = "S 20999";
step_cfg.disable_first_acquisition.disabled_plus_code  = "S 24999";

end
