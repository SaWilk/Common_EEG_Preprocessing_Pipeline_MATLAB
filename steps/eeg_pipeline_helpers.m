% =========================================================================
% FILE: eeg_pipeline_helpers.m
% =========================================================================
function helpers = eeg_pipeline_helpers(default_log_file)
% EEG_PIPELINE_HELPERS Utility factory for the unified EEG runner.
%
% WHAT THIS FILE DOES
%   - Returns a struct of helper handles used by the runner and step files
%
% INPUT
%   - default_log_file : log file used by helpers.log_msg_default(...)
%
% OUTPUT
%   - helpers struct with function handles
%
% Saskia Wilken Dez 2025

helpers = struct();

% -------------------------------------------------------------------------
% Config-building helpers
% -------------------------------------------------------------------------
helpers.pick_value               = @pick_value_impl;
helpers.detect_env_mode          = @detect_env_mode_impl;
helpers.detect_machine_kind      = @detect_machine_kind_impl;
helpers.default_profile_for_mode = @default_profile_for_mode_impl;
helpers.get_hostname             = @get_hostname_impl;
helpers.get_env_first_nonempty   = @get_env_first_nonempty_impl;
helpers.get_raw_trigger_from_key = @get_raw_trigger_from_key_impl;
helpers.map_trigger_by_table     = @map_trigger_by_table_impl;

% -------------------------------------------------------------------------
% Logging and basic filesystem helpers
% -------------------------------------------------------------------------
helpers.log_msg                  = @(log_file, varargin) log_msg_impl(log_file, varargin{:});
helpers.log_msg_default          = @(varargin) log_msg_impl(default_log_file, varargin{:});
helpers.ensure_dir               = @ensure_dir_impl;
helpers.clear_directory_contents = @clear_directory_contents_impl;

% -------------------------------------------------------------------------
% Environment / worker helpers
% -------------------------------------------------------------------------
helpers.get_env_or_empty          = @get_env_or_empty_impl;
helpers.get_slurm_cpus_per_task   = @get_slurm_cpus_per_task_impl;
helpers.is_parallel_license_error = @is_parallel_license_error_impl;

% -------------------------------------------------------------------------
% Runner / planning helpers
% -------------------------------------------------------------------------
helpers.init_toolboxes                      = @init_toolboxes_impl;
helpers.discover_subjects                   = @discover_subjects_impl;
helpers.resolve_parallel_enable             = @resolve_parallel_enable_impl;
helpers.resolve_worker_count                = @resolve_worker_count_impl;
helpers.build_paths                         = @build_paths_impl;
helpers.build_subject_plans                 = @build_subject_plans_impl;
helpers.sort_subject_plans_by_expected_cost = @sort_subject_plans_by_expected_cost_impl;
helpers.run_one_subject                     = @run_one_subject_impl;

% -------------------------------------------------------------------------
% Overwrite / rerun helpers
% -------------------------------------------------------------------------
helpers.resolve_overwrite_mode      = @resolve_overwrite_mode_impl;
helpers.resolve_overwrite_policy    = @resolve_overwrite_policy_impl;
helpers.step_should_run_outputs     = @step_should_run_outputs_impl;
helpers.step_should_run_from_folder = @step_should_run_from_folder_impl;
helpers.get_step_subject_folder     = @get_step_subject_folder_impl;

% -------------------------------------------------------------------------
% EEG load / save / BIDS helpers
% -------------------------------------------------------------------------
helpers.safe_delete_set = @safe_delete_set_impl;
helpers.safe_save_set   = @safe_save_set_impl;
helpers.safe_load_set   = @safe_load_set_impl;
helpers.find_bids_vhdr  = @find_bids_vhdr_impl;
helpers.safe_load_bv    = @safe_load_bv_impl;

% -------------------------------------------------------------------------
% EEG comment / trigger helpers
% -------------------------------------------------------------------------
helpers.append_eeg_comment     = @append_eeg_comment_impl;
helpers.normalize_trigger_type = @normalize_trigger_type_impl;

% -------------------------------------------------------------------------
% EEG utility helpers used by step files
% -------------------------------------------------------------------------
helpers.normalize_event_types                 = @normalize_event_types_impl;
helpers.normalize_epoching_mode_value        = @normalize_epoching_mode_value_impl;
helpers.get_channel_indices_by_type           = @get_channel_indices_by_type_impl;
helpers.apply_reference_mode                  = @apply_reference_mode_impl;
helpers.build_epoching_output_paths           = @build_epoching_output_paths_impl;
helpers.normalize_event_list                  = @normalize_event_list_impl;
helpers.get_present_events                    = @get_present_events_impl;
helpers.preview_event_types                   = @preview_event_types_impl;
helpers.build_step06_summary_row              = @build_step06_summary_row_impl;
helpers.save_intermediate_set                 = @save_intermediate_set_impl;
helpers.apply_hard_epoch_threshold_rejection  = @apply_hard_epoch_threshold_rejection_impl;
helpers.apply_fallback_epoch_rejection        = @apply_fallback_epoch_rejection_impl;
helpers.create_baseline_condition_datasets    = @create_baseline_condition_datasets_impl;
helpers.finalize_epoched_dataset              = @finalize_epoched_dataset_impl;
helpers.save_final_epoched_outputs            = @save_final_epoched_outputs_impl;
helpers.build_eeg_key_token_stream_with_time  = @build_eeg_key_token_stream_with_time_impl;
helpers.find_first_event_latency              = @find_first_event_latency_impl;
helpers.ensure_channel_types                  = @ensure_channel_types_impl;
helpers.find_flat_or_invalid_channels         = @find_flat_or_invalid_channels_impl;
helpers.detect_bad_channels_emulation_style   = @detect_bad_channels_emulation_style_impl;
helpers.apply_filter_to_subset_only           = @apply_filter_to_subset_only_impl;
helpers.apply_pop_cleanline_to_subset         = @apply_pop_cleanline_to_subset_impl;
helpers.apply_jointprob_safely                = @apply_jointprob_safely_impl;
helpers.apply_shared_epoch_rejection          = @apply_shared_epoch_rejection_impl;
helpers.reject_ica_prep_epochs_by_mad_variance = @reject_ica_prep_epochs_by_mad_variance_impl;
helpers.compute_data_rank_svd                 = @compute_data_rank_svd_impl;
helpers.make_unique_amica_tmpdir              = @make_unique_amica_tmpdir_impl;
helpers.safe_rmdir                            = @safe_rmdir_impl;
helpers.write_ic_topography_pngs              = @write_ic_topography_pngs_impl;
helpers.merge_structs_recursive = @merge_structs_recursive_impl;

% -------------------------------------------------------------------------
% Behavior-log helpers
% -------------------------------------------------------------------------
helpers.find_behavior_log = @find_behavior_log_impl;
helpers.read_behavior_log = @read_behavior_log_impl;

% -------------------------------------------------------------------------
% Raw QC helper
% -------------------------------------------------------------------------
helpers.raw_qc_behavior_vs_eeg_and_write_csv = @raw_qc_behavior_vs_eeg_and_write_csv_impl;

end

% =========================================================================
% CONFIG-BUILDING HELPERS
% =========================================================================
function value = get_env_first_nonempty_impl(names)
value = "";

if nargin < 1 || isempty(names)
    return;
end

if ischar(names) || isstring(names)
    names = cellstr(string(names));
end

for i = 1:numel(names)
    tmp = getenv(char(string(names{i})));
    if ~isempty(tmp)
        value = string(tmp);
        return;
    end
end
end

function value = pick_value_impl(condition, value_if_true, value_if_false)
if condition
    value = value_if_true;
else
    value = value_if_false;
end
end

function hn = get_hostname_impl()
hn = "";

cands = ["COMPUTERNAME","HOSTNAME"];
for i = 1:numel(cands)
    tmp = getenv(char(cands(i)));
    if ~isempty(tmp)
        hn = string(tmp);
        return;
    end
end

try
    [status, out] = system('hostname');
    if status == 0
        hn = string(strtrim(out));
    end
catch
end
end

function mode = detect_env_mode_impl(varargin)
legacy_env_prefix = "";
if nargin >= 1 && ~isempty(varargin{1})
    legacy_env_prefix = string(varargin{1});
end

env_names = {'EEG_PIPELINE_ENV_MODE'};
if strlength(strtrim(legacy_env_prefix)) > 0
    env_names{end+1} = [char(legacy_env_prefix) '_ENV_MODE']; %#ok<AGROW>
end

mode = string(get_env_first_nonempty_impl(env_names));
mode = lower(strtrim(mode));

if any(mode == ["pc","server","hpc"])
    return;
end

machine_kind = detect_machine_kind_impl(legacy_env_prefix);

switch machine_kind
    case "hpc_hummel"
        mode = "hpc";
    case "server_windows"
        mode = "server";
    otherwise
        mode = "pc";
end
end

function machine_kind = detect_machine_kind_impl(varargin)
legacy_env_prefix = "";
if nargin >= 1 && ~isempty(varargin{1})
    legacy_env_prefix = string(varargin{1});
end

machine_kind = "unknown";

env_names = {'EEG_PIPELINE_MACHINE_KIND'};
if strlength(strtrim(legacy_env_prefix)) > 0
    env_names{end+1} = [char(legacy_env_prefix) '_MACHINE_KIND']; %#ok<AGROW>
end

override = string(get_env_first_nonempty_impl(env_names));
override = lower(strtrim(override));

if any(override == ["local_windows","server_windows","hpc_hummel"])
    machine_kind = override;
    return;
end

hostname = lower(strtrim(get_hostname_impl()));

if strlength(hostname) > 0 && contains(hostname, "hummel")
    machine_kind = "hpc_hummel";
    return;
end

if ~isempty(getenv('SLURM_JOB_ID'))
    machine_kind = "hpc_hummel";
    return;
end

if strlength(hostname) > 0 && startsWith(hostname, "vdi")
    machine_kind = "server_windows";
    return;
end

if ispc
    machine_kind = "local_windows";
    return;
end
end

function profile = default_profile_for_mode_impl(mode, machine_kind)
mode         = string(lower(strtrim(mode)));
machine_kind = string(lower(strtrim(machine_kind)));

switch mode
    case "hpc"
        profile = "hpc_hummel";

    case "server"
        profile = "server_windows";

    case "pc"
        if machine_kind == "server_windows"
            profile = "server_windows";
        else
            profile = "pc";
        end

    otherwise
        profile = "pc";
end
end

function out = merge_structs_recursive_impl(base, override)
if nargin < 1 || isempty(base)
    out = override;
    return;
end

if nargin < 2 || isempty(override)
    out = base;
    return;
end

if ~isstruct(base) || ~isstruct(override)
    out = override;
    return;
end

out = base;
override_fields = fieldnames(override);

for i = 1:numel(override_fields)
    fn = override_fields{i};

    if ~isfield(out, fn)
        out.(fn) = override.(fn);
        continue;
    end

    if isstruct(out.(fn)) && isstruct(override.(fn))
        out.(fn) = merge_structs_recursive_impl(out.(fn), override.(fn));
    else
        out.(fn) = override.(fn);
    end
end
end

% =========================================================================
% LOGGING / FILESYSTEM
% =========================================================================
function log_msg_impl(log_file, varargin)
message_text = sprintf(varargin{:});
timestamp    = datestr(now, 'yyyy-mm-dd HH:MM:SS');

fprintf('[%s] %s\n', timestamp, message_text);

fid = fopen(log_file, 'a');
if fid >= 0
    fprintf(fid, '[%s] %s\n', timestamp, message_text);
    fclose(fid);
end
end

function ensure_dir_impl(path_in)
if exist(path_in, 'dir') ~= 7
    mkdir(path_in);
end
end

function clear_directory_contents_impl(path_in)
path_in = char(string(path_in));

if exist(path_in, 'dir') ~= 7
    return;
end

dir_info = dir(path_in);
real_mask = ~ismember({dir_info.name}, {'.','..'});
dir_info = dir_info(real_mask);

for k = 1:numel(dir_info)
    full_item = fullfile(path_in, dir_info(k).name);
    if dir_info(k).isdir
        rmdir(full_item, 's');
    else
        delete(full_item);
    end
end
end

% =========================================================================
% ENVIRONMENT / WORKERS
% =========================================================================
function value = get_env_or_empty_impl(name)
tmp = getenv(name);
if isempty(tmp)
    value = "";
else
    value = string(tmp);
end
end

function n_workers = get_slurm_cpus_per_task_impl()
n_workers = [];
value = getenv('SLURM_CPUS_PER_TASK');

if ~isempty(value)
    tmp = str2double(value);
    if ~isnan(tmp) && tmp >= 1
        n_workers = tmp;
    end
end
end

function tf = is_parallel_license_error_impl(me)
tf = false;

try
    message_text = lower(string(me.message));
catch
    message_text = "";
end

try
    message_id = lower(string(me.identifier));
catch
    message_id = "";
end

tf = tf || contains(message_text, "license manager error -4");
tf = tf || (contains(message_text, "maximum number of users") && contains(message_text, "toolbox"));
tf = tf || contains(message_text, "distrib_computing_toolbox");
tf = tf || (contains(message_text, "unable to check out a license") && contains(message_text, "parallel"));
tf = tf || (contains(message_id, "license") && contains(message_text, "check out"));
end

% =========================================================================
% RUNNER / PLANNING
% =========================================================================
function init_toolboxes_impl(cfg)
addpath(cfg.root_dir);

eeglab_root = resolve_toolbox_root_impl(cfg, "eeglab");
faster_root = resolve_toolbox_root_impl(cfg, "faster");

if strlength(eeglab_root) > 0
    addpath(char(eeglab_root));
end

if strlength(faster_root) > 0
    if cfg.toolboxes.use_genpath
        addpath(genpath(char(faster_root)));
    else
        addpath(char(faster_root));
    end
end

if exist('eeglab', 'file') ~= 2
    error('EEGLAB not found. Expected eeglab.m under: %s', eeglab_root);
end
end

function root = resolve_toolbox_root_impl(cfg, which_toolbox)
env_name = upper(which_toolbox) + "_ROOT";
root = string(getenv(env_name));

if strlength(root) > 0
    return;
end

mode = string(cfg.env.mode);

switch mode
    case "pc"
        root = string(cfg.toolboxes.("path_" + which_toolbox + "_pc"));
    case "server"
        root = string(cfg.toolboxes.("path_" + which_toolbox + "_server"));
    case "hpc"
        root = string(cfg.toolboxes.("path_" + which_toolbox + "_hpc"));
    otherwise
        root = "";
end
end

function sub_ids = discover_subjects_impl(cfg)
sub_ids = {};
discovery_root = "";

    % -------------------------------------------------------------------------
    % 1) Explicit subject list always wins
    % -------------------------------------------------------------------------
if isfield(cfg, 'subjects') && isfield(cfg.subjects, 'list') && ~isempty(cfg.subjects.list)
    sub_ids = cfg.subjects.list;
    discovery_root = "cfg.subjects.list";

else
        % ---------------------------------------------------------------------
        % 2) Decide where discovery should happen
        %    - If Step 01 runs, discover from raw EEG source files
        %    - Otherwise discover from existing BIDS sub-* folders
        % ---------------------------------------------------------------------
    use_step01_source_discovery = ...
        isfield(cfg, 'steps') && ...
        isfield(cfg.steps, 'prep_01_bids_formatting') && ...
        isfield(cfg.steps.prep_01_bids_formatting, 'run') && ...
        cfg.steps.prep_01_bids_formatting.run;

    if use_step01_source_discovery
        source_root = char(string(cfg.paths.source_eeg_root));
        discovery_root = string(source_root);

        if exist(source_root, 'dir') ~= 7
            error('Step 01 subject discovery failed: source_eeg_root does not exist: %s', source_root);
        end

        if isfield(cfg, 'prep_01') && isfield(cfg.prep_01, 'raw_eeg_regex') && ...
                strlength(string(cfg.prep_01.raw_eeg_regex)) > 0
            raw_regex = char(string(cfg.prep_01.raw_eeg_regex));
        else
            raw_regex = '^.*?(\d{3})(?:_(\d{3}))?\.vhdr$';
        end

        dir_info = dir(fullfile(source_root, '*.vhdr'));
        tmp_ids = {};

        for k = 1:numel(dir_info)
            this_name = dir_info(k).name;
            tok = regexp(this_name, raw_regex, 'tokens', 'once');

            if ~isempty(tok) && ~isempty(tok{1})
                tmp_ids{end+1} = char(string(tok{1})); %#ok<AGROW>
            end
        end

        sub_ids = unique(tmp_ids, 'stable');

    else
        bids_root = char(string(cfg.paths.bids_root));
        discovery_root = string(bids_root);

        dir_info = dir(fullfile(bids_root, 'sub-*'));
        dir_info = dir_info([dir_info.isdir]);

        sub_ids = {dir_info.name};
        sub_ids = cellfun(@(x) erase(x, 'sub-'), sub_ids, 'UniformOutput', false);
    end
end

if isstring(sub_ids)
    sub_ids = cellstr(sub_ids);
end
if ischar(sub_ids)
    sub_ids = {sub_ids};
end

sub_ids = sub_ids(:);

valid_regex = cfg.constants.valid_sub_id_regex;
keep_mask = ~cellfun(@isempty, regexp(sub_ids, valid_regex, 'once'));
sub_ids = sub_ids(keep_mask);

if isempty(sub_ids)
    error('No valid subject IDs found in %s (after regex filter).', char(string(discovery_root)));
end

sub_num = cellfun(@str2double, sub_ids);
[~, sort_ix] = sort(sub_num);
sub_ids = sub_ids(sort_ix);

use_min = false;
min_id_num = NaN;

if isfield(cfg, 'subjects') && isfield(cfg.subjects, 'min_id')
    min_id_raw = cfg.subjects.min_id;

    if ~(isempty(min_id_raw) || ...
            (isstring(min_id_raw) && strlength(min_id_raw) == 0) || ...
            (ischar(min_id_raw) && isempty(strtrim(min_id_raw))))
        min_id_num = str2double(string(min_id_raw));
        use_min = ~isnan(min_id_num) && isfinite(min_id_num);
    end
end

if use_min
    sub_ids = sub_ids(cellfun(@str2double, sub_ids) >= min_id_num);
end

if isempty(sub_ids)
    if use_min
        error('No subjects remain after min_id >= %03d filter.', round(min_id_num));
    else
        error('No subjects remain after filtering (unexpected).');
    end
end
end

function use_parallel = resolve_parallel_enable_impl(cfg)
use_parallel = false;

if isfield(cfg, 'parallel') && isfield(cfg.parallel, 'enable')
    use_parallel = logical(cfg.parallel.enable);
end
end

function n_workers = resolve_worker_count_impl(cfg, master_log)
if ~isempty(cfg.parallel.force_workers)
    n_workers = cfg.parallel.force_workers;
    log_msg_impl(master_log, ...
        'Resolved worker count from cfg.parallel.force_workers=%d', ...
        n_workers);
    return;
end

worker_env = getenv('EEG_PIPELINE_WORKERS');
if ~isempty(worker_env)
    tmp = str2double(worker_env);
    if ~isnan(tmp) && tmp >= 1
        n_workers = tmp;
        log_msg_impl(master_log, ...
            'Resolved worker count from EEG_PIPELINE_WORKERS=%d', ...
            n_workers);
        return;
    end
end

machine_kind = "";
if isfield(cfg, 'env') && isfield(cfg.env, 'machine_kind')
    machine_kind = string(cfg.env.machine_kind);
end

profile = "";
if isfield(cfg, 'paths') && isfield(cfg.paths, 'profile')
    profile = string(cfg.paths.profile);
end

switch machine_kind
    case "server_windows"
        n_workers = 4;

    case "local_windows"
        n_workers = 2;

    case "hpc_hummel"
        tmp = get_slurm_cpus_per_task_impl();
        if ~isempty(tmp)
            n_workers = tmp;
        else
            n_workers = feature('numcores');
        end

    otherwise
        switch profile
            case "server_windows"
                n_workers = 4;
            case "pc"
                n_workers = 2;
            case "hpc_hummel"
                tmp = get_slurm_cpus_per_task_impl();
                if ~isempty(tmp)
                    n_workers = tmp;
                else
                    n_workers = feature('numcores');
                end
            otherwise
                n_workers = min(2, feature('numcores'));
        end
end

n_workers = max(1, round(n_workers));

if ~strcmp(machine_kind, "hpc_hummel")
    try
        cluster_obj = parcluster('local');
        if ~isempty(cluster_obj.NumWorkers) && isnumeric(cluster_obj.NumWorkers)
            n_workers = min(n_workers, cluster_obj.NumWorkers);
        end
    catch
    end
end

log_msg_impl(master_log, ...
    'Resolved worker count=%d (machine_kind=%s, profile=%s)', ...
    n_workers, machine_kind, profile);
end

function paths = build_paths_impl(cfg, subj_id)
paths = struct();

paths.root_dir         = cfg.root_dir;
paths.source_eeg_root  = char(string(cfg.paths.source_eeg_root));
paths.source_beh_root  = char(string(cfg.paths.source_beh_root));
paths.bids_root        = char(string(cfg.paths.bids_root));
paths.derivatives_root = char(string(cfg.paths.derivatives_root));

paths.subj_label = sprintf('sub-%s', subj_id);

session_label = "01";
if isfield(cfg, 'bids') && isfield(cfg.bids, 'session_label') && strlength(string(cfg.bids.session_label)) > 0
    session_label = string(cfg.bids.session_label);
end

task_label = "";
if isfield(cfg, 'bids') && isfield(cfg.bids, 'task_label') && strlength(string(cfg.bids.task_label)) > 0
    task_label = string(cfg.bids.task_label);
end

paths.session_label   = char(session_label);
paths.bids_task_label = char(task_label);

% BIDS locations
paths.bids_sub_dir = fullfile(paths.bids_root, paths.subj_label);
paths.bids_ses_dir = fullfile(paths.bids_sub_dir, ['ses-' char(session_label)]);
paths.prep_01_out_dir = paths.bids_ses_dir;

% Derivatives roots
paths.step_02_root           = fullfile(paths.derivatives_root, '01_trigger_fix');
paths.step_03_until_ica_root = fullfile(paths.derivatives_root, '02_until_ica');
paths.step_03_for_ica_root   = fullfile(paths.derivatives_root, '03_for_ica');

ica_tag = "runica";
if isfield(cfg, 'prep_04') && isfield(cfg.prep_04, 'ica_method')
    ica_tag = string(cfg.prep_04.ica_method);
end

suffix = "";
if isfield(cfg.paths, 'branch_by_ica_method') && cfg.paths.branch_by_ica_method
    suffix = "_" + ica_tag;
end

paths.step_04_root = fullfile(paths.derivatives_root, char("04_after_ica"      + suffix));
paths.step_05_root = fullfile(paths.derivatives_root, char("05_until_epoching" + suffix));
paths.step_06_root = fullfile(paths.derivatives_root, char("06_epoched"        + suffix));

ensure_dir_impl(paths.step_02_root);
ensure_dir_impl(paths.step_03_until_ica_root);
ensure_dir_impl(paths.step_03_for_ica_root);
ensure_dir_impl(paths.step_04_root);
ensure_dir_impl(paths.step_05_root);
ensure_dir_impl(paths.step_06_root);

% Subject-specific step folders
paths.prep_02_out_dir           = fullfile(paths.step_02_root, paths.subj_label);
paths.prep_03_out_dir_until_ica = fullfile(paths.step_03_until_ica_root, paths.subj_label);
paths.prep_03_out_dir_for_ica   = fullfile(paths.step_03_for_ica_root, paths.subj_label);
paths.prep_04_out_dir           = fullfile(paths.step_04_root, paths.subj_label);
paths.prep_05_out_dir           = fullfile(paths.step_05_root, paths.subj_label);
paths.prep_06_out_dir           = fullfile(paths.step_06_root, paths.subj_label);

ensure_dir_impl(paths.prep_02_out_dir);
ensure_dir_impl(paths.prep_03_out_dir_until_ica);
ensure_dir_impl(paths.prep_03_out_dir_for_ica);
ensure_dir_impl(paths.prep_04_out_dir);
ensure_dir_impl(paths.prep_05_out_dir);
ensure_dir_impl(paths.prep_06_out_dir);

% QA / checks
paths.checks_root = fullfile(paths.derivatives_root, 'checks');
ensure_dir_impl(paths.checks_root);

paths.checks_ica_components_root = fullfile(paths.checks_root, 'ica_comps');
ensure_dir_impl(paths.checks_ica_components_root);

paths.checks_ica_components_subj_dir = fullfile(paths.checks_ica_components_root, paths.subj_label);
paths.checks_ica_components_rej_dir  = fullfile(paths.checks_ica_components_subj_dir, 'rej');
paths.checks_ica_components_edge_dir = fullfile(paths.checks_ica_components_subj_dir, 'edge');

ensure_dir_impl(paths.checks_ica_components_subj_dir);
ensure_dir_impl(paths.checks_ica_components_rej_dir);
ensure_dir_impl(paths.checks_ica_components_edge_dir);

paths.qc_root = fullfile(paths.derivatives_root, 'qc');
ensure_dir_impl(paths.qc_root);

paths.qc_dir = fullfile(paths.qc_root, paths.subj_label);
ensure_dir_impl(paths.qc_dir);
end

function subject_plans = build_subject_plans_impl(cfg, sub_ids, master_log)
step_names = { ...
    'prep_01_bids_formatting', ...
    'prep_02_triggerfix', ...
    'prep_03_until_ica', ...
    'prep_04_ica', ...
    'prep_05_after_ica', ...
    'prep_06_epoching'};

subject_plans = repmat(struct( ...
    'subj_id', '', ...
    'any_step_to_run', false, ...
    'steps', struct()), numel(sub_ids), 1);

for i = 1:numel(sub_ids)
    subj_id = sub_ids{i};
    paths   = build_paths_impl(cfg, subj_id);

    plan = struct();
    plan.subj_id = subj_id;
    plan.any_step_to_run = false;
    plan.steps = struct();

    for s = 1:numel(step_names)
        step_name = step_names{s};
        step_cfg  = cfg.steps.(step_name);

        info = struct();
        info.run = false;
        info.reason = "step disabled";
        info.step_folder = "";
        info.folder_info = struct();
        info.delete_before_run = false;
        info.policy = struct();

        if ~step_cfg.run
            plan.steps.(step_name) = info;
            continue;
        end

        policy = resolve_overwrite_policy_impl(cfg, step_cfg);
        step_folder = get_step_subject_folder_impl(paths, step_name);
        [do_run, reason, folder_info] = step_should_run_from_folder_impl(step_folder, policy);

        info.run = do_run;
        info.reason = reason;
        info.step_folder = step_folder;
        info.folder_info = folder_info;
        info.policy = policy;
        info.delete_before_run = do_run && folder_info.exists && ~folder_info.is_empty;

        plan.steps.(step_name) = info;
    end

    plan = propagate_downstream_reruns_impl(plan, step_names);

    run_flags = false(1, numel(step_names));
    for s = 1:numel(step_names)
        run_flags(s) = plan.steps.(step_names{s}).run;
    end
    plan.any_step_to_run = any(run_flags);

    subject_plans(i) = plan;

    log_msg_impl(master_log, ...
        'Preplan sub-%s | 01=%d | 02=%d | 03=%d | 04=%d | 05=%d | 06=%d', ...
        subj_id, ...
        plan.steps.prep_01_bids_formatting.run, ...
        plan.steps.prep_02_triggerfix.run, ...
        plan.steps.prep_03_until_ica.run, ...
        plan.steps.prep_04_ica.run, ...
        plan.steps.prep_05_after_ica.run, ...
        plan.steps.prep_06_epoching.run);
end
end

function plan = propagate_downstream_reruns_impl(plan, step_names)
triggered = false;

for s = 1:numel(step_names)
    step_name = step_names{s};
    info = plan.steps.(step_name);

    if info.run
        triggered = true;
        plan.steps.(step_name) = info;
        continue;
    end

    if triggered
        if isfield(info, 'policy') && ~isempty(info.policy)
            info.run = true;
            info.reason = "rerun forced because earlier enabled step will be regenerated";

            if isfield(info, 'folder_info') && isstruct(info.folder_info) && ...
                    isfield(info.folder_info, 'exists') && isfield(info.folder_info, 'is_empty')
                info.delete_before_run = info.folder_info.exists && ~info.folder_info.is_empty;
            else
                info.delete_before_run = false;
            end

            plan.steps.(step_name) = info;
        end
    end
end
end

function subject_plans = sort_subject_plans_by_expected_cost_impl(subject_plans)
if isempty(subject_plans)
    return;
end

weights = zeros(numel(subject_plans), 1);

for i = 1:numel(subject_plans)
    s = subject_plans(i).steps;
    weights(i) = ...
        100 * double(s.prep_04_ica.run) + ...
        20 * double(s.prep_03_until_ica.run) + ...
        10 * double(s.prep_01_bids_formatting.run) + ...
        10 * double(s.prep_05_after_ica.run) + ...
        5 * double(s.prep_06_epoching.run) + ...
        1 * double(s.prep_02_triggerfix.run);
end

[~, ix] = sort(weights, 'descend');
subject_plans = subject_plans(ix);
end

function out = run_one_subject_impl(subject_plan, cfg)
subj_id = subject_plan.subj_id;

out = struct('subj', subj_id, 'ok', false, 'message', '', 'logfile', '');

ensure_dir_impl(cfg.paths.logs_dir);

sub_log = fullfile( ...
    cfg.paths.logs_dir, ...
    sprintf('%s-%s_%s.log', ...
    cfg.constants.log_prefix_subject, ...
    subj_id, ...
    datestr(now, cfg.constants.datestr_subject)));

out.logfile = sub_log;

helpers = eeg_pipeline_helpers(sub_log);

try
    helpers.log_msg(sub_log, '--- START sub-%s ---', subj_id);
    t_subject = tic;

    is_thread_pool = isfield(cfg, 'parallel') && ...
        isfield(cfg.parallel, 'pool_is_thread') && ...
        cfg.parallel.pool_is_thread;

    if is_thread_pool
        helpers.log_msg(sub_log, ...
            'Thread pool -> skipping init_toolboxes + eeglab init inside worker.');
    else
        init_toolboxes_impl(cfg);

        if cfg.toolboxes.eeglab.nogui
            if cfg.env.mode == "hpc" && cfg.toolboxes.eeglab.no_update_check_on_hpc
                try
                    setpref('eeglab', 'plugin_update_check', 0);
                    setpref('eeglab', 'update_check', 0);
                    setpref('eeglab', 'version_check', 0);
                catch me_pref
                    helpers.log_msg(sub_log, ...
                        'WARNING: setpref failed (%s). Continuing.', ...
                        me_pref.message);
                end
            end
            eeglab('nogui');
        else
            eeglab;
        end

        helpers.log_msg(sub_log, 'EEGLAB initialized.');
    end

    paths = build_paths_impl(cfg, subj_id);

    helpers.log_msg(sub_log, ...
        'BIDS context: session=%s | task=%s | bids_ses_dir=%s', ...
        string(paths.session_label), ...
        string(paths.bids_task_label), ...
        string(paths.bids_ses_dir));

    % Step 01
    run_step_with_logging_impl( ...
        'prep_01_bids_formatting', ...
        'Step 01: BIDS formatting', ...
        subject_plan, cfg, paths, helpers, sub_log, subj_id);

    % Step 02
    run_step_with_logging_impl( ...
        'prep_02_triggerfix', ...
        'Step 02: triggerfix', ...
        subject_plan, cfg, paths, helpers, sub_log, subj_id);

    % Step 03
    run_step_with_logging_impl( ...
        'prep_03_until_ica', ...
        'Step 03: until ICA', ...
        subject_plan, cfg, paths, helpers, sub_log, subj_id);

    % Step 04
    run_step_with_logging_impl( ...
        'prep_04_ica', ...
        'Step 04: ICA', ...
        subject_plan, cfg, paths, helpers, sub_log, subj_id);

    % Step 05
    run_step_with_logging_impl( ...
        'prep_05_after_ica', ...
        'Step 05: IC rejection (ICLabel)', ...
        subject_plan, cfg, paths, helpers, sub_log, subj_id);

    % Step 06
    run_step_with_logging_impl( ...
        'prep_06_epoching', ...
        'Step 06: epoching + final rejection', ...
        subject_plan, cfg, paths, helpers, sub_log, subj_id);

    helpers.log_msg(sub_log, 'TOTAL subject runtime: %.2f min', toc(t_subject) / 60);
    helpers.log_msg(sub_log, '--- END sub-%s OK ---', subj_id);

    out.ok = true;

catch me
    out.ok = false;
    out.message = me.message;

    helpers.log_msg(sub_log, 'ERROR: %s', me.message);
    helpers.log_msg(sub_log, '%s', getReport(me, 'extended', 'hyperlinks', 'off'));

    try
        [parent_dir, base_name, ext] = fileparts(sub_log);
        err_log = fullfile(parent_dir, sprintf('%s_ERR%s', base_name, ext));
        if exist(sub_log, 'file')
            movefile(sub_log, err_log);
            out.logfile = err_log;
        end
    catch
    end
end
end

function run_step_with_logging_impl(step_name, step_label, subject_plan, cfg, paths, helpers, log_file, subj_id)
step_info = subject_plan.steps.(step_name);

if step_info.run
    maybe_clear_step_folder_impl(paths, step_name, subject_plan, helpers, cfg, log_file);

    helpers.log_msg(log_file, '%s', step_label);
    t_step = tic;

    step_out = feval(cfg.step_fns.(step_name), subj_id, cfg, paths, helpers);

    helpers.log_msg(log_file, '%s runtime: %.2f min', step_label, toc(t_step) / 60);

    if ~step_out.ok
        error('%s failed for sub-%s: %s', step_name, subj_id, step_out.message);
    end
else
    helpers.log_msg(log_file, ...
        '%s -> skipped by preplan (%s)', ...
        step_label, step_info.reason);
end
end

function maybe_clear_step_folder_impl(paths, step_name, subject_plan, helpers, cfg, log_file) %#ok<INUSD>
info = subject_plan.steps.(step_name);

if ~info.delete_before_run
    return;
end

step_folder = get_step_subject_folder_impl(paths, step_name);

helpers.log_msg(log_file, 'Clearing step folder before rerun: %s', step_folder);
clear_directory_contents_impl(step_folder);
end

% =========================================================================
% OVERWRITE / RERUN HELPERS
% =========================================================================
function overwrite_mode = resolve_overwrite_mode_impl(cfg, step_overwrite_mode)
overwrite_mode = string(cfg.io.overwrite_mode);

if nargin >= 2 && strlength(string(step_overwrite_mode)) > 0
    overwrite_mode = string(step_overwrite_mode);
end

if ~ismember(overwrite_mode, ["delete","skip","if_older_than"])
    overwrite_mode = "delete";
end
end

function policy = resolve_overwrite_policy_impl(cfg, step_cfg)
policy = struct();
policy.mode = string(cfg.io.overwrite_mode);
policy.cutoff_raw = "";
policy.cutoff_datenum = NaN;

if isfield(cfg, 'io') && isfield(cfg.io, 'overwrite_if_older_than')
    policy.cutoff_raw = string(cfg.io.overwrite_if_older_than);
end

if nargin >= 2 && isstruct(step_cfg)
    if isfield(step_cfg, 'overwrite_mode') && strlength(string(step_cfg.overwrite_mode)) > 0
        policy.mode = string(step_cfg.overwrite_mode);
    end
    if isfield(step_cfg, 'overwrite_if_older_than') && strlength(string(step_cfg.overwrite_if_older_than)) > 0
        policy.cutoff_raw = string(step_cfg.overwrite_if_older_than);
    end
end

if ~ismember(policy.mode, ["delete","skip","if_older_than"])
    policy.mode = "delete";
end

if policy.mode == "if_older_than"
    policy.cutoff_datenum = parse_cutoff_to_datenum_impl(policy.cutoff_raw);
    if isnan(policy.cutoff_datenum)
        error('overwrite_mode="if_older_than" requires a valid cutoff date. Got: %s', policy.cutoff_raw);
    end
end
end

function dn = parse_cutoff_to_datenum_impl(x)
dn = NaN;

if nargin < 1 || isempty(x)
    return;
end

if isnumeric(x) && isscalar(x) && isfinite(x)
    dn = x;
    return;
end

x = char(string(x));
x = strtrim(x);

if isempty(x)
    return;
end

time_formats = { ...
    'yyyy-mm-dd HH:MM:SS', ...
    'yyyy-mm-dd HH:MM', ...
    'yyyy-mm-dd', ...
    'dd.mm.yyyy HH:MM:SS', ...
    'dd.mm.yyyy HH:MM', ...
    'dd.mm.yyyy'};

for k = 1:numel(time_formats)
    try
        dn = datenum(x, time_formats{k});
        if ~isnan(dn)
            return;
        end
    catch
    end
end

try
    dn = datenum(datetime(x));
catch
end
end

function [do_run, reason, needs_regen] = step_should_run_outputs_impl(out_files, overwrite_mode, cfg)
needs_regen = false;

if nargin < 1 || isempty(out_files)
    out_files = {};
end

if ischar(out_files) || isstring(out_files)
    out_files = {out_files};
end

if ~iscell(out_files)
    out_files = {out_files};
end

exists_mask = false(size(out_files));

for k = 1:numel(out_files)
    f = out_files{k};
    if iscell(f)
        f = f{1};
    end
    f = char(string(f));
    exists_mask(k) = exist(f, 'file') == 2;
end

n_exist = sum(exists_mask);

if n_exist == 0
    do_run = true;
    reason = "no outputs present";
    return;
end

if n_exist == numel(out_files)
    if overwrite_mode == "skip" || overwrite_mode == "if_older_than"
        do_run = false;
        reason = "all outputs exist -> skip";
        return;
    else
        do_run = true;
        reason = "all outputs exist -> delete + regenerate";
        return;
    end
end

needs_regen = true;
do_run = true;
reason = sprintf('partial outputs exist (%d/%d) -> regenerate', n_exist, numel(out_files));
end

function [do_run, reason, info] = step_should_run_from_folder_impl(step_folder, policy)
info = struct();
info.exists  = false;
info.datenum = NaN;
info.is_empty = true;

step_folder = char(string(step_folder));

if exist(step_folder, 'dir') ~= 7
    do_run = true;
    reason = "output folder missing -> run";
    return;
end

info.exists = true;

dir_info = dir(step_folder);
real_mask = ~ismember({dir_info.name}, {'.','..'});
real_info = dir_info(real_mask);

info.is_empty = isempty(real_info);

folder_info = dir(step_folder);
if ~isempty(folder_info)
    info.datenum = folder_info.datenum;
end

if info.is_empty
    do_run = true;
    reason = "output folder exists but is empty -> run";
    return;
end

switch policy.mode
    case "skip"
        do_run = false;
        reason = "output folder exists and non-empty -> skip";

    case "delete"
        do_run = true;
        reason = "output folder exists and non-empty -> delete + regenerate";

    case "if_older_than"
        if isnan(info.datenum)
            do_run = true;
            reason = "folder date unavailable -> regenerate";
        elseif info.datenum < policy.cutoff_datenum
            do_run = true;
            reason = "output folder older than cutoff -> delete + regenerate";
        else
            do_run = false;
            reason = "output folder newer than cutoff -> skip";
        end

    otherwise
        do_run = true;
        reason = "unknown policy -> regenerate";
end
end

function step_folder = get_step_subject_folder_impl(paths, step_name)
switch step_name
    case 'prep_01_bids_formatting'
        step_folder = paths.prep_01_out_dir;

    case 'prep_02_triggerfix'
        step_folder = paths.prep_02_out_dir;

    case 'prep_03_until_ica'
        step_folder = paths.prep_03_out_dir_until_ica;

    case 'prep_04_ica'
        step_folder = paths.prep_04_out_dir;

    case 'prep_05_after_ica'
        step_folder = paths.prep_05_out_dir;

    case 'prep_06_epoching'
        step_folder = paths.prep_06_out_dir;

    otherwise
        error('Unknown step name: %s', step_name);
end
end

% =========================================================================
% SAVE / LOAD / BIDS HELPERS
% =========================================================================
function safe_delete_set_impl(set_file)
if nargin < 1 || isempty(set_file)
    return;
end

if iscell(set_file)
    if isempty(set_file)
        return;
    end
    set_file = set_file{1};
end

set_file = char(string(set_file));
if isempty(set_file)
    return;
end

[parent_dir, base_name, ~] = fileparts(set_file);

for ext = {'.set', '.fdt'}
    f = fullfile(parent_dir, [base_name ext{1}]);
    if exist(f, 'file') == 2
        delete(f);
    end
end
end

function EEG = safe_save_set_impl(EEG, out_dir, out_fname, helpers, cfg) %#ok<INUSD>
out_dir   = force_char_scalar_impl(out_dir);
out_fname = force_char_scalar_impl(out_fname);

ensure_dir_impl(out_dir);

EEG.filename = force_char_scalar_impl(getfield_safe_impl(EEG, 'filename', ''));
EEG.filepath = force_char_scalar_impl(getfield_safe_impl(EEG, 'filepath', ''));

if contains(EEG.filename, filesep) || contains(EEG.filename, '/')
    EEG.filename = '';
end

EEG = pop_saveset(EEG, 'filename', out_fname, 'filepath', out_dir);

if nargin >= 4 && isstruct(helpers) && isfield(helpers, 'log_msg_default')
    helpers.log_msg_default('Saved set: %s', fullfile(out_dir, out_fname));
end
end

function EEG = safe_load_set_impl(in_dir, in_fname, helpers)
in_dir   = force_char_scalar_impl(in_dir);
in_fname = force_char_scalar_impl(in_fname);

if exist(in_dir, 'dir') ~= 7
    error('safe_load_set: input directory not found: %s', in_dir);
end

full_path = fullfile(in_dir, in_fname);
if exist(full_path, 'file') ~= 2
    error('safe_load_set: file not found: %s', full_path);
end

EEG = pop_loadset('filename', in_fname, 'filepath', in_dir);
EEG = eeg_checkset(EEG);

if nargin >= 3 && isstruct(helpers) && isfield(helpers, 'log_msg_default')
    helpers.log_msg_default('Loaded set: %s', full_path);
end
end

function [vhdr_dir, vhdr_name] = find_bids_vhdr_impl(paths, subj_id, helpers)
vhdr_dir  = '';
vhdr_name = '';

candidate_dirs = {};

if isfield(paths, 'bids_ses_dir') && strlength(string(paths.bids_ses_dir)) > 0
    candidate_dirs{end+1} = fullfile(char(string(paths.bids_ses_dir)), 'eeg'); %#ok<AGROW>
end

if isfield(paths, 'bids_sub_dir') && strlength(string(paths.bids_sub_dir)) > 0
    if isfield(paths, 'session_label') && strlength(string(paths.session_label)) > 0
        candidate_dirs{end+1} = fullfile( ...
            char(string(paths.bids_sub_dir)), ...
            ['ses-' char(string(paths.session_label))], ...
            'eeg'); %#ok<AGROW>
    end
    candidate_dirs{end+1} = fullfile(char(string(paths.bids_sub_dir)), 'eeg'); %#ok<AGROW>
end

candidate_dirs = unique(candidate_dirs, 'stable');

task_label = "";
if isfield(paths, 'bids_task_label') && strlength(string(paths.bids_task_label)) > 0
    task_label = string(paths.bids_task_label);
end

best = [];
best_dir = '';

for d = 1:numel(candidate_dirs)
    eeg_dir = candidate_dirs{d};

    if exist(eeg_dir, 'dir') ~= 7
        continue;
    end

    candidates = [];
    if strlength(task_label) > 0
        pattern = sprintf('*task-%s*_eeg.vhdr', char(task_label));
        candidates = dir(fullfile(eeg_dir, pattern));
    end

    if isempty(candidates)
        candidates = dir(fullfile(eeg_dir, '*.vhdr'));
    end

    if isempty(candidates)
        continue;
    end

    [~, ix] = max([candidates.datenum]);
    best = candidates(ix);
    best_dir = eeg_dir;
    break;
end

if isempty(best)
    if nargin >= 3 && isfield(helpers, 'log_msg_default')
        helpers.log_msg_default( ...
            'prep_03_until_ica: BIDS fallback: no *.vhdr found for sub-%s (checked: %s)', ...
            subj_id, strjoin(string(candidate_dirs), ' | '));
    end
    return;
end

vhdr_dir  = best_dir;
vhdr_name = best.name;

if nargin >= 3 && isfield(helpers, 'log_msg_default')
    helpers.log_msg_default('prep_03_until_ica: BIDS fallback: using vhdr=%s', ...
        fullfile(vhdr_dir, vhdr_name));
end
end

function EEG = safe_load_bv_impl(vhdr_dir, vhdr_name, helpers)
vhdr_dir  = force_char_scalar_impl(vhdr_dir);
vhdr_name = force_char_scalar_impl(vhdr_name);

if exist(vhdr_dir, 'dir') ~= 7
    error('safe_load_bv: directory not found: %s', vhdr_dir);
end

full_path = fullfile(vhdr_dir, vhdr_name);
if exist(full_path, 'file') ~= 2
    error('safe_load_bv: file not found: %s', full_path);
end

if exist('pop_loadbv', 'file') ~= 2
    error('safe_load_bv: pop_loadbv not found (EEGLAB BrainVision loader missing).');
end

EEG = pop_loadbv(vhdr_dir, vhdr_name);
EEG = eeg_checkset(EEG);

if nargin >= 3 && isstruct(helpers) && isfield(helpers, 'log_msg_default')
    helpers.log_msg_default('Loaded BrainVision: %s', full_path);
end
end

function out = force_char_scalar_impl(x)
if isstring(x)
    x = x(:);
    if isempty(x)
        out = '';
    else
        out = char(x(1));
    end
    return;
end

if iscell(x)
    if isempty(x)
        out = '';
    else
        out = force_char_scalar_impl(x{1});
    end
    return;
end

if ischar(x)
    if isempty(x)
        out = '';
    else
        out = x(1, :);
    end
    return;
end

if isempty(x)
    out = '';
    return;
end

out = char(string(x(1)));
end

function value = getfield_safe_impl(S, field_name, default_value)
if isstruct(S) && isfield(S, field_name)
    value = S.(field_name);
else
    value = default_value;
end
end

% =========================================================================
% EEG COMMENT / TRIGGER
% =========================================================================
function EEG = append_eeg_comment_impl(EEG, line_text)
try
    if ~isfield(EEG, 'comments') || isempty(EEG.comments)
        EEG.comments = line_text;
    else
        EEG.comments = sprintf('%s\n%s', EEG.comments, line_text);
    end
catch
end
end

function token = normalize_trigger_type_impl(t)
if isnumeric(t)
    token = strtrim(num2str(t));
    return;
end

token = char(string(t));
token = strtrim(token);
token = regexprep(token, '\s+', ' ');

match_1 = regexp(token, '^S(\d+)$', 'tokens', 'once');
if ~isempty(match_1)
    token = ['S ' match_1{1}];
    return;
end

match_2 = regexp(token, '^S\s+(\d+)$', 'tokens', 'once');
if ~isempty(match_2)
    token = ['S ' match_2{1}];
    return;
end
end

function token = get_raw_trigger_from_key_impl(raw_triggers, key_name)
key_name = force_char_scalar_impl(key_name);

if isempty(key_name)
    token = '';
    return;
end

if isstruct(raw_triggers) && isfield(raw_triggers, key_name)
    token = normalize_trigger_type_impl(raw_triggers.(key_name));
else
    token = normalize_trigger_type_impl(key_name);
end
end

function new_type = map_trigger_by_table_impl(current_type, map_table, raw_triggers)
new_type = '';

if isempty(map_table)
    return;
end

current_type = normalize_trigger_type_impl(current_type);

for r = 1:size(map_table, 1)
    raw_key   = map_table{r,1};
    target_id = map_table{r,2};

    raw_token = get_raw_trigger_from_key_impl(raw_triggers, raw_key);

    if strcmp(current_type, raw_token)
        new_type = normalize_trigger_type_impl(target_id);
        return;
    end
end
end

% =========================================================================
% EEG UTILITIES
% =========================================================================
function EEG = normalize_event_types_impl(EEG)
if isfield(EEG, 'event') && ~isempty(EEG.event)
    try
        tmp = cellfun(@char, {EEG.event.type}, 'UniformOutput', false);
        [EEG.event.type] = tmp{:};
    catch
    end
end
end

function mode = normalize_epoching_mode_value_impl(mode_in)
mode = lower(strtrim(char(string(mode_in))));
mode = regexprep(mode, '\s+', ' ');
end

function [idx_eeg, idx_eog, idx_non_eeg] = get_channel_indices_by_type_impl(EEG)
idx_eeg = [];
idx_eog = [];
idx_non_eeg = [];

if ~isfield(EEG, 'chanlocs') || isempty(EEG.chanlocs) || ~isfield(EEG.chanlocs, 'type')
    idx_eeg = (1:EEG.nbchan)';
    return;
end

types = lower(string({EEG.chanlocs.type}));
idx_eeg = find(types == "eeg");
idx_eog = find(types == "eog");
idx_non_eeg = find(~(types == "eeg" | types == "eog"));

idx_eeg = idx_eeg(:);
idx_eog = idx_eog(:);
idx_non_eeg = idx_non_eeg(:);
end

function EEG_out = apply_reference_mode_impl(EEG_in, step_cfg, helpers)
EEG_out = EEG_in;

[idx_eeg, ~, ~] = get_channel_indices_by_type_impl(EEG_out);
reference_mode = lower(string(step_cfg.reference_mode));

switch reference_mode
    case {"keep","none"}
        EEG_out = helpers.append_eeg_comment(EEG_out, ...
            'prep_06_epoching: reference kept unchanged');

    case "avg"
        if isempty(idx_eeg)
            EEG_out = helpers.append_eeg_comment(EEG_out, ...
                'prep_06_epoching: WARNING no EEG channels found -> average reference skipped');
            return;
        end

        if isfield(step_cfg, 'reference_exclude_non_eeg') && step_cfg.reference_exclude_non_eeg
            exclude_idx = setdiff(1:EEG_out.nbchan, idx_eeg);
            EEG_out = pop_reref(EEG_out, [], 'exclude', exclude_idx);
        else
            EEG_out = pop_reref(EEG_out, []);
        end

        EEG_out = eeg_checkset(EEG_out);
        EEG_out = helpers.append_eeg_comment(EEG_out, ...
            'prep_06_epoching: average reference applied');

    case "mastoid"
        if ~isfield(step_cfg, 'mastoid_channel_labels') || numel(step_cfg.mastoid_channel_labels) < 2
            error('cfg.prep_06.mastoid_channel_labels must contain two labels for reference_mode="mastoid".');
        end

        mastoid_labels = cellstr(string(step_cfg.mastoid_channel_labels));
        mastoid_idx = zeros(1, numel(mastoid_labels));

        for k = 1:numel(mastoid_labels)
            this_idx = find(strcmpi({EEG_out.chanlocs.labels}, mastoid_labels{k}), 1, 'first');
            if isempty(this_idx)
                error('Mastoid reference channel not found: %s', mastoid_labels{k});
            end
            mastoid_idx(k) = this_idx;
        end

        if isfield(step_cfg, 'reference_exclude_non_eeg') && step_cfg.reference_exclude_non_eeg && ~isempty(idx_eeg)
            exclude_idx = setdiff(1:EEG_out.nbchan, idx_eeg);
            EEG_out = pop_reref(EEG_out, mastoid_idx, 'exclude', exclude_idx);
        else
            EEG_out = pop_reref(EEG_out, mastoid_idx);
        end

        EEG_out = eeg_checkset(EEG_out);
        EEG_out = helpers.append_eeg_comment(EEG_out, sprintf( ...
            'prep_06_epoching: mastoid reference applied using %s', ...
            strjoin(string(step_cfg.mastoid_channel_labels), ', ')));

    otherwise
        error('Unsupported cfg.prep_06.reference_mode: %s', char(string(step_cfg.reference_mode)));
end
end

function output_spec = build_epoching_output_paths_impl(run_base, out_dir, step_cfg, idx_eeg, idx_eog, idx_non_eeg)
output_spec = struct();
output_spec.all_paths = {};

mode_raw = step_cfg.epoching_mode;
mode = normalize_epoching_mode_value_impl(mode_raw);

if strcmp(mode, 'event_locked')
    base_stem = string(run_base) + "_epoched_final";
    output_spec.all_paths = build_output_paths_for_base_stem_epoching_impl( ...
        base_stem, out_dir, step_cfg, idx_eeg, idx_eog, idx_non_eeg);

elseif strcmp(mode, 'baseline')
    base_stem_open   = string(run_base) + "_cond-open_epoched_final";
    base_stem_closed = string(run_base) + "_cond-closed_epoched_final";

    paths_open = build_output_paths_for_base_stem_epoching_impl( ...
        base_stem_open, out_dir, step_cfg, idx_eeg, idx_eog, idx_non_eeg);

    paths_closed = build_output_paths_for_base_stem_epoching_impl( ...
        base_stem_closed, out_dir, step_cfg, idx_eeg, idx_eog, idx_non_eeg);

    output_spec.all_paths = [paths_open(:); paths_closed(:)];

else
    error('Unsupported cfg.prep_06.epoching_mode: raw=>>%s<< | normalized=>>%s<<', ...
        char(string(mode_raw)), mode);
end
end

function out_path = save_intermediate_set_impl(EEG, out_dir, base_stem, overwrite_mode, cfg, savemode, helpers) %#ok<INUSD>
if nargin < 6 || isempty(savemode)
    savemode = 'twofiles';
end

out_name = char(string(base_stem) + ".set");
out_path = fullfile(out_dir, out_name);

if exist(out_path, 'file') == 2 && overwrite_mode == "skip"
    return;
end

if overwrite_mode == "delete" && exist(out_path, 'file') == 2
    safe_delete_set_impl(out_path);
end

EEG = pop_saveset(EEG, ...
    'filename', out_name, ...
    'filepath', out_dir, ...
    'savemode', savemode);

if nargin >= 7 && isstruct(helpers) && isfield(helpers, 'log_msg_default')
    helpers.log_msg_default('Saved intermediate set: %s', out_path);
end
end

function [EEG_out, info] = apply_hard_epoch_threshold_rejection_impl(EEG_in, idx_eeg, thresh_uv)
EEG_out = EEG_in;

info = struct();
info.n_total    = EEG_in.trials;
info.n_rejected = 0;
info.n_kept     = EEG_in.trials;
info.thresh_uv  = thresh_uv;

if isempty(idx_eeg) || EEG_in.trials < 1
    return;
end

if isempty(thresh_uv) || ~isscalar(thresh_uv) || ~isfinite(thresh_uv) || thresh_uv <= 0
    return;
end

data = EEG_in.data(idx_eeg, :, :);
bad = squeeze(any(any(abs(data) > thresh_uv, 1), 2));
bad = bad(:);

bad_epochs = find(bad);

if isempty(bad_epochs)
    return;
end

EEG_out = pop_rejepoch(EEG_in, bad_epochs, 0);
EEG_out = eeg_checkset(EEG_out);

info.n_rejected = numel(bad_epochs);
info.n_kept     = EEG_out.trials;
end

function [EEG_out, info] = apply_fallback_epoch_rejection_impl(EEG_in, idx_eeg, step_cfg)
EEG_out = EEG_in;

info = struct();
info.n_total    = EEG_in.trials;
info.n_rejected = 0;
info.n_kept     = EEG_in.trials;
info.robust_z   = isfield(step_cfg, 'faster_use_robust_z') && step_cfg.faster_use_robust_z;

if EEG_in.trials < 1 || isempty(idx_eeg)
    return;
end

bad_faster = false(EEG_in.trials, 1);
bad_ptp    = false(EEG_in.trials, 1);

if isfield(step_cfg, 'use_faster') && step_cfg.use_faster && exist('epoch_properties', 'file') == 2
    props = epoch_properties(EEG_in, idx_eeg);

    if ~isempty(props) && size(props, 1) ~= EEG_in.trials && size(props, 2) == EEG_in.trials
        props = props.';
    end

    if ~isempty(props) && size(props, 1) == EEG_in.trials
        if info.robust_z
            med = median(props, 1, 'omitnan');
            madv = median(abs(props - med), 1, 'omitnan');
            denom = 1.4826 .* madv;
            denom(denom == 0 | isnan(denom)) = Inf;
            zmat = (props - med) ./ denom;
        else
            mu = mean(props, 1, 'omitnan');
            sd = std(props, 0, 1, 'omitnan');
            sd(sd == 0 | isnan(sd)) = Inf;
            zmat = (props - mu) ./ sd;
        end

        bad_faster = any(abs(zmat) > step_cfg.faster_z_thresh, 2);
    end
end

if isfield(step_cfg, 'use_ptp') && step_cfg.use_ptp
    data = double(EEG_in.data(idx_eeg, :, :));
    ptp  = squeeze(max(data, [], 2) - min(data, [], 2));
    bad_ptp = any(ptp > step_cfg.ptp_uV_thresh, 1)';
end

bad = bad_faster | bad_ptp;
bad_epochs = find(bad);

if isempty(bad_epochs)
    return;
end

EEG_out = pop_rejepoch(EEG_in, bad_epochs, 0);
EEG_out = eeg_checkset(EEG_out);

info.n_rejected = numel(bad_epochs);
info.n_kept     = EEG_out.trials;
end

function [EEG_open, EEG_closed] = create_baseline_condition_datasets_impl(EEG, step_cfg, helpers, run_base)
EEG_open   = [];
EEG_closed = [];

if ~isfield(EEG, 'event') || isempty(EEG.event)
    error('No EEG.event present -> cannot segment baseline open/closed.');
end

if ~isfield(EEG, 'srate') || isempty(EEG.srate)
    error('EEG.srate missing -> cannot segment baseline open/closed.');
end

event_times = [];
event_codes = strings(0,1);

for k = 1:numel(EEG.event)
    code = normalize_trigger_type_impl(EEG.event(k).type);

    if strcmpi(code, 'boundary')
        continue;
    end

    if matches_any_prefix_impl(code, step_cfg.baseline_open_marker_prefixes) || ...
       matches_any_prefix_impl(code, step_cfg.baseline_closed_marker_prefixes) || ...
       matches_any_exact_impl(code, step_cfg.baseline_end_markers)

        event_codes(end+1,1) = string(code); %#ok<AGROW>
        event_times(end+1,1) = double(EEG.event(k).latency) / double(EEG.srate); %#ok<AGROW>
    end
end

if isempty(event_times)
    error('No open/closed segmentation markers found in baseline recording.');
end

[event_times, sort_ix] = sort(event_times);
event_codes = event_codes(sort_ix);

recording_end_s = double(EEG.pnts) / double(EEG.srate);
sample_eps = 1.0 / double(EEG.srate);

current_condition = string(step_cfg.baseline_start_condition);
current_t1 = 0;

seg_condition = strings(0,1);
seg_t1 = [];
seg_t2 = [];

for i = 1:numel(event_codes)
    code = event_codes(i);
    t_ev = event_times(i);

    if t_ev <= current_t1 + sample_eps
        continue;
    end

    next_condition = current_condition;

    if matches_any_exact_impl(code, step_cfg.baseline_end_markers)
        next_condition = "open";
    elseif matches_any_prefix_impl(code, step_cfg.baseline_open_marker_prefixes)
        next_condition = "open";
    elseif matches_any_prefix_impl(code, step_cfg.baseline_closed_marker_prefixes)
        next_condition = "closed";
    end

    if next_condition ~= current_condition
        seg_condition(end+1,1) = current_condition; %#ok<AGROW>
        seg_t1(end+1,1) = current_t1; %#ok<AGROW>
        seg_t2(end+1,1) = t_ev; %#ok<AGROW>

        current_condition = next_condition;
        current_t1 = t_ev;
    end
end

if current_t1 < recording_end_s - sample_eps
    seg_condition(end+1,1) = current_condition; %#ok<AGROW>
    seg_t1(end+1,1) = current_t1; %#ok<AGROW>
    seg_t2(end+1,1) = recording_end_s; %#ok<AGROW>
end

if isempty(seg_t1)
    error('Could not derive any baseline segments.');
end

helpers.log_msg_default( ...
    'prep_06_epoching: %s | derived %d baseline segments', ...
    char(string(run_base)), numel(seg_t1));

open_parts = {};
closed_parts = {};

epoch_len = double(step_cfg.regepoch_length_sec);
epoch_step = double(step_cfg.regepoch_step_sec);
if epoch_step <= 0
    epoch_step = epoch_len;
end

for s = 1:numel(seg_t1)
    t1 = seg_t1(s);
    t2 = seg_t2(s);

    if (t2 - t1) < epoch_len
        continue;
    end

    EEG_seg = pop_select(EEG, 'time', [t1, t2 - sample_eps]);
    EEG_seg = eeg_checkset(EEG_seg);

    EEG_ep = eeg_regepochs( ...
        EEG_seg, ...
        'recurrence', epoch_step, ...
        'limits', [0 epoch_len], ...
        'eventtype', 'regepoch');

    EEG_ep = eeg_checkset(EEG_ep);
    EEG_ep.etc.baseline_condition = char(seg_condition(s));

    EEG_ep = append_eeg_comment_impl(EEG_ep, sprintf( ...
        'prep_06_epoching: baseline_condition=%s | chunk=[%.3f %.3f] s | regepoch_length=%.1f s | regepoch_step=%.1f s', ...
        seg_condition(s), t1, t2, epoch_len, epoch_step));

    if seg_condition(s) == "open"
        open_parts{end+1} = EEG_ep; %#ok<AGROW>
    else
        closed_parts{end+1} = EEG_ep; %#ok<AGROW>
    end
end

EEG_open   = merge_eeg_sets_impl(open_parts);
EEG_closed = merge_eeg_sets_impl(closed_parts);
end

function [EEG_final, rej_info] = finalize_epoched_dataset_impl( ...
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
    save_intermediate_set_impl( ...
        EEG_ep, out_dir, string(base_stem) + "_stage-epoched", ...
        "delete", cfg, step_cfg.savemode, helpers);
end

[idx_eeg, ~, ~] = get_channel_indices_by_type_impl(EEG_ep);
EEG_work = EEG_ep;

if step_cfg.do_artifact_rejection

    if isempty(idx_eeg) || EEG_work.trials < 1
        EEG_work = helpers.append_eeg_comment(EEG_work, ...
            'prep_06_epoching: artifact rejection skipped (no EEG channels or no epochs)');
    else
        if step_cfg.do_initial_hard_threshold_rejection
            [EEG_work, hard_info] = apply_hard_epoch_threshold_rejection_impl( ...
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
                save_intermediate_set_impl( ...
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
                [EEG_work, shared_info] = apply_shared_epoch_rejection_impl( ...
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
                [EEG_work, soft_info] = apply_fallback_epoch_rejection_impl( ...
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
                save_intermediate_set_impl( ...
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
    (step_cfg.max_reject_prop >= 0);

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
        save_intermediate_set_impl( ...
            EEG_final, out_dir, string(base_stem) + "_stage-baselinecorrected", ...
            "delete", cfg, step_cfg.savemode, helpers);
    end
else
    EEG_final = helpers.append_eeg_comment(EEG_final, ...
        'prep_06_epoching: baseline correction skipped');
end
end

function saved_paths = save_final_epoched_outputs_impl(EEG_final, base_stem, out_dir, step_cfg, cfg, helpers)
saved_paths = {};

[idx_eeg, idx_eog, idx_non_eeg] = get_channel_indices_by_type_impl(EEG_final);

if step_cfg.split_non_eeg_channels
    [primary_idx, secondary_idx] = split_final_channel_indices_epoching_impl( ...
        idx_eeg, idx_eog, idx_non_eeg, step_cfg);

    if isempty(primary_idx)
        error('No primary channels available for final EEG output.');
    end

    EEG_primary = pop_select(EEG_final, 'channel', primary_idx);
    EEG_primary = eeg_checkset(EEG_primary);
    EEG_primary.setname = char(string(base_stem) + "_EEG");

    primary_name = char(string(base_stem) + "_EEG.set");
    primary_path = fullfile(out_dir, primary_name);

    EEG_primary = helpers.safe_save_set(EEG_primary, out_dir, primary_name, helpers, cfg);
    helpers.log_msg_default('prep_06_epoching: saved: %s', primary_path);

    saved_paths{end+1,1} = primary_path; %#ok<AGROW>

    if ~isempty(secondary_idx)
        EEG_secondary = pop_select(EEG_final, 'channel', secondary_idx);
        EEG_secondary = eeg_checkset(EEG_secondary);
        EEG_secondary.setname = char(string(base_stem) + "_NON_EEG");

        secondary_name = char(string(base_stem) + "_NON_EEG.set");
        secondary_path = fullfile(out_dir, secondary_name);

        EEG_secondary = helpers.safe_save_set(EEG_secondary, out_dir, secondary_name, helpers, cfg);
        helpers.log_msg_default('prep_06_epoching: saved: %s', secondary_path);

        saved_paths{end+1,1} = secondary_path; %#ok<AGROW>
    end
else
    EEG_full = EEG_final;
    EEG_full.setname = char(string(base_stem));

    out_name = char(string(base_stem) + ".set");
    out_path = fullfile(out_dir, out_name);

    EEG_full = helpers.safe_save_set(EEG_full, out_dir, out_name, helpers, cfg);
    helpers.log_msg_default('prep_06_epoching: saved: %s', out_path);

    saved_paths{end+1,1} = out_path; %#ok<AGROW>
end
end

function paths_out = build_output_paths_for_base_stem_epoching_impl(base_stem, out_dir, step_cfg, idx_eeg, idx_eog, idx_non_eeg)
paths_out = {};

if step_cfg.split_non_eeg_channels
    paths_out{end+1,1} = fullfile(out_dir, char(string(base_stem) + "_EEG.set")); %#ok<AGROW>

    [~, secondary_idx] = split_final_channel_indices_epoching_impl( ...
        idx_eeg, idx_eog, idx_non_eeg, step_cfg);

    if ~isempty(secondary_idx)
        paths_out{end+1,1} = fullfile(out_dir, char(string(base_stem) + "_NON_EEG.set")); %#ok<AGROW>
    end
else
    paths_out{end+1,1} = fullfile(out_dir, char(string(base_stem) + ".set")); %#ok<AGROW>
end
end

function [primary_idx, secondary_idx] = split_final_channel_indices_epoching_impl(idx_eeg, idx_eog, idx_non_eeg, step_cfg)
if isfield(step_cfg, 'eeg_only_keep_eog') && step_cfg.eeg_only_keep_eog
    primary_idx = unique([idx_eeg(:); idx_eog(:)]);
    secondary_idx = idx_non_eeg(:);
else
    primary_idx = idx_eeg(:);
    secondary_idx = unique([idx_eog(:); idx_non_eeg(:)]);
end
end

function tf = matches_any_prefix_impl(code, prefix_list)
tf = false;

if ischar(prefix_list) || isstring(prefix_list)
    prefix_list = cellstr(string(prefix_list));
end

for k = 1:numel(prefix_list)
    if startsWith(string(code), string(prefix_list{k}))
        tf = true;
        return;
    end
end
end

function tf = matches_any_exact_impl(code, exact_list)
tf = false;

if ischar(exact_list) || isstring(exact_list)
    exact_list = cellstr(string(exact_list));
end

for k = 1:numel(exact_list)
    if string(code) == string(exact_list{k})
        tf = true;
        return;
    end
end
end

function EEG_merged = merge_eeg_sets_impl(parts)
EEG_merged = [];

if isempty(parts)
    return;
end

EEG_merged = parts{1};
for k = 2:numel(parts)
    EEG_merged = pop_mergeset(EEG_merged, parts{k}, 0);
    EEG_merged = eeg_checkset(EEG_merged);
end
end

function [tokens, times_s] = build_eeg_key_token_stream_with_time_impl(EEG)
if ~isfield(EEG,'event') || isempty(EEG.event)
    tokens  = strings(0,1);
    times_s = zeros(0,1);
    return;
end
if ~isfield(EEG,'srate') || isempty(EEG.srate)
    error('EEG.srate missing/empty');
end

n = numel(EEG.event);
tokens  = strings(0,1);
times_s = zeros(0,1);

for k = 1:n
    t = normalize_trigger_type_impl(EEG.event(k).type);
    if strcmpi(t, 'boundary'); continue; end
    tokens(end+1,1)  = string(t);
    times_s(end+1,1) = double(EEG.event(k).latency) / double(EEG.srate);
end
end

function latency = find_first_event_latency_impl(EEG, event_type)
latency = [];

if ~isfield(EEG, 'event') || isempty(EEG.event)
    return;
end

target = normalize_trigger_type_impl(event_type);

for k = 1:numel(EEG.event)
    current_type = normalize_trigger_type_impl(EEG.event(k).type);
    if strcmp(current_type, target)
        latency = EEG.event(k).latency;
        return;
    end
end
end

function EEG = ensure_channel_types_impl(EEG, step_cfg)
if ~isfield(EEG, 'chanlocs') || isempty(EEG.chanlocs)
    return;
end

labels = {EEG.chanlocs.labels};

for k = 1:numel(EEG.chanlocs)
    EEG.chanlocs(k).type = 'EEG';
end

set_type_by_labels_local(step_cfg.eog_channel_labels,     'EOG');
set_type_by_labels_local(step_cfg.scr_channel_labels,     'SCR');
set_type_by_labels_local(step_cfg.startle_channel_labels, 'Startle');
set_type_by_labels_local(step_cfg.ekg_channel_labels,     'EKG');

EEG = eeg_checkset(EEG);

    function set_type_by_labels_local(label_list, type_name)
        for i = 1:numel(label_list)
            idx = find(strcmpi(labels, label_list{i}));
            for j = 1:numel(idx)
                EEG.chanlocs(idx(j)).type = type_name;
            end
        end
    end
end

function [flat_indices, flat_labels] = find_flat_or_invalid_channels_impl(EEG, candidate_indices, variance_epsilon)
flat_indices = [];
flat_labels  = {};

if isempty(candidate_indices)
    return;
end

data_2d = double(EEG.data(candidate_indices, :));

has_invalid = any(~isfinite(data_2d), 2);
chan_var    = var(data_2d, 0, 2);

is_flat = (chan_var <= variance_epsilon) | has_invalid;

flat_indices = candidate_indices(is_flat);

if ~isempty(flat_indices)
    flat_labels = {EEG.chanlocs(flat_indices).labels};
end
end

function [bad_indices, bad_labels] = detect_bad_channels_emulation_style_impl(EEG, eeg_indices, flatline_sec, corr_threshold)
bad_indices = [];
bad_labels  = {};

if isempty(eeg_indices)
    return;
end

if exist('clean_rawdata', 'file') ~= 2
    return;
end

EEG_tmp = EEG;
EEG_tmp = pop_select(EEG_tmp, 'channel', eeg_indices);
EEG_tmp = eeg_checkset(EEG_tmp);

labels_before = {EEG_tmp.chanlocs.labels};

EEG_clean = clean_rawdata(EEG_tmp, flatline_sec, -1, corr_threshold, -1, -1, -1);
EEG_clean = eeg_checkset(EEG_clean);

labels_after = {EEG_clean.chanlocs.labels};
removed_labels = setdiff(labels_before, labels_after, 'stable');

if isempty(removed_labels)
    return;
end

all_labels = {EEG.chanlocs.labels};

for i = 1:numel(removed_labels)
    idx = find(strcmpi(all_labels, removed_labels{i}), 1, 'first');
    if ~isempty(idx)
        bad_indices(end+1) = idx; %#ok<AGROW>
    end
end

bad_indices = unique(bad_indices);
bad_labels  = {EEG.chanlocs(bad_indices).labels};
end

function EEG = apply_filter_to_subset_only_impl(EEG, subset_indices, locutoff_hz, hicutoff_hz, label_for_log)
if isempty(subset_indices)
    return;
end

original_data = EEG.data;

EEG = pop_eegfiltnew(EEG, 'locutoff', locutoff_hz, 'hicutoff', hicutoff_hz, 'usefftfilt', 1);
EEG = eeg_checkset(EEG);

non_subset = setdiff(1:EEG.nbchan, subset_indices);
EEG.data(non_subset, :) = original_data(non_subset, :);

EEG = eeg_checkset(EEG);

if nargin >= 5 && ~isempty(label_for_log)
    EEG = append_eeg_comment_impl(EEG, ...
        sprintf('%s: applied only to channels %s', label_for_log, mat2str(subset_indices)));
end
end

function [EEG, did_apply] = apply_pop_cleanline_to_subset_impl(EEG, subset_indices, step_cfg)
did_apply = false;

if isempty(subset_indices)
    return;
end

if exist('pop_cleanline', 'file') ~= 2
    return;
end

original_data = EEG.data;

try
    EEG_tmp = EEG;
    EEG_tmp.data = EEG.data(subset_indices, :);

    fs = EEG_tmp.srate;
    freqs = step_cfg.line_noise_frequencies_hz;
    freqs = freqs(freqs < fs / 2);

    if isempty(freqs)
        did_apply = true;
        return;
    end

    % Backward-compatible fallbacks in case older configs are used
     bandwidth_hz      = getfield_safe_impl(step_cfg, 'pop_cleanline_bandwidth_hz', 2);
    p_value           = getfield_safe_impl(step_cfg, 'pop_cleanline_p_value', 0.01);
    scanforlines      = getfield_safe_impl(step_cfg, 'pop_cleanline_scanforlines', false);
    winsize_sec       = getfield_safe_impl(step_cfg, 'pop_cleanline_winsize_sec', 4);
    winstep_sec       = getfield_safe_impl(step_cfg, 'pop_cleanline_winstep_sec', 1);
    tau_val           = getfield_safe_impl(step_cfg, 'pop_cleanline_tau', 100);
    pad_val           = getfield_safe_impl(step_cfg, 'pop_cleanline_pad', 2);
    taperbandwidth_hz = getfield_safe_impl(step_cfg, 'pop_cleanline_taperbandwidth_hz', 2);
    norm_spectrum     = getfield_safe_impl(step_cfg, 'pop_cleanline_norm_spectrum', 0);
    compute_power     = getfield_safe_impl(step_cfg, 'pop_cleanline_computepower', 0);
    verbose_flag      = getfield_safe_impl(step_cfg, 'pop_cleanline_verbose', false);

    EEG_tmp = pop_cleanline(EEG_tmp, ...
        'bandwidth',        bandwidth_hz, ...
        'chanlist',         1:size(EEG_tmp.data, 1), ...
        'computepower',     compute_power, ...
        'linefreqs',        freqs, ...
        'normSpectrum',     norm_spectrum, ...
        'p',                p_value, ...
        'pad',              pad_val, ...
        'plotfigures',      0, ...
        'scanforlines',     double(scanforlines), ...
        'sigtype',          'Channels', ...
        'taperbandwidth',   taperbandwidth_hz, ...
        'tau',              tau_val, ...
        'verb',             double(verbose_flag), ...
        'winsize',          winsize_sec, ...
        'winstep',          winstep_sec);

    EEG.data(subset_indices, :) = EEG_tmp.data;
    did_apply = true;

catch me
    EEG.data = original_data;
    did_apply = false;
    warning('apply_pop_cleanline_to_subset failed: %s', me.message);
end

EEG = eeg_checkset(EEG);
end

function [EEG, did_apply] = apply_jointprob_safely_impl(EEG, local_threshold, global_threshold)
did_apply = false;

if EEG.nbchan < 2
    return;
end

try
    if isfield(EEG, 'chanlocs') && isfield(EEG.chanlocs, 'type')
        types = lower(string({EEG.chanlocs.type}));
        candidate_mask = (types == "eeg") | (types == "eog");
        candidate_idx  = find(candidate_mask);
    else
        candidate_idx = 1:EEG.nbchan;
    end

    if numel(candidate_idx) < 2
        return;
    end

    data_2d = double(reshape(EEG.data(candidate_idx, :, :), numel(candidate_idx), []));
    chan_var = var(data_2d, 0, 2);

    valid_mask = isfinite(chan_var) & (chan_var > 0);
    valid_idx_local = find(valid_mask);

    if numel(valid_idx_local) < 2
        return;
    end

    valid_idx = candidate_idx(valid_idx_local);

    EEG = pop_jointprob(EEG, 1, valid_idx, local_threshold, global_threshold, 0, 1, 0, [], 0);
    EEG = eeg_checkset(EEG);
    did_apply = true;

catch me
    EEG = append_eeg_comment_impl(EEG, sprintf('ica-prep: pop_jointprob failed: %s', me.message));
    did_apply = false;
end
end

function [EEG, info] = reject_ica_prep_epochs_by_mad_variance_impl(EEG, chan_idx, z_thresh, use_logvar)
info = struct();
info.did_apply       = false;
info.z_thresh        = z_thresh;
info.n_before        = EEG.trials;
info.n_rejected      = 0;
info.rejected_epochs = [];

if EEG.trials < 2 || isempty(chan_idx)
    return;
end

X = double(EEG.data(chan_idx, :, :));
n_chan  = size(X, 1);
n_epoch = size(X, 3);

v = zeros(n_chan, n_epoch);
for e = 1:n_epoch
    v(:, e) = var(X(:, :, e), 0, 2);
end

if use_logvar
    v = log10(v + eps);
end

z = zeros(size(v));

for c = 1:n_chan
    x_c  = v(c, :);
    med  = median(x_c);
    madv = median(abs(x_c - med));
    denom = (1.4826 * madv) + eps;
    z(c, :) = (x_c - med) ./ denom;
end

bad_epoch_mask = any(abs(z) > z_thresh, 1);
bad_epochs = find(bad_epoch_mask);

if isempty(bad_epochs)
    return;
end

EEG = pop_rejepoch(EEG, bad_epoch_mask, 0);
EEG = eeg_checkset(EEG);

if ~isfield(EEG, 'etc') || isempty(EEG.etc)
    EEG.etc = struct();
end

EEG.etc.ica_prep_mad_rejection = struct();
EEG.etc.ica_prep_mad_rejection.z_thresh = z_thresh;
EEG.etc.ica_prep_mad_rejection.use_logvar = use_logvar;
EEG.etc.ica_prep_mad_rejection.rejected_epochs = bad_epochs;

info.did_apply       = true;
info.n_rejected      = numel(bad_epochs);
info.rejected_epochs = bad_epochs;
end

function [EEG, info] = apply_shared_epoch_rejection_impl(EEG, reject_cfg)
info = struct();
info.did_apply       = false;
info.n_before        = EEG.trials;
info.n_rejected      = 0;
info.rejected_epochs = [];

if EEG.trials < 1 || ~reject_cfg.enable
    return;
end

idx_eeg = find(strcmpi({EEG.chanlocs.type}, 'EEG'));

if isempty(idx_eeg)
    return;
end

bad_faster = false(EEG.trials, 1);
bad_ptp    = false(EEG.trials, 1);

have_faster = (exist('epoch_properties', 'file') == 2);

if reject_cfg.use_faster && have_faster
    props = epoch_properties(EEG, idx_eeg);

    if ~isempty(props) && size(props, 1) ~= EEG.trials
        props = props.';
    end

    if size(props, 1) == EEG.trials
        if reject_cfg.use_robust_z
            med = median(props, 1, 'omitnan');
            madv = median(abs(props - med), 1, 'omitnan');
            denom = 1.4826 .* madv;
            denom(denom == 0 | isnan(denom)) = Inf;
            zmat = (props - med) ./ denom;
        else
            mu = mean(props, 1, 'omitnan');
            sd = std(props, 0, 1, 'omitnan');
            sd(sd == 0 | isnan(sd)) = Inf;
            zmat = (props - mu) ./ sd;
        end

        bad_faster = any(abs(zmat) > reject_cfg.faster_z, 2);
    end
end

if reject_cfg.use_ptp
    data = double(EEG.data(idx_eeg, :, :));
    ptp  = squeeze(max(data, [], 2) - min(data, [], 2));
    bad_ptp = any(ptp > reject_cfg.ptp_uV_thresh, 1)';
end

bad = bad_faster | bad_ptp;
bad_epochs = find(bad);

if ~isempty(bad_epochs)
    EEG = pop_rejepoch(EEG, bad_epochs, 0);
    EEG = eeg_checkset(EEG);
end

info.did_apply       = true;
info.n_rejected      = numel(bad_epochs);
info.rejected_epochs = bad_epochs;
end

function r = compute_data_rank_svd_impl(X)
% Robust numerical rank via SVD with explicit tolerance.
% X is expected to be [channels x samples].

if nargin < 1 || isempty(X)
    r = 0;
    return;
end

X = double(X);

if any(~isfinite(X(:)))
    % Conservative fallback if the data contain invalid values.
    r = size(X, 1);
    return;
end

% Center per channel to reduce mean-offset effects.
X = X - mean(X, 2);

s = svd(X, 'econ');

if isempty(s)
    r = 0;
    return;
end

tol = max(size(X)) * eps(max(s)) * max(s);
r = sum(s > tol);

% Safety clamp
r = min(r, size(X, 1));
end

function outdir = make_unique_amica_tmpdir_impl(step_cfg, subj_label, run_base)
% Create and return a unique AMICA temp directory for one subject/run.

if isfield(step_cfg, 'amica_tmp_root') && strlength(string(step_cfg.amica_tmp_root)) > 0
    rootdir = char(string(step_cfg.amica_tmp_root));
else
    rootdir = tempdir;
end

ensure_dir_impl(rootdir);

subj_label = sanitize_filename_impl(subj_label);
run_base   = sanitize_filename_impl(run_base);

tmp_stub = tempname(rootdir);
[~, tmp_base] = fileparts(tmp_stub);

folder_name = sprintf('amica_tmp_%s_%s_%s', subj_label, run_base, tmp_base);
outdir = fullfile(rootdir, folder_name);

if exist(outdir, 'dir') ~= 7
    mkdir(outdir);
end
end

function safe_rmdir_impl(folder_path)
folder_path = char(string(folder_path));

if isempty(folder_path)
    return;
end

if exist(folder_path, 'dir') == 7
    try
        rmdir(folder_path, 's');
    catch
        % Do not crash pipeline on tmp cleanup failure.
    end
end
end

function s = sanitize_filename_impl(s)
s = char(string(s));
s = strtrim(s);

if isempty(s)
    s = 'x';
    return;
end

s = regexprep(s, '[^\w\-]', '_');
end

function write_ic_topography_pngs_impl(EEG, ic_list, out_dir, file_prefix, tag, topo_cfg, classif)
if isempty(ic_list)
    return;
end

ensure_dir_impl(out_dir);

if isfield(EEG, 'icachansind') && ~isempty(EEG.icachansind)
    chanlocs_ica = EEG.chanlocs(EEG.icachansind);
else
    chanlocs_ica = EEG.chanlocs(1:size(EEG.icawinv, 1));
end

for ii = 1:numel(ic_list)
    ic = ic_list(ii);

    fig = figure('Visible', 'off', 'Color', 'w');
    ax = axes(fig); %#ok<LAXES>
    axis(ax, 'off');

    try
        topoplot(EEG.icawinv(:, ic), chanlocs_ica, ...
            'electrodes', topo_cfg.ic_topo_electrodes);

        if nargin >= 7 && ~isempty(classif) && size(classif, 2) >= 7
            ttl = sprintf([ ...
                '%s | IC %d (B %.2f M %.2f E %.2f H %.2f L %.2f C %.2f O %.2f) -> %s'], ...
                file_prefix, ic, ...
                classif(ic, 1), classif(ic, 2), classif(ic, 3), ...
                classif(ic, 4), classif(ic, 5), classif(ic, 6), ...
                classif(ic, 7), upper(tag));
        else
            ttl = sprintf('%s | IC %d -> %s', file_prefix, ic, upper(tag));
        end

        title(ttl, 'Interpreter', 'none', 'FontSize', 13);

    catch me_plot
        clf(fig);
        axis off;
        text(0, 0.5, sprintf('%s | IC %d\nCould not plot:\n%s', ...
            file_prefix, ic, me_plot.message), ...
            'Interpreter', 'none');
    end

    png_name = sprintf('%s_IC%03d_%s.png', file_prefix, ic, tag);
    png_path = fullfile(out_dir, png_name);

    set(fig, ...
        'PaperUnits', 'centimeters', ...
        'PaperPosition', topo_cfg.ic_topo_fig_cm);

    print(fig, png_path, '-dpng', sprintf('-r%d', topo_cfg.ic_topo_dpi));
    close(fig);
end
end

function target_events = normalize_event_list_impl(event_list)
target_events = strings(0,1);

if isempty(event_list)
    return;
end

if ischar(event_list) || isstring(event_list)
    event_list = cellstr(string(event_list));
end

for i = 1:numel(event_list)
    tok = string(normalize_trigger_type_impl(event_list{i}));
    if strlength(tok) > 0
        target_events(end+1,1) = tok; %#ok<AGROW>
    end
end

target_events = unique(target_events, 'stable');
end

function present_events = get_present_events_impl(EEG, target_events)
present_events = strings(0,1);

if ~isfield(EEG, 'event') || isempty(EEG.event)
    return;
end

all_types = strings(0,1);
for k = 1:numel(EEG.event)
    tok = string(normalize_trigger_type_impl(EEG.event(k).type));
    if tok == "boundary" || strlength(tok) == 0
        continue;
    end
    all_types(end+1,1) = tok; %#ok<AGROW>
end

all_types = unique(all_types, 'stable');
present_events = intersect(target_events, all_types, 'stable');
end

function preview = preview_event_types_impl(EEG, n_max)
preview = strings(0,1);

if nargin < 2 || isempty(n_max)
    n_max = 25;
end

if ~isfield(EEG, 'event') || isempty(EEG.event)
    return;
end

all_types = strings(0,1);
for k = 1:numel(EEG.event)
    tok = string(normalize_trigger_type_impl(EEG.event(k).type));
    if tok == "boundary" || strlength(tok) == 0
        continue;
    end
    all_types(end+1,1) = tok; %#ok<AGROW>
end

all_types = unique(all_types, 'stable');
preview = all_types(1:min(n_max, numel(all_types)));
end

function row = build_step06_summary_row_impl( ...
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

shared_enable   = false;
shared_faster_z = NaN;
shared_ptp      = NaN;
shared_robust   = false;

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


% =========================================================================
% BEHAVIOR LOG HELPERS
% =========================================================================
function beh_file = find_behavior_log_impl(path_bids_root, subj_id, session_label)
if nargin < 3 || isempty(session_label)
    session_label = "01";
end

session_label = char(string(session_label));
subj_label    = sprintf('sub-%s', subj_id);
ses_label     = sprintf('ses-%s', session_label);

beh_dir = fullfile(path_bids_root, subj_label, ses_label, 'beh');

if exist(beh_dir, 'dir') ~= 7
    error('No beh directory: %s', beh_dir);
end

cands = [dir(fullfile(beh_dir, '*.log')); dir(fullfile(beh_dir, '*.txt'))];

if isempty(cands)
    error('No .log/.txt files in %s', beh_dir);
end

scores = zeros(numel(cands), 1);

for k = 1:numel(cands)
    name_lower = lower(cands(k).name);

    % Strong preference for BIDS-style subject/session naming.
    if contains(name_lower, lower(subj_label))
        scores(k) = scores(k) + 100;
    end

    if contains(name_lower, lower(ses_label))
        scores(k) = scores(k) + 50;
    end

    % Prefer files that explicitly look like behavior files.
    if contains(name_lower, '_beh.')
        scores(k) = scores(k) + 30;
    end

    % Mild preference for task-tagged BIDS files.
    if contains(name_lower, 'task-')
        scores(k) = scores(k) + 10;
    end

    % Mild preference for .log over .txt.
    if endsWith(name_lower, '.log')
        scores(k) = scores(k) + 5;
    end

    % Small backward-compatibility bonus for legacy naming.
    if contains(name_lower, 'cf_')
        scores(k) = scores(k) + 1;
    end
end

meta = [scores(:), vertcat(cands.datenum)];
[~, order] = sortrows(meta, [-1 -2]);

best = cands(order(1));
beh_file = fullfile(best.folder, best.name);
end

function beh = read_behavior_log_impl(beh_file)
raw_text = fileread(beh_file);
lines = regexp(raw_text, '\r\n|\n|\r', 'split');

header_idx = 0;
for i = 1:numel(lines)
    if startsWith(strtrim(lines{i}), 'Subject')
        header_idx = i;
        break;
    end
end

tmp_file = [tempname '.txt'];
fid = fopen(tmp_file, 'w');

if fid < 0
    error('Could not create temporary file for behavior-log import.');
end

if header_idx > 0
    for i = header_idx:numel(lines)
        fprintf(fid, '%s\n', lines{i});
    end
else
    for i = 1:numel(lines)
        fprintf(fid, '%s\n', lines{i});
    end
end

fclose(fid);

try
    opts = detectImportOptions(tmp_file, 'FileType', 'text');
catch
    opts = detectImportOptions(tmp_file, 'Delimiter', '\t', 'FileType', 'text');
end

T = readtable(tmp_file, opts);
delete(tmp_file);

T.Properties.VariableNames = matlab.lang.makeValidName(T.Properties.VariableNames);
beh = T;
end

% =========================================================================
% RAW QC WRITER
% =========================================================================
function [ok, rep] = check_subsequence_order_detailed_impl(beh_tokens, eeg_tokens)
i = 1; j = 1;
lastMatchEegIdx = 0;

while i <= numel(beh_tokens) && j <= numel(eeg_tokens)
    if beh_tokens(i) == eeg_tokens(j)
        lastMatchEegIdx = j;
        i = i + 1;
        j = j + 1;
    else
        j = j + 1;
    end
end

ok = (i > numel(beh_tokens));

rep = struct();
rep.last_match_eeg_idx = lastMatchEegIdx;

if ok
    rep.summary = sprintf('OK: %d behavior tokens found in EEG stream (in-order subsequence).', numel(beh_tokens));
    rep.missing_token = "";
    rep.beh_i = NaN;
    rep.beh_ctx = strings(0,1);
    rep.eeg_ctx = strings(0,1);
    rep.beh_ctx_i1 = NaN; rep.beh_ctx_i2 = NaN;
    rep.eeg_ctx_j1 = NaN; rep.eeg_ctx_j2 = NaN;
    return;
end

rep.missing_token = beh_tokens(i);
rep.beh_i = i;

rep.beh_ctx_i1 = max(1, i-10);
rep.beh_ctx_i2 = min(numel(beh_tokens), i+10);
rep.beh_ctx = beh_tokens(rep.beh_ctx_i1:rep.beh_ctx_i2);

rep.eeg_ctx_j1 = max(1, lastMatchEegIdx-10);
rep.eeg_ctx_j2 = min(numel(eeg_tokens), lastMatchEegIdx+30);
rep.eeg_ctx = eeg_tokens(rep.eeg_ctx_j1:rep.eeg_ctx_j2);
end

function raw_qc_behavior_vs_eeg_and_write_csv_impl(beh, EEG, subj_id, bids_base, out_dir, varargin)

arguments
    beh table
    EEG struct
    subj_id char
    bids_base char
    out_dir char
end
arguments (Repeating)
    varargin
end

opts = struct();
opts.bin_size_s                 = 1;
opts.max_rows                   = 20000;
opts.keep_tokens                = ["S 20","S 21","S 22","S 23","S 24","S 15","S 5"];
opts.write_csv_on_ok            = false;
opts.behavior_column_event_type = "EventType";
opts.behavior_column_code       = "Code";
opts.behavior_column_time       = "Time";
opts.behavior_time_unit         = "ms";
opts.behavior_log_map           = {};
opts.raw_triggers               = struct();

if numel(varargin) == 1 && isstruct(varargin{1})
    user_opts = varargin{1};
    fields = fieldnames(user_opts);
    for k = 1:numel(fields)
        opts.(fields{k}) = user_opts.(fields{k});
    end
elseif ~isempty(varargin)
    for k = 1:2:numel(varargin)
        key = string(varargin{k});
        opts.(char(key)) = varargin{k + 1};
    end
end

ensure_dir_impl(out_dir);

[beh_tok, beh_t_s] = build_beh_key_token_stream_with_time_impl(beh, opts);
[eeg_tok, eeg_t_s] = build_eeg_key_token_stream_with_time_impl(EEG);

keep_b = ismember(beh_tok, opts.keep_tokens);
beh_tok = beh_tok(keep_b);
beh_t_s = beh_t_s(keep_b);

keep_e = ismember(eeg_tok, opts.keep_tokens);
eeg_tok = eeg_tok(keep_e);
eeg_t_s = eeg_t_s(keep_e);

if isempty(beh_tok) || isempty(eeg_tok)
    return;
end

[ok, rep] = check_subsequence_order_detailed_impl(beh_tok, eeg_tok);

if ok && ~opts.write_csv_on_ok
    return;
end

is_stim_b = ismember(beh_tok, ["S 20","S 21","S 22","S 23","S 24"]);
is_stim_e = ismember(eeg_tok, ["S 20","S 21","S 22","S 23","S 24"]);

if any(is_stim_b) && any(is_stim_e)
    t_b0 = beh_t_s(find(is_stim_b, 1, 'first'));
    t_e0 = eeg_t_s(find(is_stim_e, 1, 'first'));
    delay_s = t_e0 - t_b0;
else
    delay_s = NaN;
end

if any(is_stim_b)
    beh_rel = beh_t_s - beh_t_s(find(is_stim_b, 1, 'first'));
else
    beh_rel = beh_t_s - beh_t_s(1);
end

if any(is_stim_e)
    eeg_rel = eeg_t_s - eeg_t_s(find(is_stim_e, 1, 'first'));
else
    eeg_rel = eeg_t_s - eeg_t_s(1);
end

if ~isnan(delay_s)
    beh_rel_aligned = beh_rel + delay_s;
else
    beh_rel_aligned = beh_rel;
end

bin = opts.bin_size_s;

min_t = min([0; beh_rel_aligned; eeg_rel]);
max_t = max([beh_rel_aligned; eeg_rel]);

bin_start = floor(min_t / bin) * bin;
bin_end   = ceil(max_t / bin)  * bin;

edges = bin_start:bin:bin_end;

if numel(edges) < 2
    edges = [bin_start, bin_start + bin];
end

n_bins = numel(edges) - 1;

if n_bins > opts.max_rows
    n_bins = opts.max_rows;
    edges = edges(1:n_bins + 1);
end

beh_in_bin = cell(n_bins, 1);
eeg_in_bin = cell(n_bins, 1);
n_beh      = zeros(n_bins, 1);
n_eeg      = zeros(n_bins, 1);

for bi = 1:n_bins
    t1 = edges(bi);
    t2 = edges(bi + 1);

    idx_b = beh_rel_aligned >= t1 & beh_rel_aligned < t2;
    idx_e = eeg_rel         >= t1 & eeg_rel         < t2;

    if any(idx_b)
        beh_in_bin{bi} = strjoin(beh_tok(idx_b), '|');
        n_beh(bi) = sum(idx_b);
    else
        beh_in_bin{bi} = "";
    end

    if any(idx_e)
        eeg_in_bin{bi} = strjoin(eeg_tok(idx_e), '|');
        n_eeg(bi) = sum(idx_e);
    else
        eeg_in_bin{bi} = "";
    end
end

T = table();
T.bin_start_s  = edges(1:n_bins)';
T.bin_end_s    = edges(2:n_bins + 1)';
T.beh_events   = string(beh_in_bin);
T.eeg_events   = string(eeg_in_bin);
T.n_beh_events = n_beh;
T.n_eeg_events = n_eeg;

out_csv = fullfile(out_dir, sprintf('order_mismatch_sub-%s_%s.csv', subj_id, bids_base));

fid = fopen(out_csv, 'w');
if fid < 0
    return;
end

fprintf(fid, 'subject;%s\n', subj_id);
fprintf(fid, 'bids_base;%s\n', bids_base);
fprintf(fid, 'delay_s;%s\n', num2str(delay_s));
fprintf(fid, 'bin_size_s;%g\n', bin);
fprintf(fid, 'mismatch;%d\n', ~ok);

if ~ok
    fprintf(fid, 'first_missing_token;%s\n', rep.missing_token);
    fprintf(fid, 'beh_missing_index;%d\n', rep.beh_i);
    fprintf(fid, 'last_match_eeg_index;%d\n', rep.last_match_eeg_idx);
end

fprintf(fid, '\n');
fprintf(fid, 'bin_start_s;bin_end_s;beh_events;eeg_events;n_beh_events;n_eeg_events\n');

for r = 1:height(T)
    fprintf(fid, '%.3f;%.3f;%s;%s;%d;%d\n', ...
        T.bin_start_s(r), T.bin_end_s(r), ...
        escape_semicolons_impl(T.beh_events(r)), ...
        escape_semicolons_impl(T.eeg_events(r)), ...
        T.n_beh_events(r), T.n_eeg_events(r));
end

fclose(fid);
end

function s = escape_semicolons_impl(s)
s = string(s);
s = replace(s, ";", ",");
end

function [tokens, times_s] = build_beh_key_token_stream_with_time_impl(beh, opts)
vars = string(beh.Properties.VariableNames);

col_event = string(opts.behavior_column_event_type);
col_code  = string(opts.behavior_column_code);
col_time  = string(opts.behavior_column_time);

required = [col_event, col_code, col_time];

if ~all(ismember(required, vars))
    error(['Behavior log missing required columns. Required: %s | Found: %s'], ...
        strjoin(required, ', '), strjoin(vars, ', '));
end

n_rows = height(beh);
time_s_all = nan(n_rows, 1);

time_col = beh.(char(col_time));

for r = 1:n_rows
    time_s_all(r) = convert_behavior_time_to_seconds_impl( ...
        time_col(r), opts.behavior_time_unit);
end

[~, ix] = sort(time_s_all);
beh = beh(ix, :);
time_s_all = time_s_all(ix);

tokens  = strings(0, 1);
times_s = zeros(0, 1);

map_table = opts.behavior_log_map;
if isempty(map_table)
    return;
end

event_col = beh.(char(col_event));
code_col  = beh.(char(col_code));

for r = 1:height(beh)
    event_type = string(event_col(r));
    code       = string(code_col(r));
    t          = time_s_all(r);

    for m = 1:size(map_table, 1)
        map_event = string(map_table{m,1});
        map_code  = string(map_table{m,2});
        map_ref   = string(map_table{m,3});

        if behavior_value_matches_impl(event_type, map_event) && ...
           behavior_value_matches_impl(code, map_code)

            raw_token = get_raw_trigger_from_key_impl(opts.raw_triggers, map_ref);

            if ~isempty(raw_token)
                tokens(end+1, 1)  = string(raw_token); %#ok<AGROW>
                times_s(end+1, 1) = t;                %#ok<AGROW>
            end
            break;
        end
    end
end
end

function t_s = convert_behavior_time_to_seconds_impl(time_raw, time_unit)
if iscell(time_raw)
    time_raw = time_raw{1};
end

if isstring(time_raw) || ischar(time_raw)
    t_num = str2double(strrep(char(string(time_raw)), ',', '.'));
else
    t_num = double(time_raw);
end

if isnan(t_num)
    error('Behavior-log time value could not be converted to numeric seconds/ms.');
end

switch lower(char(string(time_unit)))
    case {'ms','millisecond','milliseconds'}
        t_s = t_num / 1000;
    case {'s','sec','second','seconds'}
        t_s = t_num;
    otherwise
        error('Unsupported behavior_log_time_unit: %s', string(time_unit));
end
end

function tf = behavior_value_matches_impl(value, pattern)
value   = lower(strtrim(char(string(value))));
pattern = lower(strtrim(char(string(pattern))));

value   = regexprep(value, '\s+', ' ');
pattern = regexprep(pattern, '\s+', ' ');

if strcmp(pattern, '*')
    tf = true;
else
    tf = strcmp(value, pattern);
end
end

% function token = resolve_raw_trigger_from_key_impl(ref, raw_triggers)
% ref = string(ref);
% 
% if strlength(ref) == 0
%     token = "";
%     return;
% end
% 
% if isstruct(raw_triggers) && isfield(raw_triggers, char(ref))
%     token = string(normalize_trigger_type_impl(raw_triggers.(char(ref))));
% else
%     token = string(normalize_trigger_type_impl(ref));
% end
% end
% in case missing this function causes an error anywhere: call
% get_raw_trigger_from_key_impl instead

