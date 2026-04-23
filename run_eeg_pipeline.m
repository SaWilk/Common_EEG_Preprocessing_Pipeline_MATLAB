% =========================================================================
% FILE: run_eeg_pipeline.m
% =========================================================================
function run_eeg_pipeline(config_spec, varargin)
% RUN_EEG_PIPELINE Unified EEG preprocessing runner.
%
% WHAT THIS SCRIPT DOES
%   - Loads all user-facing settings from eeg_pipeline_config.m
%   - Initializes toolboxes
%   - Discovers subjects or uses explicitly requested subjects
%   - Preplans step execution using folder-based overwrite logic
%   - Runs enabled preprocessing steps serially or in parallel
%   - Writes one master log and one subject log per subject
%
% INPUT
%   Required:
%     - eeg_pipeline_config.m in the same folder
%     - eeg_pipeline_helpers.m on the MATLAB path
%     - external step functions on the MATLAB path or in ./steps
%
%   Optional call-time subject override:
%     run_eeg_pipeline('211','212','213')
%     run_eeg_pipeline({'211','212','213'})
%
% OUTPUT
%   - Step 01 BIDS raw output under cfg.paths.bids_root
%   - Steps 02-06 derivatives under cfg.paths.derivatives_root
%   - Logs under <runner_folder>/logs/runlog_pipeline/
%
% NOTES
%   - The user should normally edit ONLY eeg_pipeline_config.m
%   - This runner intentionally stays thin and delegates utilities to
%     eeg_pipeline_helpers.m
%
% REQUIREMENTS
%   - EEGLAB
%   - FASTER
%   - (AMICA - optional)
%   - (cleanline - optional)
%
% Saskia Wilken Dez 2025

% =========================================================================
% ROOT / PATH SETUP
% =========================================================================
this_file = mfilename('fullpath');
root_dir  = fileparts(this_file);
steps_dir = fullfile(root_dir, 'steps');

addpath(root_dir);

if exist(steps_dir, 'dir') ~= 7
    error('Steps directory not found: %s', steps_dir);
end
addpath(steps_dir);

if exist('eeg_pipeline_helpers', 'file') ~= 2
    error('Helper file not found on path. Expected in root or steps: %s | %s', root_dir, steps_dir);
end

if nargin < 1 || isempty(config_spec)
    error(['You must pass the config function as first argument, e.g. ' ...
        'run_eeg_pipeline(''eeg_pipeline_config_baseline'').']);
end

% =========================================================================
% RESOLVE CONFIG FUNCTION
% =========================================================================
[config_fn, config_name, config_file] = resolve_config_function_local(config_spec, root_dir);

% =========================================================================
% LOAD CONFIG
% =========================================================================
cfg = config_fn();

cfg.runner_file     = this_file;
cfg.runner_root_dir = root_dir;
cfg.config_name     = string(config_name);
cfg.config_file     = string(config_file);

if nargin > 1
    subject_args = varargin;

    if numel(subject_args) == 1 && iscell(subject_args{1})
        cfg.subjects.list = subject_args{1};
    else
        cfg.subjects.list = subject_args;
    end

    cfg.subjects.min_id = [];
end

% =========================================================================
% MASTER LOG
% =========================================================================
if ~isfield(cfg.paths, 'logs_dir') || strlength(string(cfg.paths.logs_dir)) == 0
    cfg.paths.logs_dir = fullfile(cfg.root_dir, 'logs', 'runlog_pipeline');
end

logs_dir = char(string(cfg.paths.logs_dir));
if exist(logs_dir, 'dir') ~= 7
    mkdir(logs_dir);
end

master_log = fullfile( ...
    logs_dir, ...
    sprintf('%s_%s.log', ...
        char(string(cfg.constants.log_prefix_master)), ...
        datestr(now, char(string(cfg.constants.datestr_master)))));

helpers = eeg_pipeline_helpers(master_log);

% =========================================================================
% PIPELINE NAME
% =========================================================================
pipeline_name = "unnamed_pipeline";
if isfield(cfg, 'pipeline') && isfield(cfg.pipeline, 'name') && ...
        strlength(string(cfg.pipeline.name)) > 0
    pipeline_name = string(cfg.pipeline.name);
end

% =========================================================================
% RUN HEADER
% =========================================================================
helpers.log_msg(master_log, '=== PIPELINE START %s ===', datestr(now));
helpers.log_msg(master_log, 'pipeline_name    : %s', char(pipeline_name));
helpers.log_msg(master_log, 'config_name      : %s', char(string(cfg.config_name)));
helpers.log_msg(master_log, 'config_file      : %s', char(string(cfg.config_file)));
helpers.log_msg(master_log, 'step_prefix      : %s', char(string(cfg.pipeline.step_prefix)));
helpers.log_msg(master_log, 'runner_root_dir  : %s', root_dir);
helpers.log_msg(master_log, 'steps_dir        : %s', steps_dir);
helpers.log_msg(master_log, 'env_mode         : %s', char(string(cfg.env.mode)));
helpers.log_msg(master_log, 'machine_kind     : %s', char(string(cfg.env.machine_kind)));
helpers.log_msg(master_log, 'hostname         : %s', char(string(cfg.env.hostname)));
helpers.log_msg(master_log, ...
    'is_slurm         : %d | SLURM_JOB_ID=%s | SLURM_CLUSTER_NAME=%s', ...
    cfg.env.is_slurm, ...
    char(string(cfg.env.slurm_job_id)), ...
    char(string(cfg.env.slurm_cluster)));
helpers.log_msg(master_log, 'profile          : %s', char(string(cfg.paths.profile)));
helpers.log_msg(master_log, 'source_eeg_root  : %s', char(string(cfg.paths.source_eeg_root)));
helpers.log_msg(master_log, 'source_beh_root  : %s', char(string(cfg.paths.source_beh_root)));
helpers.log_msg(master_log, 'bids_root        : %s', char(string(cfg.paths.bids_root)));
helpers.log_msg(master_log, 'derivatives_root : %s', char(string(cfg.paths.derivatives_root)));
helpers.log_msg(master_log, 'task_label       : %s', char(string(cfg.bids.task_label)));
helpers.log_msg(master_log, 'session_label    : %s', char(string(cfg.bids.session_label)));
helpers.log_msg(master_log, 'overwrite_mode   : %s', char(string(cfg.io.overwrite_mode)));
helpers.log_msg(master_log, 'overwrite_date   : %s', char(string(cfg.io.overwrite_if_older_than)));

helpers.log_msg(master_log, ...
    'step05 iclabel: eye=%.2f mus=%.2f heart=%.2f line=%.2f ch=%.2f other=%.2f brain_min=%.2f edge=%.2f', ...
    cfg.prep_05.iclabel_eye_remove_thr, ...
    cfg.prep_05.iclabel_muscle_remove_thr, ...
    cfg.prep_05.iclabel_heart_remove_thr, ...
    cfg.prep_05.iclabel_linenoise_remove_thr, ...
    cfg.prep_05.iclabel_channoise_remove_thr, ...
    cfg.prep_05.iclabel_other_remove_thr, ...
    cfg.prep_05.iclabel_brain_min_keep_thr, ...
    cfg.prep_05.iclabel_edge_margin);

helpers.log_msg(master_log, ...
    ['step06: mode=%s | ref=%s | epoch=[%.3f %.3f] s | hard_thresh_apply=%d | hard_thresh=%.1f uV | ' ...
     'baseline_apply=%d | baseline=[%d %d] ms | max_reject_prop=%.3f'], ...
    char(string(cfg.prep_06.epoching_mode)), ...
    char(string(cfg.prep_06.reference_mode)), ...
    cfg.prep_06.epoch_start_s, ...
    cfg.prep_06.epoch_end_s, ...
    cfg.prep_06.do_initial_hard_threshold_rejection, ...
    cfg.prep_06.initial_hard_threshold_uv, ...
    cfg.prep_06.do_baseline_correction, ...
    cfg.prep_06.base_start_ms, ...
    cfg.prep_06.base_end_ms, ...
    cfg.prep_06.max_reject_prop);

% =========================================================================
% MASTER TOOLBOX INIT
% =========================================================================
helpers.init_toolboxes(cfg);
helpers.log_msg(master_log, 'Toolboxes initialized (master).');

% =========================================================================
% SUBJECT DISCOVERY
% =========================================================================
sub_ids = helpers.discover_subjects(cfg);
helpers.log_msg(master_log, 'Found %d subject(s).', numel(sub_ids));

% =========================================================================
% PARALLEL SETUP
% =========================================================================
use_parallel      = helpers.resolve_parallel_enable(cfg);
pool_obj          = [];
pool_started_here = false;

if use_parallel
    if isempty(getenv('MATLAB_PREFDIR'))
        pref_dir = fullfile(tempdir, 'matlab_prefs');
        setenv('MATLAB_PREFDIR', pref_dir);
        if exist(pref_dir, 'dir') ~= 7
            mkdir(pref_dir);
        end
    end

    n_workers = helpers.resolve_worker_count(cfg, master_log);
    helpers.log_msg(master_log, 'Parallel requested (%d workers).', n_workers);

    try
        pool_obj = gcp('nocreate');

        if isempty(pool_obj)
            parpool('local', n_workers);
            pool_obj = gcp('nocreate');
            pool_started_here = true;
        end

        cfg.parallel.pool_is_thread = false;
        cfg.parallel.pool_type      = "none";

        if ~isempty(pool_obj)
            cfg.parallel.pool_is_thread = isa(pool_obj, 'parallel.ThreadPool');
            cfg.parallel.pool_type      = string(class(pool_obj));
        end

        helpers.log_msg(master_log, ...
            'Parallel pool type: %s | thread_based=%d', ...
            char(string(cfg.parallel.pool_type)), ...
            cfg.parallel.pool_is_thread);

        if ~isempty(pool_obj) && ~cfg.parallel.pool_is_thread
            try
                cmd_root  = sprintf('addpath(''%s'');', strrep(root_dir,  '''', ''''''));
                cmd_steps = sprintf('addpath(''%s'');', strrep(steps_dir, '''', ''''''));

                pctRunOnAll(cmd_root);
                pctRunOnAll(cmd_steps);
                helpers.log_msg(master_log, 'Worker paths updated: root + steps');
            catch me_path
                helpers.log_msg(master_log, ...
                    'WARNING: Could not push paths to workers (%s). Continuing.', ...
                    me_path.message);
            end
        end

        if cfg.parallel.pool_is_thread
            helpers.log_msg(master_log, ...
                'Thread pool detected -> initializing EEGLAB in master.');

            if cfg.toolboxes.eeglab.nogui
                if cfg.env.mode == "hpc" && cfg.toolboxes.eeglab.no_update_check_on_hpc
                    try
                        setpref('eeglab', 'plugin_update_check', 0);
                        setpref('eeglab', 'update_check', 0);
                        setpref('eeglab', 'version_check', 0);
                    catch me_pref
                        helpers.log_msg(master_log, ...
                            'WARNING: setpref failed (%s). Continuing.', ...
                            me_pref.message);
                    end
                end
                eeglab('nogui');
            else
                eeglab;
            end

            helpers.log_msg(master_log, 'EEGLAB initialized (master, thread pool).');
        end

    catch me_pool
        if helpers.is_parallel_license_error(me_pool)
            helpers.log_msg(master_log, ...
                'WARNING: Parallel license unavailable. Falling back to serial. (%s)', ...
                me_pool.message);
        else
            helpers.log_msg(master_log, ...
                'WARNING: Could not start parallel pool. Falling back to serial. (%s)', ...
                me_pool.message);
        end

        try
            pool_obj = gcp('nocreate');
            if ~isempty(pool_obj) && pool_started_here
                delete(pool_obj);
            end
        catch
        end

        use_parallel                = false;
        cfg.parallel.enable         = false;
        cfg.parallel.pool_is_thread = false;
        cfg.parallel.pool_type      = "none";
        pool_obj                    = [];
        pool_started_here           = false;
    end
else
    helpers.log_msg(master_log, 'Parallel disabled (serial run).');
    cfg.parallel.pool_is_thread = false;
    cfg.parallel.pool_type      = "none";
end

% =========================================================================
% AMICA ON HPC -> FORCE SERIAL
% =========================================================================
force_serial_due_to_amica = ...
    use_parallel && ...
    (cfg.env.mode == "hpc") && ...
    cfg.steps.prep_04_ica.run && ...
    (string(cfg.prep_04.ica_method) == "amica");

if force_serial_due_to_amica
    helpers.log_msg(master_log, ...
        'HPC + AMICA subject loop -> forcing serial execution.');

    use_parallel                = false;
    cfg.parallel.enable         = false;
    cfg.parallel.pool_is_thread = false;
    cfg.parallel.pool_type      = "none";

    if ~isempty(pool_obj) && pool_started_here
        try
            delete(pool_obj);
            helpers.log_msg(master_log, 'Closed pool that was started for parallel execution.');
        catch me_close
            helpers.log_msg(master_log, ...
                'WARNING: Could not close pool after forcing serial mode (%s).', ...
                me_close.message);
        end
        pool_obj = [];
        pool_started_here = false;
    end
end

% =========================================================================
% PREPLAN
% =========================================================================
subject_plans = helpers.build_subject_plans(cfg, sub_ids, master_log);

keep_mask = arrayfun(@(x) x.any_step_to_run, subject_plans);
subject_plans = subject_plans(keep_mask);

helpers.log_msg(master_log, ...
    'Planning complete: %d/%d subject(s) require work.', ...
    numel(subject_plans), numel(sub_ids));

subject_plans = helpers.sort_subject_plans_by_expected_cost(subject_plans);

% =========================================================================
% EXECUTION
% =========================================================================
n_sub = numel(subject_plans);
status = repmat(struct('subj', '', 'ok', false, 'message', '', 'logfile', ''), n_sub, 1);

if n_sub == 0
    helpers.log_msg(master_log, '=== PIPELINE END %s ===', datestr(now));
    helpers.log_msg(master_log, 'No subjects required work. Nothing to do.');
    return;
end

if use_parallel
    parfor i = 1:n_sub
        status(i) = helpers.run_one_subject(subject_plans(i), cfg); %#ok<PFOUS>
    end
else
    for i = 1:n_sub
        status(i) = helpers.run_one_subject(subject_plans(i), cfg);
    end
end

% =========================================================================
% FINAL SUMMARY
% =========================================================================
ok_mask = [status.ok];
n_ok    = sum(ok_mask);
n_fail  = sum(~ok_mask);

helpers.log_msg(master_log, '=== PIPELINE END %s ===', datestr(now));
helpers.log_msg(master_log, 'Completed: %d ok | %d failed', n_ok, n_fail);

if n_fail > 0
    helpers.log_msg(master_log, 'Failed subjects:');
    for k = find(~ok_mask)
        helpers.log_msg(master_log, ...
            '  sub-%s | %s | log=%s', ...
            char(string(status(k).subj)), ...
            char(string(status(k).message)), ...
            char(string(status(k).logfile)));
    end
    error('Pipeline finished with failures (%d/%d). See logs.', n_fail, n_sub);
end

end

function [config_fn, config_name, config_file] = resolve_config_function_local(config_spec, root_dir)
config_file = "";

if isa(config_spec, 'function_handle')
    config_fn   = config_spec;
    config_name = func2str(config_spec);
    config_file = which(config_name);
    return;
end

config_text = char(string(config_spec));
config_text = strtrim(config_text);

if isempty(config_text)
    error('Config argument is empty.');
end

config_dir = '';
[maybe_dir, maybe_name, maybe_ext] = fileparts(config_text);

if ~isempty(maybe_dir)
    config_dir  = maybe_dir;
    config_name = maybe_name;
else
    config_name = config_text;
    if endsWith(config_name, '.m', 'IgnoreCase', true)
        [~, config_name] = fileparts(config_name);
    end
end

if ~isempty(config_dir)
    if exist(config_dir, 'dir') ~= 7
        error('Config directory not found: %s', config_dir);
    end
    addpath(config_dir);
end

if exist(config_name, 'file') ~= 2
    candidate_in_root = fullfile(root_dir, [config_name '.m']);
    if exist(candidate_in_root, 'file') == 2
        addpath(root_dir);
    end
end

if exist(config_name, 'file') ~= 2
    if ~isempty(maybe_ext)
        error('Config file not found: %s', config_text);
    else
        error('Config function not found on path: %s', config_name);
    end
end

config_fn   = str2func(config_name);
config_file = which(config_name);

if isempty(config_file)
    error('Could not resolve config function file for: %s', config_name);
end
end