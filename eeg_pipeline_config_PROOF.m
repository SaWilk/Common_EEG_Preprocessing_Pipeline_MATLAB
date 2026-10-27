% =========================================================================
% FILE: eeg_pipeline_config_PROOF.m
% =========================================================================
% Copyright (C) 2025–2026 Saskia Wilken and contributors
%
function cfg = eeg_pipeline_config_PROOF()
% EEG_PIPELINE_CONFIG
%
% PURPOSE
%   Define all user-facing settings for the EEG preprocessing pipeline.
%
% INPUT
%   Edit this file.
%
% OUTPUT
%   cfg : full configuration struct for run_eeg_pipeline.m
%
% REQUIREMENTS
%   - EEGLAB with ERPLAB plugin
%   - FASTER
%   - (AMICA - optional)
%   - (cleanline - optional)

% Saskia Wilken Dec 2025

bootstrap_log = fullfile(tempdir, 'eeg_pipeline_config_bootstrap.log');
helpers = eeg_pipeline_helpers(bootstrap_log);

% =========================================================================
% USER SETTINGS
% Edit the cfg.* fields in this section.
%
% PATH CONCEPT
%   source_eeg_root   = fresh/raw BrainVision files before BIDS formatting
%   source_beh_root   = optional project-specific raw behavior/log files
%   bids_root         = BIDS-formatted raw dataset
%                       -> output of Step 01
%                       -> input of Steps 02-06
%   derivatives_root  = preprocessing outputs from Steps 02-06
% =========================================================================

cfg = struct();

% One shared timestamp for all QC files produced by this pipeline run.
% Filenames start with yyyy-mm-dd-hh-mm so runs can be compared directly.
cfg.qc = struct();
cfg.qc.filename_timestamp_format = 'yyyy-mm-dd-HH-MM';
cfg.qc.run_timestamp = string(datestr(now, cfg.qc.filename_timestamp_format));
cfg.qc.table_delimiter = ';';

% -------------------------------------------------------------------------
% Project identity
% -------------------------------------------------------------------------
cfg.pipeline = struct();
cfg.pipeline.name        = "matrics_classical_pipeline";
cfg.pipeline.step_prefix = "eeg";

cfg.constants = struct();
cfg.constants.log_prefix_master = "run_eeg_pipeline_classical";

cfg.bids = struct();
cfg.bids.dataset_folder_name = "BIDS_RTGMN_Classic";
cfg.bids.task_label          = "classical";
cfg.bids.session_label       = "01";

% -------------------------------------------------------------------------
% Profile / paths
% -------------------------------------------------------------------------
cfg.paths = struct();

cfg.paths.branch_by_ica_method = true;

cfg.paths.profile_override = "";

cfg.paths.profile_paths = struct();

cfg.paths.profile_paths.pc = struct( ...
    'source_eeg_root',  'Z:\pb\KLPSY1\KLPSY1-RTG\PROOF - Data\Real\EEG\Classical', ...
    'source_beh_root',  'Z:\pb\KLPSY1\KLPSY1-RTG\PROOF - Data\Real\LOGFILES\Classical', ...
    'bids_root',        'Z:\pb\KLPSY1\KLPSY1-RTG\MATRICS\sourcedata', ...
    'derivatives_root', 'Z:\pb\KLPSY1\KLPSY1-RTG\MATRICS\derivatives\preprocessed_eeg');

cfg.paths.profile_paths.server_windows = struct( ...
    'source_eeg_root',  'Z:\pb\KLPSY1\KLPSY1-RTG\PROOF - Data\Real\EEG\Classical', ...
    'source_beh_root',  'Z:\pb\KLPSY1\KLPSY1-RTG\PROOF - Data\Real\LOGFILES\Classical', ...
    'bids_root',        'Z:\pb\KLPSY1\KLPSY1-RTG\MATRICS\sourcedata', ...
    'derivatives_root', 'Z:\pb\KLPSY1\KLPSY1-RTG\MATRICS\derivatives\preprocessed_eeg');

cfg.paths.profile_paths.hpc_hummel = struct( ...
    'source_eeg_root',  '', ...
    'source_beh_root',  '', ...
    'bids_root',        fullfile( ...
        '/beegfs/u/bbf7366/sourcedata', ...
        char(cfg.bids.dataset_folder_name)), ...
    'derivatives_root', ...
        '/beegfs/u/bbf7366/derivatives/preprocessed_eeg_classical');

cfg.paths.bids_root_override        = "";
cfg.paths.derivatives_root_override = "";
cfg.paths.source_eeg_root_override  = "";
cfg.paths.source_beh_root_override  = "";

% =========================================================================
% TOOLBOX PATHS
% =========================================================================
cfg.toolboxes = struct();

cfg.toolboxes.path_eeglab_pc = ...
    "K:\Wilken_Arbeitsordner\MATLAB\eeglab_current\eeglab2025.1.0";
cfg.toolboxes.path_eeglab_server = ...
    "K:\Wilken_Arbeitsordner\MATLAB\eeglab_current\eeglab2025.1.0";
cfg.toolboxes.path_eeglab_hpc = ...
    "/beegfs/u/bbf7366/toolboxes/eeglab2025.1.0";

cfg.toolboxes.path_faster_pc = ...
    "K:\Wilken_Arbeitsordner\MATLAB\FASTER";
cfg.toolboxes.path_faster_server = ...
    "K:\Wilken_Arbeitsordner\MATLAB\FASTER";
cfg.toolboxes.path_faster_hpc = ...
    "/beegfs/u/bbf7366/toolboxes/FASTER";

cfg.toolboxes.path_erplab_pc = ...
    "K:\Wilken_Arbeitsordner\MATLAB\erplab13.00";
cfg.toolboxes.path_erplab_server = ...
    "K:\Wilken_Arbeitsordner\MATLAB\erplab13.00";
cfg.toolboxes.path_erplab_hpc = ...
    "/beegfs/u/bbf7366/toolboxes/erplab";

cfg.toolboxes.erplab = struct();
cfg.toolboxes.erplab.use_genpath = true;

cfg.toolboxes.use_genpath = false;

cfg.toolboxes.eeglab = struct();
cfg.toolboxes.eeglab.no_update_check_on_hpc = true;
cfg.toolboxes.eeglab.nogui = true;

% -------------------------------------------------------------------------
% Overwrite behavior
% -------------------------------------------------------------------------
cfg.io = struct();
cfg.io.overwrite_mode          = "delete";
cfg.io.overwrite_if_older_than = "";

% =========================================================================
% INTERNAL SETUP
% =========================================================================
this_file = mfilename('fullpath');
root_dir  = fileparts(this_file);

cfg.this_file = this_file;
cfg.root_dir  = root_dir;

% =========================================================================
% CONSTANTS
% =========================================================================
cfg.constants.valid_sub_id_regex = '^\d{3}$';
cfg.constants.log_prefix_subject = 'sub';
cfg.constants.datestr_master     = 'yyyymmdd_HHMMSS';
cfg.constants.datestr_subject    = 'yyyymmdd_HHMMSS_FFF';

% =========================================================================
% ENVIRONMENT
% =========================================================================
cfg.env = struct();
cfg.env.mode         = helpers.detect_env_mode();
cfg.env.machine_kind = helpers.detect_machine_kind();
cfg.env.hostname     = helpers.get_hostname();

cfg.env.is_slurm = ~isempty(getenv('SLURM_JOB_ID'));
cfg.env.slurm_job_id = string( ...
    helpers.get_env_first_nonempty({'SLURM_JOB_ID'}));
cfg.env.slurm_cluster = string( ...
    helpers.get_env_first_nonempty({'SLURM_CLUSTER_NAME'}));

% =========================================================================
% RESOLVED PATHS
% =========================================================================
cfg.paths.profile = helpers.default_profile_for_mode( ...
    cfg.env.mode, cfg.env.machine_kind);

profile_env = helpers.get_env_first_nonempty( ...
    {'EEG_PIPELINE_PROFILE'});
if strlength(profile_env) > 0
    cfg.paths.profile = string(profile_env);
end

if strlength(string(cfg.paths.profile_override)) > 0
    cfg.paths.profile = string(cfg.paths.profile_override);
end

profile_name = char(string(cfg.paths.profile));
if ~isfield(cfg.paths.profile_paths, profile_name)
    error( ...
        'Unknown cfg.paths.profile="%s". Define it in cfg.paths.profile_paths.', ...
        string(cfg.paths.profile));
end

profile_cfg = cfg.paths.profile_paths.(profile_name);

cfg.paths.source_eeg_root  = string(profile_cfg.source_eeg_root);
cfg.paths.source_beh_root  = string(profile_cfg.source_beh_root);
cfg.paths.bids_root        = string(profile_cfg.bids_root);
cfg.paths.derivatives_root = string(profile_cfg.derivatives_root);
cfg.paths.logs_dir = fullfile( ...
    fileparts(cfg.paths.derivatives_root), ...
    'logs', ...
    'runlog_pipeline');

bids_env = helpers.get_env_first_nonempty( ...
    {'EEG_PIPELINE_BIDS_ROOT'});
derivatives_env = helpers.get_env_first_nonempty( ...
    {'EEG_PIPELINE_DERIVATIVES_ROOT'});
source_eeg_env = helpers.get_env_first_nonempty( ...
    {'EEG_PIPELINE_SOURCE_EEG_ROOT'});
source_beh_env = helpers.get_env_first_nonempty( ...
    {'EEG_PIPELINE_SOURCE_BEH_ROOT'});

if strlength(bids_env) > 0
    cfg.paths.bids_root = string(bids_env);
end

if strlength(derivatives_env) > 0
    cfg.paths.derivatives_root = string(derivatives_env);
end

if strlength(source_eeg_env) > 0
    cfg.paths.source_eeg_root = string(source_eeg_env);
end

if strlength(source_beh_env) > 0
    cfg.paths.source_beh_root = string(source_beh_env);
end

if strlength(string(cfg.paths.bids_root_override)) > 0
    cfg.paths.bids_root = string(cfg.paths.bids_root_override);
end

if strlength(string(cfg.paths.derivatives_root_override)) > 0
    cfg.paths.derivatives_root = ...
        string(cfg.paths.derivatives_root_override);
end

if strlength(string(cfg.paths.source_eeg_root_override)) > 0
    cfg.paths.source_eeg_root = ...
        string(cfg.paths.source_eeg_root_override);
end

if strlength(string(cfg.paths.source_beh_root_override)) > 0
    cfg.paths.source_beh_root = ...
        string(cfg.paths.source_beh_root_override);
end

% =========================================================================
% SUBJECTS
% =========================================================================
cfg.subjects = struct();
cfg.subjects.list   = [];
cfg.subjects.min_id = [];

% =========================================================================
% PARALLEL
% =========================================================================
cfg.parallel = struct();
cfg.parallel.enable        = true;
cfg.parallel.force_workers = [];

% =========================================================================
% STEP TOGGLES
% =========================================================================
cfg.steps = struct();

cfg.steps.enable_downstream_rerun = true;

cfg.steps.prep_01_bids_formatting = struct( ...
    'run', false, ...
    'overwrite_mode', "", ...
    'overwrite_if_older_than', "");

cfg.steps.prep_02_triggerfix = struct( ...
    'run', false, ...
    'overwrite_mode', "", ...
    'overwrite_if_older_than', "");

cfg.steps.prep_03_until_ica = struct( ...
    'run', false, ...
    'overwrite_mode', "", ...
    'overwrite_if_older_than', "");

cfg.steps.prep_04_ica = struct( ...
    'run', false, ...
    'overwrite_mode', "", ...
    'overwrite_if_older_than', "");

cfg.steps.prep_05_after_ica = struct( ...
    'run', true, ...
    'overwrite_mode', "", ...
    'overwrite_if_older_than', "");

cfg.steps.prep_06_epoching = struct( ...
    'run', true, ...
    'overwrite_mode', "", ...
    'overwrite_if_older_than', "");

% =========================================================================
% STEP FUNCTION HANDLES
% =========================================================================
cfg.step_fns = struct();
cfg.step_fns.prep_01_bids_formatting = ...
    str2func(char(cfg.pipeline.step_prefix + "_prep01_bids_formatting"));
cfg.step_fns.prep_02_triggerfix = ...
    str2func(char(cfg.pipeline.step_prefix + "_prep02_triggerfix"));
cfg.step_fns.prep_03_until_ica = ...
    str2func(char(cfg.pipeline.step_prefix + "_prep03_untilica"));
cfg.step_fns.prep_04_ica = ...
    str2func(char(cfg.pipeline.step_prefix + "_prep04_ica"));
cfg.step_fns.prep_05_after_ica = ...
    str2func(char(cfg.pipeline.step_prefix + "_prep05_after_ica"));
cfg.step_fns.prep_06_epoching = ...
    str2func(char(cfg.pipeline.step_prefix + "_prep06_epoching"));

% =========================================================================
% STEP 01: BIDS FORMATTING
% =========================================================================
cfg.prep_01 = struct();

cfg.prep_01.do_eeg = true;
cfg.prep_01.do_beh = true;

cfg.prep_01.try_eeglab_bids_export = true;
cfg.prep_01.write_readme_if_exporter_did_not = true;
cfg.prep_01.copy_eeg_sidecar_log_to_events = false;

cfg.prep_01.raw_eeg_regex = ...
    '_(\d{3})(?:_(\d{3}))?\.vhdr$';

cfg.prep_01.existing_bids_vhdr_regex = ...
    '^sub-(\d+)_ses-(\d+)_task-([A-Za-z0-9]+)(?:_run-(\d+))?_eeg\.vhdr$';

cfg.prep_01.session_label = cfg.bids.session_label;
cfg.prep_01.task_label    = cfg.bids.task_label;

% =========================================================================
% STEP 02: TRIGGERFIX
% =========================================================================
cfg.prep_02 = struct();

cfg.prep_02.run_raw_order_qc = true;

cfg.prep_02.allow_multiple_runs  = false;
cfg.prep_02.multiple_vhdr_policy = "most_recent";

cfg.prep_02.qc_out_dir = "";

cfg.prep_02.task_label         = cfg.bids.task_label;
cfg.prep_02.session_label      = cfg.bids.session_label;
cfg.prep_02.input_vhdr_pattern = "";

cfg.prep_02.use_explicit_chanlist = false;
cfg.prep_02.explicit_chanlist     = 1:66;

cfg.prep_02.raw_qc_keep_tokens = [ ...
    "S 20", "S 21", "S 22", "S 23", "S 24", "S 15", "S 5"];
cfg.prep_02.raw_qc_bin_size_s      = 1;
cfg.prep_02.raw_qc_max_rows        = 20000;
cfg.prep_02.raw_qc_write_csv_on_ok = false;

cfg.prep_02.behavior_log_column_event_type = 'EventType';
cfg.prep_02.behavior_log_column_code       = 'Code';
cfg.prep_02.behavior_log_column_time       = 'Time';
cfg.prep_02.behavior_log_time_unit         = "ms";

cfg.prep_02.behavior_log_map = { ...
    'Picture', 'cs-',      'cs_minus'; ...
    'Picture', 'csminus',  'cs_minus'; ...
    'Picture', 'cs_min',   'cs_minus'; ...
    'Picture', 'csmin',    'cs_minus'; ...
    'Picture', 'cs1',      'cs_minus'; ...
    'Picture', 'GS1',      'gs_1'; ...
    'Picture', 'GSU',      'gs_u'; ...
    'Picture', 'GS2',      'gs_2'; ...
    'Picture', 'cs+',      'cs_plus'; ...
    'Picture', 'csplus',   'cs_plus'; ...
    'Picture', 'cs_pls',   'cs_plus'; ...
    'Picture', 'cspls',    'cs_plus'; ...
    'Picture', 'cs2',      'cs_plus'; ...
    'Sound',   'Startle',  'startle'; ...
    'Nothing', 'Shock',    'shock' ...
    };

cfg.prep_02.phase_start_markers = struct();
cfg.prep_02.phase_start_markers.habituation    = "S 91";
cfg.prep_02.phase_start_markers.acquisition    = "S 92";
cfg.prep_02.phase_start_markers.generalization = "S 93";
cfg.prep_02.phase_start_markers.extinction     = "S 94";
cfg.prep_02.phase_start_markers.return_of_fear = "S 95";

cfg.prep_02.raw_triggers = struct();
cfg.prep_02.raw_triggers.cs_minus = "S 20";
cfg.prep_02.raw_triggers.gs_1     = "S 21";
cfg.prep_02.raw_triggers.gs_u     = "S 22";
cfg.prep_02.raw_triggers.gs_2     = "S 23";
cfg.prep_02.raw_triggers.cs_plus  = "S 24";
cfg.prep_02.raw_triggers.startle  = "S 15";
cfg.prep_02.raw_triggers.shock    = "S 5";

cfg.prep_02.habituation_map = { ...
    'cs_minus', "S 201"; ...
    'gs_1',     "S 211"; ...
    'gs_u',     "S 221"; ...
    'gs_2',     "S 231"; ...
    'cs_plus',  "S 241" ...
    };

cfg.prep_02.generalization_map = { ...
    'cs_minus', "S 203"; ...
    'gs_1',     "S 213"; ...
    'gs_u',     "S 223"; ...
    'gs_2',     "S 233"; ...
    'cs_plus',  "S 243" ...
    };

cfg.prep_02.return_of_fear_map = { ...
    'cs_minus', "S 205"; ...
    'gs_1',     "S 215"; ...
    'gs_u',     "S 225"; ...
    'gs_2',     "S 235"; ...
    'cs_plus',  "S 245" ...
    };

cfg.prep_02.acquisition = struct();
cfg.prep_02.acquisition.cs_minus_key      = 'cs_minus';
cfg.prep_02.acquisition.cs_plus_key       = 'cs_plus';
cfg.prep_02.acquisition.n_first_block     = 10;
cfg.prep_02.acquisition.code_minus_block1 = "S 2021";
cfg.prep_02.acquisition.code_plus_block1  = "S 2421";
cfg.prep_02.acquisition.code_minus_block2 = "S 2022";
cfg.prep_02.acquisition.code_plus_block2  = "S 2422";

cfg.prep_02.extinction = struct();
cfg.prep_02.extinction.cs_minus_key      = 'cs_minus';
cfg.prep_02.extinction.cs_plus_key       = 'cs_plus';
cfg.prep_02.extinction.n_first_block     = 11;
cfg.prep_02.extinction.n_second_block    = 10;
cfg.prep_02.extinction.code_minus_block1 = "S 2041";
cfg.prep_02.extinction.code_plus_block1  = "S 2441";
cfg.prep_02.extinction.code_minus_block2 = "S 2042";
cfg.prep_02.extinction.code_plus_block2  = "S 2442";
cfg.prep_02.extinction.code_minus_block3 = "S 2043";
cfg.prep_02.extinction.code_plus_block3  = "S 2443";

cfg.prep_02.disable_first_ext_trials = true;
cfg.prep_02.disable_first_acq_trials = true;

cfg.prep_02.disable_first_extinction = struct();
cfg.prep_02.disable_first_extinction.first_minus_code = "S 2041";
cfg.prep_02.disable_first_extinction.first_plus_code  = "S 2441";
cfg.prep_02.disable_first_extinction.revert_minus_key = 'cs_minus';
cfg.prep_02.disable_first_extinction.revert_plus_key  = 'cs_plus';

cfg.prep_02.disable_first_acquisition = struct();
cfg.prep_02.disable_first_acquisition.first_minus_code = "S 2021";
cfg.prep_02.disable_first_acquisition.first_plus_code  = "S 2421";
cfg.prep_02.disable_first_acquisition.disabled_minus_code = "S 20999";
cfg.prep_02.disable_first_acquisition.disabled_plus_code  = "S 24999";

% =========================================================================
% STEP 03: UNTIL ICA
% =========================================================================
cfg.prep_03 = struct();

cfg.prep_03.crop_to_task_markers = false;
cfg.prep_03.crop_start_marker    = 'S 91';
cfg.prep_03.crop_end_marker      = 'S 97';
cfg.prep_03.crop_padding_sec     = [0 0];

% Make sure that all non-EEG channel labels used in the dataset are included
% here. Otherwise they may be treated as EEG channels during preprocessing.
cfg.prep_03.eog_channel_labels = ...
    {'IO1', 'IO2', 'LO1', 'LO2'};
cfg.prep_03.scr_channel_labels = ...
    {'SCR'};
cfg.prep_03.startle_channel_labels = ...
    {'Startle'};
cfg.prep_03.ekg_channel_labels = ...
    {'EKG'};

cfg.prep_03.downsample_hz = 250;

% -------------------------------------------------------------------------
% Filter settings
% -------------------------------------------------------------------------
cfg.prep_03.highpass_hz          = 0.01;
cfg.prep_03.lowpass_hz           = 30;
cfg.prep_03.ica_prep_highpass_hz = 1;

% -------------------------------------------------------------------------
% Bad-channel detection and interpolation
% -------------------------------------------------------------------------
cfg.prep_03.bad_channel_detection_method = "pop_rejchan";

% Flat or invalid EEG channels are identified independently of the selected
% bad-channel backend. AUX channels are removed only if they are non-finite
% or completely constant.
cfg.prep_03.flat_channel_detection = struct();
cfg.prep_03.flat_channel_detection.enable = true;
cfg.prep_03.flat_channel_detection.mode = ...
    "cumulative_fraction";
cfg.prep_03.flat_channel_detection.max_flat_fraction = 0.10;
cfg.prep_03.flat_channel_detection.continuous_flat_sec = 5;
cfg.prep_03.flat_channel_detection.step_tolerance_uV = 0;

% Used only with bad_channel_detection_method="clean_rawdata".
cfg.prep_03.clean_rawdata_channel_corr_threshold = 0.80;

% Used only with bad_channel_detection_method="pop_rejchan".
cfg.prep_03.pop_rejchan_z_threshold  = 5;
cfg.prep_03.pop_rejchan_freqrange_hz = ...
    [1, cfg.prep_03.lowpass_hz + 10];

cfg.prep_03.interpolate_bad_channels_before_ica = true;
cfg.prep_03.interp_method = 'spherical';

% -------------------------------------------------------------------------
% Step-03 intermediate exports
% -------------------------------------------------------------------------
cfg.prep_03.save_intermediate_steps = false;
cfg.prep_03.save_intermediate_after_bad_channel_rejection = true;
cfg.prep_03.save_intermediate_after_rereference = true;
cfg.prep_03.save_intermediate_after_highpass = true;
cfg.prep_03.save_intermediate_after_lowpass = true;
cfg.prep_03.intermediate_savemode = 'twofiles';

% -------------------------------------------------------------------------
% Re-referencing
% -------------------------------------------------------------------------
cfg.prep_03.reference_mode            = "avg";
cfg.prep_03.reference_exclude_non_eeg = true;
cfg.prep_03.mastoid_channel_labels    = {'T9', 'T10'};

% -------------------------------------------------------------------------
% Line-noise filtering
% -------------------------------------------------------------------------
cfg.prep_03.line_noise_method = "pop_cleanline";
cfg.prep_03.line_noise_frequencies_hz = [50 100];

cfg.prep_03.pop_cleanline_bandwidth_hz      = 4;
cfg.prep_03.pop_cleanline_p_value           = 0.01;
cfg.prep_03.pop_cleanline_scanforlines      = true;
cfg.prep_03.pop_cleanline_winsize_sec       = 2;
cfg.prep_03.pop_cleanline_winstep_sec       = 1;
cfg.prep_03.pop_cleanline_tau               = 50;
cfg.prep_03.pop_cleanline_pad               = 4;
cfg.prep_03.pop_cleanline_taperbandwidth_hz = 4;
cfg.prep_03.pop_cleanline_norm_spectrum     = 0;
cfg.prep_03.pop_cleanline_computepower      = 0;
cfg.prep_03.pop_cleanline_verbose           = false;

% -------------------------------------------------------------------------
% ICA-training epoch rejection
% -------------------------------------------------------------------------
cfg.prep_03.ica_prep_epoch_rejection_method = "faster_ptp";

cfg.prep_03.ica_prep_erplab_epoch_rejection = struct();
cfg.prep_03.ica_prep_erplab_epoch_rejection.channel_scope = "eeg";
cfg.prep_03.ica_prep_erplab_epoch_rejection.twindow_ms = [];
cfg.prep_03.ica_prep_erplab_epoch_rejection.clear_existing_flags = true;

cfg.prep_03.ica_prep_erplab_epoch_rejection.use_extreme_voltage = true;
cfg.prep_03.ica_prep_erplab_epoch_rejection.extreme_voltage_uV = 300;
cfg.prep_03.ica_prep_erplab_epoch_rejection.flag_extreme_voltage = 1;

cfg.prep_03.ica_prep_erplab_epoch_rejection.use_sample_diff = true;
cfg.prep_03.ica_prep_erplab_epoch_rejection.sample_diff_uV = 75;
cfg.prep_03.ica_prep_erplab_epoch_rejection.flag_sample_diff = 2;

cfg.prep_03.ica_prep_erplab_epoch_rejection.use_flatline = false;
cfg.prep_03.ica_prep_erplab_epoch_rejection.flatline_tolerance_uV = 0.5;
cfg.prep_03.ica_prep_erplab_epoch_rejection.flatline_duration_ms = 200;
cfg.prep_03.ica_prep_erplab_epoch_rejection.flag_flatline = 3;

cfg.prep_03.ica_prep_erplab_epoch_rejection.review = "off";
cfg.prep_03.ica_prep_erplab_epoch_rejection.history = "off";
cfg.prep_03.ica_prep_erplab_epoch_rejection.lowpass_hz = -1;

cfg.prep_03.ica_prep_mad_z_threshold = 3;
cfg.prep_03.ica_prep_mad_use_logvar  = true;
cfg.prep_03.ica_prep_max_reject_prop = 1.00;

cfg.prep_03.ica_prep_faster_ptp_epoch_rejection = struct();
cfg.prep_03.ica_prep_faster_ptp_epoch_rejection.use_faster = true;
cfg.prep_03.ica_prep_faster_ptp_epoch_rejection.faster_z = 4;
cfg.prep_03.ica_prep_faster_ptp_epoch_rejection.use_robust_z = true;
cfg.prep_03.ica_prep_faster_ptp_epoch_rejection.use_ptp = true;
cfg.prep_03.ica_prep_faster_ptp_epoch_rejection.ptp_uV_thresh = 100;
cfg.prep_03.ica_prep_faster_ptp_epoch_rejection.max_reject_prop = 1.00;

% =========================================================================
% STEP 04: ICA
% =========================================================================
cfg.prep_04 = struct();

cfg.prep_04.ica_method = "runica";
cfg.prep_04.use_extended_infomax = true;
cfg.prep_04.interrupt_ica = 'off';
cfg.prep_04.use_pca_rank_if_interpolated = true;
cfg.prep_04.amica_require_no_spaces_on_windows = true;
cfg.prep_04.ica_channel_scope = "eeg_eog";
% Step 04 derives the task filter from cfg.bids.task_label and requires an
% exact *_forica.set / *_preica.set pair for every processed run.

% AMICA always fits one model. Reaching max_iter with finite, valid output is
% retained as a warning. Invalid/non-finite output remains a hard failure.
cfg.prep_04.amica_max_iter = 3000;
cfg.prep_04.amica_write_update_norm_history = false;
cfg.prep_04.amica_check_convergence = true;
cfg.prep_04.amica_fail_on_nonconvergence = true;
cfg.prep_04.amica_convergence_min_iterations = 50;
cfg.prep_04.amica_convergence_tail_window = 20;
cfg.prep_04.amica_keep_tmp_on_qc_failure = false;

cfg.prep_04.write_run_qc_table = false;
cfg.prep_04.write_subject_qc_table = true;
cfg.prep_04.qc_table_delimiter = ';';

% =========================================================================
% STEP 05: AFTER ICA / ICLABEL
% =========================================================================
cfg.prep_05 = struct();

cfg.prep_05.clear_subject_ica_comps_dir = true; % remove existing QA PNGs only
% for the current subject/task/run before exporting replacements

% Every ICLabel rejection rule has an independent switch. The thresholds
% below retain the previous PROOF configuration.
cfg.prep_05.iclabel_remove_eye           = true;
cfg.prep_05.iclabel_remove_muscle        = true;
cfg.prep_05.iclabel_remove_heart         = true;
cfg.prep_05.iclabel_remove_linenoise     = true;
cfg.prep_05.iclabel_remove_channoise     = true;
cfg.prep_05.iclabel_remove_other         = false;
cfg.prep_05.iclabel_remove_low_brain     = false;

cfg.prep_05.iclabel_eye_remove_thr       = 0.70;
cfg.prep_05.iclabel_muscle_remove_thr    = 0.80;
cfg.prep_05.iclabel_heart_remove_thr     = 0.80;
cfg.prep_05.iclabel_linenoise_remove_thr = 0.80;
cfg.prep_05.iclabel_channoise_remove_thr = 0.80;
cfg.prep_05.iclabel_other_remove_thr     = 0.95;
cfg.prep_05.iclabel_brain_min_keep_thr   = 0.00;

cfg.prep_05.save_ic_topos_png   = false;
cfg.prep_05.iclabel_edge_margin = 0.00;
cfg.prep_05.ic_topo_dpi         = 300;
cfg.prep_05.ic_topo_fig_cm      = [0 0 18 18];
cfg.prep_05.ic_topo_electrodes  = 'off';

% -------------------------------------------------------------------------
% Two-level signal QC after IC rejection
% -------------------------------------------------------------------------
% Warning-level violations are written to the log and QC tables, but the
% cleaned dataset is still saved.
%
% Extreme violations are written to QC, but a single extreme metric still
% remains a warning. At least two simultaneous extreme metrics are required
% for a signal-QC failure. Invalid/non-finite output remains an immediate
% technical failure.
cfg.prep_05.signal_qc_enable = true;

% Retained for backward-compatible configuration validation. This must stay
% true because hard QC failures must never produce a cleaned output dataset.
cfg.prep_05.signal_qc_fail_on_violation = true;

cfg.prep_05.signal_qc_channel_scope = "eeg";
cfg.prep_05.signal_qc_max_prop_ic_removed = 0.95;
cfg.prep_05.signal_qc_min_remaining_components = 2;

% Warning thresholds.
cfg.prep_05.signal_qc_min_median_channel_correlation = 0.80;
cfg.prep_05.signal_qc_max_relative_change_rms = 0.85;
cfg.prep_05.signal_qc_min_rms_ratio = 0.50;
cfg.prep_05.signal_qc_max_rms_ratio = 1.10;

% Extreme thresholds. At least two must be crossed together to prevent saving.
cfg.prep_05.signal_qc_hard_min_median_channel_correlation = 0.10;
cfg.prep_05.signal_qc_hard_max_relative_change_rms = 10.00;
cfg.prep_05.signal_qc_hard_min_rms_ratio = 0.10;
cfg.prep_05.signal_qc_hard_max_rms_ratio = 10.00;
cfg.prep_05.signal_qc_min_extreme_metrics_to_fail = 2; % independent problem domains, not correlated raw metrics

cfg.prep_05.signal_qc_fail_on_nonfinite = true;
cfg.prep_05.signal_qc_fail_on_flat_channels = true;
cfg.prep_05.signal_qc_flat_std_epsilon = 1e-8;

% Optional validation-sample diagnostic for either RUNICA or AMICA. MI has no
% universal pass/fail threshold and is therefore disabled for routine runs.
cfg.prep_05.compute_decomposition_qc = false;
cfg.prep_05.decomposition_qc_max_samples = 5000;
cfg.prep_05.decomposition_qc_mi_bins = 20;

cfg.prep_05.write_component_table = true;       % retained for targeted review
cfg.prep_05.write_run_summary_table = false;    % avoid duplicate run files
cfg.prep_05.write_subject_summary_table = true; % one compact source per subject
cfg.prep_05.qc_table_delimiter = ';';

% =========================================================================
% STEP 06: EPOCHING + FINAL ARTIFACT REJECTION
% =========================================================================
cfg.prep_06 = struct();

cfg.prep_06.epoching_mode  = "event_locked";
cfg.prep_06.overwrite_mode = "";

cfg.prep_06.save_final_only = true;
cfg.prep_06.save_intermediate_steps = false;

cfg.prep_06.reference_mode = "keep";
cfg.prep_06.mastoid_channel_labels = {'T9', 'T10'};

cfg.prep_06.do_baseline_correction = true;
cfg.prep_06.base_start_ms = -200;
cfg.prep_06.base_end_ms   = 0;

cfg.prep_06.events_phase = { ...
    'S 201', 'S 241', ...
    'S 2021', 'S 2421', 'S 2022', 'S 2422', ...
    'S 203', 'S 213', 'S 223', 'S 233', 'S 243', ...
    'S 2041', 'S 2441', 'S 2042', 'S 2442', ...
    'S 2043', 'S 2443', ...
    'S 205', 'S 245' ...
    };

cfg.prep_06.epoch_start_s = -0.4;
cfg.prep_06.epoch_end_s   = 2.6;

% Baseline-mode settings are retained for structural consistency but are
% ignored while epoching_mode="event_locked".
cfg.prep_06.regepoch_length_sec = 10;
cfg.prep_06.regepoch_step_sec   = 10;

cfg.prep_06.baseline_has_conditions = false;
cfg.prep_06.baseline_condition_definitions = {};
cfg.prep_06.baseline_start_condition = "";
cfg.prep_06.baseline_end_markers = {};
cfg.prep_06.baseline_end_condition = "";

cfg.prep_06.do_artifact_rejection = true;

cfg.prep_06.do_initial_hard_threshold_rejection = false;
cfg.prep_06.initial_hard_threshold_uv = 200;

cfg.prep_06.epoch_rejection_method = "faster_ptp";

cfg.prep_06.max_reject_prop = 1;

% Warning only: report subjects with more than 25% rejected epochs at the
% end of console output and in the master run log.
cfg.prep_06.warn_if_reject_prop_gt = 0.25;

% -------------------------------------------------------------------------
% ERPLAB epoch rejection
% -------------------------------------------------------------------------
cfg.prep_06.erplab_epoch_rejection = struct();

cfg.prep_06.erplab_epoch_rejection.channel_scope = "eeg";
cfg.prep_06.erplab_epoch_rejection.twindow_ms = [];
cfg.prep_06.erplab_epoch_rejection.clear_existing_flags = true;

cfg.prep_06.erplab_epoch_rejection.use_extreme_voltage = true;
cfg.prep_06.erplab_epoch_rejection.extreme_voltage_uV = 200;
cfg.prep_06.erplab_epoch_rejection.flag_extreme_voltage = 1;

cfg.prep_06.erplab_epoch_rejection.use_sample_diff = true;
cfg.prep_06.erplab_epoch_rejection.sample_diff_uV = 50;
cfg.prep_06.erplab_epoch_rejection.flag_sample_diff = 2;

cfg.prep_06.erplab_epoch_rejection.use_flatline = false;
cfg.prep_06.erplab_epoch_rejection.flatline_tolerance_uV = 0.5;
cfg.prep_06.erplab_epoch_rejection.flatline_duration_ms = 100;
cfg.prep_06.erplab_epoch_rejection.flag_flatline = 3;

cfg.prep_06.erplab_epoch_rejection.review = "off";
cfg.prep_06.erplab_epoch_rejection.history = "off";
cfg.prep_06.erplab_epoch_rejection.lowpass_hz = -1;

% -------------------------------------------------------------------------
% FASTER/PTP epoch rejection
% -------------------------------------------------------------------------
cfg.prep_06.faster_ptp_epoch_rejection = struct();

cfg.prep_06.faster_ptp_epoch_rejection.use_faster = true;
cfg.prep_06.faster_ptp_epoch_rejection.faster_z = 3;
cfg.prep_06.faster_ptp_epoch_rejection.use_robust_z = true;

cfg.prep_06.faster_ptp_epoch_rejection.use_ptp = true;
cfg.prep_06.faster_ptp_epoch_rejection.ptp_uV_thresh = 100;

% -------------------------------------------------------------------------
% MAD-variance epoch rejection
% -------------------------------------------------------------------------
cfg.prep_06.mad_z_threshold = 3;
cfg.prep_06.mad_use_logvar  = true;

% -------------------------------------------------------------------------
% Minimum trials per condition
% -------------------------------------------------------------------------
cfg.prep_06.min_trials_per_condition_enable = true;
cfg.prep_06.min_trials_per_condition_min_n = 3;
cfg.prep_06.min_trials_per_condition_zero_tol_ms = 2;

cfg.prep_06.min_trials_per_condition_codes = { ...
    'acq_cs_minus', {'S 2021', 'S 2022'}; ...
    'acq_cs_plus',  {'S 2421', 'S 2422'}; ...
    'ext_cs_minus', {'S 2041', 'S 2042', 'S 2043'}; ...
    'ext_cs_plus',  {'S 2441', 'S 2442', 'S 2443'} ...
    };

% -------------------------------------------------------------------------
% Summary tables
% -------------------------------------------------------------------------
cfg.prep_06.write_run_summary_table = true;
cfg.prep_06.write_subject_summary_table = true;
cfg.prep_06.qc_table_delimiter = ';';

end
