% =========================================================================
% FILE: eeg_pipeline_config.m
% =========================================================================
function cfg = eeg_pipeline_config()
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
% Saskia Wilken Dec 2025

bootstrap_log = fullfile(tempdir, 'eeg_pipeline_config_bootstrap.log');
helpers = eeg_pipeline_helpers(bootstrap_log);

% =========================================================================
% USER SETTINGS
% Edit the cfg.* fields in this section.
% =========================================================================

cfg = struct();

% -------------------------------------------------------------------------
% Project identity
% -------------------------------------------------------------------------
cfg.pipeline = struct();
cfg.pipeline.name        = "rtgmn_pipeline"; % project name used in cfg
cfg.pipeline.step_prefix = "eeg";            % step 02-06 function prefix - rename if you want to customize your step functions

cfg.constants = struct();
cfg.constants.log_prefix_master = "run_eeg_pipeline"; % master log filename prefix

cfg.bids = struct();
cfg.bids.dataset_folder_name = "BIDS_RTGMN"; % BIDS dataset folder name
cfg.bids.task_label          = "rtgmn";      % BIDS task label
cfg.bids.session_label       = "01";         % BIDS session label

% -------------------------------------------------------------------------
% Profile / paths
% -------------------------------------------------------------------------
cfg.paths = struct();
cfg.paths.profile_override = ""; % leave empty for automatic profile selection

cfg.paths.profile_paths = struct();

cfg.paths.profile_paths.pc_now = struct( ...
    'bids_root', fullfile('K:\Wilken_Arbeitsordner\Raw_data', char(cfg.bids.dataset_folder_name)), ...
    'out_root',  'Z:\pb\KPP_KPN_joined\Aperiodic\Saskia\derivatives');

cfg.paths.profile_paths.pc_shared = struct( ...
    'bids_root', 'Z:\pb\KPP_KPN_joined\Aperiodic\Saskia\sourcedata', ...
    'out_root',  'Z:\pb\KPP_KPN_joined\Aperiodic\Saskia\derivatives');

cfg.paths.profile_paths.server_windows = struct( ...
    'bids_root', 'Z:\pb\KPP_KPN_joined\Aperiodic\Saskia\sourcedata', ...
    'out_root',  'Z:\pb\KPP_KPN_joined\Aperiodic\Saskia\derivatives');

cfg.paths.profile_paths.hpc_hummel = struct( ...
    'bids_root', fullfile('/beegfs/u/bbf7366/raw', char(cfg.bids.dataset_folder_name)), ...
    'out_root',  '/beegfs/u/bbf7366/derivatives/preprocessed_eeg');

cfg.paths.bids_root_override = ""; % optional absolute override for BIDS root
cfg.paths.out_root_override  = ""; % optional absolute override for output root

% -------------------------------------------------------------------------
% Overwrite behavior
% -------------------------------------------------------------------------
cfg.io = struct();
cfg.io.overwrite_mode          = "skip"; % "skip" | "delete" | "if_older_than" - whether old preprocessing step files are kept or discarded
cfg.io.overwrite_if_older_than = "";     % cutoff date for "if_older_than"

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
cfg.constants.valid_sub_id_regex = '^\d{3}$';      % valid subject IDs
cfg.constants.log_prefix_subject = 'sub';          % subject log prefix
cfg.constants.datestr_master     = 'yyyymmdd_HHMMSS';     % master log timestamp format
cfg.constants.datestr_subject    = 'yyyymmdd_HHMMSS_FFF'; % subject log timestamp format

% =========================================================================
% ENVIRONMENT
% =========================================================================
cfg.env = struct();
cfg.env.mode         = helpers.detect_env_mode();      % "pc" | "server" | "hpc"
cfg.env.machine_kind = helpers.detect_machine_kind();  % concrete machine/profile family
cfg.env.hostname     = helpers.get_hostname();         % host name

cfg.env.is_slurm      = ~isempty(getenv('SLURM_JOB_ID')); % true if running under SLURM
cfg.env.slurm_job_id  = string(helpers.get_env_first_nonempty({'SLURM_JOB_ID'}));        % SLURM job id
cfg.env.slurm_cluster = string(helpers.get_env_first_nonempty({'SLURM_CLUSTER_NAME'}));  % SLURM cluster name

% =========================================================================
% PATHS
% =========================================================================
cfg.paths.profile = helpers.default_profile_for_mode(cfg.env.mode, cfg.env.machine_kind); % default profile by environment

profile_env = helpers.get_env_first_nonempty({'EEG_PIPELINE_PROFILE'}); % optional env override
if strlength(profile_env) > 0
    cfg.paths.profile = string(profile_env);
end

if strlength(string(cfg.paths.profile_override)) > 0
    cfg.paths.profile = string(cfg.paths.profile_override);
end

profile_name = char(string(cfg.paths.profile));
if ~isfield(cfg.paths.profile_paths, profile_name)
    error('Unknown cfg.paths.profile="%s". Please define it in cfg.paths.profile_paths.', string(cfg.paths.profile));
end

cfg.paths.bids_root = string(cfg.paths.profile_paths.(profile_name).bids_root); % resolved BIDS root
cfg.paths.out_root  = string(cfg.paths.profile_paths.(profile_name).out_root);  % resolved output root

bids_env = helpers.get_env_first_nonempty({'EEG_PIPELINE_BIDS_ROOT'}); % optional env override
out_env  = helpers.get_env_first_nonempty({'EEG_PIPELINE_OUT_ROOT'});  % optional env override

if strlength(bids_env) > 0
    cfg.paths.bids_root = string(bids_env);
end

if strlength(out_env) > 0
    cfg.paths.out_root = string(out_env);
end

if strlength(string(cfg.paths.bids_root_override)) > 0
    cfg.paths.bids_root = string(cfg.paths.bids_root_override);
end

if strlength(string(cfg.paths.out_root_override)) > 0
    cfg.paths.out_root = string(cfg.paths.out_root_override);
end

cfg.paths.logs_dir = fullfile(cfg.root_dir, 'logs', 'runlog_pipeline'); % folder for pipeline logs
cfg.paths.branch_by_ica_method = true; % create separate 04/05/06 folders per ICA method

% =========================================================================
% TOOLBOX PATHS
% =========================================================================
cfg.toolboxes = struct();

cfg.toolboxes.path_eeglab_pc     = "K:\Wilken_Arbeitsordner\MATLAB\eeglab_current\eeglab2025.1.0"; % EEGLAB path on PC
cfg.toolboxes.path_eeglab_server = "K:\Wilken_Arbeitsordner\MATLAB\eeglab_current\eeglab2025.1.0"; % EEGLAB path on server
cfg.toolboxes.path_eeglab_hpc    = "/beegfs/u/bbf7366/toolboxes/eeglab2025.1.0";                    % EEGLAB path on HPC

cfg.toolboxes.path_faster_pc     = "K:\Wilken_Arbeitsordner\MATLAB\FASTER"; % FASTER path on PC
cfg.toolboxes.path_faster_server = "K:\Wilken_Arbeitsordner\MATLAB\FASTER"; % FASTER path on server
cfg.toolboxes.path_faster_hpc    = "/beegfs/u/bbf7366/toolboxes/FASTER";    % FASTER path on HPC

cfg.toolboxes.use_genpath = true; % add toolbox subfolders recursively

cfg.toolboxes.eeglab = struct();
cfg.toolboxes.eeglab.no_update_check_on_hpc = true; % suppress EEGLAB update checks on HPC
cfg.toolboxes.eeglab.nogui = true;                  % start EEGLAB without GUI

% =========================================================================
% SUBJECTS
% =========================================================================
cfg.subjects = struct();
cfg.subjects.list   = []; % explicit subject list or [], e.g. {'211','212'}
cfg.subjects.min_id = []; % [] = no lower cutoff | numeric/string ID

% =========================================================================
% PARALLEL
% =========================================================================
cfg.parallel = struct();
cfg.parallel.enable         = true;    % allow parallel execution
cfg.parallel.force_workers  = [];      % explicit worker count or []
cfg.parallel.pool_is_thread = false;   % runner-internal flag
cfg.parallel.pool_type      = "none";  % runner-internal flag

% =========================================================================
% STEP TOGGLES
% =========================================================================
cfg.steps = struct();

cfg.steps.prep_01_bids_formatting = struct( ...
    'run', true, ...                 % run step 01
    'overwrite_mode', "", ...        % optional step-specific overwrite mode
    'overwrite_if_older_than', "");  % optional step-specific cutoff date

cfg.steps.prep_02_triggerfix = struct( ...
    'run', false, ...                % run step 02
    'overwrite_mode', "", ...
    'overwrite_if_older_than', "");

cfg.steps.prep_03_until_ica = struct( ...
    'run', true, ...                 % run step 03
    'overwrite_mode', "if_older_than", ...
    'overwrite_if_older_than', "2026-03-15");

cfg.steps.prep_04_ica = struct( ...
    'run', true, ...                 % run step 04
    'overwrite_mode', "delete", ...
    'overwrite_if_older_than', "");

cfg.steps.prep_05_after_ica = struct( ...
    'run', true, ...                 % run step 05
    'overwrite_mode', "delete", ...
    'overwrite_if_older_than', "");

cfg.steps.prep_06_epoching = struct( ...
    'run', true, ...                 % run step 06
    'overwrite_mode', "delete", ...
    'overwrite_if_older_than', "");

% =========================================================================
% STEP FUNCTION HANDLES
% =========================================================================
cfg.step_fns = struct();
cfg.step_fns.prep_01_bids_formatting = str2func('eeg_prep01_bids_formatting');                      % step 01 function
cfg.step_fns.prep_02_triggerfix      = str2func(char(cfg.pipeline.step_prefix + "_prep02_triggerfix")); % step 02 function
cfg.step_fns.prep_03_until_ica       = str2func(char(cfg.pipeline.step_prefix + "_prep03_untilica"));   % step 03 function
cfg.step_fns.prep_04_ica             = str2func(char(cfg.pipeline.step_prefix + "_prep04_ica"));        % step 04 function
cfg.step_fns.prep_05_after_ica       = str2func(char(cfg.pipeline.step_prefix + "_prep05_after_ica"));  % step 05 function
cfg.step_fns.prep_06_epoching        = str2func(char(cfg.pipeline.step_prefix + "_prep06_epoching"));   % step 06 function

% =========================================================================
% STEP 01: BIDS FORMATTING
% =========================================================================
cfg.prep_01 = struct();

cfg.prep_01.session_label = cfg.bids.session_label; % BIDS session label
cfg.prep_01.task_label    = cfg.bids.task_label;    % BIDS task label

cfg.prep_01.do_eeg = true;  % copy/rename raw BrainVision EEG into BIDS
cfg.prep_01.do_beh = false; % copy project-specific CF behavior files (RTGMN-specific; usually leave off)

cfg.prep_01.try_eeglab_bids_export           = true; % additionally try pop_exportbids after copying
cfg.prep_01.write_readme_if_exporter_did_not = true; % write README if exporter did not create dataset-level description

cfg.prep_01.copy_eeg_sidecar_log_to_events = false; % copy project-specific CF log as *_events.log (RTGMN-specific)

cfg.prep_01.raw_eeg_dir = 'K:\Wilken_Arbeitsordner\Raw_data\RTG_Metin_Nilay_EEG_Baseline'; % raw EEG source folder
cfg.prep_01.raw_beh_dir = ''; % project-specific CF behavior/log folder; only relevant if do_beh=true or copy_eeg_sidecar_log_to_events=true

cfg.prep_01.raw_eeg_regex = '^B_(\d{3})(?:_(\d{3}))?\.vhdr$'; % raw EEG filename pattern: subject + optional run

cfg.prep_01.existing_bids_vhdr_regex = ...
    '^sub-(\d+)_ses-(\d+)_task-([A-Za-z0-9]+)(?:_run-(\d+))?_eeg\.vhdr$'; % existing BIDS EEG header pattern used when do_eeg=false

% =========================================================================
% STEP 02: TRIGGERFIX
% =========================================================================
cfg.prep_02 = struct();

cfg.prep_02.run_raw_order_qc = true; % compare behavior-log event order to raw EEG triggers

cfg.prep_02.allow_multiple_runs  = false;         % allow multiple matching BIDS EEG runs
cfg.prep_02.multiple_vhdr_policy = "most_recent"; % "most_recent" | "first" | "error"

cfg.prep_02.qc_out_dir = ""; % optional QC output folder override

cfg.prep_02.task_label         = cfg.bids.task_label;    % BIDS task label
cfg.prep_02.session_label      = cfg.bids.session_label; % BIDS session label
cfg.prep_02.input_vhdr_pattern = "";                     % optional explicit vhdr pattern

cfg.prep_02.use_explicit_chanlist = false; % load only explicit channels
cfg.prep_02.explicit_chanlist     = 1:66;  % explicit channel indices if enabled

cfg.prep_02.raw_qc_keep_tokens     = ["S 20","S 21","S 22","S 23","S 24","S 15","S 5"]; % raw tokens used for order QC
cfg.prep_02.raw_qc_bin_size_s      = 1;     % time bin size for QC CSV
cfg.prep_02.raw_qc_max_rows        = 20000; % maximum rows in QC CSV
cfg.prep_02.raw_qc_write_csv_on_ok = false; % also write QC CSV when no mismatch was found

cfg.prep_02.behavior_log_column_event_type = 'EventType'; % behavior-log event-type column
cfg.prep_02.behavior_log_column_code       = 'Code';      % behavior-log code column
cfg.prep_02.behavior_log_column_time       = 'Time';      % behavior-log time column
cfg.prep_02.behavior_log_time_unit         = "ms";        % "ms" | "s"

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
    }; % behavior-log to raw-trigger mapping

cfg.prep_02.phase_start_markers = struct();
cfg.prep_02.phase_start_markers.habituation    = "S 91"; % habituation start marker
cfg.prep_02.phase_start_markers.acquisition    = "S 92"; % acquisition start marker
cfg.prep_02.phase_start_markers.generalization = "S 93"; % generalization start marker
cfg.prep_02.phase_start_markers.extinction     = "S 94"; % extinction start marker
cfg.prep_02.phase_start_markers.return_of_fear = "S 95"; % return-of-fear start marker

cfg.prep_02.raw_triggers = struct();
cfg.prep_02.raw_triggers.cs_minus = "S 20"; % raw CS- trigger
cfg.prep_02.raw_triggers.gs_1     = "S 21"; % raw GS1 trigger
cfg.prep_02.raw_triggers.gs_u     = "S 22"; % raw GSU trigger
cfg.prep_02.raw_triggers.gs_2     = "S 23"; % raw GS2 trigger
cfg.prep_02.raw_triggers.cs_plus  = "S 24"; % raw CS+ trigger
cfg.prep_02.raw_triggers.startle  = "S 15"; % raw startle trigger
cfg.prep_02.raw_triggers.shock    = "S 5";  % raw shock trigger

cfg.prep_02.habituation_map = { ...
    'cs_minus', "S 201"; ...
    'gs_1',     "S 211"; ...
    'gs_u',     "S 221"; ...
    'gs_2',     "S 231"; ...
    'cs_plus',  "S 241"  ...
    }; % habituation renaming map

cfg.prep_02.generalization_map = { ...
    'cs_minus', "S 203"; ...
    'gs_1',     "S 213"; ...
    'gs_u',     "S 223"; ...
    'gs_2',     "S 233"; ...
    'cs_plus',  "S 243"  ...
    }; % generalization renaming map

cfg.prep_02.return_of_fear_map = { ...
    'cs_minus', "S 205"; ...
    'gs_1',     "S 215"; ...
    'gs_u',     "S 225"; ...
    'gs_2',     "S 235"; ...
    'cs_plus',  "S 245"  ...
    }; % return-of-fear renaming map

cfg.prep_02.acquisition = struct();
cfg.prep_02.acquisition.cs_minus_key      = 'cs_minus'; % raw key treated as CS- in acquisition
cfg.prep_02.acquisition.cs_plus_key       = 'cs_plus';  % raw key treated as CS+ in acquisition
cfg.prep_02.acquisition.n_first_block     = 10;         % number of trials in acquisition block 1
cfg.prep_02.acquisition.code_minus_block1 = "S 2021";   % acquisition block 1 CS- code
cfg.prep_02.acquisition.code_plus_block1  = "S 2421";   % acquisition block 1 CS+ code
cfg.prep_02.acquisition.code_minus_block2 = "S 2022";   % acquisition block 2 CS- code
cfg.prep_02.acquisition.code_plus_block2  = "S 2422";   % acquisition block 2 CS+ code

cfg.prep_02.extinction = struct();
cfg.prep_02.extinction.cs_minus_key      = 'cs_minus'; % raw key treated as CS- in extinction
cfg.prep_02.extinction.cs_plus_key       = 'cs_plus';  % raw key treated as CS+ in extinction
cfg.prep_02.extinction.n_first_block     = 11;         % number of trials in extinction block 1
cfg.prep_02.extinction.n_second_block    = 10;         % number of trials in extinction block 2
cfg.prep_02.extinction.code_minus_block1 = "S 2041";   % extinction block 1 CS- code
cfg.prep_02.extinction.code_plus_block1  = "S 2441";   % extinction block 1 CS+ code
cfg.prep_02.extinction.code_minus_block2 = "S 2042";   % extinction block 2 CS- code
cfg.prep_02.extinction.code_plus_block2  = "S 2442";   % extinction block 2 CS+ code
cfg.prep_02.extinction.code_minus_block3 = "S 2043";   % extinction block 3 CS- code
cfg.prep_02.extinction.code_plus_block3  = "S 2443";   % extinction block 3 CS+ code

cfg.prep_02.disable_first_ext_trials = true; % special handling for first extinction trials
cfg.prep_02.disable_first_acq_trials = true; % special handling for first acquisition trials

cfg.prep_02.disable_first_extinction = struct();
cfg.prep_02.disable_first_extinction.first_minus_code = "S 2041";   % first extinction CS- code
cfg.prep_02.disable_first_extinction.first_plus_code  = "S 2441";   % first extinction CS+ code
cfg.prep_02.disable_first_extinction.revert_minus_key = 'cs_minus'; % revert first extinction CS- to raw code
cfg.prep_02.disable_first_extinction.revert_plus_key  = 'cs_plus';  % revert first extinction CS+ to raw code

cfg.prep_02.disable_first_acquisition = struct();
cfg.prep_02.disable_first_acquisition.first_minus_code    = "S 2021"; % first acquisition CS- code
cfg.prep_02.disable_first_acquisition.first_plus_code     = "S 2421"; % first acquisition CS+ code
cfg.prep_02.disable_first_acquisition.disabled_minus_code = "S 20999"; % replacement code for first acquisition CS-
cfg.prep_02.disable_first_acquisition.disabled_plus_code  = "S 24999"; % replacement code for first acquisition CS+

% =========================================================================
% STEP 03: UNTIL ICA
% =========================================================================
cfg.prep_03 = struct();

cfg.prep_03.crop_to_task_markers = false; % crop continuous data to task marker interval
cfg.prep_03.crop_start_marker    = 'S 91'; % crop start marker
cfg.prep_03.crop_end_marker      = 'S 97'; % crop end marker
cfg.prep_03.crop_padding_sec     = [0 0];  % padding around crop interval in seconds

cfg.prep_03.eog_channel_labels     = {'IO1','IO2','LO1','LO2'}; % labels treated as EOG
cfg.prep_03.scr_channel_labels     = {'SCR'};                   % labels treated as SCR
cfg.prep_03.startle_channel_labels = {'Startle'};               % labels treated as Startle
cfg.prep_03.ekg_channel_labels     = {'EKG'};                   % labels treated as EKG

cfg.prep_03.downsample_hz = 250; % target sampling rate

cfg.prep_03.highpass_hz          = 0.1; % continuous high-pass filter
cfg.prep_03.lowpass_hz           = 100; % continuous low-pass filter
cfg.prep_03.ica_prep_highpass_hz = 1;   % high-pass used for ICA-prep data

cfg.prep_03.detect_bad_channels_mode = "auto"; % bad-channel detection mode
cfg.prep_03.auto_badchan_z_threshold  = 2.5;   % z-threshold for automatic bad-channel detection
cfg.prep_03.auto_badchan_freqrange_hz = [1, cfg.prep_03.lowpass_hz + 10]; % frequency range for bad-channel detection

cfg.prep_03.emu_flatline_sec           = 5;    % flatline criterion in seconds for emulation-style bad-channel detection
cfg.prep_03.emu_channel_corr_threshold = 0.80; % channel correlation threshold for emulation-style bad-channel detection

cfg.prep_03.flag_flat_channels_as_bad     = true; % flag zero-variance / invalid channels as bad
cfg.prep_03.flat_channel_variance_epsilon = 0;    % variance cutoff for flat-channel detection

cfg.prep_03.interpolate_bad_channels_before_ica = true;     % interpolate bad channels before ICA
cfg.prep_03.interp_method                    = 'spherical'; % interpolation method

cfg.prep_03.line_noise_method         = "pop_cleanline"; % line-noise removal method
cfg.prep_03.line_noise_frequencies_hz = [50 100];        % line-noise frequencies

cfg.prep_03.pop_cleanline_bandwidth_hz      = 4;     % Cleanline bandwidth
cfg.prep_03.pop_cleanline_p_value           = 0.01;  % Cleanline significance threshold
cfg.prep_03.pop_cleanline_scanforlines      = true;  % let Cleanline scan for line frequencies
cfg.prep_03.pop_cleanline_winsize_sec       = 2;     % Cleanline window size
cfg.prep_03.pop_cleanline_winstep_sec       = 1;     % Cleanline window step
cfg.prep_03.pop_cleanline_tau               = 50;    % Cleanline tau parameter
cfg.prep_03.pop_cleanline_pad               = 4;     % Cleanline FFT padding
cfg.prep_03.pop_cleanline_taperbandwidth_hz = 4;     % Cleanline taper bandwidth
cfg.prep_03.pop_cleanline_norm_spectrum     = 0;     % Cleanline normalize spectrum flag
cfg.prep_03.pop_cleanline_computepower      = 0;     % Cleanline compute power flag
cfg.prep_03.pop_cleanline_verbose           = false; % Cleanline verbosity

cfg.prep_03.ica_prep_use_regepochs           = true; % create regular short epochs for ICA prep
cfg.prep_03.ica_prep_regepoch_length_sec     = 1;    % ICA-prep epoch length
cfg.prep_03.ica_prep_use_mad_epoch_rejection = true; % reject ICA-prep epochs by MAD variance
cfg.prep_03.ica_prep_mad_z_threshold         = 3;    % MAD variance z-threshold
cfg.prep_03.ica_prep_mad_use_logvar          = true; % use log-variance for MAD rejection
cfg.prep_03.ica_prep_use_jointprob_rejection = true; % apply pop_jointprob during ICA prep
cfg.prep_03.ica_prep_jointprob_local         = 2;    % pop_jointprob local threshold
cfg.prep_03.ica_prep_jointprob_global        = 2;    % pop_jointprob global threshold

cfg.prep_03.apply_average_reference = true; % apply average reference before ICA output save

cfg.prep_03.shared_epoch_rejection = struct();
cfg.prep_03.shared_epoch_rejection.enable        = true;  % use shared epoch rejection helper
cfg.prep_03.shared_epoch_rejection.use_faster    = true;  % use epoch_properties/FASTER features
cfg.prep_03.shared_epoch_rejection.faster_z      = 4;     % FASTER z-threshold
cfg.prep_03.shared_epoch_rejection.use_robust_z  = true;  % use MAD-based z instead of mean/sd
cfg.prep_03.shared_epoch_rejection.use_ptp       = true;  % include peak-to-peak rejection
cfg.prep_03.shared_epoch_rejection.ptp_uV_thresh = 800;   % peak-to-peak threshold in µV

% =========================================================================
% STEP 04: ICA
% =========================================================================
cfg.prep_04 = struct();

cfg.prep_04.ica_method                   = "amica"; % "amica" | "runica"
cfg.prep_04.use_extended_infomax         = true;    % extended infomax for runica
cfg.prep_04.interrupt_ica                = 'off';   % ICA interruption behavior
cfg.prep_04.use_pca_rank_if_interpolated = true;    % reduce ICA rank if channels were interpolated
cfg.prep_04.amica_require_no_spaces_on_windows = true; % guard against AMICA path issues on Windows

% =========================================================================
% STEP 05: AFTER ICA / ICLABEL
% =========================================================================
cfg.prep_05 = struct();

cfg.prep_05.clear_subject_ica_comps_dir = true; % clear subject QA component PNG folder before writing new files

cfg.prep_05.iclabel_eye_remove_thr       = 0.80; % remove IC if eye probability exceeds threshold
cfg.prep_05.iclabel_muscle_remove_thr    = 0.80; % remove IC if muscle probability exceeds threshold
cfg.prep_05.iclabel_heart_remove_thr     = 0.80; % remove IC if heart probability exceeds threshold
cfg.prep_05.iclabel_linenoise_remove_thr = 0.80; % remove IC if line-noise probability exceeds threshold
cfg.prep_05.iclabel_channoise_remove_thr = 0.80; % remove IC if channel-noise probability exceeds threshold
cfg.prep_05.iclabel_other_remove_thr     = 0.95; % remove IC if "other" probability exceeds threshold
cfg.prep_05.iclabel_brain_min_keep_thr   = 0.05; % remove IC if brain probability is below threshold

cfg.prep_05.save_ic_topos_png   = true; % save IC topography QA PNGs
cfg.prep_05.iclabel_edge_margin = 0.10; % margin below threshold used to flag edge ICs

cfg.prep_05.ic_topo_dpi        = 300;         % IC QA PNG resolution
cfg.prep_05.ic_topo_fig_cm     = [0 0 18 18]; % IC QA PNG figure size
cfg.prep_05.ic_topo_electrodes = 'off';       % topoplot electrode display mode

cfg.prep_05.write_component_table       = true; % write per-component QC table
cfg.prep_05.write_run_summary_table     = true; % write per-run QC summary table
cfg.prep_05.write_subject_summary_table = true; % write per-subject QC summary table
cfg.prep_05.qc_table_delimiter          = ';';  % delimiter for text-based QC tables

% =========================================================================
% STEP 06: EPOCHING + FINAL ARTIFACT REJECTION
% =========================================================================
cfg.prep_06 = struct();

cfg.prep_06.save_final_only         = true;       % save only final datasets
cfg.prep_06.save_intermediate_steps = false;      % also save intermediate step datasets
cfg.prep_06.savemode                = 'twofiles'; % EEGLAB savemode for optional intermediate saves

cfg.prep_06.reference_mode         = "avg";        % "avg" | "mastoid"
cfg.prep_06.mastoid_channel_labels = {'T9','T10'}; % labels used for mastoid reference

cfg.prep_06.epoch_start_s = -0.4; % epoch start in seconds
cfg.prep_06.epoch_end_s   =  2.6; % epoch end in seconds

cfg.prep_06.do_artifact_rejection               = true; % run epoch rejection
cfg.prep_06.do_initial_hard_threshold_rejection = true; % run hard threshold rejection first
cfg.prep_06.initial_hard_threshold_uv           = 100;  % absolute hard threshold in µV

cfg.prep_06.faster_z_thresh               = 3;    % fallback local FASTER z-threshold
cfg.prep_06.faster_use_robust_z           = true; % use MAD-based z for fallback local rejection
cfg.prep_06.faster_warn_if_reject_prop_gt = 0.25; % warn if fallback local rejection exceeds this proportion
cfg.prep_06.max_reject_prop               = 0.25; % exclude subject if total rejected epoch proportion exceeds this value

cfg.prep_06.do_baseline_correction = false; % apply baseline correction after rejection
cfg.prep_06.base_start_ms          = -200;  % baseline window start in ms
cfg.prep_06.base_end_ms            = 0;     % baseline window end in ms

cfg.prep_06.shared_epoch_rejection = struct();
cfg.prep_06.shared_epoch_rejection.enable        = true;  % use shared epoch rejection helper
cfg.prep_06.shared_epoch_rejection.use_faster    = true;  % use epoch_properties/FASTER features
cfg.prep_06.shared_epoch_rejection.faster_z      = 2;     % shared rejection z-threshold
cfg.prep_06.shared_epoch_rejection.use_robust_z  = false; % use MAD-based z in shared rejection
cfg.prep_06.shared_epoch_rejection.use_ptp       = true;  % include peak-to-peak rejection
cfg.prep_06.shared_epoch_rejection.ptp_uV_thresh = 300;   % shared rejection peak-to-peak threshold in µV

cfg.prep_06.events_phase = { ...
    'S 201','S 241', ...
    'S 2021','S 2421','S 2022','S 2422', ...
    'S 203','S 213','S 223','S 233','S 243', ...
    'S 2041','S 2441','S 2042','S 2442','S 2043','S 2443', ...
    'S 205','S 245' ...
    }; % event codes used for epoching

cfg.prep_06.write_run_summary_table     = true;
cfg.prep_06.write_subject_summary_table = true;
cfg.prep_06.qc_table_delimiter          = ';';

end