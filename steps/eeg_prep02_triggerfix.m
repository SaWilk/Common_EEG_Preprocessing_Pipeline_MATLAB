function step_out = eeg_prep02_triggerfix(subj_id, cfg, paths, helpers)
% Generic Step 02: triggerfix via phase gates + generic blocking
step_out = struct('ok', false, 'skipped', false, 'out_set_file', '', 'message', '');

try
    helpers.log_msg_default('Step 02 start for sub-%s', subj_id);

    % ---------------------------------------------------------------------
    % Defaults
    % ---------------------------------------------------------------------
    step_cfg = local_default_step_cfg();

    if isfield(cfg, 'steps') && isfield(cfg.steps, 'prep_02_triggerfix') && isstruct(cfg.steps.prep_02_triggerfix)
        step_cfg = helpers.merge_structs_recursive(step_cfg, cfg.steps.prep_02_triggerfix);
    end

    if isfield(cfg, 'bids') && isstruct(cfg.bids)
        if isfield(cfg.bids, 'task_label');    step_cfg.task_label = string(cfg.bids.task_label); end
        if isfield(cfg.bids, 'session_label'); step_cfg.session_label = string(cfg.bids.session_label); end
    end

    if isfield(cfg, 'prep_02') && isstruct(cfg.prep_02)
        step_cfg = helpers.merge_structs_recursive(step_cfg, cfg.prep_02);
    end

    overwrite_mode = helpers.resolve_overwrite_mode(cfg, step_cfg.overwrite_mode);

    % ---------------------------------------------------------------------
    % Paradigm triggerfix config
    % ---------------------------------------------------------------------
    paradigm_name = "MyParadigm";
    paradigm_name = "myParadigm";
    % if isfield(cfg, 'prep_02') && isstruct(cfg.prep_02) && isfield(cfg.prep_02, 'paradigm_name')
    %     paradigm_name = char(string(cfg.prep_02.paradigm_name));
    % elseif isfield(step_cfg, 'paradigm_name')
    %     paradigm_name = char(string(step_cfg.paradigm_name));
    % end

    if strlength(paradigm_name) > 0 && isfield(cfg, 'paradigms') && isfield(cfg.paradigms, paradigm_name) ...
            && isfield(cfg.paradigms.(paradigm_name), 'triggerfix')

        tf = cfg.paradigms.(paradigm_name).triggerfix;
        if isfield(tf, 'enable_first_match_replacements')
            step_cfg.enable_first_match_replacements = logical(tf.enable_first_match_replacements);
        else
            step_cfg.enable_first_match_replacements = true; % Default
        end

        if isfield(tf, 'use_gating_from_start_markers')
            step_cfg.use_gating_from_start_markers = logical(tf.use_gating_from_start_markers);
        else
            step_cfg.use_gating_from_start_markers = true;
        end

        if isfield(tf, 'gates') && isfield(tf.gates, 'start_markers')
            if ~isempty(tf.gates.start_markers) && ~isstruct(tf.gates.start_markers)
                error('Step 02: tf.gates.start_markers must be a struct (can be empty).');
            end
            step_cfg.phase_start_markers = struct();
            sm = tf.gates.start_markers;
            phFields = fieldnames(sm);
            for kk = 1:numel(phFields)
                pName = char(phFields{kk});
                step_cfg.phase_start_markers.(pName) = sm.(pName);
            end
        else
            step_cfg.phase_start_markers = struct();
        end

        if isfield(tf, 'blocking')
            step_cfg.blocking = tf.blocking;
        end

        if isfield(tf, 'raw_triggers')
            rt = tf.raw_triggers;
            if ~isstruct(rt); error('Step 02: tf.raw_triggers must be a struct.'); end
            step_cfg.raw_triggers = struct();
            fns = fieldnames(rt);
            for ii = 1:numel(fns)
                fn = char(fns{ii});
                step_cfg.raw_triggers.(fn) = rt.(fns{ii});
            end
        end

        if isfield(tf, 'rules')
            step_cfg = helpers.apply_triggerfix_rules_from_cfg_rules(step_cfg, tf.rules);
        end

        if isfield(tf, 'first_match_replacements')
            step_cfg.first_match_replacements = tf.first_match_replacements;
        end

        helpers.log_msg_default('Step 02: Using paradigm triggerfix config "%s".', paradigm_name);
    else
        helpers.log_msg_default('Step 02: No paradigm triggerfix config found -> using defaults.');
    end

    session_label = char(string(step_cfg.session_label));
    task_label    = char(string(step_cfg.task_label));

    % ---------------------------------------------------------------------
    % Paths
    % ---------------------------------------------------------------------
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

    % ---------------------------------------------------------------------
    % Input discovery
    % ---------------------------------------------------------------------
    if strlength(string(step_cfg.input_vhdr_pattern)) > 0
        pattern = char(string(step_cfg.input_vhdr_pattern));
    else
        pattern = sprintf('sub-%s_ses-%s_task-%s*_eeg.vhdr', subj_id, session_label, task_label);
    end

    vhdr_list = dir(fullfile(eeg_dir, pattern));
    if isempty(vhdr_list)
        error('Step 02: no BIDS EEG .vhdr found for sub-%s in %s (pattern=%s)', subj_id, eeg_dir, pattern);
    end

    [~, sort_ix] = sort({vhdr_list.name});
    vhdr_list = vhdr_list(sort_ix);

    if numel(vhdr_list) > 1 && ~step_cfg.allow_multiple_runs
        switch string(step_cfg.multiple_vhdr_policy)
            case "error"
                error('Step 02: found %d vhdr files but allow_multiple_runs=false.', numel(vhdr_list));
            case "first"
                vhdr_list = vhdr_list(1);
            otherwise % most_recent
                [~, ix] = max([vhdr_list.datenum]);
                vhdr_list = vhdr_list(ix);
        end
    end

    beh = [];
    if step_cfg.run_raw_order_qc
        try
            beh_file = helpers.find_behavior_log(paths.bids_root, subj_id, session_label);
            beh = helpers.read_behavior_log(beh_file);
            helpers.log_msg_default('Step 02: behavior log for RAW QC: %s', beh_file);
        catch
            helpers.log_msg_default('WARNING: Step 02 RAW QC skipped (could not read behavior log).');
            beh = [];
        end
    end

    out_files = strings(0,1);
    ran_any   = false;

    % =====================================================================
    % PRECOMPUTE for generic blocking (dynamic phases + cats)
    % =====================================================================
    phase_marker_tokens = struct();
    has_any_phase_marker = false;

    if isfield(step_cfg, 'phase_start_markers') && isstruct(step_cfg.phase_start_markers) && ...
            step_cfg.use_gating_from_start_markers

        pFields = fieldnames(step_cfg.phase_start_markers);
        for kk = 1:numel(pFields)
            pName = char(pFields{kk});
            tok = helpers.normalize_trigger_type(step_cfg.phase_start_markers.(pName));
            if strlength(string(tok)) > 0
                phase_marker_tokens.(pName) = tok;
                has_any_phase_marker = true;
            end
        end
    end

    blocking = struct();
    if isfield(step_cfg,'blocking') && isstruct(step_cfg.blocking)
        blocking = step_cfg.blocking;
    end

    count_scope = "global";
    if isfield(blocking,'count_scope')
        count_scope = lower(strtrim(string(blocking.count_scope)));
    end
    if ~ismember(count_scope, ["global","phase"])
        count_scope = "global";
    end

    catNames = {};
    if isstruct(blocking)
        catNames = setdiff(fieldnames(blocking), {'count_scope'});
    end

    cat_raw_tok = struct();
    for ci = 1:numel(catNames)
        cat = char(catNames{ci});
        if ~isfield(blocking, cat) || ~isstruct(blocking.(cat)); continue; end
        if ~isfield(blocking.(cat), 'raw_key'); continue; end
        raw_key = char(string(blocking.(cat).raw_key));
        if strlength(raw_key) == 0; continue; end
        tok = helpers.get_raw_trigger_from_key(step_cfg.raw_triggers, raw_key);
        if strlength(string(tok)) > 0
            cat_raw_tok.(cat) = tok;
        end
    end

    cat_counter = struct();
    cat_counter_phase = struct();

    % =====================================================================
    % MAIN LOOP over vhdr
    % =====================================================================
    for f = 1:numel(vhdr_list)

        bids_vhdr = vhdr_list(f).name;
        [~, bids_base] = fileparts(bids_vhdr);

        out_set_file = fullfile(paths.prep_02_out_dir, sprintf('%s_triggersfixed.set', bids_base));
        out_set_file_char = char(string(out_set_file)); % robust

        output_check_cfg = cfg;
        if ~isfield(output_check_cfg, 'io') || ~isstruct(output_check_cfg.io)
            output_check_cfg.io = struct();
        end

        if isfield(step_cfg, 'overwrite_if_older_than') && strlength(string(step_cfg.overwrite_if_older_than)) > 0
            output_check_cfg.io.overwrite_if_older_than = string(step_cfg.overwrite_if_older_than);
        end

        [do_run, skip_reason] = helpers.step_should_run_outputs(out_set_file_char, overwrite_mode, output_check_cfg);
        if ~do_run
            out_files(end+1,1) = string(out_set_file_char); %#ok<AGROW>
            continue;
        end

        ran_any = true;

        if exist(out_set_file_char, 'file') == 2
            helpers.safe_delete_set(out_set_file_char);
        end

        helpers.log_msg_default('Step 02: loading %s', bids_vhdr);

        if step_cfg.use_explicit_chanlist
            EEG = pop_loadbv(eeg_dir, bids_vhdr, [], step_cfg.explicit_chanlist);
        else
            EEG = helpers.safe_load_bv(eeg_dir, bids_vhdr, helpers);
        end
        EEG = eeg_checkset(EEG);
        EEG = helpers.normalize_event_types(EEG);

        % ---- OPTIONAL RAW QC BEFORE REMAPPING ----
        if step_cfg.run_raw_order_qc && ~isempty(beh)
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
                helpers.log_msg_default('WARNING: Step 02 RAW QC failed for %s (sub-%s). Reason: %s', ...
                    bids_base, subj_id, me_qc.message);
            end
        else
            helpers.log_msg_default('Step 02 RAW QC skipped for %s (run_raw_order_qc=%d, beh_present=%d).', ...
                bids_base, logical(step_cfg.run_raw_order_qc), ~isempty(beh));
        end

        % ---- PASS 1: generic blocking (with optional phase gating) ----
        % Reset counters per file
        cat_counter = struct();
        cat_counter_phase = struct();

        for x = 1:numel(EEG.event)

            current_type = helpers.normalize_trigger_type(EEG.event(x).type);

            % phase update (skip remap for phase markers)
            if has_any_phase_marker
                hitPhase = false;
                pFields = fieldnames(phase_marker_tokens);
                for kk = 1:numel(pFields)
                    pName = pFields{kk};
                    if strcmp(current_type, phase_marker_tokens.(pName))
                        current_phase = string(pName);
                        hitPhase = true;
                        break;
                    end
                end
                if hitPhase
                    continue;
                end
            end

            % find matched category by raw token
            matched_cat = "";
            catKeys = fieldnames(cat_raw_tok);
            for ci = 1:numel(catKeys)
                cat = catKeys{ci};
                if strcmp(current_type, cat_raw_tok.(cat))
                    matched_cat = string(cat);
                    break;
                end
            end

            if strlength(matched_cat) == 0
                EEG.event(x).type = current_type;
                continue;
            end

            cat = char(matched_cat);

            if ~isfield(blocking, cat) || ~isfield(blocking.(cat),'blocks')
                continue;
            end

            blocks = blocking.(cat).blocks;
            if isempty(blocks); continue; end

            % counter
            if count_scope == "phase"
                if ~exist('current_phase','var') || strlength(current_phase) == 0
                    continue;
                end
                phKey = char(current_phase);
                if ~isfield(cat_counter_phase, phKey)
                    cat_counter_phase.(phKey) = struct();
                end
                if ~isfield(cat_counter_phase.(phKey), cat)
                    cat_counter_phase.(phKey).(cat) = 0;
                end
                cat_counter_phase.(phKey).(cat) = cat_counter_phase.(phKey).(cat) + 1;
                n = cat_counter_phase.(phKey).(cat);
            else
                if ~isfield(cat_counter, cat); cat_counter.(cat) = 0; end
                cat_counter.(cat) = cat_counter.(cat) + 1;
                n = cat_counter.(cat);
            end

            % select matching block
            cum = 0;
            new_code = "";
            for bi = 1:numel(blocks)
                bi_n = blocks{bi}.n;
                if isempty(bi_n); continue; end
                cum = cum + double(bi_n);
                if n <= cum
                    new_code = blocks{bi}.code;
                    break;
                end
            end

            if strlength(string(new_code)) > 0
                EEG.event(x).type = char(string(new_code));
            else
                EEG.event(x).type = current_type;
            end
        end

        EEG = helpers.append_eeg_comment(EEG, ...
            sprintf('prep02_triggerfix: generic blocking applied for sub-%s', subj_id));

        % ---- PASS X: generic first-match replacements ----
        if isfield(step_cfg, 'enable_first_match_replacements')
            run_replacements = logical(step_cfg.enable_first_match_replacements);
        else
            run_replacements = true;
        end

        if run_replacements && isfield(step_cfg, 'first_match_replacements') && ...
                ~isempty(step_cfg.first_match_replacements)

            replacements = step_cfg.first_match_replacements;
            if ~iscell(replacements)
                replacements = {replacements};
            end

            n_done = zeros(numel(replacements), 1);

            for x = 1:numel(EEG.event)
                current_type = helpers.normalize_trigger_type(EEG.event(x).type);

                for r = 1:numel(replacements)
                    if n_done(r) >= (getfield_default(replacements{r}, 'max_replacements', 1))
                        continue;
                    end

                    rule = replacements{r};

                    % resolve match_code
                    match_code = "";
                    if isfield(rule, 'match_code') && strlength(string(rule.match_code)) > 0
                        match_code = helpers.normalize_trigger_type(rule.match_code);
                    elseif isfield(rule, 'match_code_key') && strlength(string(rule.match_code_key)) > 0
                        match_code = helpers.get_raw_trigger_from_key(step_cfg.raw_triggers, rule.match_code_key);
                        match_code = helpers.normalize_trigger_type(match_code);
                    end

                    if strlength(match_code) == 0 || ~strcmp(current_type, match_code)
                        continue;
                    end

                    % resolve replace_code
                    replace_code = "";
                    if isfield(rule, 'replace_code') && strlength(string(rule.replace_code)) > 0
                        replace_code = helpers.normalize_trigger_type(rule.replace_code);
                    elseif isfield(rule, 'replace_code_key') && strlength(string(rule.replace_code_key)) > 0
                        replace_code = helpers.get_raw_trigger_from_key(step_cfg.raw_triggers, rule.replace_code_key);
                        replace_code = helpers.normalize_trigger_type(replace_code);
                    end

                    if strlength(replace_code) == 0
                        continue;
                    end

                    EEG.event(x).type = replace_code;
                    n_done(r) = n_done(r) + 1;
                end
            end

            EEG = helpers.append_eeg_comment(EEG, ...
                sprintf('prep02_triggerfix: generic first-match replacements applied for sub-%s', subj_id));
        end

        % -----------------------------------------------------------------
        % SAVE OUTPUT (.set)
        % -----------------------------------------------------------------
        EEG = eeg_checkset(EEG);

        out_base = bids_base; % filename = <bids_base>_triggersfixed.set
        EEG.setname = sprintf('%s_triggersfixed', out_base);

        fname = sprintf('%s_triggersfixed.set', out_base);
        paths_out_dir = paths.prep_02_out_dir;

        EEG = helpers.safe_save_set(EEG, paths_out_dir, fname, helpers, cfg);

        helpers.log_msg_default('Step 02: saved %s', fullfile(paths_out_dir, fname));

        out_files(end+1,1) = string(out_set_file_char); %#ok<AGROW>
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

end % <-- function end

% =========================================================================
% LOCAL HELPERS
% =========================================================================
function v = getfield_default(s, field, default_val)
if isfield(s, field) && ~isempty(s.(field))
    v = s.(field);
else
    v = default_val;
end
end

function step_cfg = local_default_step_cfg()
step_cfg = struct();

% General behavior
step_cfg.run_raw_order_qc      = true;
step_cfg.allow_multiple_runs   = false;
step_cfg.multiple_vhdr_policy  = "most_recent";
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

% Optional enabling flags / generic defaults
step_cfg.enable_first_match_replacements = true;
step_cfg.use_gating_from_start_markers   = true;

% Blocking default (leer)
step_cfg.blocking = struct();

% First-match replacements default (leer)
step_cfg.first_match_replacements = {};

end
