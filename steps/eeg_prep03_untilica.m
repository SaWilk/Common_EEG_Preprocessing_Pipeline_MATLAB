function step_out = eeg_prep03_untilica(subj_id, cfg, paths, helpers)
% EEG_PREP03_UNTILICA
%
% Preprocess continuous EEG until ICA preparation.
%
% Outputs:
%   (1) *_preica.set : continuous pipeline dataset for downstream steps
%   (2) *_forica.set : ICA-training-only dataset
%
% Input preference:
%   A) Step 02 output: *_triggersfixed.set
%   B) fallback: raw BIDS BrainVision *.vhdr
%
% Design note:
%   This step is intended to be configurable from cfg.prep_03.
%   In the usual case, users should only need to adjust the config.
%   Only fundamentally different preprocessing logic should require edits
%   to this function.

%% ========================================================================
%  OUTPUT INIT
% ========================================================================
step_out = struct( ...
    'ok', false, ...
    'skipped', false, ...
    'message', '', ...
    'run_base_name', '', ...
    'in_triggersfixed_set', '', ...
    'out_preica_set', '', ...
    'out_forica_set', '' );

%% ========================================================================
%  STEP CFG DEFAULTS
% ========================================================================
step_cfg = local_default_prep03_cfg_impl();

%% ========================================================================
%  MERGE OVERRIDES FROM CFG
% ========================================================================
if isfield(cfg, 'prep_03') && isstruct(cfg.prep_03)
    step_cfg = helpers.merge_structs_recursive(step_cfg, cfg.prep_03);
end

if isfield(cfg, 'steps') && isfield(cfg.steps, 'prep_03_until_ica')
    s = cfg.steps.prep_03_until_ica;
    if isfield(s, 'overwrite_mode') && strlength(string(s.overwrite_mode)) > 0
        step_cfg.overwrite_mode = string(s.overwrite_mode);
    end
end

overwrite_mode = helpers.resolve_overwrite_mode(cfg, step_cfg.overwrite_mode);

if numel(step_cfg.crop_padding_sec) ~= 2
    error('prep03_untilica: cfg.prep_03.crop_padding_sec must have exactly two elements [pre post].');
end

%% ========================================================================
%  PATHS
% ========================================================================
if isfield(paths, 'prep_02_out_dir') && strlength(string(paths.prep_02_out_dir)) > 0
    prep02_out_dir = paths.prep_02_out_dir;
else
    prep02_out_dir = fullfile(paths.derivatives_root, '01_trigger_fix', sprintf('sub-%s', subj_id));
end

if isfield(paths, 'prep_03_out_dir_until_ica') && strlength(string(paths.prep_03_out_dir_until_ica)) > 0
    prep03_out_dir_untilica = paths.prep_03_out_dir_until_ica;
else
    prep03_out_dir_untilica = fullfile(paths.derivatives_root, '02_until_ica', sprintf('sub-%s', subj_id));
end

if isfield(paths, 'prep_03_out_dir_for_ica') && strlength(string(paths.prep_03_out_dir_for_ica)) > 0
    prep03_out_dir_forica = paths.prep_03_out_dir_for_ica;
else
    prep03_out_dir_forica = fullfile(paths.derivatives_root, '03_for_ica', sprintf('sub-%s', subj_id));
end

helpers.ensure_dir(prep03_out_dir_untilica);
helpers.ensure_dir(prep03_out_dir_forica);

%% ========================================================================
%  FIND INPUT
% ========================================================================
input_source = "triggersfixed_set";
in_dir  = prep02_out_dir;
in_name = "";

trigger_fixed_sets = dir(fullfile(in_dir, '*_triggersfixed.set'));

if ~isempty(trigger_fixed_sets)

    if numel(trigger_fixed_sets) > 1
        [~, ix] = max([trigger_fixed_sets.datenum]);
        helpers.log_msg_default( ...
            'prep03_untilica: WARNING multiple *_triggersfixed.set found (%d). Using most recent: %s', ...
            numel(trigger_fixed_sets), trigger_fixed_sets(ix).name);
        trigger_fixed_sets = trigger_fixed_sets(ix);
    end

    in_name = trigger_fixed_sets.name;
    run_base_name = erase(in_name, '_triggersfixed.set');

else
    [vhdr_dir, vhdr_name] = helpers.find_bids_vhdr(paths, subj_id, helpers);

    if isempty(vhdr_name)
        msg = sprintf(['prep03_untilica: no input found. Neither *_triggersfixed.set in %s ' ...
            'nor any *.vhdr in BIDS eeg folder for sub-%s.'], in_dir, subj_id);
        helpers.log_msg_default('%s', msg);
        step_out.message = msg;
        return;
    end

    input_source = "bids_vhdr";
    in_dir  = vhdr_dir;
    in_name = vhdr_name;
    run_base_name = regexprep(in_name, '\.vhdr$', '', 'ignorecase');
end

step_out.run_base_name = run_base_name;

if input_source == "triggersfixed_set"
    step_out.in_triggersfixed_set = fullfile(in_dir, in_name);
else
    step_out.in_triggersfixed_set = "";
end

out_preica = fullfile(prep03_out_dir_untilica, sprintf('%s_preica.set', run_base_name));
out_forica = fullfile(prep03_out_dir_forica,   sprintf('%s_forica.set', run_base_name));

step_out.out_preica_set = out_preica;
step_out.out_forica_set = out_forica;

%% ========================================================================
%  OVERWRITE POLICY
% ========================================================================
out_files = {out_preica, out_forica};
[do_run, reason, needs_regen] = helpers.step_should_run_outputs(out_files, overwrite_mode, cfg);

if ~do_run
    helpers.log_msg_default('prep03_untilica: skip (%s)', reason);
    step_out.skipped = true;
    step_out.ok = true;
    step_out.message = reason;
    return;
end

helpers.log_msg_default( ...
    'prep03_untilica: START sub-%s | %s | input_source=%s | input=%s', ...
    subj_id, run_base_name, input_source, fullfile(in_dir, in_name));

%% ========================================================================
%  LOAD INPUT
% ========================================================================
if input_source == "triggersfixed_set"
    EEG = helpers.safe_load_set(in_dir, in_name, helpers);
elseif input_source == "bids_vhdr"
    EEG = helpers.safe_load_bv(in_dir, in_name, helpers);
else
    error('prep03_untilica: internal error: unknown input_source=%s', char(input_source));
end

EEG = eeg_checkset(EEG);

EEG = helpers.append_eeg_comment(EEG, 'prep03_untilica: start');
EEG = helpers.append_eeg_comment(EEG, sprintf('prep03_untilica: input_source=%s', input_source));
EEG = helpers.append_eeg_comment(EEG, sprintf('prep03_untilica: input=%s', fullfile(in_dir, in_name)));

%% ========================================================================
%  CHANNEL TYPES
% ========================================================================
EEG = helpers.ensure_channel_types(EEG, step_cfg);

[eeg_idx, eog_idx, aux_idx] = helpers.get_channel_indices_by_type(EEG);

EEG = helpers.append_eeg_comment(EEG, sprintf( ...
    'prep03_untilica: channel counts EEG=%d | EOG=%d | AUX=%d', ...
    numel(eeg_idx), numel(eog_idx), numel(aux_idx)));

%% ========================================================================
%  FIND DEAD / INVALID CHANNELS
%  - dead EEG channels are kept for later interpolation
%  - dead AUX channels are removed permanently
% ========================================================================
dead_idx_all    = [];
dead_labels_all = {};

dead_eeg_idx    = [];
dead_eeg_labels = {};

dead_aux_idx    = [];
dead_aux_labels = {};

if step_cfg.flag_flat_channels_as_bad

    all_idx = 1:EEG.nbchan;

    [dead_idx_all, dead_labels_all] = helpers.find_flat_or_invalid_channels( ...
        EEG, all_idx, step_cfg.flat_channel_variance_epsilon);

    if ~isempty(dead_idx_all)

        [eeg_idx_now, eog_idx_now, aux_idx_now] = helpers.get_channel_indices_by_type(EEG); %#ok<ASGLU>

        dead_eeg_idx = intersect(dead_idx_all, eeg_idx_now);
        dead_aux_idx = intersect(dead_idx_all, aux_idx_now);

        if ~isempty(dead_eeg_idx)
            dead_eeg_labels = {EEG.chanlocs(dead_eeg_idx).labels};
            helpers.log_msg_default( ...
                'prep03_untilica: sub-%s | dead/invalid EEG channels flagged for later interpolation: %s', ...
                subj_id, strjoin(string(dead_eeg_labels), ', '));

            EEG = helpers.append_eeg_comment(EEG, sprintf( ...
                'prep03_untilica: dead/invalid EEG flagged for interpolation: %s', ...
                strjoin(dead_eeg_labels, ', ')));
        end

        if ~isempty(dead_aux_idx)
            dead_aux_labels = {EEG.chanlocs(dead_aux_idx).labels};
            helpers.log_msg_default( ...
                'prep03_untilica: sub-%s | removing dead/invalid AUX channels permanently: %s', ...
                subj_id, strjoin(string(dead_aux_labels), ', '));

            EEG = helpers.append_eeg_comment(EEG, sprintf( ...
                'prep03_untilica: removing dead/invalid AUX channels permanently: %s', ...
                strjoin(dead_aux_labels, ', ')));

            EEG = pop_select(EEG, 'nochannel', dead_aux_idx);
            EEG = eeg_checkset(EEG);

            if ~isempty(dead_eeg_labels)
                all_labels_after_aux_delete = {EEG.chanlocs.labels};
                dead_eeg_idx = find(ismember(all_labels_after_aux_delete, dead_eeg_labels));
            else
                dead_eeg_idx = [];
            end
        end
    end
end

if ~isfield(EEG, 'etc') || isempty(EEG.etc)
    EEG.etc = struct();
end

EEG.etc.dead_channels_detected = struct();
EEG.etc.dead_channels_detected.all_indices     = dead_idx_all;
EEG.etc.dead_channels_detected.all_labels      = dead_labels_all;
EEG.etc.dead_channels_detected.dead_eeg_idx    = dead_eeg_idx;
EEG.etc.dead_channels_detected.dead_eeg_labels = dead_eeg_labels;
EEG.etc.dead_channels_detected.dead_aux_idx    = dead_aux_idx;
EEG.etc.dead_channels_detected.dead_aux_labels = dead_aux_labels;

[eeg_idx, eog_idx, aux_idx] = helpers.get_channel_indices_by_type(EEG);

EEG = helpers.append_eeg_comment(EEG, sprintf( ...
    'prep03_untilica: channel counts AFTER dead-channel handling EEG=%d | EOG=%d | AUX=%d', ...
    numel(eeg_idx), numel(eog_idx), numel(aux_idx)));

%% ========================================================================
%  CROP TO TASK WINDOW
% ========================================================================
if step_cfg.crop_to_task_markers
    start_latency = helpers.find_first_event_latency(EEG, step_cfg.crop_start_marker);
    end_latency   = helpers.find_first_event_latency(EEG, step_cfg.crop_end_marker);

    if isempty(start_latency) || isempty(end_latency)
        msg = sprintf( ...
            'prep03_untilica: missing task markers start(%s)=%d end(%s)=%d -> cannot continue', ...
            step_cfg.crop_start_marker, isempty(start_latency), ...
            step_cfg.crop_end_marker, isempty(end_latency));
        helpers.log_msg_default('%s', msg);
        step_out.message = msg;
        return;
    end

    t_start = (double(start_latency) / EEG.srate) - step_cfg.crop_padding_sec(1);
    t_end   = (double(end_latency)   / EEG.srate) + step_cfg.crop_padding_sec(2);

    t_start = max(t_start, 0);
    t_end   = min(t_end, (EEG.pnts - 1) / EEG.srate);

    if t_end <= t_start
        msg = sprintf( ...
            'prep03_untilica: invalid crop window t_start=%.3f t_end=%.3f -> cannot continue', ...
            t_start, t_end);
        helpers.log_msg_default('%s', msg);
        step_out.message = msg;
        return;
    end

    EEG = pop_select(EEG, 'time', [t_start t_end]);
    EEG = eeg_checkset(EEG);

    EEG = helpers.append_eeg_comment(EEG, sprintf( ...
        'prep03_untilica: cropped %s..%s padding=[%.2f %.2f] t=[%.3f %.3f]', ...
        step_cfg.crop_start_marker, step_cfg.crop_end_marker, ...
        step_cfg.crop_padding_sec(1), step_cfg.crop_padding_sec(2), ...
        t_start, t_end));
end

%% ========================================================================
%  DOWNSAMPLE
% ========================================================================
if isempty(step_cfg.downsample_hz) || double(step_cfg.downsample_hz) == 0
    EEG = helpers.append_eeg_comment(EEG, 'prep03_untilica: downsampling skipped');
else
    target_hz = double(step_cfg.downsample_hz);

    if ~isscalar(target_hz) || ~isfinite(target_hz) || target_hz <= 0
        error('prep03_untilica: invalid cfg.prep_03.downsample_hz: %s', mat2str(step_cfg.downsample_hz));
    end

    if abs(double(EEG.srate) - target_hz) > eps
        EEG = pop_resample(EEG, target_hz);
        EEG = eeg_checkset(EEG);
        EEG = helpers.append_eeg_comment(EEG, sprintf( ...
            'prep03_untilica: downsampled to %.0f Hz', target_hz));
    else
        EEG = helpers.append_eeg_comment(EEG, sprintf( ...
            'prep03_untilica: downsampling skipped (already %.0f Hz)', target_hz));
    end
end


%% ========================================================================
% High-Pass Filter before bad-channel detection (EEG + EOG ONLY)
% =========================================================================
[eeg_idx, eog_idx, ~] = helpers.get_channel_indices_by_type(EEG);
%filter_idx = sort(unique([eeg_idx(:); eog_idx(:)]));
filter_idx = sort(eeg_idx(:));

EEG = helpers.apply_filter_to_subset_only(EEG, filter_idx, ...
    step_cfg.highpass_hz, [], 'prep03_untilica high-pass');

%% ========================================================================
%  OPTIONAL DEBUG SAVE: AFTER HIGH-PASS
% ========================================================================
if step_cfg.save_intermediate_steps && step_cfg.save_intermediate_after_highpass
    helpers.save_intermediate_set( ...
        EEG, ...
        prep03_out_dir_untilica, ...
        string(run_base_name) + "_stage-prep03_after-highpass", ...
        "delete", ...
        cfg, ...
        step_cfg.intermediate_savemode, ...
        helpers);
end


%% ========================================================================
%  LINE NOISE (EEG + EOG ONLY)
% ========================================================================
[eeg_idx, eog_idx, ~] = helpers.get_channel_indices_by_type(EEG);
filter_idx = sort(unique([eeg_idx(:); eog_idx(:)]));


line_noise_applied = false;
if string(step_cfg.line_noise_method) == "pop_cleanline"
label_for_log = 'prep03_untilica line noise (cleanline)';
[EEG, line_noise_applied] = helpers.apply_pop_cleanline_to_subset(EEG, filter_idx, step_cfg, helpers, label_for_log);
    %[EEG, line_noise_applied] = helpers.apply_pop_cleanline_to_subset(EEG, filter_idx, step_cfg);
    if ~line_noise_applied
        helpers.log_msg_default('prep03_untilica: WARNING pop_cleanline did not apply successfully.');
    end
end

EEG = helpers.append_eeg_comment(EEG, sprintf( ...
    'prep03_untilica: line noise method=%s applied=%d freqs=%s', ...
    string(step_cfg.line_noise_method), line_noise_applied, ...
    mat2str(step_cfg.line_noise_frequencies_hz)));

EEG = helpers.apply_filter_to_subset_only(EEG, filter_idx, ...
    [], step_cfg.lowpass_hz, 'prep03_untilica low-pass');

%% ========================================================================
%  OPTIONAL DEBUG SAVE: AFTER LOW-PASS
% ========================================================================
if step_cfg.save_intermediate_steps && step_cfg.save_intermediate_after_lowpass
    helpers.save_intermediate_set( ...
        EEG, ...
        prep03_out_dir_untilica, ...
        string(run_base_name) + "_stage-prep03_after-lowpass", ...
        "delete", ...
        cfg, ...
        step_cfg.intermediate_savemode, ...
        helpers);
end

%% ========================================================================
%  FLAT / INVALID EEG CHANNELS
% ========================================================================
flat_idx = [];
flat_labels = {};

if step_cfg.flag_flat_channels_as_bad && ~isempty(eeg_idx)
    [flat_idx, flat_labels] = helpers.find_flat_or_invalid_channels( ...
        EEG, eeg_idx, step_cfg.flat_channel_variance_epsilon);

    if ~isempty(flat_idx)
        EEG = helpers.append_eeg_comment(EEG, sprintf( ...
            'prep03_untilica: flat/invalid EEG flagged: %s', ...
            strjoin(flat_labels, ', ')));
    end
end

%% ========================================================================
%  BAD CHANNEL DETECTION (EEG ONLY)
% ========================================================================
bad_idx = [];
bad_labels = {};

badchan_method = lower(strtrim(string(step_cfg.bad_channel_detection_method)));

switch char(badchan_method)

    case 'clean_rawdata'
        if ~isempty(eeg_idx)
            try
                [emu_bad_idx, ~] = helpers.detect_bad_channels_emulation_style( ...
                    EEG, eeg_idx, step_cfg.clean_rawdata_flatline_sec, step_cfg.clean_rawdata_channel_corr_threshold);

                bad_idx = sort(unique([ ...
                    emu_bad_idx(:); ...
                    flat_idx(:); ...
                    dead_eeg_idx(:) ...
                    ]));

                bad_idx = intersect(bad_idx, eeg_idx);
                bad_idx = setdiff(bad_idx, eog_idx);

            catch me
                helpers.log_msg_default( ...
                    'prep03_untilica: badchan auto FAILED -> fallback flat/dead EEG only. %s', ...
                    me.message);

                bad_idx = sort(unique([flat_idx(:); dead_eeg_idx(:)]));
                bad_idx = intersect(bad_idx, eeg_idx);
            end
        end

    case 'pop_rejchan'
        if isempty(eeg_idx)
            bad_idx = sort(unique([flat_idx(:); dead_eeg_idx(:)]));
        else
            try
                [~, idx_prob] = pop_rejchan(EEG, 'elec', eeg_idx, ...
                    'threshold', step_cfg.pop_rejchan_z_threshold, ...
                    'norm', 'on', 'measure', 'prob');

                [~, idx_kurt] = pop_rejchan(EEG, 'elec', eeg_idx, ...
                    'threshold', step_cfg.pop_rejchan_z_threshold, ...
                    'norm', 'on', 'measure', 'kurt');

                [~, idx_spec] = pop_rejchan(EEG, 'elec', eeg_idx, ...
                    'threshold', step_cfg.pop_rejchan_z_threshold, ...
                    'norm', 'on', 'measure', 'spec', ...
                    'freqrange', step_cfg.pop_rejchan_freqrange_hz);

                bad_idx = sort(unique([ ...
                    idx_prob(:); ...
                    idx_kurt(:); ...
                    idx_spec(:); ...
                    flat_idx(:); ...
                    dead_eeg_idx(:) ...
                    ]));

                bad_idx = intersect(bad_idx, eeg_idx);
                bad_idx = setdiff(bad_idx, eog_idx);

            catch me
                helpers.log_msg_default( ...
                    'prep03_untilica: badchan auto_rejchan FAILED -> fallback flat/dead EEG only. %s', ...
                    me.message);

                bad_idx = sort(unique([flat_idx(:); dead_eeg_idx(:)]));
                bad_idx = intersect(bad_idx, eeg_idx);
            end
        end

    case 'off'
        bad_idx = sort(unique([flat_idx(:); dead_eeg_idx(:)]));
        bad_idx = intersect(bad_idx, eeg_idx);

    otherwise
error('prep03_untilica: unsupported bad_channel_detection_method: %s', ...
    string(step_cfg.bad_channel_detection_method));
end

if ~isempty(bad_idx)
    bad_labels = {EEG.chanlocs(bad_idx).labels};

    helpers.log_msg_default( ...
        'prep03_untilica: sub-%s | final bad EEG channels flagged by %s (n=%d): %s', ...
        subj_id, ...
        char(badchan_method), ...
        numel(bad_labels), ...
        strjoin(string(bad_labels), ', '));

    EEG = helpers.append_eeg_comment(EEG, sprintf( ...
        'prep03_untilica: bad EEG labels (to interpolate): %s', ...
        strjoin(bad_labels, ', ')));
else
    helpers.log_msg_default( ...
        'prep03_untilica: sub-%s | final bad EEG channels flagged by %s: none', ...
        subj_id, ...
        char(badchan_method));

    EEG = helpers.append_eeg_comment(EEG, 'prep03_untilica: no bad EEG channels flagged');
end

if ~isfield(EEG, 'chaninfo') || isempty(EEG.chaninfo)
    EEG.chaninfo = struct();
end
EEG.chaninfo.bad = bad_labels;

%% ========================================================================
%  INTERPOLATE BAD CHANNELS BEFORE ICA
% ========================================================================
if step_cfg.interpolate_bad_channels_before_ica && ~isempty(bad_idx)
    EEG = helpers.append_eeg_comment(EEG, sprintf( ...
        'prep03_untilica: interpolate BEFORE ICA (%s): %s', ...
        step_cfg.interp_method, strjoin(bad_labels, ', ')));

    EEG = pop_interp(EEG, bad_idx, step_cfg.interp_method);
    EEG = eeg_checkset(EEG);

    [eeg_idx, eog_idx, aux_idx] = helpers.get_channel_indices_by_type(EEG);

    helpers.log_msg_default( ...
        'prep03_untilica: AFTER interpolation channel counts EEG=%d | EOG=%d | AUX=%d', ...
        numel(eeg_idx), numel(eog_idx), numel(aux_idx));

    EEG = helpers.append_eeg_comment(EEG, sprintf( ...
        'prep03_untilica: AFTER interpolation channel counts EEG=%d | EOG=%d | AUX=%d', ...
        numel(eeg_idx), numel(eog_idx), numel(aux_idx)));

    if ~isfield(EEG, 'etc') || isempty(EEG.etc)
        EEG.etc = struct();
    end
    EEG.etc.interpolated_channel_indices = bad_idx;
    EEG.etc.interpolated_channel_labels  = bad_labels;
else
    if ~isfield(EEG, 'etc') || isempty(EEG.etc)
        EEG.etc = struct();
    end
    EEG.etc.interpolated_channel_indices = [];
    EEG.etc.interpolated_channel_labels  = {};
end

%% ========================================================================
%  OPTIONAL DEBUG SAVE: AFTER BAD CHANNEL REJECTION / INTERPOLATION
% ========================================================================
if step_cfg.save_intermediate_steps && step_cfg.save_intermediate_after_bad_channel_rejection
    helpers.save_intermediate_set( ...
        EEG, ...
        prep03_out_dir_untilica, ...
        string(run_base_name) + "_stage-prep03_after-badchan", ...
        "delete", ...
        cfg, ...
        step_cfg.intermediate_savemode, ...
        helpers);
end
% ========================================================================
%  2nd LINE NOISE (EEG + EOG ONLY): after interpolation (before rereference)
% ========================================================================
line_noise_applied_2 = false;

if string(step_cfg.line_noise_method) == "pop_cleanline"

    label_for_log = 'prep03_untilica line noise (cleanline AFTER interp BEFORE reref)';

    [eeg_idx2, eog_idx2, ~] = helpers.get_channel_indices_by_type(EEG);
    filter_idx2 = sort(unique([eeg_idx2(:); eog_idx2(:)]));

    [EEG, line_noise_applied_2] = helpers.apply_pop_cleanline_to_subset( ...
        EEG, filter_idx2, step_cfg, helpers, label_for_log);

    if ~line_noise_applied_2
        helpers.log_msg_default('prep03_untilica: WARNING 2nd pop_cleanline did not apply successfully.');
    end

else
    helpers.log_msg_default('prep03_untilica: 2nd line noise skipped (line_noise_method=%s)', ...
        string(step_cfg.line_noise_method));
end

EEG = helpers.append_eeg_comment(EEG, sprintf( ...
    'prep03_untilica: 2nd line noise method=%s applied=%d freqs=%s', ...
    string(step_cfg.line_noise_method), line_noise_applied_2, ...
    mat2str(step_cfg.line_noise_frequencies_hz)));

% Lowpass wie im ersten Cleanline-Pass danach
if string(step_cfg.line_noise_method) == "pop_cleanline"
    EEG = helpers.apply_filter_to_subset_only(EEG, filter_idx2, ...
        [], step_cfg.lowpass_hz, 'prep03_untilica low-pass AFTER 2nd cleanline');
end

%% ========================================================================
%  REREFERENCE
% ========================================================================
EEG = helpers.apply_reference_mode(EEG, step_cfg, helpers, 'prep03_untilica');

if ~isfield(EEG, 'etc') || isempty(EEG.etc)
    EEG.etc = struct();
end

EEG.etc.prep03_reference_mode = char(string(step_cfg.reference_mode));



%% ========================================================================
%  OPTIONAL DEBUG SAVE: AFTER REREFERENCE
% ========================================================================
if step_cfg.save_intermediate_steps && step_cfg.save_intermediate_after_rereference
    helpers.save_intermediate_set( ...
        EEG, ...
        prep03_out_dir_untilica, ...
        string(run_base_name) + "_stage-prep03_after-reref", ...
        "delete", ...
        cfg, ...
        step_cfg.intermediate_savemode, ...
        helpers);
end

%% ========================================================================
%  NOW IT IS SAFE TO DELETE OUTPUTS
% ========================================================================
if overwrite_mode == "delete" || needs_regen
        helpers.safe_delete_set(out_preica);
        helpers.safe_delete_set(out_forica);
end

%% ========================================================================
%  SAVE PREICA
% ========================================================================
EEG = helpers.append_eeg_comment(EEG, sprintf( ...
    'prep03_untilica: saved preica: %s', out_preica));

EEG = helpers.safe_save_set( ...
    EEG, ...
    prep03_out_dir_untilica, ...
    sprintf('%s_preica.set', run_base_name), ...
    helpers, ...
    cfg);

helpers.log_msg_default( ...
    'prep03_untilica: saved preica: %s', ...
    out_preica);


%% ========================================================================
%  CREATE FORICA
% ========================================================================
ica_prep_eeg = EEG;

ica_prep_eeg = helpers.apply_filter_to_subset_only( ...
    ica_prep_eeg, filter_idx, step_cfg.ica_prep_highpass_hz, [], ...
    'prep03_untilica ICA-prep high-pass');

ica_prep_eeg = helpers.append_eeg_comment(ica_prep_eeg, sprintf( ...
    'prep03_untilica: ICA-prep high-pass %.2f Hz', step_cfg.ica_prep_highpass_hz));

if step_cfg.ica_prep_use_regepochs
    if step_cfg.ica_prep_regepoch_length_sec <= 0
        error('prep03_untilica: cfg.prep_03.ica_prep_regepoch_length_sec must be > 0.');
    end

    ica_prep_eeg = eeg_regepochs(ica_prep_eeg, ...
        'recurrence', step_cfg.ica_prep_regepoch_length_sec, ...
        'limits', [0 step_cfg.ica_prep_regepoch_length_sec]);

    ica_prep_eeg = eeg_checkset(ica_prep_eeg);

    ica_prep_eeg = helpers.append_eeg_comment(ica_prep_eeg, sprintf( ...
        'prep03_untilica: ICA-prep regepochs %.2fs', ...
        step_cfg.ica_prep_regepoch_length_sec));
end

%% ========================================================================
%  ICA-PREP EPOCH REJECTION
% ========================================================================
ica_rej_method = "erplab";
if isfield(step_cfg, 'ica_prep_epoch_rejection_method') && ...
        strlength(string(step_cfg.ica_prep_epoch_rejection_method)) > 0
    ica_rej_method = lower(strtrim(string(step_cfg.ica_prep_epoch_rejection_method)));
end

switch ica_rej_method

    case {"none","off","disabled"}
        ica_prep_eeg = helpers.append_eeg_comment(ica_prep_eeg, ...
            'prep03_untilica: ICA-prep epoch rejection skipped by config');

        helpers.log_msg_default( ...
            'prep03_untilica: sub-%s | ICA-prep epoch rejection skipped backend=none', ...
            subj_id);

    case {"erplab","erplab_artifact","erplab_epoch_rejection"}
        if ~isfield(step_cfg, 'ica_prep_erplab_epoch_rejection') || ...
                ~isstruct(step_cfg.ica_prep_erplab_epoch_rejection)
            error('cfg.prep_03.ica_prep_erplab_epoch_rejection is missing, but ica_prep_epoch_rejection_backend="erplab".');
        end

        [ica_eeg_idx, ~, ~] = helpers.get_channel_indices_by_type(ica_prep_eeg);

        if isempty(ica_eeg_idx)
            ica_prep_eeg = helpers.append_eeg_comment(ica_prep_eeg, ...
                'prep03_untilica: ICA-prep ERPLAB rejection skipped because no EEG channels were found');

            helpers.log_msg_default( ...
                'prep03_untilica: sub-%s | ICA-prep ERPLAB rejection skipped: no EEG channels', ...
                subj_id);

        elseif ~isfield(ica_prep_eeg, 'trials') || ica_prep_eeg.trials < 1
            ica_prep_eeg = helpers.append_eeg_comment(ica_prep_eeg, ...
                'prep03_untilica: ICA-prep ERPLAB rejection skipped because no epochs were found');

            helpers.log_msg_default( ...
                'prep03_untilica: sub-%s | ICA-prep ERPLAB rejection skipped: no epochs', ...
                subj_id);

        else
            erplab_reject_cfg = step_cfg.ica_prep_erplab_epoch_rejection;
            erplab_reject_cfg.enable = true; % method selects ERPLAB; no user-facing second switch

            [ica_prep_eeg, erplab_info] = helpers.apply_erplab_epoch_rejection( ...
                ica_prep_eeg, ...
                ica_eeg_idx, ...
                erplab_reject_cfg, ...
                helpers, ...
                sprintf('sub-%s', subj_id), ...
                char(string(run_base_name) + " | ICA-prep"));

            ica_prep_eeg = helpers.append_eeg_comment(ica_prep_eeg, sprintf( ...
                ['prep03_untilica: ICA-prep ERPLAB rejection | rejected=%d/%d | kept=%d | ' ...
                 'extreme_voltage=%d | sample_diff=%d | flatline=%d'], ...
                erplab_info.n_rejected, ...
                erplab_info.n_before, ...
                erplab_info.n_kept, ...
                erplab_info.n_rejected_extreme_voltage, ...
                erplab_info.n_rejected_sample_diff, ...
                erplab_info.n_rejected_flatline));

            helpers.log_msg_default( ...
                ['prep03_untilica: sub-%s | ICA-prep ERPLAB rejection=%d/%d | kept=%d | ' ...
                 'extreme_voltage=%d | sample_diff=%d | flatline=%d'], ...
                subj_id, ...
                erplab_info.n_rejected, ...
                erplab_info.n_before, ...
                erplab_info.n_kept, ...
                erplab_info.n_rejected_extreme_voltage, ...
                erplab_info.n_rejected_sample_diff, ...
                erplab_info.n_rejected_flatline);
        end

              case {"mad","mad_variance","mad_epoch_rejection"}

        [ica_eeg_idx, ~, ~] = helpers.get_channel_indices_by_type(ica_prep_eeg);

        if isempty(ica_eeg_idx)
            ica_prep_eeg = helpers.append_eeg_comment(ica_prep_eeg, ...
                'prep03_untilica: ICA-prep MAD rejection skipped because no EEG channels were found');

            helpers.log_msg_default( ...
                'prep03_untilica: sub-%s | ICA-prep MAD rejection skipped: no EEG channels', ...
                subj_id);

        elseif ~isfield(ica_prep_eeg, 'trials') || ica_prep_eeg.trials < 1
            ica_prep_eeg = helpers.append_eeg_comment(ica_prep_eeg, ...
                'prep03_untilica: ICA-prep MAD rejection skipped because no epochs were found');

            helpers.log_msg_default( ...
                'prep03_untilica: sub-%s | ICA-prep MAD rejection skipped: no epochs', ...
                subj_id);

        else
            z_thresh = 3;
            if isfield(step_cfg, 'ica_prep_mad_z_threshold') && ...
                    ~isempty(step_cfg.ica_prep_mad_z_threshold)
                z_thresh = step_cfg.ica_prep_mad_z_threshold;
            end

            use_logvar = true;
            if isfield(step_cfg, 'ica_prep_mad_use_logvar') && ...
                    ~isempty(step_cfg.ica_prep_mad_use_logvar)
                use_logvar = logical(step_cfg.ica_prep_mad_use_logvar);
            end

            [ica_prep_eeg, mad_info] = helpers.reject_ica_prep_epochs_by_mad_variance( ...
                ica_prep_eeg, ...
                ica_eeg_idx, ...
                z_thresh, ...
                use_logvar);

            n_kept = ica_prep_eeg.trials;

            ica_prep_eeg = helpers.append_eeg_comment(ica_prep_eeg, sprintf( ...
                ['prep03_untilica: ICA-prep MAD variance rejection | rejected=%d/%d | kept=%d | ' ...
                 'z=%.2f | logvar=%d'], ...
                mad_info.n_rejected, ...
                mad_info.n_before, ...
                n_kept, ...
                z_thresh, ...
                use_logvar));

            helpers.log_msg_default( ...
                ['prep03_untilica: sub-%s | ICA-prep MAD variance rejection=%d/%d | kept=%d | ' ...
                 'z=%.2f | logvar=%d'], ...
                subj_id, ...
                mad_info.n_rejected, ...
                mad_info.n_before, ...
                n_kept, ...
                z_thresh, ...
                use_logvar);

            if isfield(step_cfg, 'ica_prep_max_reject_prop') && mad_info.n_before > 0
                reject_prop = mad_info.n_rejected / mad_info.n_before;

                if reject_prop > step_cfg.ica_prep_max_reject_prop
                    msg = sprintf( ...
                        'prep03_untilica: ICA-prep MAD variance rejection removed %.1f%% of epochs (threshold %.1f%%) -> cannot continue', ...
                        100 * reject_prop, 100 * step_cfg.ica_prep_max_reject_prop);
                    helpers.log_msg_default('%s', msg);
                    step_out.message = msg;
                    return;
                end
            end
        end

        case {"faster","faster_ptp"}

        if ~isfield(step_cfg, 'ica_prep_faster_ptp_epoch_rejection') || ...
                ~isstruct(step_cfg.ica_prep_faster_ptp_epoch_rejection)
            error('cfg.prep_03.ica_prep_faster_ptp_epoch_rejection is missing, but ica_prep_epoch_rejection_method="faster_ptp".');
        end

        [ica_eeg_idx, ~, ~] = helpers.get_channel_indices_by_type(ica_prep_eeg);

        if isempty(ica_eeg_idx)
            ica_prep_eeg = helpers.append_eeg_comment(ica_prep_eeg, ...
                'prep03_untilica: ICA-prep FASTER/PTP rejection skipped because no EEG channels were found');

            helpers.log_msg_default( ...
                'prep03_untilica: sub-%s | ICA-prep FASTER/PTP rejection skipped: no EEG channels', ...
                subj_id);

        elseif ~isfield(ica_prep_eeg, 'trials') || ica_prep_eeg.trials < 1
            ica_prep_eeg = helpers.append_eeg_comment(ica_prep_eeg, ...
                'prep03_untilica: ICA-prep FASTER/PTP rejection skipped because no epochs were found');

            helpers.log_msg_default( ...
                'prep03_untilica: sub-%s | ICA-prep FASTER/PTP rejection skipped: no epochs', ...
                subj_id);

        else
            reject_cfg = step_cfg.ica_prep_faster_ptp_epoch_rejection;
            reject_cfg.enable = true; % method selects FASTER/PTP; no user-facing second switch

            [ica_prep_eeg, faster_info] = helpers.apply_shared_epoch_rejection( ...
                ica_prep_eeg, ...
                reject_cfg);

            n_kept = ica_prep_eeg.trials;

            if isfield(faster_info, 'use_faster') && faster_info.use_faster && ...
                    isfield(faster_info, 'have_faster') && ~faster_info.have_faster
                helpers.log_msg_default( ...
                    'prep03_untilica: sub-%s | WARNING ICA-prep FASTER requested but epoch_properties() was not found. PTP may still have been applied if enabled.', ...
                    subj_id);
            end

            ica_prep_eeg = helpers.append_eeg_comment(ica_prep_eeg, sprintf( ...
                ['prep03_untilica: ICA-prep FASTER/PTP rejection | rejected=%d/%d | kept=%d | ' ...
                 'bad_faster=%d | bad_ptp=%d | z=%.2f | robust_z=%d | ptp=%.1f uV'], ...
                faster_info.n_rejected, ...
                faster_info.n_before, ...
                n_kept, ...
                helpers.getfield_safe(faster_info, 'n_bad_faster', 0), ...
                helpers.getfield_safe(faster_info, 'n_bad_ptp', 0), ...
                helpers.getfield_safe(faster_info, 'faster_z', NaN), ...
                helpers.getfield_safe(faster_info, 'use_robust_z', false), ...
                helpers.getfield_safe(faster_info, 'ptp_uV_thresh', NaN)));

            helpers.log_msg_default( ...
                ['prep03_untilica: sub-%s | ICA-prep FASTER/PTP rejection=%d/%d | kept=%d | ' ...
                 'bad_faster=%d | bad_ptp=%d | z=%.2f | robust_z=%d | ptp=%.1f uV'], ...
                subj_id, ...
                faster_info.n_rejected, ...
                faster_info.n_before, ...
                n_kept, ...
                helpers.getfield_safe(faster_info, 'n_bad_faster', 0), ...
                helpers.getfield_safe(faster_info, 'n_bad_ptp', 0), ...
                helpers.getfield_safe(faster_info, 'faster_z', NaN), ...
                helpers.getfield_safe(faster_info, 'use_robust_z', false), ...
                helpers.getfield_safe(faster_info, 'ptp_uV_thresh', NaN));

            if isfield(reject_cfg, 'max_reject_prop') && faster_info.n_before > 0
                reject_prop = faster_info.n_rejected / faster_info.n_before;

                if reject_prop > reject_cfg.max_reject_prop
                    msg = sprintf( ...
                        'prep03_untilica: ICA-prep FASTER/PTP rejection removed %.1f%% of epochs (threshold %.1f%%) -> cannot continue', ...
                        100 * reject_prop, 100 * reject_cfg.max_reject_prop);
                    helpers.log_msg_default('%s', msg);
                    step_out.message = msg;
                    return;
                end
            end
        end

    otherwise
        error(['Unsupported cfg.prep_03.ica_prep_epoch_rejection_method="%s". ' ...
               'Use "erplab", "faster_ptp", "mad_variance", or "none".'], ...
               char(ica_rej_method));
end

%% ========================================================================
%  SAVE FORICA
% ========================================================================
ica_prep_eeg = helpers.append_eeg_comment(ica_prep_eeg, sprintf( ...
    'prep03_untilica: saved forica: %s', out_forica));

ica_prep_eeg = helpers.safe_save_set( ...
    ica_prep_eeg, ...
    prep03_out_dir_forica, ...
    sprintf('%s_forica.set', run_base_name), ...
    helpers, ...
    cfg);

helpers.log_msg_default( ...
    'prep03_untilica: saved forica: %s', ...
    out_forica);

helpers.log_msg_default('prep03_untilica: DONE sub-%s | %s', subj_id, run_base_name);

step_out.ok = true;
step_out.skipped = false;
step_out.message = 'ok';

end

function step_cfg = local_default_prep03_cfg_impl()
step_cfg = struct();

% Crop
step_cfg.crop_to_task_markers = true;
step_cfg.crop_start_marker    = 'S 91';
step_cfg.crop_end_marker      = 'S 97';
step_cfg.crop_padding_sec     = [0 0];

% Channel typing labels
step_cfg.eog_channel_labels     = {'IO1','IO2','LO1','LO2'};
step_cfg.scr_channel_labels     = {'SCR'};
step_cfg.startle_channel_labels = {'Startle'};
step_cfg.ekg_channel_labels     = {'EKG'};

% Downsample
step_cfg.downsample_hz = 250;

% Bad channel detection
step_cfg.bad_channel_detection_method = "clean_rawdata"; % "clean_rawdata" | "pop_rejchan" | "off"

% Used when bad_channel_detection_method = "clean_rawdata"
step_cfg.clean_rawdata_flatline_sec           = 5;
step_cfg.clean_rawdata_channel_corr_threshold = 0.80;

% Used when bad_channel_detection_method = "pop_rejchan"
step_cfg.pop_rejchan_z_threshold  = 3.29;
step_cfg.pop_rejchan_freqrange_hz = [1 125];

% Interpolation timing
step_cfg.interpolate_bad_channels_before_ica = true;
step_cfg.interp_method = 'spherical';

% Step 03 debug/intermediate exports.
% Master switch. Default false = no Step 03 intermediate debug files.
% If true, the individual switches below decide which stages are written.
step_cfg.save_intermediate_steps = false;

% Save after final bad EEG channel list has been applied.
% In this pipeline, bad EEG channels are usually interpolated rather than
% permanently removed.
step_cfg.save_intermediate_after_bad_channel_rejection = true;

% Save after rereferencing.
step_cfg.save_intermediate_after_rereference = true;

% Save after high-pass filtering.
step_cfg.save_intermediate_after_highpass = true;

% Save after low-pass filtering.
step_cfg.save_intermediate_after_lowpass = true;

step_cfg.intermediate_savemode = 'twofiles';

% Referencing
step_cfg.reference_mode            = "avg";  % "keep" | "avg" | "mastoid"
step_cfg.reference_exclude_non_eeg = true;
step_cfg.mastoid_channel_labels    = {'T9','T10'};

% Filters
step_cfg.highpass_hz          = 0.01;
step_cfg.lowpass_hz           = 40;
step_cfg.ica_prep_highpass_hz = 1;

% Line noise
step_cfg.line_noise_method          = "pop_cleanline"; % "pop_cleanline" | "off"
step_cfg.line_noise_frequencies_hz  = [50 100];
step_cfg.pop_cleanline_bandwidth_hz = 2;
step_cfg.pop_cleanline_p_value      = 0.01;
step_cfg.pop_cleanline_scanforlines      = true;
step_cfg.pop_cleanline_winsize_sec       = 2;
step_cfg.pop_cleanline_winstep_sec       = 1;
step_cfg.pop_cleanline_tau               = 50;
step_cfg.pop_cleanline_pad               = 4;
step_cfg.pop_cleanline_taperbandwidth_hz = 4;
step_cfg.pop_cleanline_norm_spectrum     = 0;
step_cfg.pop_cleanline_computepower      = 0;
step_cfg.pop_cleanline_verbose           = false;

% ICA-prep: regepochs + rejection
step_cfg.ica_prep_use_regepochs       = true;
step_cfg.ica_prep_regepoch_length_sec = 1;

% Main ICA-prep epoch-rejection method.
% Select exactly one:
%   "erplab"     = ERPLAB pop_artextval/pop_artdiff/pop_artflatline
%   "faster_ptp" = FASTER epoch_properties + peak-to-peak threshold
%   "mad_variance" = robust MAD rejection on epoch variance
%   "none"       = no ICA-prep epoch rejection
step_cfg.ica_prep_epoch_rejection_method = "erplab";

% Legacy jointprob settings.
% Currently retained for backward compatibility with older configs.
step_cfg.ica_prep_use_jointprob_rejection = true;
step_cfg.ica_prep_jointprob_local         = 3;
step_cfg.ica_prep_jointprob_global        = 3;

% MAD ICA-prep rejection settings.
% Only used when ica_prep_epoch_rejection_method="mad_variance".
% These are the original scalar settings used by
% reject_ica_prep_epochs_by_mad_variance_impl.
step_cfg.ica_prep_use_mad_epoch_rejection = true;
step_cfg.ica_prep_mad_z_threshold         = 4;
step_cfg.ica_prep_mad_use_logvar          = true;
step_cfg.ica_prep_max_reject_prop         = 1.00;

% ERPLAB ICA-prep rejection.
% Same logic as final Step 06 rejection, but more lenient.
step_cfg.ica_prep_erplab_epoch_rejection = struct();
step_cfg.ica_prep_erplab_epoch_rejection.enable = true;
step_cfg.ica_prep_erplab_epoch_rejection.channel_scope = "eeg";
step_cfg.ica_prep_erplab_epoch_rejection.twindow_ms = [];
step_cfg.ica_prep_erplab_epoch_rejection.clear_existing_flags = true;

step_cfg.ica_prep_erplab_epoch_rejection.use_extreme_voltage = true;
step_cfg.ica_prep_erplab_epoch_rejection.extreme_voltage_uV  = 300;
step_cfg.ica_prep_erplab_epoch_rejection.flag_extreme_voltage = 1;

step_cfg.ica_prep_erplab_epoch_rejection.use_sample_diff = true;
step_cfg.ica_prep_erplab_epoch_rejection.sample_diff_uV  = 75;
step_cfg.ica_prep_erplab_epoch_rejection.flag_sample_diff = 2;

step_cfg.ica_prep_erplab_epoch_rejection.use_flatline = true;
step_cfg.ica_prep_erplab_epoch_rejection.flatline_tolerance_uV = 0.5;
step_cfg.ica_prep_erplab_epoch_rejection.flatline_duration_ms  = 200;
step_cfg.ica_prep_erplab_epoch_rejection.flag_flatline = 3;

step_cfg.ica_prep_erplab_epoch_rejection.review = "off";
step_cfg.ica_prep_erplab_epoch_rejection.history = "off";
step_cfg.ica_prep_erplab_epoch_rejection.lowpass_hz = -1;

% FASTER/PTP ICA-prep rejection.
% Only used when ica_prep_epoch_rejection_method="faster_ptp".
step_cfg.ica_prep_faster_ptp_epoch_rejection = struct();

step_cfg.ica_prep_faster_ptp_epoch_rejection.enable       = true;
step_cfg.ica_prep_faster_ptp_epoch_rejection.use_faster   = true;
step_cfg.ica_prep_faster_ptp_epoch_rejection.faster_z     = 4;
step_cfg.ica_prep_faster_ptp_epoch_rejection.use_robust_z = true;

step_cfg.ica_prep_faster_ptp_epoch_rejection.use_ptp       = true;
step_cfg.ica_prep_faster_ptp_epoch_rejection.ptp_uV_thresh = 800;

% 1.00 means disabled. Example: 0.50 stops Step 03 if >50% of ICA-prep
% epochs are removed.
step_cfg.ica_prep_faster_ptp_epoch_rejection.max_reject_prop = 1.00;

% Overwrite override
step_cfg.overwrite_mode = "";
end