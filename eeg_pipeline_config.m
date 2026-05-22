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

% -------------------------------------------------------------------------
% Project identity
% -------------------------------------------------------------------------
cfg.pipeline = struct();
cfg.pipeline.name        = "aperiodic_pipeline"; % set recognizable name: project name used in cfg and logsheader
cfg.pipeline.step_prefix = "eeg";                % step 02-06 function prefix, needed to find step-functions. Keep as "eeg" unless you have a good reason to change it.

cfg.constants = struct();
cfg.constants.log_prefix_master = "run_eeg_pipeline_aperiodic"; % master log filename prefix

cfg.bids = struct();
cfg.bids.dataset_folder_name = "baseline";   % BIDS dataset folder name (if you have multiple datasets in the same raw folder)
cfg.bids.task_label          = "baseline";   % BIDS task label of EEG dataset
cfg.bids.session_label       = "01";         % BIDS session label

cfg.paths.branch_by_ica_method = true; % create separate 04/05/06 folders per ICA method
% -------------------------------------------------------------------------
% Profile / paths
% Configure ALL machine-specific path profiles here.
%
% To add a new profile later:
%   1) duplicate one block below
%   2) give it a new name
%   3) optionally set cfg.paths.profile_override to that name
% -------------------------------------------------------------------------
cfg.paths = struct();

%# HOWTO: how would we hav to set the overwrite? are there pre-set options?
cfg.paths.profile_override = ""; % leave empty for automatic profile selection

cfg.paths.profile_paths = struct();

cfg.paths.profile_paths.pc = struct( ...
    'source_eeg_root',  'Z:\pb\KLPSY1\KLPSY1-RTG\PROOF - Data\Real\EEG\Baseline', ...
    'source_beh_root',  '', ...
    'bids_root',        'Z:\pb\KPP_KPN_joined\Aperiodic\Saskia\sourcedata', ...
    'derivatives_root', 'Z:\pb\KPP_KPN_joined\Aperiodic\Saskia\derivatives');

cfg.paths.profile_paths.server_windows = struct( ...
    'source_eeg_root',  'Z:\pb\KLPSY1\KLPSY1-RTG\PROOF - Data\Real\EEG\Baseline', ...
    'source_beh_root',  '', ...
    'bids_root',         'Z:\pb\KPP_KPN_joined\Aperiodic\Saskia\sourcedata', ...
    'derivatives_root', 'Z:\pb\KPP_KPN_joined\Aperiodic\Saskia\derivatives');

cfg.paths.profile_paths.hpc_hummel = struct( ...
    'source_eeg_root',  '', ...
    'source_beh_root',  '', ...
    'bids_root',        fullfile('/beegfs/u/bbf7366/sourcedata', char(cfg.bids.dataset_folder_name)), ...
    'derivatives_root', '/beegfs/u/bbf7366/derivatives/preprocessed_eeg_baseline');

cfg.paths.bids_root_override        = "";
cfg.paths.derivatives_root_override = "";
cfg.paths.source_eeg_root_override  = "";
cfg.paths.source_beh_root_override  = "";

% =========================================================================
% TOOLBOX PATHS
% =========================================================================
cfg.toolboxes = struct();

cfg.toolboxes.path_eeglab_pc     = "K:\Wilken_Arbeitsordner\MATLAB\eeglab_current\eeglab2025.1.0"; % EEGLAB path on PC
cfg.toolboxes.path_eeglab_server = "K:\Wilken_Arbeitsordner\MATLAB\eeglab_current\eeglab2025.1.0"; % EEGLAB path on server
cfg.toolboxes.path_eeglab_hpc    = "/beegfs/u/bbf7366/toolboxes/eeglab2025.1.0";                   % EEGLAB path on HPC

cfg.toolboxes.path_faster_pc     = "K:\Wilken_Arbeitsordner\MATLAB\FASTER"; % FASTER path on PC
cfg.toolboxes.path_faster_server = "K:\Wilken_Arbeitsordner\MATLAB\FASTER"; % FASTER path on server
cfg.toolboxes.path_faster_hpc    = "/beegfs/u/bbf7366/toolboxes/FASTER";    % FASTER path on HPC

cfg.toolboxes.path_erplab_pc     = "K:\Wilken_Arbeitsordner\MATLAB\erplab13.00";
cfg.toolboxes.path_erplab_server = "K:\Wilken_Arbeitsordner\MATLAB\erplab13.00";
cfg.toolboxes.path_erplab_hpc    = "/beegfs/u/bbf7366/toolboxes/eeglab2025.1.0/plugins/erplab";

cfg.toolboxes.erplab = struct();
cfg.toolboxes.erplab.use_genpath = true;

cfg.toolboxes.use_genpath = false; % add toolbox subfolders recursively

cfg.toolboxes.eeglab = struct();
cfg.toolboxes.eeglab.no_update_check_on_hpc = true; % suppress EEGLAB update checks on HPC
cfg.toolboxes.eeglab.nogui = true;                  % start EEGLAB without GUI

% -------------------------------------------------------------------------
% Overwrite behavior
% -------------------------------------------------------------------------
cfg.io = struct();
cfg.io.overwrite_mode          = "delete"; % "skip" | "delete" | "if_older_than"
cfg.io.overwrite_if_older_than = "";       % # HOWTO: cutoff date for "if_older_than" in which format?

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
cfg.constants.valid_sub_id_regex = '^\d{3}$';          % valid subject IDs, default: three digits like "001"
cfg.constants.log_prefix_subject = 'sub';              % subject log prefix
cfg.constants.datestr_master     = 'yyyymmdd_HHMMSS';  % master log timestamp format
cfg.constants.datestr_subject    = 'yyyymmdd_HHMMSS_FFF'; % subject log timestamp format

% =========================================================================
% ENVIRONMENT  -- do not edit, will be automatically detected at runtime
% =========================================================================
cfg.env = struct();
cfg.env.mode         = helpers.detect_env_mode();      % "pc" | "server" | "hpc"
cfg.env.machine_kind = helpers.detect_machine_kind();  % concrete machine/profile family
cfg.env.hostname     = helpers.get_hostname();         % host name

cfg.env.is_slurm      = ~isempty(getenv('SLURM_JOB_ID')); % true if running under SLURM
cfg.env.slurm_job_id  = string(helpers.get_env_first_nonempty({'SLURM_JOB_ID'}));       % SLURM job id
cfg.env.slurm_cluster = string(helpers.get_env_first_nonempty({'SLURM_CLUSTER_NAME'})); % SLURM cluster name

% =========================================================================
% RESOLVED PATHS -- do not edit, will be resolved at runtime based on profile and environment
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

profile_cfg = cfg.paths.profile_paths.(profile_name);

% -------------------------------------------------------------------------
% Base paths from selected profile
% -------------------------------------------------------------------------
cfg.paths.source_eeg_root  = string(profile_cfg.source_eeg_root);
cfg.paths.source_beh_root  = string(profile_cfg.source_beh_root);
cfg.paths.bids_root        = string(profile_cfg.bids_root);
cfg.paths.derivatives_root = string(profile_cfg.derivatives_root);
cfg.paths.logs_dir = fullfile(fileparts(cfg.paths.derivatives_root), 'logs', 'runlog_pipeline'); % log folder in data-directory

% -------------------------------------------------------------------------
% Optional environment overrides
% Intended for batch/HPC/test runs without editing this config file
% -------------------------------------------------------------------------
bids_env = helpers.get_env_first_nonempty({'EEG_PIPELINE_BIDS_ROOT'});
derivatives_env = helpers.get_env_first_nonempty({'EEG_PIPELINE_DERIVATIVES_ROOT'});
source_eeg_env = helpers.get_env_first_nonempty({'EEG_PIPELINE_SOURCE_EEG_ROOT'});
source_beh_env = helpers.get_env_first_nonempty({'EEG_PIPELINE_SOURCE_BEH_ROOT'});

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

% -------------------------------------------------------------------------
% Explicit config overrides
% Highest priority because they are set directly in this file (in Profile paths section above) and intended for manual runs. Environment variables are more intended for batch/HPC/test runs without editing this config file.
% -------------------------------------------------------------------------
if strlength(string(cfg.paths.bids_root_override)) > 0
    cfg.paths.bids_root = string(cfg.paths.bids_root_override);
end

if strlength(string(cfg.paths.derivatives_root_override)) > 0
    cfg.paths.derivatives_root = string(cfg.paths.derivatives_root_override);
end

if strlength(string(cfg.paths.source_eeg_root_override)) > 0
    cfg.paths.source_eeg_root = string(cfg.paths.source_eeg_root_override);
end

if strlength(string(cfg.paths.source_beh_root_override)) > 0
    cfg.paths.source_beh_root = string(cfg.paths.source_beh_root_override);
end

% =========================================================================
% SUBJECTS
% =========================================================================
cfg.subjects = struct();
cfg.subjects.list   = []; % explicit subject list, e.g. {'211','212'}, leave empty to autodetect from source_eeg_root using cfg.constants.valid_sub_id_regex
cfg.subjects.min_id = []; % numeric/string ID, no lower cutoff if left empty 

% =========================================================================
% PARALLEL
% =========================================================================
cfg.parallel = struct();
cfg.parallel.enable         = true;   % allow parallel execution
cfg.parallel.force_workers  = [];     % explicit worker count, leave empty for automatic determination
cfg.parallel.pool_is_thread = false;  % runner-internal flag
cfg.parallel.pool_type      = "none"; % runner-internal flag
%# HOWTO: what are runner internal flags?
% =========================================================================
% STEP TOGGLES
% =========================================================================
cfg.steps = struct();

cfg.steps.enable_downstream_rerun = true; % if true, sets all downstream steps to run when a step is set to run. E.g. if Step 03 is set to run, but output for steps 04-06 already exists from a previous run, Steps 04-06 will automatically also be set to run

cfg.steps.prep_01_bids_formatting = struct( ...
    'run', true, ...                % Step 01 creates/updates cfg.paths.bids_root from source_*_root
    'overwrite_mode', "delete", ...
    'overwrite_if_older_than', "");

cfg.steps.prep_02_triggerfix = struct( ...
    'run', true, ...
    'overwrite_mode', "delete", ...
    'overwrite_if_older_than', "");

cfg.steps.prep_03_until_ica = struct( ...
    'run', true, ...
    'overwrite_mode', "delete", ...
    'overwrite_if_older_than', "");

cfg.steps.prep_04_ica = struct( ...
    'run', true, ...
    'overwrite_mode', "delete", ...
    'overwrite_if_older_than', "");

cfg.steps.prep_05_after_ica = struct( ...
    'run', true, ...
    'overwrite_mode', "delete", ...
    'overwrite_if_older_than', "");

cfg.steps.prep_06_epoching = struct( ...
    'run', true, ...
    'overwrite_mode', "delete", ...
    'overwrite_if_older_than', "");

% =========================================================================
% STEP FUNCTION HANDLES -- do not edit, will be resolved at runtime
% =========================================================================
cfg.step_fns = struct();
cfg.step_fns.prep_01_bids_formatting = str2func('eeg_prep01_bids_formatting');
cfg.step_fns.prep_02_triggerfix      = str2func(char(cfg.pipeline.step_prefix + "_prep02_triggerfix"));
cfg.step_fns.prep_03_until_ica       = str2func(char(cfg.pipeline.step_prefix + "_prep03_untilica"));
cfg.step_fns.prep_04_ica             = str2func(char(cfg.pipeline.step_prefix + "_prep04_ica"));
cfg.step_fns.prep_05_after_ica       = str2func(char(cfg.pipeline.step_prefix + "_prep05_after_ica"));
cfg.step_fns.prep_06_epoching        = str2func(char(cfg.pipeline.step_prefix + "_prep06_epoching"));

% =========================================================================
% STEP 01: BIDS FORMATTING
% Step behavior only. Input/output locations come from cfg.paths.
% =========================================================================
cfg.prep_01 = struct();

cfg.prep_01.do_eeg = true;  % copy/rename raw BrainVision EEG into BIDS
cfg.prep_01.do_beh = false; % copy project-specific CF behavior files # HOWTO: what are CF files? specific format needed?

cfg.prep_01.try_eeglab_bids_export           = true; % additionally try pop_exportbids after copying
cfg.prep_01.write_readme_if_exporter_did_not = true; % write README if exporter did not create dataset-level description

cfg.prep_01.copy_eeg_sidecar_log_to_events = false; % copy project-specific CF log as *_events.log

cfg.prep_01.raw_eeg_regex = '^B_(\d{3})(?:_(\d{3}))?\.vhdr$'; % raw EEG filename pattern: starts with B, then 3-digit subject + optional 3-digit run

cfg.prep_01.existing_bids_vhdr_regex = ...
    '^sub-(\d+)_ses-(\d+)_task-([A-Za-z0-9]+)(?:_run-(\d+))?_eeg\.vhdr$'; % existing BIDS EEG header pattern used when do_eeg=false
   
cfg.prep_01.session_label = cfg.bids.session_label; % get session label defined in project identity
cfg.prep_01.task_label    = cfg.bids.task_label;    % get task label defined in project identity
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
cfg.prep_02.input_vhdr_pattern = "";                     % optional explicit vhdr pattern # HOWTO: as regex pattern?

cfg.prep_02.use_explicit_chanlist = false; % load only explicit channels
cfg.prep_02.explicit_chanlist     = 1:66;  % explicit channel indices if enabled

% quality control settings 
cfg.prep_02.raw_qc_keep_tokens     = ["S 20","S 21","S 22","S 23","S 24","S 15","S 5"];
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
    'cs_plus',  "S 241"  ...
    };

cfg.prep_02.generalization_map = { ...
    'cs_minus', "S 203"; ...
    'gs_1',     "S 213"; ...
    'gs_u',     "S 223"; ...
    'gs_2',     "S 233"; ...
    'cs_plus',  "S 243"  ...
    };

cfg.prep_02.return_of_fear_map = { ...
    'cs_minus', "S 205"; ...
    'gs_1',     "S 215"; ...
    'gs_u',     "S 225"; ...
    'gs_2',     "S 235"; ...
    'cs_plus',  "S 245"  ...
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
cfg.prep_02.disable_first_acquisition.first_minus_code    = "S 2021";
cfg.prep_02.disable_first_acquisition.first_plus_code     = "S 2421";
cfg.prep_02.disable_first_acquisition.disabled_minus_code = "S 20999";
cfg.prep_02.disable_first_acquisition.disabled_plus_code  = "S 24999";

% =========================================================================
% STEP 03: UNTIL ICA
% =========================================================================
cfg.prep_03 = struct();

% crop dataset around specifically defined triggers, e.g. exp start and exp
% end
cfg.prep_03.crop_to_task_markers = false; %# HOWTO: if this is set to false, the following lines are irrelevant/ignored?
cfg.prep_03.crop_start_marker    = 'S 91'; % beginning of cropping area
cfg.prep_03.crop_end_marker      = 'S 97'; % end of cropping area
cfg.prep_03.crop_padding_sec     = [0 0];

%# HOWTO: make sure these include your channel labels for AUX/EOG, otherwise channels will be included as EEG in ICA
cfg.prep_03.eog_channel_labels     = {'IO1','IO2','LO1','LO2'}; % ocular channels (detecting eye movements/blinks)
cfg.prep_03.scr_channel_labels     = {'EDA', 'SCR', 'GSR_MR_100_xx'}; % skin conductance response channels
cfg.prep_03.startle_channel_labels = {'Startle'}; % Startle response channels
cfg.prep_03.ekg_channel_labels     = {'ECG', 'EKG'}; % Heart rate channels

cfg.prep_03.downsample_hz = 250; % downsample frequency

% -------------------------------------------------------------------------
% Filter settings
% -------------------------------------------------------------------------
cfg.prep_03.highpass_hz          = 0.1; % set lower if you are interested in low-frequency components
cfg.prep_03.lowpass_hz           = 40; % set higher if you are interested in higher frequencies
cfg.prep_03.ica_prep_highpass_hz = 1; % only for the ica training set; leave if possible as ICA is sensitive towards slow drifts

% -------------------------------------------------------------------------
% Bad channel detection and interpolation
% -------------------------------------------------------------------------
cfg.prep_03.detect_bad_channels_mode = "auto"; %# HOWTO: which options are there?
cfg.prep_03.auto_badchan_z_threshold  = 2.5;
cfg.prep_03.auto_badchan_freqrange_hz = [1, cfg.prep_03.lowpass_hz + 10];

cfg.prep_03.emu_flatline_sec           = 5;
cfg.prep_03.emu_channel_corr_threshold = 0.80;

cfg.prep_03.flag_flat_channels_as_bad     = true;
cfg.prep_03.flat_channel_variance_epsilon = 0;

cfg.prep_03.interpolate_bad_channels_before_ica = true;
cfg.prep_03.interp_method = 'spherical';

% -------------------------------------------------------------------------
% Re-Referencing
% -------------------------------------------------------------------------
% "keep"    = do not rereference in Step 03
% "avg"     = average reference
% "mastoid" = rereference to mastoids listed below
%
% Default should usually be "avg" to match the preprocessing handout.
% Keep cfg.prep_06.reference_mode = "keep" unless you intentionally want a
% second rereference during epoching.
cfg.prep_03.reference_mode            = "avg";  % "keep" | "avg" | "mastoid"
cfg.prep_03.reference_exclude_non_eeg = true;   % do not rereference EOG/SCR/Startle/EKG
cfg.prep_03.mastoid_channel_labels    = {'T9','T10'};

% -------------------------------------------------------------------------
% Filtering
% -------------------------------------------------------------------------

cfg.prep_03.line_noise_method         = "pop_cleanline"; %# HOWTO: Which others are there? or is other option "none", because we filter at 40Hz?
cfg.prep_03.line_noise_frequencies_hz = [50 100]; % in europe, set to [60 120] in US

cfg.prep_03.ica_prep_epoch_rejection_method = "erplab"; % "erplab" | "faster_ptp" | "mad_variance" | "none" -- settings below

cfg.prep_03.pop_cleanline_bandwidth_hz      = 4;
cfg.prep_03.pop_cleanline_p_value           = 0.01;
cfg.prep_03.pop_cleanline_scanforlines      = true; % leave on usually as it improves line noise detection
cfg.prep_03.pop_cleanline_winsize_sec       = 2;
cfg.prep_03.pop_cleanline_winstep_sec       = 1;
cfg.prep_03.pop_cleanline_tau               = 50;
cfg.prep_03.pop_cleanline_pad               = 4;
cfg.prep_03.pop_cleanline_taperbandwidth_hz = 4;
cfg.prep_03.pop_cleanline_norm_spectrum     = 0;
cfg.prep_03.pop_cleanline_computepower      = 0;
cfg.prep_03.pop_cleanline_verbose           = false;

% ERPLAB ICA-prep rejection.
% Same criteria as final Step 06 rejection, but more lenient:
%   final:     +/-200 uV, 50 uV step, 100 ms flatline
%   ICA-prep:  +/-300 uV, 75 uV step, 200 ms flatline
cfg.prep_03.ica_prep_erplab_epoch_rejection = struct();

% Check only EEG channels, not EOG/SCR/Startle/EKG.
cfg.prep_03.ica_prep_erplab_epoch_rejection.channel_scope = "eeg";

% [] = whole ICA-training regepoch.
cfg.prep_03.ica_prep_erplab_epoch_rejection.twindow_ms = [];

cfg.prep_03.ica_prep_erplab_epoch_rejection.clear_existing_flags = true;

% 1) Exclude very large voltages.
cfg.prep_03.ica_prep_erplab_epoch_rejection.use_extreme_voltage = true;
cfg.prep_03.ica_prep_erplab_epoch_rejection.extreme_voltage_uV  = 300;
cfg.prep_03.ica_prep_erplab_epoch_rejection.flag_extreme_voltage = 1;

% 2) Exclude large sample-to-sample voltage jumps.
cfg.prep_03.ica_prep_erplab_epoch_rejection.use_sample_diff = true;
cfg.prep_03.ica_prep_erplab_epoch_rejection.sample_diff_uV  = 75;
cfg.prep_03.ica_prep_erplab_epoch_rejection.flag_sample_diff = 2;

% 3) Exclude flatline/blocking, but more lenient than final rejection.
cfg.prep_03.ica_prep_erplab_epoch_rejection.use_flatline = true;
cfg.prep_03.ica_prep_erplab_epoch_rejection.flatline_tolerance_uV = 0.5;
cfg.prep_03.ica_prep_erplab_epoch_rejection.flatline_duration_ms  = 200;
cfg.prep_03.ica_prep_erplab_epoch_rejection.flag_flatline = 3;

cfg.prep_03.ica_prep_erplab_epoch_rejection.review = "off";
cfg.prep_03.ica_prep_erplab_epoch_rejection.history = "off";
cfg.prep_03.ica_prep_erplab_epoch_rejection.lowpass_hz = -1;

% MAD ICA-prep rejection settings.
% Only used when cfg.prep_03.ica_prep_epoch_rejection_method == "mad_variance".
cfg.prep_03.ica_prep_mad_z_threshold = 3;
cfg.prep_03.ica_prep_mad_use_logvar  = true;
cfg.prep_03.ica_prep_max_reject_prop = 1.00;

% MAD variance rejection settings.
% Only used when cfg.prep_06.epoch_rejection_method == "mad_variance".
cfg.prep_06.mad_z_threshold = 3;
cfg.prep_06.mad_use_logvar  = true;

%# TODO: add FASTER settings for ICA-prep epoch rejection if we decide to keep that method?
% =========================================================================
% STEP 04: ICA
% =========================================================================
cfg.prep_04 = struct();

cfg.prep_04.ica_method                   = "runica"; %"runica" | "amica" -CURRENTLY BROKEN DO NOT USE WILL BE FIXED
cfg.prep_04.use_extended_infomax         = true;
cfg.prep_04.interrupt_ica                = 'off';
cfg.prep_04.use_pca_rank_if_interpolated = true;
cfg.prep_04.amica_require_no_spaces_on_windows = true;
cfg.prep_04.ica_channel_scope = "eeg_eog";

% =========================================================================
% STEP 05: AFTER ICA / ICLABEL
% =========================================================================
cfg.prep_05 = struct();

cfg.prep_05.clear_subject_ica_comps_dir = true; % delete existing ICA components directory for subject before saving new one, to avoid confusion from old ICA results

% settings for ICLabel rejection
% NOTE: In the handout we only agreed on ICLabel for eye artifact
% rejection. However, why not use it for removing other artifacts as well?
% It is a well-validated algorithm and if thresholds are set
% conservatively, no harm is done
cfg.prep_05.iclabel_eye_remove_thr       = 0.85;
cfg.prep_05.iclabel_muscle_remove_thr    = 0.85;
cfg.prep_05.iclabel_heart_remove_thr     = 0.85;
cfg.prep_05.iclabel_linenoise_remove_thr = 0.85;
cfg.prep_05.iclabel_channoise_remove_thr = 0.85;
cfg.prep_05.iclabel_other_remove_thr     = 1.01;
cfg.prep_05.iclabel_brain_min_keep_thr   = 0.00;

cfg.prep_05.save_ic_topos_png   = true;
cfg.prep_05.iclabel_edge_margin = 0.10;

cfg.prep_05.ic_topo_dpi        = 300;
cfg.prep_05.ic_topo_fig_cm     = [0 0 18 18];
cfg.prep_05.ic_topo_electrodes = 'off';

cfg.prep_05.write_component_table       = true; % creates table listing all ICA components with their labels and probabilities, as well as whether they were removed or kept
cfg.prep_05.write_run_summary_table     = true; % creates table summarizing ICA results per run, e.g. number of components removed, number of flags per rejection criterion, etc.
cfg.prep_05.write_subject_summary_table = true; % # HOWTO: creates identical table to run_summary..?
cfg.prep_05.qc_table_delimiter          = ';';

% =========================================================================
% STEP 06: EPOCHING + FINAL ARTIFACT REJECTION
% =========================================================================
cfg.prep_06 = struct();

% -------------------------------------------------------------------------
% General mode selection
% -------------------------------------------------------------------------
cfg.prep_06.epoching_mode  = "baseline";   % "baseline" | "event_locked"
cfg.prep_06.overwrite_mode = "";

% -------------------------------------------------------------------------
% Saving
% -------------------------------------------------------------------------
cfg.prep_06.save_final_only         = true; %# HOWTO: what does this mean and how does it relate to the intermediate steps below?
cfg.prep_06.save_intermediate_steps = false;
cfg.prep_06.savemode                = 'twofiles'; %# HOWTO: what are the options?

% -------------------------------------------------------------------------
% Referencing in Step 06
% Default is KEEP because rereferencing usually already happened in Step 03.
% Only change this if you explicitly want a second rereference here.
% -------------------------------------------------------------------------
cfg.prep_06.reference_mode         = "keep";   % "keep" | "avg" | "mastoid"
cfg.prep_06.mastoid_channel_labels = {'T9','T10'};

% -------------------------------------------------------------------------
% EVENT-LOCKED mode settings
% Used only when cfg.prep_06.epoching_mode == "event_locked"
% -------------------------------------------------------------------------
cfg.prep_06.events_phase = { ...
    'S 201','S 241', ...
    'S 2021','S 2421','S 2022','S 2422', ...
    'S 203','S 213','S 223','S 233','S 243', ...
    'S 2041','S 2441','S 2042','S 2442','S 2043','S 2443', ...
    'S 205','S 245' ...
    };

cfg.prep_06.epoch_start_s = -0.4; % start of epoch relative to event in seconds
cfg.prep_06.epoch_end_s   =  2.6; % end of epoch relative to event in seconds

% -------------------------------------------------------------------------
% BASELINE mode settings
% Used only when cfg.prep_06.epoching_mode == "baseline"
% -------------------------------------------------------------------------
cfg.prep_06.regepoch_length_sec = 10; % length of epochs to be created
cfg.prep_06.regepoch_step_sec   = 10; %# HOWTO: what does this mean? if equal to length, epochs will be non-overlapping?

cfg.prep_06.baseline_start_condition        = "open"; % assumes that data contains data from before first phase, in which participants had their eyes open
cfg.prep_06.baseline_open_marker_prefixes   = {'S 1'}; % triggers marking the start of open-eye baseline segments, e.g. "S 1", "S 11", "S 12"
cfg.prep_06.baseline_closed_marker_prefixes = {'S 2'}; % triggers marking the start of closed-eye baseline segments, e.g. "S 2", "S 21", "S 22"
cfg.prep_06.baseline_end_markers            = {'S 99'};

% -------------------------------------------------------------------------
% Artifact rejection
% -------------------------------------------------------------------------
cfg.prep_06.do_artifact_rejection = true; %# HOWTO: do we have suggestions when to use which?

% Optional first-pass hard absolute-amplitude rejection.
% Usually keep this false when using ERPLAB, because ERPLAB's extreme-voltage
% rule can implement the same kind of threshold.
cfg.prep_06.do_initial_hard_threshold_rejection = false;
cfg.prep_06.initial_hard_threshold_uv           = 200;

% Select exactly one final epoch-rejection method.
%
%   "erplab"       = use cfg.prep_06.erplab_epoch_rejection
%   "faster_ptp"   = use cfg.prep_06.faster_ptp_epoch_rejection
%   "mad_variance" = use cfg.prep_06.mad_z_threshold / mad_use_logvar
%   "none"         = skip final epoch rejection
%
cfg.prep_06.epoch_rejection_method = "erplab";  % "erplab" | "faster_ptp" | "mad_variance" | "none"

% Subject-level exclusion after epoch rejection.
% 1 means disabled. Example: 0.50 would exclude subjects with >50% rejected epochs.
cfg.prep_06.max_reject_prop = 1;

% -------------------------------------------------------------------------
% ERPLAB epoch rejection
% Only used when cfg.prep_06.epoch_rejection_method == "erplab".
% -------------------------------------------------------------------------
cfg.prep_06.erplab_epoch_rejection = struct();

cfg.prep_06.erplab_epoch_rejection.channel_scope = "eeg";
cfg.prep_06.erplab_epoch_rejection.twindow_ms = [];
cfg.prep_06.erplab_epoch_rejection.clear_existing_flags = true;

cfg.prep_06.erplab_epoch_rejection.use_extreme_voltage = true;
cfg.prep_06.erplab_epoch_rejection.extreme_voltage_uV  = 200;
cfg.prep_06.erplab_epoch_rejection.flag_extreme_voltage = 1;

cfg.prep_06.erplab_epoch_rejection.use_sample_diff = true;
cfg.prep_06.erplab_epoch_rejection.sample_diff_uV  = 50;
cfg.prep_06.erplab_epoch_rejection.flag_sample_diff = 2;

cfg.prep_06.erplab_epoch_rejection.use_flatline = false;
cfg.prep_06.erplab_epoch_rejection.flatline_tolerance_uV = 0.5;
cfg.prep_06.erplab_epoch_rejection.flatline_duration_ms  = 100;
cfg.prep_06.erplab_epoch_rejection.flag_flatline = 3;

cfg.prep_06.erplab_epoch_rejection.review = "off";
cfg.prep_06.erplab_epoch_rejection.history = "off";
cfg.prep_06.erplab_epoch_rejection.lowpass_hz = -1;

% -------------------------------------------------------------------------
% FASTER/PTP epoch rejection
% Only used when cfg.prep_06.epoch_rejection_method == "faster_ptp".
%
% To use FASTER only: set use_faster=true and use_ptp=false.
% To use PTP only:    set use_faster=false and use_ptp=true.
% To use both:        set both to true.
% -------------------------------------------------------------------------
cfg.prep_06.faster_ptp_epoch_rejection = struct();

cfg.prep_06.faster_ptp_epoch_rejection.use_faster    = true;
cfg.prep_06.faster_ptp_epoch_rejection.faster_z      = 3;
cfg.prep_06.faster_ptp_epoch_rejection.use_robust_z  = false;

cfg.prep_06.faster_ptp_epoch_rejection.use_ptp       = true;
cfg.prep_06.faster_ptp_epoch_rejection.ptp_uV_thresh = 300;

% -------------------------------------------------------------------------
% MAD variance epoch rejection
% Only used when cfg.prep_06.epoch_rejection_method == "mad_variance".
% -------------------------------------------------------------------------
cfg.prep_06.mad_z_threshold = 3;
cfg.prep_06.mad_use_logvar  = true;
% -------------------------------------------------------------------------
% Reject Participants if not enough Trials are present
% replaces the faster_warn_if_reject_prop_gt setting wiht a more elaborate
% version 
% -------------------------------------------------------------------------
cfg.prep_06.min_trials_per_condition_enable      = true; 
cfg.prep_06.min_trials_per_condition_min_n       = 3; % min num of trials in each condition so participant is not excluded
cfg.prep_06.min_trials_per_condition_zero_tol_ms = 2; % jitter allowed around trigger
cfg.prep_06.min_trials_per_condition_codes = { ...
    'condition_name', {'S XXX','S XXY'}; ...
    }; % adjust this to conditions in your setup that should have at least min_trials_per_condition

% -------------------------------------------------------------------------
% Summary tables
% -------------------------------------------------------------------------
cfg.prep_06.write_run_summary_table     = false;
cfg.prep_06.write_subject_summary_table = false;
cfg.prep_06.qc_table_delimiter          = ';';

end